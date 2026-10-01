-- HD2-Addon: mods/codex/s11_solo_spear
-- S-11 Speargun Solo Enhanced Menu v1.3.0
--
-- Changes on Steam build 25480438 / EXE 1.8.46015.0:
--   Direct damage       650 -> 1800
--   Durable damage      275 -> 1800
--   Armor penetration   AP5 -> AP6 at all impact angles
--   Spare rounds        12 -> 24
--   S-11 gas profile is promoted to MK2: gas duration 6 -> 10 s and confusion 5 -> 9 s. Other gas weapons are unaffected. Reload remains unchanged.
--
-- Requires Bingus Shared Loader v18+ and Mod Options Menu v1.1 / API 1.
-- Values are configurable through ESC > MODS; defaults match v1.2.0.

local MOD = {
    id = 'mods/codex/s11_solo_spear',
    global = 'CodexS11SoloSpear',
    title = 'S-11 Speargun Solo Enhanced',
    version = '1.3.0',
    author = 'Codex',
    log = 'S11SoloSpear.log',
    targets = {
        {
            label = 'impact damage and penetration', table = 0xE0A72CF0, stride = 76,
            row_id = 63,
            edits = {
                { offset = 4, kind = 'u32', value = 1800, max = 100000, expected = 650 },
                { offset = 8, kind = 'u32', value = 1800, max = 100000, expected = 275 },
                { offset = 12, kind = 'u32', value = 6, max = 100, expected = 5 },
                { offset = 16, kind = 'u32', value = 6, max = 100, expected = 5 },
                { offset = 20, kind = 'u32', value = 6, max = 100, expected = 5 },
                { offset = 24, kind = 'u32', value = 6, max = 100, expected = 5 },
                { offset = 44, kind = 'u32', value = 43, max = 100, expected = 42 },
                { offset = 52, kind = 'u32', value = 45, max = 100, expected = 44 },
            },
        },
        {
            label = 'extended gas and confusion duration', table = 0xE0A72CF0, stride = 76,
            row_id = 64,
            edits = {
                { offset = 44, kind = 'u32', value = 43, max = 100, expected = 42 },
                { offset = 52, kind = 'u32', value = 45, max = 100, expected = 44 },
            },
        },
        {
            label = 'spare rounds', table = 0xFB8D88A3, stride = 160,
            entity = { hi = 0x3828E205, lo = 0x1AA9E897 },
            edits = {
                { offset = 144, kind = 'u32', value = 24, max = 1000 },
                { offset = 148, kind = 'u32', value = 24, max = 1000 },
            },
        },
    },
}

-- ================================================================ tuning engine
-- Shared by every SHODAN tuning mod; the MOD table above says what to change.
--
-- The game lays its settings tables down in memory as LDLD blocks. Keyed tables hold a
-- bucket array (u64 entity hash, u32 record index, u32 0; always two buckets per entity)
-- followed by fixed-stride records; row tables hold a u64 descriptor and a u32 row count,
-- then fixed-stride rows that start with a unique id. Records are found from that structure
-- alone -- entity hash or row id, plus the exact record size this build uses -- never from
-- the stat values, so other mods changing the same weapon cannot stop these values from
-- being applied. The fields written must still hold plausible values beforehand; anything
-- else means the layout moved in a game update, and nothing is written.
--
-- Every write is read back and the rest of the record is checked untouched, or it is
-- rolled back. Once applied, the values are re-checked every few seconds and restored if
-- something else overwrote them. Changes live in memory only.

if rawget(_G, MOD.global) then return end

local HEADER_BYTES = 24
local MAX_PAYLOAD = 64 * 1024 * 1024
local FRAME_BUDGET = 0.0015
local CHUNK = 65536
local START_FRAME = 300
local PROBE_MIN_ALLOC = 64 * 1024
local PROBE_BYTES = 64 * 1024
local SELF_MARGIN = 4096
local MAX_ROUNDS = 12
local ROUND_DELAY_SECONDS = 10
local ENFORCE_SECONDS = 5
local MAX_UNINDEXED_RECORDS = 2  -- keyed tables carry at most this many records no entity points at
local MAX_LOG_LINES = 400

