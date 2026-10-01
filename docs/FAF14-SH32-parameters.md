# FAF-14与SH-32参数来源

2026-10-01整理；目标Steam build25480438，HD2Runtime SDK0.28.1。本页列出已找到的字段，不代表涵盖游戏所有隐藏参数，也不代表新mod已完成游戏内验证。

## 原始资料

- [SupportWeaponAuthoringCapabilities.json](https://github.com/SkyeShade/HD2Runtime/blob/master/sdk/SupportWeaponAuthoringCapabilities.json)：按 `supportWeapon == FAF-14 Spear` 筛选字段实例。
- [BackpackAuthoringCapabilities.json](https://github.com/SkyeShade/HD2Runtime/blob/master/sdk/BackpackAuthoringCapabilities.json)：按 `target.backpack == SH-32 Shield Generator Pack` 筛选。
- [支援武器API](https://github.com/SkyeShade/HD2Runtime/blob/master/docs/support-weapon-api.md)、[背包API](https://github.com/SkyeShade/HD2Runtime/blob/master/docs/backpack-authoring.md)、[事件与脚本值API](https://github.com/SkyeShade/HD2Runtime/blob/master/docs/event-scripting.md)。
- [飞矛公开统计](https://helldivers.wiki.gg/wiki/FAF-14_Spear)：直击4000普通／4000耐久，AP7。该直击分支当前SDK不可写，故本mod不修改它。

字段、基准、确认层级和限制的机器可读摘录见同目录 `FAF14-SH32-parameters.json`。摘录不含运行时地址；上游目录的其余字段未复制。

## 飞矛爆炸字段（全部已找到的标量与状态字段）

| 字段 | 原版 | 本mod |
| --- | --- | --- |
| inner_radius | 1.5米 | 1.5／2.5／3 |
| outer_radius | 3米 | 3／7／12 |
| shockwave_radius | 6米 | 6／10／18 |
| damage_standard_damage | 200 | 200／2000／8000 |
| damage_durable_damage | 200 | 200／2000／8000 |
| damage_ap_direct | 3 | 3／5／7 |
| damage_ap_slight | 0 | 保持 |
| damage_ap_large | 0 | 保持 |
| damage_ap_extreme | 0 | 保持 |
| damage_demolition | 30 | 保持 |
| damage_stagger | 60 | 保持 |
| damage_push_force | 70 | 保持 |
| damage_status_1_type | none | 保持 |
| damage_status_1_strength | 0 | 保持 |

以上字段前缀为 `hd2.fields.explosion.`；目标为 `hd2.support_weapon('FAF-14 Spear'):attack('primary_impact'):explosion()`。
半径和DamageInfo是两个不同记录，用一个plan中的两组操作修改。均要求allow_shared；已审阅消费者为FAF-14，但可能有动态消费者。普通伤害、耐久伤害与穿甲共同决定实际伤害，表格数字不是每个部位必定受到的伤害。

## 护盾字段

| API常量（前缀hd2.fields.shield） | 原版 | 状态 |
| --- | --- | --- |
| entity_radius | 1.3米 | 类型已确认；本mod保留原版 |
| entity_durability | 150 | 类型已确认；150／450／1500 |
| recharge_delay | 60秒 | 原生关联证据；60／10／3，游戏内效果未验证 |
| broken_recharge_delay | 12秒 | 原生关联证据；12／6／3，游戏内效果未验证 |
| recharge_rate | 150 HP/秒 | 原生关联证据；150／450／15000，游戏内效果未验证 |

目标为 `hd2.backpack('SH-32 Shield Generator Pack')`，四个变更使用一个transaction。恢复字段显式声明allow_unverified_effect。定义值在新背包生成时使用，现有背包是否重新读取尚未证明。

## 更新原则

游戏更新后应先核对HD2Runtime支持的新构建和新SDK目录，再更新expect基准及档位。一档必须使用新构建实际原版值，不能把旧值硬写回新游戏。不要仅修改版本检查或猜偏移。如果归属链未确认，保持该字段不改。
