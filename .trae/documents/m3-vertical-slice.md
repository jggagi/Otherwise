# Milestone 3 — 完整垂直切片（环境故事化 + Anchor + 「没拆开的信」惊悚时刻）

## Context（背景与目标）

M0（公寓基础）、M1（林夏消息三选一）、M2（ELSE 重构机制）均已完成。三个分支的剧情文字其实已经在 `_select_choice` 里写好（下楼 / 回复 / 不回复各一段），但存在明显落差：**选择后只是黑屏放字幕，房间原样返回，环境毫无变化**，因此玩家无法产生 GAME_VISION §10 定义的目标感受：

> 「等等——这个细节，现实里也有吗？」

本里程碑补齐产生这种感受所缺的三块能力（范围已与 Game Director 确认，ELSE 因果图延后）：

1. **分支环境变化**（§5/§6）——选择后房间留下对应痕迹。
2. **Anchor 知识机制**（§4）——跨分支保留的「金句」知识，并影响后续分支的理解。
3. **「打破解释」惊悚时刻**（§3）——用**没拆开的信**承载：模拟里林夏透露一个现实才存在的细节，退出后玩家在真实房间验证它确实在。

全部改动集中在 `scripts/main.gd`（沿用现有单文件状态机风格），不引入 autoload / 资源系统 / 新框架。

---

## 设计数据表示（保持简单、显式）

在 `main.gd` 顶部新增三个状态变量，与 `seen_branches` / `reconstruct_count` 并列：

```gdscript
var anchors: Array[String] = []          # 已获得的 Anchor id（跨重构持久）
var letter_revealed: bool = false        # 「没拆开的信」惊悚时刻是否已触发
var props_by_branch: Dictionary = {}     # Choice -> Array[Node2D]（占位道具节点）
```

---

## 实现方案（三块）

### A. 分支环境变化（environmental storytelling）

**新增占位道具系统**（临时几何，符合 AGENTS.md「aggressive temp geometry」，后续可换 Antigravity 道具精灵）：

- 新增 `_build_props()`：用 `Polygon2D` 画简单形状作占位道具（鞋 / 杯子 / 伞 / 字条），默认 `visible = false`，挂到 `room`，按分支登记进 `props_by_branch`。
- 新增 `_apply_branch_props(choice: Choice)`：隐藏所有道具，再显示该分支对应的道具。
  - 在 `_return_to_room()` 末尾调用，让房间反映刚看过的分支。
  - 在 `_reconstruct()` 里用 `_apply_branch_props(Choice.NONE)` 清空，表示「结果视为未发生」。

**暂定道具映射（草稿，待 Game Director 定稿；具体坐标实现时用十字标记法标定）**：

| 分支 | 房间痕迹 |
|---|---|
| 回复（让她上来） | 门口多一双鞋 + 茶几第二个杯子 + 门口湿伞 |
| 下楼 | 门口一把没撑开的伞靠墙（呼应她没撑伞） |
| 不回复 | 门口地上被雨打湿的字条 |

### B. Anchor 知识机制

- **获得条件**：`_return_to_room()` 追加分支名后，若去重后的 `seen_branches` 数量 ≥ 2 且尚未获得，则 `anchors.append("fear_of_tomorrow")`。
- **展示**：`_open_else()` 里，在「已体验的分支」下方，当 `anchors` 非空时渲染一行金色锚点文本（`font_color` 用暖金色 `Color(0.95, 0.78, 0.35)`），符合 §8 的「Anchor 用暖金强调」。
- **效应（体现 §4「知识比世界状态更容易跨越时间线」）**：新增 `_branch_text(choice)`，当 `anchors` 已含该 id 时，任意分支演出末尾追加一句主角的领悟。

### C. 惊悚「没拆开的信」时刻

- **新增交互物「信」**：在 `_build_interactables()` 里 `_register("letter", ...)`，初始文本平淡：「一封没拆开的信，压在桌角。」（位置待标定，建议书桌附近）。
- **模拟内的透露**：`_branch_text()` 里，当 `reconstruct_count >= 1` 且分支为「回复」时，追加林夏台词，并把 `letter_revealed = true`。
- **现实验证**：返回房间后，`letter_revealed == true` 时，信的文本更新为惊悚确认（与现有照片异常 `_apply_reconstruct_anomalies()` 同理，直接改 `entry.text`）。

---

## 分支文本统一化

把 `_select_choice()` 里硬编码的三段文本抽成 `_branch_text(choice) -> String`：

- 基础文本 = 现有三段（不动）。
- 叠加逻辑按优先级：Anchor 领悟行 → 重构中的「信」台词。

这样分支文本、Anchor 效应、惊悚台词三处都在一处可读、可测、可替换。

---

## 修改的关键文件

- [scripts/main.gd](file:///d:/TraeLab/Projects/Otherwise/scripts/main.gd) —— 唯一的核心改动文件：
  - 新增状态变量（`anchors` / `letter_revealed` / `props_by_branch`）
  - 新增 `_build_props()`、`_apply_branch_props()`、`_branch_text()`、`_maybe_earn_anchor()`
  - 修改 `_build_interactables()`（加「信」）、`_select_choice()`（用 `_branch_text`）、`_return_to_room()`（应用环境 + 触发 Anchor）、`_reconstruct()`（清环境）、`_open_else()`（金色 Anchor 展示）
- [scripts/player.gd](file:///d:/TraeLab/Projects/Otherwise/scripts/player.gd)、[scenes/apartment.tscn](file:///d:/TraeLab/Projects/Otherwise/scenes/apartment.tscn) —— 不改动（沿用现有 `set_physics_process(false)` 冻结 + Room 无偏移结构）

---

## 草稿文案（待 Game Director 定稿）

**Anchor（取自 GAME_VISION §4）：**

```text
她不是因为你没有下楼而生气。
她是在害怕明天。
```

**Anchor 效应行（追加在分支演出末尾）：**

```text
你忽然明白：她不是在等一个答复，她是在害怕明天。
```

**「信」的透露台词（重构中·回复分支）：**

```text
林夏：「……你桌上那封信，一直没拆开吧。」
```

**「信」的惊悚确认（返回房间后交互）：**

```text
封口完好，从未拆开。可你盯着它，后背发凉——
ELSE 是怎么知道它在这里的？
```

---

## 验证方案

1. **headless 双校验**（沿用既有命令，均需 exit 0）：
   - `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import`
   - `Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit-after 120`
2. **自动截图验收**：新增 `scripts/capture_m3.gd`（仿照 `capture_m2.gd` 的 SceneTree + CaptureDriver 模式），回放完整链路并截图到 `.verify/`：
   1. 初始房间（信平淡文本 + 无道具）
   2. 手机 → 选「下楼」→ 返回 → 验证门口伞痕迹
   3. 笔记本 → ELSE → 重构 → 选「回复」→ 验证林夏「信」台词
   4. 返回 → 交互「信」→ 验证惊悚确认文本
   5. 再开 ELSE → 验证金色 Anchor 展示
3. **坐标标定**：道具与「信」的位置若与背景图错位，用十字标记法（参照既有 calibrate 思路）读图判定后修正。

---

## 已知限制 / 边界

- 惊悚「信」台词目前只在**重构后的「回复」分支**触发（她进门、可自然指向桌上的信），路径偏窄；若需更易触发可再议（这是创作决策，不在本次默认实现内）。
- 道具为纯占位几何，风格与背景插画有差异，待后续 Antigravity 生成道具精灵替换。
- ELSE 因果图（§8）本里程碑不做，留作后续 UI 打磨。