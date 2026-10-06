# AGENTS.md — Trae Working Agreement

This repository is intended to be implemented primarily in **Godot 4** on the X1 Lite Creative Lab.

Before making large changes, read [docs/GAME_VISION.md](docs/GAME_VISION.md).

The project deliberately separates **creative direction**, **visual direction**, and **implementation**.

---

## 1. Roles

### Game Director

The human owner makes final decisions about:

- story
- pacing
- emotional intent
- what a choice means
- what information each branch reveals
- whether a scene is interesting
- what stays or gets cut

Agents should not silently expand the premise.

When uncertain, prefer the **smaller authored solution**.

---

### Godot Engineer — DeepSeek-V4-Pro

Primary responsibility:

- Godot 4 project structure
- GDScript
- SceneTree design
- player movement / interaction
- dialogue implementation
- state management
- timeline / branch mechanics
- save/load when needed
- debugging
- refactoring after working behavior exists
- performance appropriate for the X1 Lite

The Godot Engineer **may implement visual direction**, but should not independently redefine it.

Do not turn an art problem into a large architecture rewrite.

Do not invent new gameplay systems just because they are technically interesting.

Prefer simple, inspectable Godot scenes and resources over unnecessary frameworks.

---

### Visual / Art Director — separate design model

Primary responsibility:

- interpret visual reference images
- camera composition
- room composition
- lighting direction
- material / palette guidance
- prop density
- environmental storytelling
- UI visual language
- ELSE causality-view presentation
- identifying what should remain visually subtle

The Art Director should produce **visual guidance and references**, not restructure gameplay code.

If a visual idea requires code support, describe the required capability and hand it to the Godot Engineer.

---

### Cheap / fast model

May be used for:

- repetitive file edits
- naming cleanup
- mechanical scene edits
- simple documentation
- low-risk boilerplate

Do not delegate major architectural or creative decisions merely to save tokens.

---

## 2. Shared boundary

A healthy handoff looks like:

```text
Game Director
    ↓
creative intent / scene goal

Art Director
    ↓
visual reference + implementation constraints

Godot Engineer
    ↓
playable implementation

Game Director
    ↓
playtest / keep / cut / revise
```

Do not let a single agent simultaneously become writer, art director, engine architect, and producer.

---

## 3. Implementation philosophy

**Playable first. Systems second.**

The project is a Creative Lab prototype.

The first objective is not an elegant generalized engine.

The first objective is:

> a small scene that produces the intended feeling.

Prefer:

- one working apartment
- one working interaction
- one convincing transition
- one meaningful branch

over:

- generic quest frameworks
- generalized graph editors
- large dependency systems
- speculative future features
- plugin-heavy infrastructure

Refactor only after actual repeated needs appear.

---

## 4. First implementation milestone

### Milestone 0 — Apartment slice foundation

Create the smallest playable Godot project that establishes the game's spatial language.

Required:

1. Godot 4 project boots directly into the apartment.
2. Fixed elevated 3/4 `Camera3D`.
3. Simple apartment blockout:
   - entrance
   - living room
   - basic kitchen/dining zone
   - balcony boundary
4. Player character or temporary capsule can move around the apartment.
5. Prefer simple click-to-move if it can be implemented robustly; otherwise use minimal keyboard movement temporarily.
6. Four interactable placeholders:
   - phone
   - front door
   - laptop
   - photo
7. A tiny interaction prompt.
8. The phone can display:
   > 林夏：我在你楼下。
9. Basic warm-interior / cool-rainy-exterior lighting.
10. Keep geometry primitive if necessary.

Do **not** yet implement:

- the full timeline system
- save/load
- procedural dialogue
- LLM integration
- a full branching editor
- character facial animation
- other city locations

### Success condition

The player can launch the game, move through the apartment, inspect the four objects, receive the message, and understand the intended camera / space / mood.

Commit that milestone before expanding scope.

---

## 5. Milestone 1 — The first choice

After Milestone 0 is stable:

Implement only the first decision:

```text
林夏：我在你楼下。

[ 下楼 ]
[ 回复 ]
[ 不回复 ]
```

Each option may initially lead to a very small stub state.

The purpose is to prove branch state management without building a generalized narrative engine.

Use the simplest data representation that can support three branches.

---

## 6. Milestone 2 — ELSE reset

Only after the first choice works:

- show ELSE on the laptop
- allow the player to reconstruct one alternative
- reset the apartment to the earlier decision state
- deliberately preserve only explicitly approved cross-branch knowledge
- introduce the first subtle visual anomaly

Do not implement a general multiverse simulation.

---

## 7. Coding constraints

- Godot 4.x.
- Prefer GDScript unless there is a concrete reason otherwise.
- Keep scenes modular but not over-generalized.
- Use typed GDScript where it improves clarity.
- Avoid singleton/autoload proliferation.
- State ownership must be explicit.
- Avoid hidden cross-scene mutation.
- Keep interaction code easy to replace.
- New systems should have a concrete current use case.
- No network dependency is required for the vertical slice.

---

## 8. Art constraints for engineering

Use temporary geometry aggressively.

Good placeholder art:

- clean boxes
- simple neutral materials
- coherent proportions
- intentional lighting

Bad placeholder art:

- random free assets with conflicting styles
- neon sci-fi props
- visual noise added to make the room feel “detailed”

A cohesive graybox with good lighting is more useful than a detailed but incoherent room.

---

## 9. Scope protection

Before implementing something substantial, ask:

1. Does the apartment vertical slice need this now?
2. Will the player notice it?
3. Does it create story, interaction, or atmosphere?
4. Are we solving an observed problem or imagining a future one?

If the answers are weak, do not build it yet.

---

## 10. Definition of done for an agent task

An implementation task is complete when:

- the project runs
- the changed path can be exercised in-game
- errors are fixed rather than merely described
- relevant code is readable
- scope remains aligned with GAME_VISION
- the result is committed in a coherent unit
- the agent reports:
  - what changed
  - how to run/test it
  - known limitations
  - recommended next smallest step

The agent should not claim success without actually running the relevant Godot project or validation available in its environment.
