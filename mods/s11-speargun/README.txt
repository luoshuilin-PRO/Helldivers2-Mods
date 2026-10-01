S-11鱼叉枪自由滑条 v1.5.0
新增独立滑条：毒气持续6–30秒，混乱持续5–30秒，步长1秒。
原有滑条：普通伤害650–10000，耐久伤害275–10000，AP5–10，备弹12–120。
首次全部默认原版，设置键全新，旧版已保存的强化设置不会继承。
原“原版／强化”状态选择移除，统一使用原版Gas、Gas Confusion引用，再修改它们的持续时间。
不修改毒气每秒伤害、气体覆盖范围、敌人的状态免疫或换弹机制。
状态定义共享，SDK已审阅消费者包含S-11直击及气体爆炸，也可能有其他动态消费者；不能保证只影响S-11。

需要Bingus Shared Loader v18、Mod Options Menu API1、HD2Runtime0.28.1运行时。
关闭游戏，停用所有S-11旧版（v1.3.0、三档v1.4.0等），导入本ZIP，Loader底部，Purge → Deploy。
ESC → MODS → S-11 鱼叉枪 → 六个滑条，调节后APPLY。
备弹变化可能需补给或重新部署，建议APPLY后呼叫新武器再使用。
本次未完成游戏内验证；沿用原版查找与写入引擎，新增时间字段由Runtime检查归属、基准和冲突。
日志：S11SoloSpear.log和HD2Runtime日志。缺少Runtime会使整个新版S-11加载失败。
参考：https://github.com/SkyeShade/HD2Runtime/blob/master/sdk/SupportWeaponAuthoringCapabilities.json
