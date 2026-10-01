-- HD2-Addon: mods/luoshuilin/faf14_spear_tiers
-- v0.1.1: Loader Lua ABI version is separate from its release label.
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

    local elapsed=0
    local function register_menu()
        if state.menu_registered then return end
        local menu=rawget(_G,'ModOptionsMenu')
        if type(menu)~='table' or menu.api~=1 or type(menu.register_option)~='function' or type(menu.get)~='function' or type(menu.on_change)~='function' then return end
        do
            local id='luoshuilin.faf14-spear.slider.v1.damage'
            local ok,why=menu.register_option(id,{type='slider',mod='FAF-14 飞矛',label='爆炸伤害',min=200,max=8000,step=100,default=200,description='最左为原版。APPLY后重新呼叫装备；详细范围见安装包说明。'})
            if not ok then mod:log('MENU_REFUSED '..tostring(why));return end
            local function apply(value)
                if type(value)~='number' or value<200 or value>8000 then return end
                damage:set(value)
                mod:log(id..' = '..tostring(value))
            end
            if menu.on_change(id,apply)~=true then mod:log('MENU_CALLBACK_REFUSED');return end
            apply(menu.get(id))
        end
        do
            local id='luoshuilin.faf14-spear.slider.v1.durable'
            local ok,why=menu.register_option(id,{type='slider',mod='FAF-14 飞矛',label='爆炸耐久伤害',min=200,max=8000,step=100,default=200,description='最左为原版。APPLY后重新呼叫装备；详细范围见安装包说明。'})
            if not ok then mod:log('MENU_REFUSED '..tostring(why));return end
            local function apply(value)
                if type(value)~='number' or value<200 or value>8000 then return end
                durable:set(value)
                mod:log(id..' = '..tostring(value))
            end
            if menu.on_change(id,apply)~=true then mod:log('MENU_CALLBACK_REFUSED');return end
            apply(menu.get(id))
        end
        do
            local id='luoshuilin.faf14-spear.slider.v1.ap'
            local ok,why=menu.register_option(id,{type='slider',mod='FAF-14 飞矛',label='爆炸穿甲',min=3,max=7,step=1,default=3,description='最左为原版。APPLY后重新呼叫装备；详细范围见安装包说明。'})
            if not ok then mod:log('MENU_REFUSED '..tostring(why));return end
            local function apply(value)
                if type(value)~='number' or value<3 or value>7 then return end
                ap:set(value)
                mod:log(id..' = '..tostring(value))
            end
            if menu.on_change(id,apply)~=true then mod:log('MENU_CALLBACK_REFUSED');return end
            apply(menu.get(id))
        end
        do
            local id='luoshuilin.faf14-spear.slider.v1.inner'
            local ok,why=menu.register_option(id,{type='slider',mod='FAF-14 飞矛',label='内半径（米）',min=1.5,max=3,step=0.5,default=1.5,description='最左为原版。APPLY后重新呼叫装备；详细范围见安装包说明。'})
            if not ok then mod:log('MENU_REFUSED '..tostring(why));return end
            local function apply(value)
                if type(value)~='number' or value<1.5 or value>3 then return end
                inner:set(value)
                mod:log(id..' = '..tostring(value))
            end
            if menu.on_change(id,apply)~=true then mod:log('MENU_CALLBACK_REFUSED');return end
            apply(menu.get(id))
        end
        do
            local id='luoshuilin.faf14-spear.slider.v1.outer'
            local ok,why=menu.register_option(id,{type='slider',mod='FAF-14 飞矛',label='外半径（米）',min=3,max=12,step=1,default=3,description='最左为原版。APPLY后重新呼叫装备；详细范围见安装包说明。'})
            if not ok then mod:log('MENU_REFUSED '..tostring(why));return end
            local function apply(value)
                if type(value)~='number' or value<3 or value>12 then return end
                outer:set(value)
                mod:log(id..' = '..tostring(value))
            end
            if menu.on_change(id,apply)~=true then mod:log('MENU_CALLBACK_REFUSED');return end
            apply(menu.get(id))
        end
        do
            local id='luoshuilin.faf14-spear.slider.v1.shock'
            local ok,why=menu.register_option(id,{type='slider',mod='FAF-14 飞矛',label='冲击波半径（米）',min=6,max=18,step=1,default=6,description='最左为原版。APPLY后重新呼叫装备；详细范围见安装包说明。'})
            if not ok then mod:log('MENU_REFUSED '..tostring(why));return end
            local function apply(value)
                if type(value)~='number' or value<6 or value>18 then return end
                shock:set(value)
                mod:log(id..' = '..tostring(value))
            end
            if menu.on_change(id,apply)~=true then mod:log('MENU_CALLBACK_REFUSED');return end
            apply(menu.get(id))
        end
        state.menu_registered=true;mod:log('SLIDERS_REGISTERED')
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
    mod:log('slider addon initialized; original preset is the default')
    return state
end
local state=runtime.events.run_as('mods/luoshuilin/faf14_spear_tiers',start)
rawset(_G,key,state)
return state
