# Helldivers 2 自定义模组：游戏内设置版

三个可独立安装的模组，提供中文菜单选项。通过 Mod Options Menu 在 ESC → MODS 中设置。

## 下载

| 模组 | 版本 | 下载 |
| --- | --- | --- |
| S-11 鱼叉枪单刷强化版（游戏内设置） | v1.3.0 | [下载 ZIP](downloads/S-11-Speargun-Solo-Enhanced-Menu-v1.3.0.zip) |
| 民主护佑（50%／70%／90% 游戏内设置） | v0.2.0 | [下载 ZIP](downloads/Democracy-Protects-Menu-v0.2.0.zip) |
| 敌人 HP（游戏内开关） | v1.1.2 菜单改版 | [本地生成步骤](#敌人-hp-v112) |

下载单个模组 ZIP 后交给 Arsenal 导入。GitHub 的 Code → Download ZIP 是整个源码仓库，不能直接作为模组安装包导入。

## 必需依赖

以下依赖需要另外下载、启用和部署：

- **[Bingus Shared Loader v18](https://github.com/CowboyBingus/BingusSharedLoader)** — 作者 CowboyBingus。
- **[Mod Options Menu v1.1](https://github.com/CowboyBingus/ModOptionsMenu)** — 作者 CowboyBingus；[Nexus 下载页面](https://www.nexusmods.com/helldivers2/mods/16625)。

本仓库中的版本是按 Mod Options Menu v1.1 / API 1 接口制作的。更新版是否兼容需要另外确认；目前没有核实 v1.3.4。依赖软件的下载包由作者提供，本仓库提供链接。

## 安装及加载顺序

1. 关闭游戏。
2. 在 HDArsenal 中导入需要的模组，以及上述两个依赖。
3. 停用同一模组的旧版或其他同时修改同一功能的版本。
4. 启用模组和 Mod Options Menu，保持 **Bingus Shared Loader 位于加载顺序底部**。
5. 执行 Purge → Deploy，启动游戏。
6. 在舰船上或任务中打开 ESC → MODS，进入相应类别。修改后点击 APPLY，或按菜单提示的应用按键（键盘 Tab）。

如果 Vanilla Plus Megapack 已提供 Mod Options Menu，只启用一份菜单实现。

## S-11 鱼叉枪 v1.3.0

| 设置 | 范围 | 默认值 |
| --- | --- | --- |
| 直击伤害 | 0–10000，步长 50 | 1800 |
| 耐久伤害 | 0–10000，步长 25 | 1800 |
| 穿甲等级 | AP1–AP10，统一四个角度 | AP6 |
| 备用弹数 | 1–120 | 24 |
| 毒气效果 | 原版 / 强化 | 强化 |

强化毒气使用游戏已有 MK2 状态引用：毒气 10 秒、混乱 9 秒；原版为 6 秒、5 秒。此选项没有提供毒气每秒伤害调节。换弹机制保持原有实现。

伤害等设置会在运行时定位和复核数据后应用。备用弹数修改的是容量，已生成角色的现有库存可能需要补给或重新部署才能刷新。

## 民主护佑 v0.2.0

- 三档选择：50%（原版）、70%、90%（默认）。
- 仅作用于带有民主护佑被动的护甲。
- 应用后请换下护甲再穿回，或重新部署，刷新角色被动。
- 概率不代表每 10 次致命伤害必定存活固定次数。

## 敌人 HP v1.1.2

此版本编号指本仓库的菜单改版，不是原作者的 v1.1.2 更新。

原作者 **Medic3038** 的 [Nexus 页面](https://www.nexusmods.com/helldivers2/mods/16650) 明确禁止向其他网站上传完整文件，修改也需要其许可。因此此仓库仅提供菜单改动补丁，不提供原作完整 Lua 或改版 ZIP。公开分发完整改版需另外取得原作者许可。

对已有原包的用户，本地生成方法：

1. 准备原始 `Enemy-HP-1.1.1-with-names` ZIP（本补丁仅匹配这一版本）。
2. 安装 Python 3，在本仓库目录运行：

```text
python scripts/prepare_enemy_hp.py "原始ZIP的完整路径"
python scripts/build.py
```

3. 在 `build/` 中取得 `Enemy-HP-With-Names-Menu-v1.1.2.zip`。生成的完整 Lua 和 ZIP 默认由 `.gitignore` 排除，不随仓库上传。


- 在舰船上或任务中设置“显示敌人 HP”开关，默认开启。
- 保留原模组行为：显示自己红色标记敌人的名称及当前 / 最大 HP；并非全地图血条。
- 关闭后隐藏当前标签并暂停标记读取。重新开启后可再次标记敌人。
- 中文的是菜单，敌人名称仍沿用原包的英文名称表。

## 游戏版本与验证状态

这些包沿用 Steam build **25480438** 的实现。民主护佑和敌人 HP 保留原包的构建 / 哈希检查；鱼叉枪保留布局和原始数值检查。游戏更新后可能拒绝应用，或者需要重新适配。

现有包说明记录了此前的隔离脚本检查；三个菜单版没有完成游戏内菜单与实战验证。这次发布整理没有修改 Lua 逻辑或 ZIP 内容，也没有新增兼容性测试。

建议仅在单人或获得同意的私人游戏中使用改变玩法数值的模组。

## 设置与日志

菜单设置保存于：

```text
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\ModOptionsMenu.values
```

日志位置：

- 鱼叉枪：上述 Logs 目录中的 `S11SoloSpear.log`。
- 菜单依赖：上述 Logs 目录中的 `ModOptionsMenu.log`。
- 民主护佑：`%LOCALAPPDATA%\DemocracyProtects090.log`。
- 敌人 HP：`%LOCALAPPDATA%\Hd2EnemyHp`。

## 源码、致谢与许可

- 各模组的 Lua、安装包清单和原有说明放在 `mods/` 对应目录。
- 鱼叉枪和民主护佑发布 ZIP 放在 `downloads/`；`SHA256SUMS.txt` 记录校验值。
- 打包脚本为 `scripts/build.py`，从各目录中现有清单和最终 Lua 入口重建 ZIP。
- 游戏内菜单与共享加载框架由 CowboyBingus 提供，链接见依赖部分。
- 敌人 HP 原作者为 Medic3038，本仓库仅提供针对用户提供的 Enemy HP 1.1.1 with names 包的菜单补丁。保留脚本内原有署名及对 etxp 的 HD2 G-60 Smart Targeting 的致谢。民主护佑也基于用户提供的原包进行适配；来源说明不能视为获得重新发布许可。
- 修改及中文菜单由仓库维护者借助 OpenAI Codex 整理制作。

当前没有为整个仓库声明 MIT 等统一许可证。基于其他作者代码的部分仍受原作者的许可条件约束，本仓库没有包含敌人 HP 原作或完整改版，其他来源不明的原作也不据此获得转载许可。依赖框架及游戏本体的权利属于各自作者和权利人。
