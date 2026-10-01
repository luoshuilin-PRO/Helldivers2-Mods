-- HD2-Addon: mods/localdev/democracy_protects_100
-- Build placeholders are replaced with functions and constants, not executed by Python.
-- HD2-Addon declaration is inserted by the builder as the very first line.
local key='DemocracyProtects090'
if rawget(_G,key) then return rawget(_G,key) end
local public={version='0.2.0-menu',status='initializing'}
rawset(_G,key,public)
local log_path=(os.getenv('LOCALAPPDATA') or os.getenv('TEMP') or '.')..'/DemocracyProtects090.log'
local first=true
local function log(message)
    pcall(function()
        local f=io.open(log_path,first and 'w' or 'a')
        if f then f:write(os.date('%Y-%m-%d %H:%M:%S')..' '..tostring(message)..'\n'); f:close(); first=false end
    end)
end
log('Democracy Protects menu: 50/70/90 percent; actor refresh may require armor change')
local make_api=(function() -- Windows adapter. Reads and writes only this Lua VM's own process.
-- Only private, non-executable data pages are eligible. Read-only pages are
-- temporarily writable for each checked four-byte write, then restored.
return function(log)
    local ffi=require('ffi')
    assert(ffi.abi('64bit'),'64-bit runtime required')
    assert(not ffi.abi('gc64'),'non-GC64 LuaJIT required to exclude Lua-owned strings')
    for declaration in ([=[
        void *GetCurrentProcess(void);
        void *GetModuleHandleA(const char *name);
        uint32_t GetModuleFileNameW(void *module, uint16_t *path, uint32_t count);
        int ReadProcessMemory(void *, const void *, void *, size_t, size_t *);
        int WriteProcessMemory(void *, void *, const void *, size_t, size_t *);
        size_t VirtualQuery(const void *, void *, size_t);
        int VirtualProtect(void *, size_t, uint32_t, uint32_t *);
        uint64_t GetTickCount64(void);
        void *CreateFileW(const uint16_t *, uint32_t, uint32_t, void *, uint32_t, uint32_t, void *);
        int ReadFile(void *, void *, uint32_t, uint32_t *, void *);
        int CloseHandle(void *);
        int32_t BCryptOpenAlgorithmProvider(void **, const uint16_t *, const uint16_t *, uint32_t);
        int32_t BCryptCreateHash(void *, void **, void *, uint32_t, const void *, uint32_t, uint32_t);
        int32_t BCryptHashData(void *, const void *, uint32_t, uint32_t);
        int32_t BCryptFinishHash(void *, void *, uint32_t, uint32_t);
        int32_t BCryptDestroyHash(void *);
        int32_t BCryptCloseAlgorithmProvider(void *, uint32_t);
]=]):gmatch('[^;]+;') do pcall(ffi.cdef,declaration) end
    local k=ffi.load('kernel32'); local crypto=ffi.load('bcrypt')
    local query=ffi.cast('size_t (*)(const void *, void *, size_t)', k.VirtualQuery)
    local process=k.GetCurrentProcess()
    local api={log=log}
    local function valid(a,n)
        return type(a)=='number' and a>=65536 and a<140737488355328
            and n>0 and n<=1048576 and a+n<140737488355328
    end
    local function num(b,offset,ctype)
        local v=ffi.new(ctype..'[1]'); ffi.copy(v,b+offset,ffi.sizeof(v)); return tonumber(v[0])
    end
    function api.module(name)
        local m=k.GetModuleHandleA(name)
        if m==nil then return nil end
        return tonumber(ffi.cast('uintptr_t',m))
    end
    function api.now() return tonumber(k.GetTickCount64())/1000 end
    function api.region(address)
        local r=ffi.new('uint8_t[48]')
        if query(ffi.cast('void *',address),r,48)~=48 then return nil end
        local base=num(r,0,'uintptr_t');local size=num(r,24,'size_t')
        if size<=0 or base+size<=address then return nil end
        return {base=base,finish=base+size,eligible=base>=4294967296
            and num(r,32,'uint32_t')==0x1000 and (num(r,36,'uint32_t')==4 or num(r,36,'uint32_t')==2)
            and num(r,40,'uint32_t')==0x20000}
    end
    function api.read(address,n)
        if not valid(address,n) then return nil end
        local b=ffi.new('uint8_t[?]',n); local got=ffi.new('size_t[1]')
        if k.ReadProcessMemory(process,ffi.cast('void *',address),b,n,got)==0 or got[0]~=n then return nil end
        return ffi.string(b,n)
    end
    function api.write(address,bytes)
        if not valid(address,#bytes) or #bytes~=4 then return false end
        local r=ffi.new('uint8_t[48]')
        if query(ffi.cast('void *',address),r,48)~=48 then return false end
        local base=num(r,0,'uintptr_t'); local size=num(r,24,'size_t')
        local protection=num(r,36,'uint32_t')
        if num(r,32,'uint32_t')~=0x1000 or (protection~=4 and protection~=2)
            or num(r,40,'uint32_t')~=0x20000 or address<base or address+4>base+size then return false end
        local written=ffi.new('size_t[1]')
        local previous=ffi.new('uint32_t[1]')
        local discarded=ffi.new('uint32_t[1]')
        local pointer=ffi.cast('void *',address)
        if protection==2 and k.VirtualProtect(pointer,4,4,previous)==0 then
            api.log('DATA_PAGE_TEMPORARY_WRITE_ACCESS_FAILED');return false
        end
        local ok=k.WriteProcessMemory(process,pointer,bytes,4,written)~=0 and written[0]==4
        if protection==2 and k.VirtualProtect(pointer,4,previous[0],discarded)==0 then
            api.log('DATA_PAGE_PROTECTION_RESTORE_FAILED');return false
        end
        return ok
    end
    function api.hash(module)
        local path=ffi.new('uint16_t[32768]')
        local length=k.GetModuleFileNameW(ffi.cast('void *',module),path,32768)
        assert(length>0 and length<32768,'module path unavailable')
        local file=k.CreateFileW(path,0x80000000,7,nil,3,0x08000000,nil)
        assert(file~=ffi.cast('void *',-1),'module file unavailable')
        local provider=ffi.new('void *[1]'); local hash=ffi.new('void *[1]')
        local ok,value=pcall(function()
            local name=ffi.new('uint16_t[7]',{83,72,65,50,53,54,0})
            assert(crypto.BCryptOpenAlgorithmProvider(provider,name,nil,0)==0,'SHA256 provider failed')
            assert(crypto.BCryptCreateHash(provider[0],hash,nil,0,nil,0,0)==0,'SHA256 creation failed')
            local buf=ffi.new('uint8_t[1048576]'); local count=ffi.new('uint32_t[1]')
            while true do
                assert(k.ReadFile(file,buf,1048576,count,nil)~=0,'module read failed')
                if count[0]==0 then break end
                assert(crypto.BCryptHashData(hash[0],buf,count[0],0)==0,'SHA256 update failed')
            end
            local digest=ffi.new('uint8_t[32]')
            assert(crypto.BCryptFinishHash(hash[0],digest,32,0)==0,'SHA256 finish failed')
            local s={}; for i=0,31 do s[#s+1]=string.format('%02x',digest[i]) end
            return table.concat(s)
        end)
        if hash[0]~=nil then crypto.BCryptDestroyHash(hash[0]) end
        if provider[0]~=nil then crypto.BCryptCloseAlgorithmProvider(provider[0],0) end
        k.CloseHandle(file)
        if not ok then error(value) end
        return value
    end
    return api
end
 end)()
local make_core=(function() return function(api,cfg)
    local s={status='INITIALIZING'}
    local cursor,region,verified,stopped=4294967296,nil,false,false
    local target,owned,next_check,scanned=nil,false,0,0
    local function status(v)if s.status~=v then s.status=v;api.log(v)end end
    local function uint(b)
        if not b then return nil end
        local v=0;for i=#b,1,-1 do v=v*256+b:byte(i)end;return v
    end
    local function identify(p)
        if api.read(p-24,24)~=cfg.header or api.read(p,16)~=cfg.prefix then return false end
        local b=api.read(p+16,40)
        if not b then return false end
        -- Canonical loaded record has a relocated pointer to two 16-byte modifiers.
        return uint(b:sub(1,8))==p+56 and uint(b:sub(9,16))==2
            and b:sub(17)==string.rep('\0',24)
    end
    local function restore()
        if not owned then return true end
        if not identify(target) or api.read(target+56,32)~=cfg.desired then
            owned=false;api.log('RESTORE_SKIPPED_CHANGED_RECORD');return false
        end
        local ok=api.write(target+64,cfg.original:sub(9,12))
        local same=api.read(target+56,32)==cfg.original
        if same then owned=false end
        return ok and same
    end
    local function activate(p)
        if not identify(p) then return false end
        local mods=api.read(p+56,32)
        if mods~=cfg.original and mods~=cfg.desired then return false end
        target=p
        if mods==cfg.desired then status('ALREADY_SET_EXTERNALLY');return true end
        local r=api.region(p+64)
        if not r or not r.eligible or p+68>r.finish then status('TARGET_NOT_WRITABLE');return false end
        local ok=api.write(p+64,cfg.desired:sub(9,12))
        owned=api.read(p+56,32)==cfg.desired
        if not ok or not owned then
            restore();stopped=true;status('WRITE_FAILED_STOPPED');return true
        end
        status('ACTIVE_'..tostring(cfg.percent or 90)..'_PERCENT_ACTOR_REFRESH_REQUIRED')
        api.log('PASSIVE_SET address='..string.format('%.0f',p+64)..' probability='..tostring(cfg.percent or 90)..'%; re-equip armor or deploy to rebuild actor modifiers')
        return true
    end
    function s.step()
        if stopped then return end
        if not verified then
            local g,e=api.module('game.dll'),api.module(nil)
            if not g or not e then return end
            if api.hash(g)~=cfg.game_sha256 or api.hash(e)~=cfg.exe_sha256 then stopped=true;status('UNSUPPORTED_BUILD_NO_WRITES');return end
            -- secondary code check disabled (full DLL hash already verified)
            verified=true;status('SEARCHING_PASSIVE_TEMPLATE')
        end
        local now=api.now()
        if target then
            if now<next_check then return end
            next_check=now+1
            if identify(target) then
                local mods=api.read(target+56,32)
                if mods==cfg.desired then return end
                if mods==cfg.original then owned=false;activate(target);return end
                owned=false;status('PASSIVE_CHANGED_EXTERNALLY_NO_WRITES');return
            end
            target=nil;owned=false;cursor=4294967296;region=nil;scanned=0
        elseif now<next_check then return end
        local deadline=now+0.003;local bytes,queries=0,0
        while bytes<4194304 and queries<128 and api.now()<=deadline do
            if not region then
                region=api.region(cursor);queries=queries+1
                if not region then cursor=4294967296;next_check=now+10;scanned=0;status('WAITING_PASSIVE_TEMPLATE');return end
                if not region.eligible then cursor=region.finish;region=nil end
            else
                local n=math.min(262144,region.finish-cursor)
                local b=api.read(cursor,n);bytes=bytes+n;scanned=scanned+n
                if scanned>17179869184 then stopped=true;status('SCAN_LIMIT_NO_WRITES');return end
                if b then
                    local i=1
                    while true do
                        local p=b:find(cfg.prefix,i,true)
                        if not p then break end
                        if activate(cursor+p-1)then return end
                        i=p+16
                    end
                end
                if cursor+n==region.finish then cursor=region.finish;region=nil else cursor=cursor+n-15 end
            end
        end
    end
    function s.set_probability(percent)
        if stopped then return false,'core stopped or unsupported build' end
        local values={ [50]="\000\000\192\063", [70]="\154\153\217\063", [90]="\051\051\243\063" }
        local bytes=values[percent]
        if not bytes then return false,'invalid probability' end
        if target then
            if not identify(target) then
                target=nil;owned=false;cursor=4294967296;region=nil;scanned=0
            elseif owned then
                if not restore() then return false,'owned value changed; restore refused' end
            elseif api.read(target+56,32)~=cfg.original then
                return false,'record changed externally; selection refused'
            end
        end
        cfg.percent=percent
        cfg.desired=cfg.original:sub(1,8)..bytes..cfg.original:sub(13)
        next_check=0
        status('SELECTED_'..percent..'_PERCENT')
        return true
    end
    function s.stop()
        stopped=true;local ok=restore();status(ok and 'STOPPED_RESTORED' or 'STOPPED_RESTORE_INCOMPLETE');return ok
    end
    return s
end
 end)()
local cfg=(function() return {
game_sha256="2e2c3b7c2500646dadd5f2b4c6e0504dbb7e7896139f64cddc0d1813c718f51e",
exe_sha256="f5fee03dcfdb2e553a4752c283590950ac13316b376d8196aa556ff0400d5f06",
header="\076\068\076\068\001\000\000\000\235\015\206\099\088\000\000\000\001\000\000\000\000\000\000\000",
prefix="\009\000\000\000\003\176\182\073\218\009\111\170\076\147\174\097",
original="\005\077\129\203\002\000\000\000\000\000\192\063\233\051\184\235\194\048\137\166\002\000\000\000\000\000\000\000\171\061\195\135",
desired="\005\077\129\203\002\000\000\000\051\051\243\063\233\051\184\235\194\048\137\166\002\000\000\000\000\000\000\000\171\061\195\135",
check_code="\072\131\236\040\243\015\016\021\088\205\138\001\139\202\186\005\077\129\203\065\184\003\000\000\000\232\210\139\108\000\072\133\192\116\035\243\015\016\072\008\015\087\192\015\047\200\118\022\131\120\004\002\117\016\243\015\092\013\162\186\138\001\015\040\193\072\131\196\040\195\015\040\194\072\131\196\040\195",
check_rva=0x870ad0,
}
 end)()
local ok,api=pcall(make_api,log)
if not ok then public.status='NATIVE_INIT_FAILED'; log(public.status..': '..tostring(api)); return public end
local core=make_core(api,cfg)
local menu_registered=false
local menu_retry=0
local function menu_poll()
    if menu_registered or api.now()<menu_retry then return end
    menu_retry=api.now()+2
    local menu=rawget(_G,'ModOptionsMenu')
    if type(menu)~='table' or menu.api~=1 or type(menu.register_option)~='function'
        or type(menu.get)~='function' or type(menu.on_change)~='function' then return end
    local id='codex.democracy.probability'
    local ok,why=menu.register_option(id,{type='choice',mod='民主护佑',label='致命伤害存活概率',
        choices={'50%（原版）','70%','90%'},default=3,
        description='只修改拥有民主护佑被动的护甲。应用后请重新装备护甲或部署，以刷新角色被动。'})
    if not ok then log('MENU_REFUSED '..tostring(why));return end
    local percentages={50,70,90}
    local function select(value)
        local percent=percentages[value]
        if not percent then return end
        local good,reason=core.set_probability(percent)
        log('MENU '..percent..'% '..tostring(good)..' '..tostring(reason or ''))
    end
    select(menu.get(id))
    menu_registered=menu.on_change(id,select)==true
    if menu_registered then log('MENU_REGISTERED') end
end
local halted=false
function public.stop()
    halted=true
    local ok,result=pcall(core.stop)
    public.status=core.status
    log('stop result='..tostring(ok and result))
    return ok and result
end
local next_check=0
local function poll()
    if halted then return end
    menu_poll()
    if not menu_registered then return end
    local now=api.now()
    if now<next_check then return end
    next_check=now+0.016
    local ok,err=pcall(core.step)
    public.status=core.status
    if not ok then
        log('FAULT: '..tostring(err)); public.stop()
        public.status='FAULT_STOPPED'
    end
end
local chained=false
local function chain()
    if chained then return end
    local original=rawget(_G,'update')
    if type(original)~='function' then return end
    rawset(_G,'update',function(...)
        poll()
        return original(...)
    end)
    local shutdown=rawget(_G,'shutdown')
    if type(shutdown)=='function' then
        rawset(_G,'shutdown',function(...)
            public.stop()
            return shutdown(...)
        end)
    end
    chained=true; log('UPDATE_HOOK_INSTALLED')
end
chain()
if not chained then
    local wwise=rawget(_G,'WwiseFlowCallbacks')
    if type(wwise)=='table' then
        for name,original in pairs(wwise) do
            if type(original)=='function' then
                wwise[name]=function(...)
                    chain()
                    if not chained then poll() end
                    return original(...)
                end
            end
        end
        log('WAITING_UPDATE_USING_WWISE_CALLBACKS')
    else
        public.status='NO_UPDATE_CALLBACK_NO_WRITES'; log(public.status); return public
    end
end
poll()
return public
