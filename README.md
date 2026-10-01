# Helldivers 2 自定义模组：三档预设版

提供鱼叉枪、民主护佑两个完整模组 ZIP，以及源码和打包脚本。首次加载均默认使用**一档原版**，在 ESC → MODS 中选择二档或三档，再点击 APPLY 应用。

## 下载

| 模组 | 版本 | 下载 |
| --- | --- | --- |
| S-11 鱼叉枪（三档预设） | v1.4.0 | [下载完整ZIP](downloads/S-11-Speargun-Three-Tiers-v1.4.0.zip) |
| 民主护佑（三档预设） | v0.3.0 | [下载完整ZIP](downloads/Democracy-Protects-Three-Tiers-v0.3.0.zip) |

下载单个模组 ZIP 后导入 Arsenal。Code → Download ZIP 下载的是源码仓库，不能直接作为模组安装包导入。

## 鱼叉枪的三个档位

| 参数 | 一档：原版（首次默认） | 二档：适度强化 | 三档：单刷强化 |
| --- | --- | --- | --- |
| 直击伤害 | 650 | 850 | 1800 |
| 耐久伤害 | 275 | 400 | 1800 |
| 四角度穿甲 | AP5 | AP5 | AP6 |
| 备用弹数 | 12 | 16 | 24 |
| 毒气状态持续时间 | 6秒 | 6秒 | 10秒 |
| 混乱状态持续时间 | 5秒 | 5秒 | 9秒 |
| 攻击范围、换弹机制 | 原版 | 原版 | 原版 |

中档是本仓库选定的适度强化方案；高档沿用旧强化版的数值。毒气选项使用游戏已有状态引用，不修改毒气每秒伤害。未新增未经确认的范围参数。

旧版的五项自由调节改为一个“强化档位”选项，选档后一起应用对应数值。备用弹数改变的是容量，已有角色的库存可能需要补给或重新部署刷新。

## 民主护佑的三个档位

| 档位 | 致命伤害存活概率 |
| --- | --- |
| 一档：原版（首次默认） | 50% |
| 二档：提高存活概率 | 80% |
| 三档：高存活概率 | 90% |

仅作用于拥有民主护佑被动的护甲。选择并应用后请换下护甲再穿回，或重新部署，刷新角色被动。概率不代表每十次必定存活固定次数。

## 必需依赖

- **[Bingus Shared Loader v18](https://github.com/CowboyBingus/BingusSharedLoader)**，作者 CowboyBingus。
- **[Mod Options Menu v1.1](https://github.com/CowboyBingus/ModOptionsMenu)**，作者 CowboyBingus；[Nexus下载页面](https://www.nexusmods.com/helldivers2/mods/16625)。

当前实现使用 Mod Options Menu v1.1 / API 1 接口。新版依赖的兼容性需要另行确认。依赖需单独下载，本仓库提供作者链接。

## 安装和升级

1. 关闭游戏，在 Arsenal 中停用两个模组的旧版。
2. 导入所需的新 ZIP，启用 Mod Options Menu 和 Bingus Shared Loader。
3. **Loader 放在加载顺序底部**，执行 Purge → Deploy。
4. 启动游戏，在舰船或任务中打开 ESC → MODS，选择档位。
5. 点击 APPLY 或按菜单提示按键（键盘 Tab）应用。

若 Megapack 已提供菜单，只启用一份 Mod Options Menu。

采用新的菜单设置键，旧版强化数值不会迁移到新版：第一次加载显示一档原版。之后用户选定的档位仍会保存，下次启动恢复该档位；如需回到原版，选择一档并应用。

设置保存于 `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\ModOptionsMenu.values`。

## 游戏版本与验证状态

沿用 Steam build **25480438** 的支持范围。民主护佑保留构建与哈希检查；鱼叉枪保留数据布局和基准数值检查。游戏更新后可能拒绝应用，需要重新适配。

本次修改了菜单预设和默认值，保留原有运行时扫描、数据复核及写入机制。新三档版未进行游戏内验证，不能保证当前游戏构建中的实际表现；建议先在单人或获得同意的私人游戏中使用。

日志：鱼叉枪位于上述 Logs 目录的 `S11SoloSpear.log`，民主护佑位于 `%LOCALAPPDATA%\DemocracyProtects090.log`。

## 源码与自行打包

- `mods/`：两个模组的最终 Lua、清单和说明。
- `downloads/`：完整安装包；`SHA256SUMS.txt`：校验值。
- 运行 `python scripts/build.py`，生成包位于 `build/`。

共享加载框架和菜单由 CowboyBingus 提供。修改及中文菜单由仓库维护者借助 OpenAI Codex 整理制作。依赖和引用代码的许可条件以各自原项目为准，本仓库未声明统一的 MIT 等许可证。
