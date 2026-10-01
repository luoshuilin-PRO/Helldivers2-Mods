# Helldivers 2 自定义模组：自由滑条与三档预设

提供五个完整模组安装包、源码和打包脚本。飞矛、护盾、RS-67潜行、民主护佑已更新为自由滑条；鱼叉枪保留三档预设版。攻城准备项目已移除。

## 最新下载

| 模组 | 版本 | 完整安装包 |
| --- | --- | --- |
| FAF-14飞矛，自由滑条 | v0.2.0 | [下载ZIP](downloads/FAF-14-Spear-Sliders-v0.2.0.zip) |
| SH-32护盾背包，自由滑条 | v0.2.0 | [下载ZIP](downloads/SH-32-Shield-Pack-Sliders-v0.2.0.zip) |
| RS-67空密码潜行，自由滑条 | v0.2.0 | [下载ZIP](downloads/RS-67-Null-Cipher-Stealth-Sliders-v0.2.0.zip) |
| 民主护佑，自由滑条 | v0.4.0 | [下载ZIP](downloads/Democracy-Protects-Slider-v0.4.0.zip) |
| S-11鱼叉枪，三档预设 | v1.4.0 | [下载ZIP](downloads/S-11-Speargun-Three-Tiers-v1.4.0.zip) |

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

**仅飞矛与护盾额外需要：[HD2Runtime-0.28.1-runtime.zip](https://github.com/SkyeShade/HD2Runtime/releases/download/v0.28.1/HD2Runtime-0.28.1-runtime.zip)**，作者SkyeShade。要下载runtime运行时包，SDK、ModBuilder和源码ZIP不能代替它。RS-67、民主护佑及鱼叉枪不需要HD2Runtime。

依赖单独下载，本仓库不捆绑第三方运行时。若Megapack已提供菜单，避免再启用重复菜单。

## 安装、升级与应用

1. 完全退出游戏，在Arsenal停用同装备旧版mod。
2. 导入所需最新ZIP，启用菜单和Loader；飞矛、护盾还需启用HD2Runtime。
3. **Loader放加载顺序最底部**，Purge → Deploy，重启游戏。
4. ESC → MODS → 对应模组，拉动滑条后点击**APPLY**（键盘Tab）。
5. 飞矛、护盾重新呼叫新装备；RS-67和民主护佑重新穿戴护甲或重新部署，刷新角色。

只停留在默认值不会强化。恢复原版时将所有滑条拉到最左，APPLY后再刷新装备或护甲。不能撤销其他mod的修改。

## 作用范围与验证状态

飞矛保留原版直击、索敌和导引，只强化爆炸；护盾保持半径1.3米。RS-67作用于所有带“降低特征”被动的护甲；民主护佑只作用于该被动护甲。

当前支持Steam build25480438对应数据。保留构建、数据归属、原版基准及修改后的复核机制；游戏更新或其他mod修改同字段时可能拒绝应用。

**四个滑条版已通过Lua5.1语法编译，尚未进行游戏内效果验证。** 护盾恢复字段上游也标为尚未完成游戏内确认。旧v0.1.1飞矛与护盾日志确认加载和菜单注册成功，不代表当前滑条版的数值已验证。

不能保证飞矛秒杀所有目标、护盾精确3秒充满、潜行完全隐身或民主护佑必定救命。参数作用与日志路径详见[说明](docs/slider-controls.md)。

## 鱼叉枪保留的三档

| 参数 | 原版默认 | 适度强化 | 单刷强化 |
| --- | --- | --- | --- |
| 普通／耐久伤害 | 650／275 | 850／400 | 1800／1800 |
| 穿甲 | AP5 | AP5 | AP6 |
| 备用弹数 | 12 | 16 | 24 |
| 毒气／混乱持续时间 | 6／5秒 | 6／5秒 | 10／9秒 |

范围、换弹不变；备弹变化可能需补给或重新部署刷新。

## 源码与打包

- mods/：各模组最终Lua、manifest及README。
- downloads/：完整安装包；SHA256SUMS.txt：校验值。
- `python scripts/build.py`：从当前源码重建最新安装包，输出至build/。

加载框架、菜单由CowboyBingus提供；飞矛、护盾调用SkyeShade的HD2Runtime公开API。RS-67字段参考[Hung1510的Armory Forge](https://github.com/Hung1510/Super-Earth-Armory-Forge)，未捆绑其代码。修改与中文设置由仓库维护者借助OpenAI Codex整理。各依赖遵循各自许可，本仓库未声明统一MIT许可证。
