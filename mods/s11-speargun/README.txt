S-11 鱼叉枪游戏内设置版 v1.3.0

需要：Bingus Shared Loader v18+ 和你提供的 Mod Options Menu v1.1。
不用安装 SC Dropper 或 SCDropper.limit；它们只是接口参考。

安装：关闭游戏，导入本 ZIP，替换/停用 S-11 v1.2.0 及更早版本。
启用 S-11、Mod Options Menu、Bingus Shared Loader，Loader 放在加载顺序底部。
执行 Purge → Deploy，再启动游戏。
如果已启用 Vanilla Plus Megapack 中的 Mod Options Menu，只需使用这一份菜单。

ESC → MODS（模组）→ S-11 鱼叉枪，修改后点 APPLY 或按 Tab 应用。
菜单保存设置，下次启动会自动读取。

可调参数：
直击伤害 0–10000（步长 50；默认 1800；原版 650）
耐久伤害 0–10000（步长 25；默认 1800；原版 275）
穿甲等级 AP1–AP10（默认 AP6；原版 AP5；统一四个角度）
备用弹数 1–120（默认 24；原版 12）
毒气效果：原版（毒气 6 秒／混乱 5 秒）或强化（10 秒／9 秒），默认强化。
毒气选项切换游戏已有状态引用，没有新增任意持续时间或毒气每秒伤害修改。

伤害、穿甲和状态引用在应用后按运行时扫描/复核更新；首次定位需要等待。
备用弹数是储备容量配置，已有角色的当前库存可能需要补给或重新部署才会更新。
没有安装菜单或注册不成功时，S-11 脚本不会写入强化数值。

保存：%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\ModOptionsMenu.values
日志：同一文件夹下的 S11SoloSpear.log 和 ModOptionsMenu.log。
沿用原 v1.2 的布局和基准检查；游戏更新后不匹配的记录会被拒绝。
修改只存在于运行内存。禁用并退出游戏、重新部署即可移除。

已做隔离脚本检查；未在游戏内验证菜单显示和实战效果。单人/私人使用。
源码在 Source/s11_menu_v13.lua，菜单 API 来源为提供的 Mod Options Menu v1.1 包。
