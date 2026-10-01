-- HD2-Addon: mods/luoshuilin/null_cipher_stealth
-- Own original addon. Modifier meanings cross-referenced with Hung1510/Armory Forge tools data.
local key='LuoshuilinNullCipherStealthV1'
if rawget(_G,key)then return rawget(_G,key)end
local public={version='0.2.0',status='initializing',preset=1,noise_reduction=50,detection_reduction=40}
rawset(_G,key,public)
local path=(os.getenv('LOCALAPPDATA')or'.')..'/NullCipherStealth.log'
local first=true
local function log(message)
    pcall(function()
        local f=io.open(path,first and'w'or'a')
        if f then f:write(os.date('%Y-%m-%d %H:%M:%S')..' '..tostring(message)..'\n');f:close();first=false end
    end)
end
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

local ok,api=pcall(make_api,log)
if not ok then log('NATIVE_INIT_FAILED '..tostring(api));public.status='NATIVE_INIT_FAILED';return public end
local header='LDLD'..string.char(1,0,0,0,235,15,206,99,88,0,0,0,1,0,0,0,0,0,0,0)
local function u32(n)
    return string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,math.floor(n/16777216)%256)
end
local noise_id=u32(2945151250)..u32(2)
local detection_id=u32(351063573)..u32(2)
local vanilla_noise=string.char(0,0,0,63)       -- f32 0.5
local vanilla_detection=string.char(154,153,25,63) -- f32 0.6
local strong_noise=string.char(205,204,76,61)  -- f32 0.05
local strong_detection=string.char(205,204,204,61) -- f32 0.1
local function uint(b)
    if not b then return nil end
    local n=0;for i=#b,1,-1 do n=n*256+b:byte(i)end;return n
end
local target,original,desired,last_applied
local verified,halted=false,false
local cursor,region,scanned,next_check=4294967296,nil,0,0
local function status(s)
    if public.status~=s then public.status=s;log(s)end
end
local function identify(p)
    if api.read(p-24,24)~=header or api.read(p,4)~=u32(32)then return false end
    local arrays=api.read(p+16,32)
    return arrays and uint(arrays:sub(1,8))==p+56 and uint(arrays:sub(9,16))==2
        and uint(arrays:sub(25,32))==0
end
local function valid_rows(rows)
    return rows and#rows==32 and rows:sub(1,8)==noise_id and rows:sub(17,24)==detection_id
end
local function wanted(rows)
    local n,d=vanilla_noise,vanilla_detection
    local ffi=require('ffi')
    local cell=ffi.new('float[1]',1-public.noise_reduction/100);n=ffi.string(cell,4)
    cell[0]=1-public.detection_reduction/100;d=ffi.string(cell,4)
    return rows:sub(1,8)..n..rows:sub(13,24)..d..rows:sub(29,32)
end
local function apply(p)
    if not identify(p)then return false end
    local rows=api.read(p+56,32)
    if not valid_rows(rows)then return false end
    if not original then
        if rows:sub(9,12)~=vanilla_noise or rows:sub(25,28)~=vanilla_detection then
            status('CONFLICT_OR_NEW_BASELINE_NO_WRITES');return false
        end
        target,original=p,rows
    end
    if rows~=original and rows~=last_applied then status('CONFLICT_NO_WRITES');return false end
    desired=wanted(original)
    if rows==desired then status(public.preset==1 and'VANILLA' or'ENHANCED');return true end
    local r=api.region(p+64)
    if not r or not r.eligible or p+84>r.finish then status('TARGET_NOT_WRITABLE');return false end
    -- Each field is checked, written and read back; restore prior bytes if either fails.
    if api.read(p+56,32)~=rows then status('CONFLICT_NO_WRITES');return false end
    local wrote=api.write(p+64,desired:sub(9,12)) and api.write(p+80,desired:sub(25,28))
    if not wrote or api.read(p+56,32)~=desired then
        api.write(p+64,rows:sub(9,12));api.write(p+80,rows:sub(25,28))
        halted=true;status('WRITE_FAILED_STOPPED');return false
    end
    last_applied=desired
    status(public.preset==1 and'VANILLA_RESTORED' or'ENHANCED_ACTOR_REFRESH_REQUIRED')
    return true
