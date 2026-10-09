# Otherwise — art direction and source provenance

The approved production direction is the existing 2D illustrated apartment. Preserve ordinary contemporary Chinese life, the warm room against cool rainy windows, and restrained comic outlines. The uncanny effect comes from a small repeated detail, not neon or new architecture.

## Delivered raster art

All new sources were generated through the built-in `image_gen` tool on 2026-10-09 (Asia/Shanghai), visually inspected, and copied into this repository. No external stock assets or API keys were used. Existing player and apartment images were supplied as style and identity references. Keep these source PNGs; Godot can consume them with `AtlasTexture`, retaining alpha without destructive crops.

| Source | Dimensions | Purpose and validation |
|---|---|---|
| `assets/art_sources/lin_xia_poses_v1.png` | 1536 × 1024, RGBA | Standing, seated without chair, holding phone; consistent clothes and identity. 68.8% of pixels have zero alpha. |
| `assets/art_sources/player_back_walk_v1.png` | 1388 × 1133, RGBA | Two opposing rear-view footfalls. First draft duplicated the leg pose; a targeted imagegen edit corrected the second frame. 71.9% zero alpha. |
| `assets/art_sources/photo_together_v1.png` | 1114 × 1411, RGBA | Warm ordinary memory of both characters, legible dark hair silhouettes; feathered transparent outer edge. |
| `assets/art_sources/entrance_rain_v1.png` | 1672 × 941, RGB | Covered residential entrance for the DOWN branch only; no people or text, fully painted canvas. |
| `assets/art_sources/hair_tie_detail_v1.png` | 1536 × 1024, RGB | Inspection closeup of the old cloth hair tie, with three clearly blue repair stitches and a small thread tail. |

Original built-in outputs remain in `C:/Users/guoqi/.codex/generated_images/01a11c3a-8ee6-72e2-ae7f-66eca275a330/`:

- Lin Xia: `exec-cb096e93-450b-4194-8c51-bc742eab0d5a.png`.
- Back walk final: `exec-4e0438d1-bf30-4d53-8b3c-2f5023206dd4.png` (draft `exec-1ff123ca-71da-4019-addc-355fa5154518.png`).
- Photo: `exec-f387b1ef-c148-49f8-aa85-89be57a66c5f.png`.
- Rain entrance: `exec-178131e7-5214-4b7e-bbf3-45596a66b191.png`.
- Hair tie detail: `exec-8f7e762b-ddad-4f46-9c63-46d180db33a5.png`.

## Character placement

Stage coordinates remain 1152 × 648. Main player height is 164 world pixels. Lin Xia uses the same standing height; do not enlarge her for the seated pose.

The Lin Xia source has three 512 × 1024 columns. Bounds below are measured with alpha > 32; these are *not* arbitrary crop estimates.

| Pose | Atlas region | Visible local bounds | Feet anchor | World location |
|---|---|---|---|---|
| Standing | `(0, 0, 512, 1024)` | `(187, 27)` to `(460, 1005)` | `(323.5, 1005)` | `(620, 405)` |
| Seated | `(512, 0, 512, 1024)` | `(119, 213)` to `(408, 1005)` | `(263.5, 1005)` | `(690, 486)` |
| Phone | `(1024, 0, 512, 1024)` | `(65, 27)` to `(332, 1005)` | `(198.5, 1005)` | `(820, 395)` |

Use a common scale `164 / 978 = 0.167689`. With centered 512 × 1024 sprites, local position relative to the feet node is `(256 - anchor.x, 512 - 1005) * scale`: approximately standing `(-11.32, -82.67)`, seated `(-1.26, -82.67)`, phone `(9.64, -82.67)`. The seated silhouette is about 133 world pixels tall. A tight crop also works, but its scale must stay tied to standing height, not normalize seated height back to 164.

For the two back-walk frames, recommended equal padded regions are `(180, 17, 440, 1071)` and `(754, 17, 440, 1071)`. This removes unequal blank column margins and gives a common feet baseline. Use the existing player height normalization on these equal canvases. The new gait is intentionally small; verify the idle-to-walk head/shoulder transition in the running game rather than assuming perfect registration.

