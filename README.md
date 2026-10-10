# Otherwise — 雨停之前

Godot 4.7.2 的离线 2D 剧情短篇。一个公寓、一个雨夜、主角与林夏。她明早离开城市，你先决定怎样回应楼下的消息，再决定怎样把告别说完。

三种开场固定现实结果；电脑 ELSE 可以重构一次其他可能。退出时只保留真正读到的知识，物品和现实选择保持原样。可主动验证书架线索，获得一次新的问话。无需重构也能进入两个完整结尾之一。

## 运行

Windows 发行包：解压 `releases/otherwise/Otherwise-0.1.0-Windows-x64.zip`，双击 `Otherwise.exe`，保留同目录 `Otherwise.pck`。无需引擎、联网或账号。

源码：在 Godot 4.7.2 中打开 `project.godot`，F5 运行主场景；或 `godot --path .`。默认窗口 1280×720，内部舞台 1152×648，也已检查 1920×1080。

| 操作 | 输入 |
| --- | --- |
| 移动 | WASD／方向键，或点击空闲地面 |
| 交互、继续 | E；对白也可空格／Enter 或点继续 |
| 选项 | 数字 1–9，鼠标，或焦点键盘操作 |
| 暂停、音量、字号、重开 | ESC |

现实关键节点自动保存，暂停时可手动保存当前现实进度。标题页继续上次雨夜；模拟中的进度不保存。字号 100%–135%，可静音。存档和设置在 `%APPDATA%\Godot\app_userdata\Otherwise`。

## 验证与构建

Windows PowerShell，在仓库根运行。需要 Godot console 可执行文件在 PATH 中，示例使用本机安装名：

```powershell
# 受限环境把引擎用户目录限定在仓库；普通本机可保留默认目录。
$env:APPDATA = Join-Path (Get-Location) '.local\validation\appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) '.local\validation\localappdata'
Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script scripts/tests/story_test.gd
Godot_v4.7.2-stable_win64_console.exe --path . --audio-driver Dummy --script scripts/tests/input_test.gd
Godot_v4.7.2-stable_win64_console.exe --path . --audio-driver Dummy --script scripts/capture_story.gd
```

截图保存在 `.local/validation/frames/`。输入测试使用引擎真实事件分发；它不代替真人操作和情绪验收。测试存档位于指定 APPDATA，不改动玩家正常存档。

构建请用新的 PowerShell，或显式传入模板路径（上面的测试改变了 APPDATA）：

```powershell
.\scripts\build-windows.ps1
.\scripts\verify-windows.ps1
# 也可指定引擎、同版本 Windows release 模板、未存在的版本目录：
.\scripts\build-windows.ps1 -GodotPath 'C:\path\godot.exe' -TemplatePath 'C:\path\windows_release_x86_64.exe' -Version '0.1.1'
```

构建使用已安装的匹配模板，不下载依赖；拒绝覆盖已有版本。输出 EXE、PCK、引擎／字体许可、说明、SHA256 和 ZIP。开发测试、截图脚本及本地验证目录不进入 PCK。

## 项目记录

- [当前创作方向](docs/GAME_VISION.md)
- [完整剧情、34 项改进与 M4–M10](docs/SMALL_GAME_PLAN.md)
- [美术方向与五项新资产](docs/ART_DIRECTION.md)
- [验证结果与交付限制](docs/QA_REPORT.md)
- [资源来源与许可记录](docs/ASSET_LICENSES.md)
- [工作约定](AGENTS.md)

实现和自动验证已完成，发行候选包可运行。真人节奏／情绪验收、真实时长和声音听感仍待试玩确认；20–30 分钟是未测设计预算。原生窗口控制授权超时，不能声称人工键鼠通关。当前只交付 Windows；没有建立 Linux 副本。