end
local function step()
    if halted then return end
    if not verified then
        local g,e=api.module('game.dll'),api.module(nil)
        if not g or not e then return end
        if api.hash(g)~='2e2c3b7c2500646dadd5f2b4c6e0504dbb7e7896139f64cddc0d1813c718f51e'
            or api.hash(e)~='f5fee03dcfdb2e553a4752c283590950ac13316b376d8196aa556ff0400d5f06' then
            halted=true;status('UNSUPPORTED_BUILD_NO_WRITES');return
        end
        verified=true;status('SEARCHING_REDUCED_SIGNATURE')
    end
    local now=api.now()
    if now<next_check then return end
    if target then
        next_check=now+1
        if identify(target)then apply(target);return end
        target,original,desired,last_applied=nil,nil,nil,nil
        cursor,region,scanned=4294967296,nil,0
    end
    local deadline=now+0.003;local bytes,queries=0,0
    while bytes<4194304 and queries<128 and api.now()<=deadline do
        if not region then
            region=api.region(cursor);queries=queries+1
            if not region then cursor=4294967296;next_check=now+10;scanned=0;return end
            if not region.eligible then cursor=region.finish;region=nil end
        else
            local n=math.min(262144,region.finish-cursor)
            local b=api.read(cursor,n);bytes=bytes+n;scanned=scanned+n
            if scanned>17179869184 then halted=true;status('SCAN_LIMIT_NO_WRITES');return end
            if b then
                local i=1
                while true do
                    local hit=b:find(header,i,true)
                    if not hit then break end
                    if apply(cursor+hit-1+24)then return end
                    i=hit+24
                end
            end
            if cursor+n==region.finish then cursor=region.finish;region=nil
            else cursor=cursor+n-23 end
        end
    end
end
local registered,retry=false,0
local function menu_poll()
    if registered or api.now()<retry then return end
    retry=api.now()+2
    local m=rawget(_G,'ModOptionsMenu')
    if type(m)~='table' or m.api~=1 or type(m.register_option)~='function' or type(m.get)~='function' or type(m.on_change)~='function' then return end
    local specs={
        {key='noise_reduction',label='移动噪音减少（%）',min=50,max=95,default=50},
        {key='detection_reduction',label='探测半径减少（%）',min=40,max=90,default=40}}
    for _,spec in ipairs(specs)do
        local field,lo,hi=spec.key,spec.min,spec.max
        local id='luoshuilin.nullcipher.slider.v1.'..field
        local good,why=m.register_option(id,{type='slider',mod='RS-67 单刷潜行',label=spec.label,min=lo,max=hi,step=1,default=spec.default,
            description='最左原版，越向右越隐蔽。仅作用于降低特征护甲，应用后重穿；不保证开枪或已暴露时隐身。'})
        if not good then log('MENU_REFUSED '..tostring(why));return end
        local function apply(value)
            if type(value)~='number' or value%1~=0 or value<lo or value>hi then return end
            public[field]=value
            public.preset=(public.noise_reduction==50 and public.detection_reduction==40)and 1 or 2
            next_check=0;log(id..' = '..tostring(value))
        end
        if m.on_change(id,apply)~=true then log('MENU_CALLBACK_REFUSED');return end
        apply(m.get(id))
    end
    registered=true;log('SLIDERS_REGISTERED')
end
local base=rawget(_G,'update')
if type(base)~='function'then status('UPDATE_HOOK_UNAVAILABLE');return public end
rawset(_G,'update',function(...)
    local ok,err=pcall(function()menu_poll();if registered then step()end end)
    if not ok then halted=true;status('FAULT '..tostring(err))end
    return base(...)
end)
log('Initialized; vanilla default; Steam build25480438; gameplay not yet verified')
return public
