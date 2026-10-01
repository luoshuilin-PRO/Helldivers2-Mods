SH-32 护盾背包（三档预设，默认原版）v0.1.1 实验版
参数（一档／二档／三档）：
护盾容量：150／450／1500
未破盾受伤后的恢复延迟：60／10／3秒
破盾恢复延迟：12／6／3秒
恢复速度：150／450／15000 HP每秒
护盾半径始终保持原版1.3米。
三档从空盾充满理论耗时0.1秒，即约3.1秒；实际时序取决于游戏机制，不能保证精确3秒充满。
三个恢复字段有原生类型与多装备数值关联证据，但上游未完成游戏内效果验证，故属于实验参数。
需要 Bingus Shared Loader v18、Mod Options Menu v1.1 / API 1、HD2Runtime 0.28.1 / API 1。未进行游戏内验证。

安装：关闭游戏，导入本ZIP以及三个依赖。Bingus Shared Loader放Arsenal加载顺序底部，Purge → Deploy。
在舰船ESC → MODS → 对应模组 → 强化档位，选择后点击APPLY（键盘Tab）。首次默认一档原版，以后保存所选档位。
应用后等待数据写入完成，再呼叫一份新的装备；已有装备可能保留旧数值。选择一档可通过相同检查恢复本模组拥有的定义值。
仅针对Steam build25480438所对应的数据布局。游戏更新、基准值变化或其他模组修改同一字段时，Runtime可能拒绝写入。
所有档位均未进行游戏内验证。默认档仅设置原版数值，不代表能撤销其他模组的修改。
依赖：
https://github.com/CowboyBingus/BingusSharedLoader
https://github.com/CowboyBingus/ModOptionsMenu
https://github.com/SkyeShade/HD2Runtime/releases
诊断：HD2Runtime日志中的本模组资源名、ensure状态和拒绝原因；菜单出现不代表写入成功。

修复：区分Loader的Lua内部版本与发行版v18，使用HD2Runtime官方包装器的内部最低版本16。
必须额外安装HD2Runtime-0.28.1-runtime.zip，否则这两个模组仍不能加载。
官方安装包：https://github.com/SkyeShade/HD2Runtime/releases/download/v0.28.1/HD2Runtime-0.28.1-runtime.zip