local MEM_COMMIT, MEM_PRIVATE = 0x1000, 0x20000
local PAGE_READONLY, PAGE_READWRITE = 0x02, 0x04

local state = {
    title = MOD.title, version = MOD.version, phase = 'starting', status = 'starting',
    frame = 0, rounds = 0, applied = 0, reapplied = 0, refused = 0,
}
rawset(_G, MOD.global, state)

-- ---------------------------------------------------------------- byte helpers
local function u32_bytes(value)
    value = value % 4294967296
    return string.char(value % 256,
                       math.floor(value / 256) % 256,
                       math.floor(value / 65536) % 256,
                       math.floor(value / 16777216) % 256)
end

local function u32(blob, offset)
    local a, b, c, d = blob:byte(offset + 1, offset + 4)
    if not d then return nil end
    return a + b * 256 + c * 65536 + d * 16777216
end

-- Independent decoder: bits -> number, so read-back checks never share code with the encoder.
local function bits_to_f32(bits)
    local sign = 1
    if bits >= 2147483648 then sign = -1; bits = bits - 2147483648 end
    local exp = math.floor(bits / 8388608)
    local mant = bits - exp * 8388608
    if exp == 255 then return mant == 0 and sign * math.huge or 0 / 0 end
    if exp == 0 then return mant == 0 and sign * 0.0 or sign * mant * 2 ^ -149 end
    return sign * (1 + mant / 8388608) * 2 ^ (exp - 127)
end

local function near(a, b)
    return a ~= nil and math.abs(a - b) < 1e-4
end

local NEEDLE = 'LDLD' .. u32_bytes(1)

-- ---------------------------------------------------------------- windows api
local ffi_ok, ffi = pcall(require, 'ffi')
local api = nil
local f32_bytes = nil
local REGION_TYPE = MOD.global .. 'Region'

