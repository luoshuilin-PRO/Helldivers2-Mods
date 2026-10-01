-- HD2-Addon: mods/luoshuilin/sh32_shield_tiers
-- v0.1.1: Loader Lua ABI version is separate from its release label.
-- Original preset is the default. No raw addresses or guessed damage owners.
local loader=rawget(_G,'CowboyBingusModLoader')
assert(loader and loader.api==1 and type(loader.version)=='number' and loader.version>=16,
    'Requires Bingus Shared Loader v18 / API 1')
local runtime=require('mods/skyeshade/hd2runtime')
local minimum='0.28.1'
local function at_least(current,required)
    local a,b,c=tostring(current):match('^(%d+)%.(%d+)%.(%d+)')
    local x,y,z=required:match('^(%d+)%.(%d+)%.(%d+)$')
    if not a then return false end
    a,b,c,x,y,z=tonumber(a),tonumber(b),tonumber(c),tonumber(x),tonumber(y),tonumber(z)
    return a>x or a==x and (b>y or b==y and c>=z)
end
assert(runtime.api_version==1 and at_least(runtime.version,minimum),
    'Requires HD2Runtime 0.28.1 / API 1')
local key='HD2RuntimeMod:mods/luoshuilin/sh32_shield_tiers'
local existing=rawget(_G,key)
if existing then return existing end
local function start()
    local hd2=runtime
    local mod=hd2.mod()
    local state={preset=1,values={},watches={},menu_registered=false}
    -- One script value per verified field, all bound to one guarded ensure.
    local function value(id,presets,step)
        local lo,hi=presets[1],presets[1]
        for _,n in ipairs(presets)do lo=math.min(lo,n);hi=math.max(hi,n)end
        local handle=mod:value({id=id,min=lo,max=hi,step=step or 1,default=presets[1]})
        state.values[#state.values+1]={handle=handle,presets=presets}
        return handle
    end

    local pack=hd2.backpack('SH-32 Shield Generator Pack')
    local health=value('shield_health',{150,450,1500})
    local delay=value('shield_delay',{60,10,3})
    local broken=value('shield_restart',{12,6,3})
    local rate=value('shield_rate',{150,450,15000})
    -- Recharge members are native-correlated, not live-proven; explicitly acknowledged.
    -- All members belong to the same ShieldComponentData record.
    state.watches[1]=hd2.ensure({transaction={id='sh32-three-tier-shield',target=pack,
        allow_unverified_effect=true,changes={
            {field=hd2.fields.shield.entity_durability,expect=150,value=health},
            {field=hd2.fields.shield.recharge_delay,expect=60,value=delay},
            {field=hd2.fields.shield.broken_recharge_delay,expect=12,value=broken},
            {field=hd2.fields.shield.recharge_rate,expect=150,value=rate}
        }}})

    local function select_preset(index)
        if type(index)~='number' or index%1~=0 or index<1 or index>3 then return false end
        -- Changes coalesce inside Runtime's 0.5 s debounce; no memory writes in this callback.
        for _,entry in ipairs(state.values)do entry.handle:set(entry.presets[index])end
        state.preset=index
        mod:log('preset '..tostring(index)..' selected; call in fresh equipment after APPLY')
        return true
    end
    local elapsed=0
    local function register_menu()
        if state.menu_registered then return end
        local menu=rawget(_G,'ModOptionsMenu')
        if type(menu)~='table' or menu.api~=1 or type(menu.register_option)~='function'
            or type(menu.get)~='function' or type(menu.on_change)~='function' then return end
        local ok,why=menu.register_option('luoshuilin.sh32-shield.preset.v1',{type='choice',mod='SH-32 护盾背包',label='强化档位',
            choices={'一档：原版（默认）','二档：适度强化','三档：单刷强化'},default=1,
            description='容量150／450／1500，破盾恢复延迟12／6／3秒，恢复速度150／450／15000每秒。3秒指开始恢复；恢复参数未验证。应用后呼叫新背包。'})
        if not ok then
            mod:log('menu registration refused: '..tostring(why));state.menu_finished=true;return
        end
        local listening=menu.on_change('luoshuilin.sh32-shield.preset.v1',select_preset)
        if listening~=true then
            mod:log('menu callback registration refused; keeping original preset')
            state.menu_finished=true;return
        end
        state.menu_registered=true
        select_preset(menu.get('luoshuilin.sh32-shield.preset.v1'))
    end
    -- Cancel the registration timer once settled. Missing menu leaves original values only.
    state.menu_timer=mod:every(1,function(timer)
        elapsed=elapsed+1
        register_menu()
        if state.menu_registered or state.menu_finished or elapsed>=30 then
            if not state.menu_registered then mod:log('menu unavailable; keeping original preset')end
            timer:cancel()
        end
    end,{id='register-preset-menu',scope='session'})
    mod:log('three-tier addon initialized; original preset is the default')
    return state
end
local state=runtime.events.run_as('mods/luoshuilin/sh32_shield_tiers',start)
rawset(_G,key,state)
return state
