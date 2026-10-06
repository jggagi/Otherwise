# Game Vision — Otherwise

## 1. Creative thesis

**Otherwise** is a contemporary narrative game set in **2026**, not in a futuristic world.

The world should look and feel almost completely ordinary: apartment buildings, laptops, phones, takeout bags, delivery boxes, umbrellas, office work, rain, elevators, ride-hailing, late-night messages.

The extraordinary element is not futuristic technology. It is the growing uncertainty around a mundane-looking AI program called **ELSE**.

The desired tone is:

> **当代都市 AI 魔幻现实主义**

Quiet, intimate, grounded, slightly uncanny.

No cyberpunk city. No holographic future interfaces. No “2050 technology” exposition.

---

## 2. The opening

A rainy weekday night in a present-day Chinese city.

The protagonist has just returned home.

The apartment contains ordinary traces of life:

- half-finished coffee
- work laptop and personal laptop
- takeout
- charger cables
- delivery boxes
- books and framed photos
- an unopened letter
- shoes and umbrellas near the door

The phone vibrates.

> **林夏：我在你楼下。**

The player initially has very little context about Lin Xia or the history between them.

The first important choice should feel completely ordinary:

1. Go downstairs.
2. Reply.
3. Do nothing.

There is no visible “morality meter” and no obvious right choice.

The selected branch plays out for a short period.

Later, the protagonist's personal computer wakes.

A side project opens:

```text
ELSE

Unresolved decision detected.

Reconstruct alternatives?

[ RECONSTRUCT ]
[ NOT NOW ]
```

The player chooses to reconstruct.

The room returns to the moment of the message.

The player makes another choice.

---

## 3. What ELSE is

ELSE is **not initially presented as supernatural**.

It is a believable 2026 personal AI experiment.

Its apparent purpose:

> reconstruct plausible counterfactual events from personal context.

Possible data sources may be referenced narratively:

- chat history
- photos
- calendar events
- location traces
- personal notes
- device history

For the prototype, these do **not** need real integrations. They are story context only.

At first, ELSE explicitly warns the player that simulations are probabilistic reconstructions, not real alternate universes.

This framing matters. The player should initially think:

> “This is just a very convincing model hallucinating a possible life.”

Then something breaks that explanation.

Example:

Inside a simulation, Lin Xia says:

> “你书柜最下面那层，还有我的东西。”

The player exits the reconstruction and checks the real apartment.

There really is something there.

Nothing in the known data provided to ELSE should explain how it knew.

Do not explain this immediately.

---

## 4. The core mechanic: knowledge instead of loot

The main progression currency is **knowledge**.

The player can experience multiple versions of the same period, but cannot simply merge all physical outcomes.

A special piece of durable knowledge is called an **Anchor**.

Example:

```text
ANCHOR

她不是因为你没有下楼而生气。
她是在害怕明天。
```

An Anchor may influence what the player can notice, ask, understand, or choose in another branch.

The important principle:

> **Knowledge crosses timelines more easily than world state does.**

This prevents the game from becoming an inventory puzzle about stealing items from parallel worlds.

---

## 5. First vertical slice

The first slice should be intentionally small.

### Space

One apartment only:

- entrance / hallway
- living room
- small dining / kitchen area
- bedroom glimpse
- balcony
- corridor just outside the door

### Characters

- protagonist
- 林夏

Do not add a cast of supporting characters yet.

### Playtime

Target approximately **20–30 minutes**.

### Branches

The opening message produces three branches.

The exact story may evolve during iteration, but an initial structure is:

#### Branch A — 下楼

The protagonist goes downstairs.

The player learns something about why Lin Xia came.

#### Branch B — 回复 / 让她上来

Lin Xia enters the apartment.

The environment changes subtly:

- two mugs instead of one
- another pair of shoes near the door
- a chair pulled out
- phone placed face-down
- wet umbrella
- different body language

#### Branch C — 不回复

Lin Xia leaves.

Later, the protagonist notices evidence that reframes her visit.

The purpose of the three branches is not to create three endings.

They should reveal **different pieces of the same emotional truth**.

---

## 6. Environmental storytelling

The apartment is part of the narrative system.

The player should learn to notice differences without always being told that something changed.

Examples:

- a mug changes position
- an extra pair of shoes appears
- a chair is pulled out
- a photo is visible in one branch
- a phone is face-up in one branch and face-down in another
- an umbrella is wet
- a delivery box has moved
- the room is slightly messier after a difficult conversation

Avoid a UI message like:

> “Timeline B differs from Timeline A.”

Whenever possible, let the room communicate the difference.

---

## 7. Visual direction

### Core look

**Stylized 3D contemporary apartment diorama / stage box.**

Use a fixed elevated **3/4 camera** with some perspective.

The apartment should feel like a carefully constructed miniature stage floating against darkness, but the materials and props should remain grounded and familiar.

The game should be achievable in Godot without requiring photoreal character production.

### Characters

Characters should be readable primarily through:

- silhouette
- clothing
- posture
- movement
- distance
- blocking within the room

Do not depend on detailed facial animation for the prototype.

### Lighting

Reality:

- warm gray interior
- wood tones
- practical lamps
- cool rainy exterior light
- restrained contrast

Simulation:

**almost identical to reality.**

Do not tint the whole world blue.

Instead use subtle anomalies:

- duplicated object positions
- a chair briefly visible in two states
- faint human pose echoes
- frozen or unnaturally repeated background motion
- an object appearing both full and empty for a moment
- repeated light patterns outside the window

The player should gradually notice that a simulation is “too consistent” in places the model did not truly reconstruct.

### Things to avoid

- cyberpunk neon
- hologram-heavy UI
- futuristic furniture
- generic sci-fi blue filters
- giant floating data panels
- photoreal facial-animation requirements
- excessive bloom
- visual clutter with no narrative purpose

---

## 8. UI

During normal play, keep HUD nearly invisible.

Interaction can be minimal:

```text
PHONE
DOOR
PHOTO
LAPTOP
```

Dialogue should feel closer to quiet cinematic subtitles than a giant RPG dialogue box.

### ELSE / causality view

The second visual layer is a restrained causality graph:

```text
林夏发来消息
      |
   +--+------+
   |         |
  下楼      不回复
   |         |
  开门      看见照片
   |         |
   ?         ?
```

Known events are solid.

Partially inferred events are subdued.

Unknown possibilities remain `?`.

**Anchor** nodes may use a subtle warm gold accent.

No overloaded sci-fi interface.

---

## 9. What this game is not

Do not accidentally turn Otherwise into:

- a combat game
- an open-world city game
- a detective evidence-board simulator
- a dating sim built around affection points
- a hard-science multiverse story
- a cyberpunk game
- a procedural LLM demo
- a giant branching tree where every choice requires bespoke content

The game should remain intimate and authored.

---

## 10. Design principle for expansion

The first room must work before the city expands.

A possible future structure could include:

- apartment
- late-night convenience store
- last metro
- office
- railway station / airport

But none of these should be built until the apartment vertical slice produces the intended feeling:

> “Wait — was that detail also present in reality?”

That feeling is the first proof that the game works.
