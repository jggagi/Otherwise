# 资源来源与许可记录

本地评审版 0.1.0，2026-10-09。此表记录可查证来源；不将缺失的历史许可记录写成已确认。

| 文件／范围 | 来源 | 使用与记录 |
| --- | --- | --- |
| `assets/art_sources/lin_xia_poses_v1.png` | 本次内置 image_gen，现有人物／公寓作参考 | AI 辅助制作的三个姿态，实际参数见 ART_DIRECTION.md |
| `player_back_walk_v1.png` | 本次 image_gen，以现有背面人物作参考并修订步态 | 两帧透明 PNG |
| `photo_together_v1.png` | 本次 image_gen，以两位人物作参考 | 回忆合影 |
| `entrance_rain_v1.png` | 本次 image_gen，以公寓作风格参考 | 单元门口有限演出背景 |
| `hair_tie_detail_v1.png` | 本次 image_gen，以既有发圈作参考 | 蓝线修补局部图 |
| `assets/audio/*.wav` | 本项目 `scripts/generate_audio.py` 原创程序合成 | 雨、脚步、手机、门、电脑；无采样外部录音 |
| `assets/fonts/NotoSansSC.ttf` | Google Fonts，Noto Sans SC | SIL Open Font License 1.1；完整文本同目录 OFL.txt，发行包附 FONT-LICENSE.txt |
| 公寓背景、原主角、旧道具、旧遮挡图 | 仓库已有，沿用原型资产 | 历史文件未随附独立许可声明，保留原文件与 Git 来源；公开商业分发前仍需项目所有者补充其来源／权利记录 |
| 新对白、场景和脚本 | 本项目本次编写 | 未引入第三方游戏代码或音乐库 |
| Godot 4.7.2 引擎与内含库 | 本机已安装官方引擎／同版本 release 模板 | MIT 及内含库声明由 Engine 许可 API 导出；发行包含 GODOT-LICENSES.txt |

字体源：[Google Fonts Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)。字体二进制与 OFL 文本从该目录下载，离线包含，未使用系统字体回退。

上述缺失记录不影响本机评审运行；本次仅产生本地发行候选包，没有公开发布。生成提示、裁切尺寸、脚点和参考资产见 ART_DIRECTION.md。每个包附文件 SHA256；构建脚本另输出 ZIP 校验值。