For the photograph, use a warm paper backing within the existing frame near `(449, 155)`, about 30 × 38 world pixels. A clean central portrait crop is `(160, 180, 794, 1006)`. At thumbnail scale, two faces matter more than cafe details. Offer the full raster in an inspection panel if the scene needs close examination.

The entrance background fills the 1152 × 648 stage by scaling its full source, without cropping out the covered foreground. It is a narrative backdrop, not a new explorable city scene. Place the two people on the empty lower landing, around `(470, 470)` and `(690, 470)`; the stairs stay behind their feet. Hide apartment furniture, rain overlay, photo and shelf while this backdrop is displayed, then restore them on return. Use the same character scale and contact shadows. The wall lamp is the warm visual focus; avoid adding rain over the sheltered character positions.

The hair tie closeup is an inspection insert, not a floor object replacement. Show the complete 3:2 image with preserved aspect ratio; 160 × 107 world pixels remains legible, and a larger 240 × 160 inspection card gives the blue seam repair more weight. The old thin charcoal-brown ring silhouette matches the existing tiny prop. In-room a few subdued blue stitch pixels can support the clue, but the inspection image carries the readable detail. Blue repair loops are deliberately enlarged for thumbnail readability; they must not glow or become a general anomaly marker.

## Minimal engineering support

- Replace the old circular 34-pixel character shadow with a shallow ellipse, approximately 21 × 6 pixels at 18–22% opacity. Keep it directly beneath the soles, static relative to feet; avoid a vertical dark disk climbing the legs.
- NPC standing silhouettes need the same shallow contact shadow. Seated feet can use two smaller contact ellipses; do not draw a second large floor shadow beneath the whole sofa.
- Sofa seating must draw the character over the sofa upholstery and below only the front arm if necessary. Keep fixed seated pose layering explicit; do not let a whole-sofa occluder hide her.
- Tabletop cup and envelope must be children of their furniture's occluder wrapper with local drawing order after the furniture, or have equivalent explicit ordering. A free `Room` child sorted by its painted tabletop Y will be hidden by the furniture's forward edge.
- Keep floor props sorted by their contact point. The umbrella's top is not the sorting anchor. NPC and player nodes should sort on soles, not torso center.
- Keep rain drops inside the painted glass polygons; rectangular ranges can place them on the wardrobe or wall. The background already contains rain, so a light sparse overlay is sufficient.
- Preserve the apartment layout. The raised camera makes visible furniture much larger than its walkable footprint; collision should describe floor occupation and leave an entrance corridor. Do not increase collision bounds merely to match the painted upper furniture silhouette.
- Keep most colors in warm taupe, dull green-grey, cream, charcoal, wood and cool desaturated blue. Lin Xia's coat distinguishes her silhouette without making her a bright accent. A phone-screen pulse can be the opening's one brighter cue.
- Fill the complete viewport with the stage backdrop color, letterbox using an intentional deep blue charcoal where needed, and avoid unpainted gray bars.

## Prompt record

The following production prompts record the final intent and invariants. Generation mode was built-in throughout. The original apartment and player sprites are reference inputs, never replacement targets.

### Lin Xia — `illustration-story`

Production 2D game character sheet, transparent PNG; three equal columns with no separators or labels. Contemporary Chinese woman about 28, saying goodbye on an ordinary rainy night. Match the apartment and player reference's dark thin clean outlines, muted flat fills and soft two-level cel shading, realistic adult proportions, calm face. Shoulder-length dark hair, warm taupe short coat over cream shirt, charcoal straight trousers, dark low shoes. Identical identity and clothes in every pose. Standing with hands loosely clasped, seated on an invisible seat with hands over knees and grounded feet, standing holding a dark phone in both hands. Elevated 3/4 camera, facing three-quarter left. All extremities inside their columns; standing heads equal height; feet on a common baseline near 90% of canvas. Warm interior illumination with subtle cool shadow planes. True alpha background including gaps between limbs; no floor, cast shadow, furniture, text, panels, watermark, bag or umbrella.

