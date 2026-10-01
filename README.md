# Helldivers 2 自定义模组：自由滑条版

提供五个完整模组安装包、源码和打包脚本。鱼叉枪、飞矛、护盾、RS-67潜行、民主护佑均为自由滑条版。攻城准备项目已移除。

## 最新下载

| 模组 | 版本 | 完整安装包 |
| --- | --- | --- |
| FAF-14飞矛，自由滑条 | v0.2.0 | [下载ZIP](downloads/FAF-14-Spear-Sliders-v0.2.0.zip) |
| SH-32护盾背包，自由滑条 | v0.2.0 | [下载ZIP](downloads/SH-32-Shield-Pack-Sliders-v0.2.0.zip) |
| RS-67空密码潜行，自由滑条 | v0.2.0 | [下载ZIP](downloads/RS-67-Null-Cipher-Stealth-Sliders-v0.2.0.zip) |
| 民主护佑，自由滑条 | v0.4.0 | [下载ZIP](downloads/Democracy-Protects-Slider-v0.4.0.zip) |
| S-11鱼叉枪，含毒气／混乱时间滑条 | v1.5.0 | [下载ZIP](downloads/S-11-Speargun-Sliders-Gas-Confusion-v1.5.0.zip) |

下载上表单个ZIP导入Arsenal，**不用解压**。Code → Download ZIP是源码仓库，不能直接作为模组安装包导入。downloads中旧包供历史参考，不要与同装备新版一起启用。

## 滑条范围与默认值

所有滑条**首次都在最左原版值**，向右加强；采用新设置键，不继承旧版强化值。已APPLY的设置会保存。

| 模组 | 可调参数 |
| --- | --- |
| 飞矛 | 爆炸普通、耐久伤害各200–8000；AP3–7；内半径1.5–3米、外半径3–12米、冲击波6–18米 |
| 护盾 | 容量150–1500；恢复速度150–15000；受伤等待60→3秒；破盾等待12→3秒 |
| RS-67 | 移动噪音减少50%–95%；探测半径减少40%–90% |
| 民主护佑 | 致命伤害存活概率50%–90%，步长1% |

护盾等待滑条显示为“缩短多少秒”：0表示原版，越向右等待越短。滑条独立控制对应参数。[详细范围、步长与限制](docs/slider-controls.md)。

## 依赖

所有模组的设置页面需要以下两项，各启用一份：

- **[Bingus Shared Loader v18](https://github.com/CowboyBingus/BingusSharedLoader)**，作者CowboyBingus。
- **[Mod Options Menu API1](https://github.com/CowboyBingus/ModOptionsMenu)**，当前参考v1.1；[Nexus下载页面](https://www.nexusmods.com/helldivers2/mods/16625)，作者CowboyBingus。

**鱼叉枪v1.5.0、飞矛与护盾额外需要：[HD2Runtime-0.28.1-runtime.zip](https://github.com/SkyeShade/HD2Runtime/releases/download/v0.28.1/HD2Runtime-0.28.1-runtime.zip)**，作者SkyeShade。要下载runtime运行时包，SDK、ModBuilder和源码ZIP不能代替它。RS-67和民主护佑不需要HD2Runtime。鱼叉枪旧版不依赖Runtime，但v1.5.0的时间滑条需要它。

依赖单独下载，本仓库不捆绑第三方运行时。若Megapack已提供菜单，避免再启用重复菜单。

## 安装、升级与应用

1. 完全退出游戏，在Arsenal停用同装备旧版mod。
2. 导入所需最新ZIP，启用菜单和Loader；鱼叉枪、飞矛、护盾还需启用HD2Runtime。
3. **Loader放加载顺序最底部**，Purge → Deploy，重启游戏。
4. ESC → MODS → 对应模组，拉动滑条后点击**APPLY**（键盘Tab）。
5. 飞矛、护盾重新呼叫新装备；RS-67和民主护佑重新穿戴护甲或重新部署，刷新角色。

只停留在默认值不会强化。恢复原版时将所有滑条拉到最左，APPLY后再刷新装备或护甲。不能撤销其他mod的修改。

## 作用范围与验证状态

飞矛保留原版直击、索敌和导引，只强化爆炸；护盾保持半径1.3米。RS-67作用于所有带“降低特征”被动的护甲；民主护佑只作用于该被动护甲。

当前支持Steam build25480438对应数据。保留构建、数据归属、原版基准及修改后的复核机制；游戏更新或其他mod修改同字段时可能拒绝应用。

**五个滑条版已通过Lua5.1语法编译，尚未进行游戏内效果验证。** 护盾恢复字段上游也标为尚未完成游戏内确认。旧v0.1.1飞矛与护盾日志确认加载和菜单注册成功，不代表当前滑条版的数值已验证。

不能保证飞矛秒杀所有目标、护盾精确3秒充满、潜行完全隐身或民主护佑必定救命。参数作用与日志路径详见[说明](docs/slider-controls.md)。

## 鱼叉枪v1.5.0：六个独立滑条

| 参数 | 最低／首次默认 | 最高 | 步长 |
| --- | --- | --- | --- |
| 直击伤害 | 650 | 10000 | 50 |
| 耐久伤害 | 275 | 10000 | 25 |
| 四角度穿甲 | AP5 | AP10 | 1 |
| 备用弹数 | 12 | 120 | 1 |
| 毒气持续时间 | 6秒 | 30秒 | 1秒 |
| 混乱持续时间 | 5秒 | 30秒 | 1秒 |

原来的“原版／强化”毒气选择已移除，改为两个独立时间滑条。首次全部默认原版，不继承旧版强化设置，APPLY后保存。

时间由HD2Runtime公开字段修改，保留原版Gas与Gas Confusion引用。不修改毒气每秒伤害、气体范围、敌人免疫或换弹机制。状态定义共享，可能影响使用同一状态的其他来源，不能保证只影响S-11或所有敌人都能混乱。

升级须停用S-11 v1.3.0、v1.4.0等旧版，安装v1.5.0及HD2Runtime运行时。ESC → MODS → S-11鱼叉枪调整六个滑条并APPLY；建议再呼叫新武器，备弹可能需补给或重新部署刷新。本版仅完成Lua语法编译，尚未游戏内验证。

参考：[HD2Runtime支援武器字段目录](https://github.com/SkyeShade/HD2Runtime/blob/master/sdk/SupportWeaponAuthoringCapabilities.json)。日志查看S11SoloSpear.log和HD2Runtime日志。

## 源码与打包

- mods/：各模组最终Lua、manifest及README。
- downloads/：完整安装包；SHA256SUMS.txt：校验值。
- `python scripts/build.py`：从当前源码重建最新安装包，输出至build/。

加载框架、菜单由CowboyBingus提供；飞矛、护盾调用SkyeShade的HD2Runtime公开API。RS-67字段参考[Hung1510的Armory Forge](https://github.com/Hung1510/Super-Earth-Armory-Forge)，未捆绑其代码。修改与中文设置由仓库维护者借助OpenAI Codex整理。各依赖遵循各自许可，本仓库未声明统一MIT许可证。
