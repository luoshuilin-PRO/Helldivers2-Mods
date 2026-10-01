-- HD2-Addon: mods/luoshuilin/faf14_spear_tiers
-- Original preset is the default. No raw addresses or guessed damage owners.
local loader=rawget(_G,'CowboyBingusModLoader')
assert(loader and loader.api==1 and type(loader.version)=='number' and loader.version>=18,
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
local key='HD2RuntimeMod:mods/luoshuilin/faf14_spear_tiers'
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

    local explosion=hd2.support_weapon('FAF-14 Spear'):attack('primary_impact'):explosion()
    local damage=value('blast_damage',{200,2000,8000})
    local durable=value('blast_durable',{200,2000,8000})
    local ap=value('blast_ap',{3,5,7})
    local inner=value('blast_inner',{1.5,2.5,3},0.5)
    local outer=value('blast_outer',{3,7,12})
    local shock=value('blast_shock',{6,10,18})
    -- Two backing objects: ExplosionSettings and its linked DamageInfo. One atomic plan.
    state.watches[1]=hd2.ensure({plan={id='faf14-three-tier-plan',operations={
        {id='faf14-radius',target=explosion,allow_shared=true,changes={
            {field=hd2.fields.explosion.inner_radius,expect=1.5,value=inner},
            {field=hd2.fields.explosion.outer_radius,expect=3,value=outer},
            {field=hd2.fields.explosion.shockwave_radius,expect=6,value=shock}}},
        {id='faf14-blast-damage',target=explosion,allow_shared=true,changes={
            {field=hd2.fields.explosion.damage_standard_damage,expect=200,value=damage},
            {field=hd2.fields.explosion.damage_durable_damage,expect=200,value=durable},
            {field=hd2.fields.explosion.damage_ap_direct,expect=3,value=ap}}}
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
        local ok,why=menu.register_option('luoshuilin.faf14-spear.preset.v1',{type='choice',mod='FAF-14 飞矛',label='强化档位',
            choices={'一档：原版（默认）','二档：适度强化','三档：单刷强化'},default=1,
            description='爆炸伤害200／2000／8000，爆炸AP3／5／7，外半径3／7／12米。直击和索敌保持原版；未验证，不能保证秒杀全部可锁定敌人。应用后呼叫新飞矛。'})
        if not ok then
            mod:log('menu registration refused: '..tostring(why));state.menu_finished=true;return
        end
        local listening=menu.on_change('luoshuilin.faf14-spear.preset.v1',select_preset)
        if listening~=true then
            mod:log('menu callback registration refused; keeping original preset')
            state.menu_finished=true;return
        end
        state.menu_registered=true
        select_preset(menu.get('luoshuilin.faf14-spear.preset.v1'))
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
local state=runtime.events.run_as('mods/luoshuilin/faf14_spear_tiers',start)
rawset(_G,key,state)
return state