local function build_api()
    for _, declaration in ipairs({
        'void *GetCurrentProcess(void);',
        'int ReadProcessMemory(void *process, const void *address, void *buffer, size_t size, size_t *read);',
        'int WriteProcessMemory(void *process, void *address, const void *buffer, size_t size, size_t *written);',
        'size_t VirtualQuery(const void *address, void *region, size_t size);',
        'int VirtualProtect(void *address, size_t size, uint32_t new_protection, uint32_t *old_protection);',
        'int CreateDirectoryA(const char *path, void *security);',
        'uint32_t GetLastError(void);',
    }) do
        pcall(ffi.cdef, declaration)
    end
    pcall(ffi.cdef, [[typedef struct {
        void *base; void *allocation_base; uint32_t allocation_protection;
        uint16_t partition; uint16_t reserved; size_t size;
        uint32_t state; uint32_t protection; uint32_t type;
    } ]] .. REGION_TYPE .. ';')

    local kernel = ffi.load('kernel32')
    local query = ffi.cast('size_t (*)(const void *, void *, size_t)', kernel.VirtualQuery)
    local virtual_protect = ffi.cast('int (*)(void *, size_t, uint32_t, uint32_t *)', kernel.VirtualProtect)
    local process = kernel.GetCurrentProcess()
    local region = ffi.new(REGION_TYPE .. '[1]')
    local region_size = ffi.sizeof(region[0])
    local counter = ffi.new('size_t[1]')

    local self = {}

    function self.read(address, size)
        if size <= 0 then return nil end
        local buffer = ffi.new('uint8_t[?]', size)
        if kernel.ReadProcessMemory(process, ffi.cast('const void *', address),
                                    buffer, size, counter) == 0 then return nil end
        if tonumber(counter[0]) ~= size then return nil end
        return ffi.string(buffer, size)
    end

    function self.query(address)
        if query(ffi.cast('const void *', address), region, region_size) ~= region_size then
            return nil
        end
        local base = tonumber(ffi.cast('uintptr_t', region[0].base))
        local size = tonumber(region[0].size)
        if not base or not size or size <= 0 then return nil end
        return { base = base, size = size, state = region[0].state,
                 protection = region[0].protection, kind = region[0].type }
    end

    function self.write(address, bytes)
        if #bytes <= 0 then return false end
        local info = self.query(address)
        if not info or info.state ~= MEM_COMMIT or info.kind ~= MEM_PRIVATE
            or address < info.base or address + #bytes > info.base + info.size
            or (info.protection ~= PAGE_READONLY and info.protection ~= PAGE_READWRITE) then
            return false
        end
        local old_protection = ffi.new('uint32_t[1]')
        local changed = info.protection == PAGE_READONLY
        if changed and virtual_protect(ffi.cast('void *', address), #bytes,
                                       PAGE_READWRITE, old_protection) == 0 then
            return false
        end
        local wrote = kernel.WriteProcessMemory(process, ffi.cast('void *', address),
                                                bytes, #bytes, counter) ~= 0
                      and tonumber(counter[0]) == #bytes
        local restored = not changed or virtual_protect(
            ffi.cast('void *', address), #bytes, old_protection[0], old_protection) ~= 0
        return wrote and restored
    end

    function self.regions()
        local out = {}
        local address = 0
        while address < 0x7FFFFFFF0000 do
            if query(ffi.cast('const void *', address), region, region_size) ~= region_size then break end
            local base = tonumber(ffi.cast('uintptr_t', region[0].base))
            local size = tonumber(region[0].size)
            if not base or not size or size <= 0 then break end
            if region[0].state == MEM_COMMIT and region[0].type == MEM_PRIVATE
                and (region[0].protection == PAGE_READONLY or region[0].protection == PAGE_READWRITE) then
                out[#out + 1] = { base = base, size = size,
                                  allocation_base = tonumber(ffi.cast('uintptr_t', region[0].allocation_base)) }
            end
            address = base + size
        end
        table.sort(out, function(a, b) return a.size > b.size end)
        return out
    end

    function self.address_of(text)
        local ok, value = pcall(function()
            return tonumber(ffi.cast('uintptr_t', ffi.cast('const char *', text)))
        end)
        if ok then return value end
        return nil
    end

    function self.mkdir(path)
        return kernel.CreateDirectoryA(path, nil) ~= 0 or kernel.GetLastError() == 183
    end

    return self
end

-- ---------------------------------------------------------------- log
local log_path, log_lines, log_counts = nil, {}, {}

local function ensure_log_path()
    if log_path ~= nil then return log_path end
    log_path = false
    local ok, resolved = pcall(function()
        local base = os.getenv('LOCALAPPDATA')
        if not base or base == '' then return nil end
        for _, part in ipairs({ 'CowboyBingus', 'Helldivers2', 'Logs' }) do
            base = base .. '/' .. part
            if not api.mkdir(base) then return nil end
        end
        return base .. '/' .. MOD.log
    end)
    if ok and resolved then log_path = resolved end
    return log_path
end

local function flush_log()
    local path = ensure_log_path()
    if not path then return end
    local ok, handle = pcall(io.open, path, 'wb')
    if not ok or not handle then return end
    local lines = {
        MOD.title .. ' v' .. MOD.version .. ' by ' .. MOD.author,
        'status: ' .. tostring(state.phase) .. ' - ' .. tostring(state.status),
        'applied ' .. state.applied .. ', re-applied ' .. state.reapplied .. ', refused ' .. state.refused,
        '',
    }
    for _, line in ipairs(log_lines) do lines[#lines + 1] = line end
    pcall(function() handle:write(table.concat(lines, '\r\n') .. '\r\n') end)
    pcall(function() handle:close() end)
end

local function log(message)
    local count = (log_counts[message] or 0) + 1
    log_counts[message] = count
    if count > 3 or #log_lines >= MAX_LOG_LINES then return end
    local line = '[frame ' .. tostring(state.frame) .. '] ' .. message
    if count == 3 then line = line .. ' (further repeats not logged)' end
    log_lines[#log_lines + 1] = line
    print('[' .. MOD.global .. '] ' .. line)
end

local function set_status(phase, status)
    state.phase, state.status = phase, status
    log(phase .. ': ' .. status)
    pcall(flush_log)
end

local function hex(n) return string.format('0x%X', n) end

-- ---------------------------------------------------------------- edits
-- Each edit: offset, kind ('f32' or 'u32'), value, max. A field is overwritten whatever it
-- holds, as long as that is a plausible value for the field (0..max); an implausible value
-- means the record layout is not the one this build uses, and the record is left alone.
local function prepare_edits()
    for _, target in ipairs(MOD.targets) do
        for _, edit in ipairs(target.edits) do
            if edit.kind == 'f32' then
                edit.bytes = f32_bytes(edit.value)
                assert(near(bits_to_f32(u32(edit.bytes, 0)), edit.value), 'float encoder self-check failed')
            else
                edit.bytes = u32_bytes(edit.value)
            end
            if edit.expected ~= nil then edit.expected_bytes = u32_bytes(edit.expected) end
        end
    end
end

local function plausible(edit, bytes)
    local bits = u32(bytes, 0)
    if not bits then return false end
    if edit.kind == 'f32' then
        local value = bits_to_f32(bits)
        return value == value and value >= 0 and value <= edit.max
    end
    return bits <= edit.max
end

local owned_fields = {}

-- Returns 'applied', 'already' or a reason the record was left alone.
local function apply_edits(address, size, target)
    local before = api.read(address, size)
    if not before then return 'unreadable' end
    local pending = {}
    for _, edit in ipairs(target.edits) do
        local current = before:sub(edit.offset + 1, edit.offset + 4)
        if current ~= edit.bytes then
            if not plausible(edit, current) then return 'implausible value at +' .. edit.offset end
            if edit.expected_bytes and current ~= edit.expected_bytes
                and current ~= (owned_fields[address] and owned_fields[address][edit.offset]) then
                return 'baseline changed at +' .. edit.offset
            end
            pending[#pending + 1] = { edit.offset, current, edit.bytes }
        end
    end
    local function remember()
        local fields = owned_fields[address] or {}
        owned_fields[address] = fields
        for _, edit in ipairs(target.edits) do fields[edit.offset] = edit.bytes end
    end
    if #pending == 0 then remember(); return 'already' end

    local function rollback(reason)
        for _, change in ipairs(pending) do api.write(address + change[1], change[2]) end
        return reason
    end
    for _, change in ipairs(pending) do
        if not api.write(address + change[1], change[3]) then return rollback('write failed at +' .. change[1]) end
    end
    local after = api.read(address, size)
    if not after then return rollback('could not read back') end
    local expected = before
    for _, change in ipairs(pending) do
        expected = expected:sub(1, change[1]) .. change[3] .. expected:sub(change[1] + 5)
    end
    if after ~= expected then return rollback('read-back did not match') end
    remember()
    return 'applied'
end

-- ---------------------------------------------------------------- record location
-- Keyed table: find the bucket count that is exactly twice the entities it holds and leaves
-- a record array of this build's stride with at most MAX_UNINDEXED_RECORDS spare records.
-- Record bytes can look like buckets, so every candidate count is checked and exactly one
-- must fit.
local function locate_keyed(blob, target)
    local total, stride, entity = #blob, target.stride, target.entity
    local offset, count, live, top, index = 0, 0, 0, -1, nil
    local found = {}
    while offset + 16 <= total do
        local low, high = u32(blob, offset), u32(blob, offset + 4)
        local slot, pad = u32(blob, offset + 8), u32(blob, offset + 12)
        if pad ~= 0 or slot > 100000 then break end
        count = count + 1
        offset = offset + 16
        if low ~= 0 or high ~= 0 then
            live = live + 1
            if slot > top then top = slot end
            if index == nil and low == entity.lo and high == entity.hi then index = slot end
        end
        local array = total - count * 16
        if index ~= nil and count == 2 * live and array > 0 and array % stride == 0 then
            local records = array / stride
            if records > top and records <= live + MAX_UNINDEXED_RECORDS then
                found[#found + 1] = count * 16 + index * stride
            end
        end
    end
    if index == nil then return nil, target.label .. ': entity not in this table' end
    if #found ~= 1 then return nil, target.label .. ': ' .. #found .. ' layouts fit (need exactly 1)' end
    return found[1]
end

-- Row table: u64 descriptor, u32 row count, u32 0, then rows of `stride` bytes that start
-- with a unique u32 id.
local function locate_row(blob, target)
    local stride, rows = target.stride, u32(blob, 8)
    if not rows or u32(blob, 12) ~= 0 or 16 + rows * stride ~= #blob then
        return nil, target.label .. ': row table size does not match this build'
    end
    local hits = {}
    for row = 0, rows - 1 do
        if u32(blob, 16 + row * stride) == target.row_id then hits[#hits + 1] = 16 + row * stride end
    end
    if #hits ~= 1 then return nil, target.label .. ': ' .. #hits .. ' rows with id ' .. target.row_id end
    return hits[1]
end

-- ---------------------------------------------------------------- sites
-- A site is one applied record: the table block it lives in (to notice the table going
-- away) and the record address (to keep the values applied).
local sites = {}

local function count_sites(target)
    local n = 0
    for _, site in ipairs(sites) do if site.target == target then n = n + 1 end end
    return n
end

local function complete()
    for _, target in ipairs(MOD.targets) do
        if count_sites(target) == 0 then return false end
    end
    return true
end

local function summary()
    local parts = {}
    for _, target in ipairs(MOD.targets) do parts[#parts + 1] = target.label .. ' ' .. count_sites(target) end
    return table.concat(parts, ', ')
end

local function same_record(a, b)
    return a.table == b.table and a.stride == b.stride and a.row_id == b.row_id
        and (a.entity == nil) == (b.entity == nil)
        and (a.entity == nil or (a.entity.hi == b.entity.hi and a.entity.lo == b.entity.lo))
end

-- A record is only trusted if every field any target edits in it holds a plausible value:
-- one implausible field means the layout moved, so no target may write to that record.
local function record_trusted(record, target)
    local blob = api.read(record, target.stride)
    if not blob then return false, 'unreadable' end
    for _, other in ipairs(MOD.targets) do
        if same_record(other, target) then
            for _, edit in ipairs(other.edits) do
                local current = blob:sub(edit.offset + 1, edit.offset + 4)
                if current ~= edit.bytes then
                    if not plausible(edit, current) then
                        return false, 'implausible value at +' .. edit.offset .. ' (' .. other.label .. ')'
                    end
                    if edit.expected_bytes and current ~= edit.expected_bytes
                        and current ~= (owned_fields[record] and owned_fields[record][edit.offset]) then
                        return false, 'baseline changed at +' .. edit.offset .. ' (' .. other.label .. ')'
                    end
                end
            end
        end
    end
    return true
end

local function add_site(target, block, payload, record)
    -- one record can carry several targets (recoil and spread share the weapon record)
    for _, site in ipairs(sites) do
        if site.record == record and site.target == target then return end
    end
    local trusted, reason = record_trusted(record, target)
    local result = trusted and apply_edits(record, target.stride, target) or reason
    if result == 'applied' or result == 'already' then
        sites[#sites + 1] = { target = target, block = block, payload = payload, record = record }
        state.applied = state.applied + 1
        log(target.label .. ' ' .. result .. ' at ' .. hex(record))
    else
        state.refused = state.refused + 1
        log(target.label .. ' at ' .. hex(record) .. ' left alone: ' .. result)
    end
end

-- ---------------------------------------------------------------- scanning
local self_addresses = {}
local seen_blocks = {}
-- Every Lua read of a table leaves a stale copy in the Lua heap, and a sweep would find
-- those too. When this Lua state allocates below 2 GiB (LuaJIT without GC64), nothing down
-- there is a real settings table: the game lays those down high.
local LUA_HEAP_LIMIT = 0x80000000
local skip_low = false

local function handle_block(address)
    if seen_blocks[address] then return end
    seen_blocks[address] = true
    if skip_low and address < LUA_HEAP_LIMIT then return end
    local header = api.read(address, HEADER_BYTES)
    if not header or header:sub(1, 8) ~= NEEDLE then return end
    local kind, payload = u32(header, 8), u32(header, 12)
    if not payload or payload < 16 or payload > MAX_PAYLOAD then return end
    local wanted = false
    for _, target in ipairs(MOD.targets) do
        if target.table == kind then wanted = true end
    end
    if not wanted then return end
    -- read the payload only, so our own copy carries no LDLD header for a later sweep to find
    local blob = api.read(address + HEADER_BYTES, payload)
    if not blob then return end
    for _, target in ipairs(MOD.targets) do
        if target.table == kind then
            local locate = target.entity and locate_keyed or locate_row
            local offset, reason = locate(blob, target)
            if offset then
                add_site(target, address, payload, address + HEADER_BYTES + offset)
            else
                log(reason .. ' (table at ' .. hex(address) .. ')')
            end
        end
    end
end

local function scan_chunk(addr, size)
    local blob = api.read(addr, size)
    if not blob then return end
    local position = 1
    while true do
        local hit = blob:find(NEEDLE, position, true)
        if not hit then break end
        local address = addr + hit - 1
        local skip = false
        for _, own in ipairs(self_addresses) do
            if own and math.abs(address - own) <= SELF_MARGIN then skip = true break end
        end
        if not skip then pcall(handle_block, address) end
        position = hit + 1
    end
end

local probe, scan

local function begin_round()
    probe = { regions = {}, index = 1, seen = {}, done = false }
    scan = { regions = {}, index = 1, cursor = 0, overlap = #NEEDLE - 1 }
    seen_blocks = {}
    state.rounds = state.rounds + 1
    for _, region in ipairs(api.regions()) do
        if region.allocation_base and region.size >= PROBE_MIN_ALLOC then
            probe.regions[#probe.regions + 1] = region
        end
        scan.regions[#scan.regions + 1] = region
    end
end

-- Returns true once this round is finished. The settings tables sit near the start of their
-- allocations, so allocation heads are probed first; the full sweep follows unless the probe
-- already found everything with Lua-heap copies filtered out.
local function scan_step()
    local deadline = os.clock() + FRAME_BUDGET
    while not probe.done and probe.index <= #probe.regions do
        local region = probe.regions[probe.index]
        probe.index = probe.index + 1
        local key = string.format('%X', region.allocation_base)
        if not probe.seen[key] then
            probe.seen[key] = true
            pcall(scan_chunk, region.allocation_base, math.min(PROBE_BYTES, region.size))
        end
        if os.clock() >= deadline then return false end
    end
    probe.done = true
    if complete() and skip_low then return true end
    while scan.index <= #scan.regions do
        local region = scan.regions[scan.index]
        if scan.cursor >= region.size then
            scan.index = scan.index + 1
            scan.cursor = 0
        else
            local take = math.min(CHUNK, region.size - scan.cursor)
            pcall(scan_chunk, region.base + scan.cursor, take)
            scan.cursor = scan.cursor + math.max(take - scan.overlap, 1)
            if os.clock() >= deadline then return false end
        end
    end
    return true
end

-- ---------------------------------------------------------------- keeping values applied
-- Drops sites whose table is gone and restores values something else overwrote.
local function enforce()
    local kept = {}
    for _, site in ipairs(sites) do
        local header = api.read(site.block, HEADER_BYTES)
        if header and header:sub(1, 8) == NEEDLE and u32(header, 8) == site.target.table
            and u32(header, 12) == site.payload then
            local trusted, reason = record_trusted(site.record, site.target)
            local result = trusted and apply_edits(site.record, site.target.stride, site.target) or reason
            if result == 'applied' then
                state.reapplied = state.reapplied + 1
                log(site.target.label .. ' was changed by something else; restored at ' .. hex(site.record))
                pcall(flush_log)
            elseif result ~= 'already' then
                log(site.target.label .. ' at ' .. hex(site.record) .. ' no longer fits: ' .. result)
            end
            kept[#kept + 1] = site
        else
            owned_fields[site.record] = nil
            log(site.target.label .. ' table at ' .. hex(site.block) .. ' is gone')
        end
    end
    sites = kept
end

-- Native Mod Options Menu API 1. Polling tolerates either addon load order.
local CONFIG = {damage=1800, durable=1800, ap=6, spare=24, gas=2}
local config_dirty = true
local menu_registered = false
local registered_rows = {}
local menu_retry = 0
local MENU_ROWS = {
    {'damage', {type='slider', label='直击伤害', min=0, max=10000, step=50, default=1800,
        description='原版 650；强化默认 1800。应用后修改 S-11 鱼叉直击伤害。'}},
    {'durable', {type='slider', label='耐久伤害', min=0, max=10000, step=25, default=1800,
        description='原版 275；强化默认 1800。影响对高耐久部位的伤害。'}},
    {'ap', {type='slider', label='穿甲等级', min=1, max=10, step=1, default=6,
        description='原版 AP5；强化默认 AP6。统一设置四个命中角度的穿甲等级。'}},
    {'spare', {type='slider', label='备用弹数', min=1, max=120, step=1, default=24,
        description='原版 12；强化默认 24。已有角色的当前库存可能需要补给或重新部署才会更新。'}},
    {'gas', {type='choice', label='毒气与混乱效果', choices={'原版：毒气 6 秒／混乱 5 秒', '强化：毒气 10 秒／混乱 9 秒'}, default=2,
        description='切换游戏已有的原版或强化气体状态。仅改变 S-11 的状态引用；毒气每秒伤害不变。'}},
}

local function accept_setting(key, value, spec)
    local number = tonumber(value)
    if not number or number ~= number then return false end
    local low, high = spec.min or 1, spec.max or #spec.choices
    if number < low or number > high or number ~= math.floor(number) then return false end
    if spec.step and (number-low) % spec.step ~= 0 then return false end
    CONFIG[key] = number
    config_dirty = true
    return true
end

local function menu_poll()
    if menu_registered or os.time() < menu_retry then return end
    menu_retry = os.time() + 2
    local menu = rawget(_G, 'ModOptionsMenu')
    if type(menu) ~= 'table' or menu.api ~= 1 or type(menu.register_option) ~= 'function'
        or type(menu.get) ~= 'function' or type(menu.on_change) ~= 'function' then return end
    local all = true
    for _, row in ipairs(MENU_ROWS) do
        local key, spec = row[1], row[2]
        if not registered_rows[key] then
            spec.mod = 'S-11 鱼叉枪'
            local id = 'codex.s11.' .. key
            local ok, why = menu.register_option(id, spec)
            if ok then
                accept_setting(key, menu.get(id), spec)
                local hooked = menu.on_change(id, function(value)
                    if accept_setting(key, value, spec) then
                        log('menu ' .. key .. ' = ' .. tostring(value))
                    end
                end)
                registered_rows[key] = hooked == true
                if not registered_rows[key] then all = false end
            else
                all = false
                log('menu registration refused: ' .. id .. ': ' .. tostring(why))
            end
        end
    end
    menu_registered = all
    if all then log('five S-11 options registered; saved values loaded') end
end

local function configure_targets()
    local impact, gas, ammo = MOD.targets[1], MOD.targets[2], MOD.targets[3]
    impact.edits[1].value = CONFIG.damage
    impact.edits[2].value = CONFIG.durable
    for index=3,6 do impact.edits[index].value = CONFIG.ap end
    local gas_id, confusion_id = CONFIG.gas == 2 and 43 or 42, CONFIG.gas == 2 and 45 or 44
    impact.edits[7].value, impact.edits[8].value = gas_id, confusion_id
    gas.edits[1].value, gas.edits[2].value = gas_id, confusion_id
    ammo.edits[1].value, ammo.edits[2].value = CONFIG.spare, CONFIG.spare
    prepare_edits()
end

-- ---------------------------------------------------------------- tick
local BUS = nil
local next_action = 0

local function tick()
    menu_poll()
    if not menu_registered then return end
    if config_dirty then
        configure_targets()
        config_dirty = false
        next_action = 0
        log('applied menu configuration; existing records will be updated')
    end
    state.frame = state.frame + 1
    if state.frame < START_FRAME or state.phase == 'gave_up' then return end
    local now = os.time()

    if state.phase == 'searching' then
        local ok, finished = pcall(scan_step)
        if not ok then
            set_status('gave_up', 'scan error: ' .. tostring(finished))
            if BUS then BUS.jobs[MOD.global] = nil end
            return
        end
        if not finished then return end
        if complete() then
            set_status('active', 'all changes applied (' .. summary() .. ')')
            next_action = now + ENFORCE_SECONDS
        elseif state.rounds >= MAX_ROUNDS then
            set_status('active', 'some changes could not be applied (' .. summary() .. ')')
            next_action = now + ENFORCE_SECONDS
        else
            set_status('waiting', 'round ' .. state.rounds .. ' incomplete (' .. summary() .. ')')
            next_action = now + ROUND_DELAY_SECONDS
        end
        return
    end

    if now < next_action then return end
    if state.phase == 'active' then
        pcall(enforce)
        next_action = now + ENFORCE_SECONDS
        if complete() or state.rounds >= MAX_ROUNDS then return end
        -- a table went away (the game rebuilt it): look for it again
        state.rounds = 0
    end
    begin_round()
    state.phase = 'searching'
end

-- ---------------------------------------------------------------- startup
local ok, failure = pcall(function()
    local loader = rawget(_G, 'CowboyBingusModLoader')
    assert(type(loader) == 'table' and type(loader.api) == 'number' and loader.api >= 1,
           'Bingus Shared Loader v15 or newer (API 1) is required')
    assert(ffi_ok and ffi, 'LuaJIT FFI is unavailable')
    assert(ffi.abi('64bit'), 'Windows x64 is required')
    assert(type(update) == 'function', 'the game update hook is unavailable')
    api = build_api()
    local cell = ffi.new('float[1]')
    f32_bytes = function(value)
        cell[0] = value
        return ffi.string(cell, 4)
    end
    prepare_edits()
    self_addresses = { api.address_of(NEEDLE) }
    skip_low = (self_addresses[1] or LUA_HEAP_LIMIT) < LUA_HEAP_LIMIT
end)

if not ok then
    state.phase, state.status = 'gave_up', tostring(failure)
    print('[' .. MOD.global .. '] ' .. tostring(failure))
    if api then pcall(flush_log) end
    return
end

set_status('starting', 'waiting for the game to settle')

-- Shared frame dispatcher used by the Bingus Shared Loader addon family, so the game's
-- update chain stays intact however many of these mods are installed.
BUS = rawget(_G, 'OCLAW_UPDATE_BUS')
if not BUS then
    BUS = { jobs = {}, base = update }
    if type(BUS.base) ~= 'function' then return end
    local dispatcher
    dispatcher = function(...)
        local ok, first, second = pcall(BUS.base, ...)
        for _, job in pairs(BUS.jobs) do pcall(job) end
        if ok then return first, second end
    end
    BUS.dispatcher = dispatcher
    _G.OCLAW_UPDATE_BUS = BUS
    update = dispatcher
end
BUS.jobs[MOD.global] = tick