### Back walking — `identity-preserve`

Use the existing male rear-view sprite as exact identity, body dimensions, clothes and drawing-style reference. Two equal-width columns of successive gentle walking poses from behind, head slightly right. Grey-green hoodie, charcoal trousers, brown house shoes. Clean comic outlines and restrained shading. Left frame left foot forward/right trailing, right frame the reverse, small opposite arm swings. Preserve head, shoulders and torso; all extremities fully in each column, heads same height, feet baseline near 94%. True alpha empty background; no shadows, glow, labels, panels or additional people.

Correction applied to the first generated sheet: keep left column unchanged and preserve all identity, alpha, canvas, head/torso and style. Change right column only: right leg bears weight closest to camera, its shoe lowest at lower right; left leg goes away, shoe peeks above left. Reverse leg crossing and arm swing. Keep lowest feet on original baseline. Do not duplicate the first pose again.

### Photograph — `illustration-story`

Portrait illustrated ordinary snapshot of these exact two Chinese characters a few years earlier at a quiet street cafe. Faces and shoulders side by side, relaxed modest smiles toward camera. Man in grey-green sweatshirt, woman in cream shirt and taupe jacket. Warm daylight, slightly faded printed-photo colors, clean dark comic lines and soft cel shading. Soft cream cafe wall with a hint of plant; central large faces and strong hair silhouettes readable at 30 × 38. No additional person, physical frame, border, words, logo, watermark, rain, science fiction, romantic embrace or dramatic gesture.

### Rain entrance — `illustration-story`

Landscape 16:9 background for one limited stage. Existing apartment is only a style reference: clean dark comic lines, ordinary coherent geometry, muted flat painted fills and restrained shading. Modest covered entrance of a present-day Chinese apartment building on a rainy night, fixed elevated three-quarter camera. No people. Plain closed glass-and-metal door slightly left of center under short canopy, cream plaster and brown-grey brick, a small warm wall lamp illuminating wet doorstep. Two shallow wet steps descend toward camera with subtle lamp reflections. A drain and rain ripples, cool rainy edges with anonymous buildings and few lit windows. Broad empty central foreground landing for two 164-pixel-tall characters near `(470,470)` and `(690,470)` on the 1152 × 648 stage, stairs behind their positions. Intimate, ordinary, restrained detail. No text, signage, logos, people, vehicles, shopfronts, neon, holograms, science fiction, cinematic haze or rain inside shelter. Fully painted canvas with no margins. Built-in `image_gen`, opaque background mode, generated 2026-10-09, visually inspected and saved in the project.

### Hair tie inspection — `illustration-story`

Landscape 3:2 inspection closeup readable at about 160 × 110. Apartment illustration is style reference; original `prop_hair_tie.png` is exact ordinary object reference. One old slightly faded thin charcoal-brown cloth elastic hair tie, not a fluffy scrunchie, lying as a horizontal oval on plain warm shelf wood, slightly elevated three-quarter view. Dark restrained comic outlines and muted fills, soft two-tone shading. Inner cloth seam on the upper-right section has one short unmistakably blue hand repair, about three small blue stitches across a split and one tiny thread tail. Blue muted but distinct, enlarged enough to notice in a thumbnail, never glowing. Slightly worn dark fabric; simple wood grain and small contact shadow. No text, labels, arrows, circles, hands, faces, jewellery, packaging, extra items or dramatic effects. Entire canvas painted with no border. Built-in `image_gen`, opaque background mode, generated 2026-10-09 using both reference images; visually inspected and saved in the project.

## Scope and remaining visual verification

These are complete authored source assets, not a new background or a complete animation set for Lin Xia. Three expressive static poses fit the small story's current needs. No additional environment replacement is needed unless in-game evidence exposes an actual readability problem. Verify contact shadows, NPC occlusion, photo placement, furniture props and walking registration in rendered gameplay. Human aesthetic judgment and a first-time player's understanding of the clue remain playtest checks.
