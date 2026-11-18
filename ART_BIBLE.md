# Long Time Ago — Official Art Bible & Master Asset Registry

> **Art Direction:** Cozy post-apocalyptic deep-sea salvage & museum sim inspired by *Dave the Diver* and *Stardew Valley*. Crisp pixel-art silhouettes, tactile sea-weathered charm, rich painterly shading, and glowing bioluminescent/holographic accents against deep-ocean blues.

---

## 1. Sprite Resolution, Grid Scale & Auto-Scaling Rules

### 3D Backpack Grid Unit Standard
All salvageable items follow a unified volumetric grid system for the 3D Backpack UI and in-world display:
- **Base Unit:** `1 grid unit = 32 px` (`Backpack.GRID_UNIT_PX = 32.0`)
- **Volume Format:** `"size_3d": [width_x, height_y, thickness_z]`
- **Target Display Pixels:** `"target_px": [width_x * 32, height_y * 32]`
  - Example: A `3 × 1 × 2` mechanical keyboard has `target_px = [96, 32]`.
  - Example: A `2 × 3 × 2` AI server core has `target_px = [64, 96]`.
- **Weight Scale:** Integer `1` (lightest, e.g. dogtags/mouse) to `5` (heaviest, e.g. AI server core).
- **Fragility Flag:** `"fragile": true | false` — fragile items (`relic_cup`, `relic_mask`, `relic_core`, `relic_console`) risk damage if stacked underneath heavier items in the 3D backpack.

### Engine Auto-Scaling & Filtering (`Backpack.load_smart_sprite`)
- **Texture Filter:** Always `CanvasItem.TEXTURE_FILTER_NEAREST` for crisp pixel art.
- **Any Input Resolution Supported:** Raw AI-generated PNGs (`512×512`, `1024×1024`, cropped custom dimensions) are automatically scaled uniformly using aspect-preserving fit:
  $$\text{scale} = \min\left(\frac{\text{target\_px.x}}{\text{frame\_w}},\ \frac{\text{target\_px.y}}{\text{frame\_h}}\right)$$
  Sprites never stretch or squash, and always fit cleanly inside their canonical pixel bounding box.
- **Horizontal Sprite-Sheets:** Animation strips are auto-detected when `width >= height * 2` on square-target assets (or filenames containing `_sheet`, `_strip`, or `_anim`). Wide static items (e.g., `3:1` keyboard, `2:1` handheld console) are protected from accidental slicing.
- **Background Requirement:** Always export PNGs with a **pure transparent background** (alpha channel) and centered artwork with minimal empty margin.

---

## 2. Official Color Palette

### Survivor & Signature Gear
| Swatch | Name | Hex Code | Usage |
| :--- | :--- | :--- | :--- |
| 🟨 | **Hazmat Mustard** | `#E5A93B` | Player diving/hazmat suit primary |
| 🟧 | **Suit Seam Shadow** | `#B87E1E` | Suit shading, folds, recessed panels |
| 🟨 | **Suit Highlight** | `#F5C35D` | Top sunlit rim highlights |
| ⬛ | **Deep Slate Pads** | `#2C3539` | Boots, gloves, knee/elbow pads, trim |
| ⬛ | **Ink Outline** | `#181D1F` | Universal dark pixel-art outline & straps |
| ⬜ | **Alloy Silver** | `#D0D8E0` | Buckles, valves, titanium hardware |

### Environment & UI Accents
| Swatch | Name | Hex Code | Usage |
| :--- | :--- | :--- | :--- |
| 🟦 | **Sonar Cyan** | `#00FFFF` | Sonar pings, EMP arcs, computing relics, HUD accents |
| 🟦 | **Deep Blueprint** | `#00BFFF` | Architectural blueprints, holographic displays |
| 🟪 | **Quantum Magenta** | `#FF00FF` | Legendary AI core, deep-abyss energy |
| 🟨 | **Museum Gold** | `#FFD700` | Gold currency, rare café relics, VIP bounties |
| 🟩 | **Bio-Hazard Lime** | `#ADFF2F` | Resource war relics, radioactive trench accents |
| 🟫 | **Barnacle Crust** | `#4E3F33` | Encrusted sea-rock clumps & seabed silt |
| 🟫 | **Dark Crater Pore** | `#17120E` | Barnacle pits, deep shadows |

### Rarity Tier Coding
- **Common:** `#00FFFF` / `#33BBFF` / `#FF9933` / `#C0C0C0`
- **Rare:** `#FFD700` / `#FF5588` / `#ADFF2F` / `#00BFFF`
- **Legendary:** `#FF00FF`

---

## 3. Master Style Prefix (Copy-Paste Base)

Use this exact prefix at the start of every AI image prompt so all characters, buildings, and relics share one cohesive visual identity:

```text
2D indie game pixel art asset, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame
```

---

## 4. Character & Building Registry (`ASSET_CATALOG`)

### Characters
| ID | File Path | Target Size (`target_px`) | Perspective |
| :--- | :--- | :--- | :--- |
| `diver` | `res://assets/characters/diver.png` | `72 × 72 px` | 2D side-scrolling horizontal swimmer facing right |
| `survivor` | `res://assets/characters/survivor.png` | `64 × 64 px` | 2.5D top-down upright stance |

#### `diver` (`res://assets/characters/diver.png` — `72×72 px`)
```text
2D indie game pixel art character sprite, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, 1:1 square canvas: a lone human deep-sea salvage diver swimming horizontally facing right, wearing a signature mustard-yellow (#E5A93B) hazmat diving suit, dark slate (#2C3539) knee pads, gloves, and propulsion fins, compact oxygen tank on back, glowing cyan diving mask visor, clean readable side-view silhouette
```

#### `survivor` (`res://assets/characters/survivor.png` — `64×64 px`)
```text
2D indie game pixel art character sprite, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, 1:1 square canvas: a friendly human survivor standing upright in 2.5D top-down RPG perspective facing forward, wearing a signature mustard-yellow (#E5A93B) hazmat diving suit with dark slate (#2C3539) boots, harness straps, and gloves, diving hood lowered around neck, warm expressive pixel face
```

---

### Buildings (Land Hub — 2.5D Top-Down)
| ID | File Path | Target Size (`target_px`) | Role |
| :--- | :--- | :--- | :--- |
| `museum` | `res://assets/buildings/museum.png` | `256 × 256 px` | Human Relic Exhibition Hall |
| `home` | `res://assets/buildings/home.png` | `256 × 256 px` | Expandable Survivor's Homestead & Cleaning Lab |
| `workshop_o2` | `res://assets/buildings/workshop_o2.png` | `192 × 192 px` | Oxygen Tank & Hydro-Fins Shop |
| `workshop_exo` | `res://assets/buildings/workshop_exo.png` | `192 × 192 px` | Exo-Cargo Frame & Salvage Riggers Shop |

#### `museum` (`res://assets/buildings/museum.png` — `256×256 px`)
```text
2D indie game pixel art building sprite, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, 1:1 square canvas in 2.5D top-down RPG perspective: a grand restored post-apocalyptic Human History Museum built from salvaged shipping containers and turquoise glass dome skylight, warm inviting golden entrance awning, stone steps, potted coastal plants, faint cyan holographic display glow inside the windows
```

#### `home` (`res://assets/buildings/home.png` — `256×256 px`)
```text
2D indie game pixel art building sprite, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, 1:1 square canvas in 2.5D top-down RPG perspective: a cozy modular Survivor's Homestead cabin constructed from driftwood timber, corrugated ocean-weathered sheet metal, solar roof panels, warm amber glowing living-room window, and a side glass-roofed Relic Cleaning Lab wing glowing softly cyan
```

#### `workshop_o2` (`res://assets/buildings/workshop_o2.png` — `192×192 px`)
```text
2D indie game pixel art building sprite, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, 1:1 square canvas in 2.5D top-down RPG perspective: a compact coastal Dive Gear & Oxygen Workshop shack with stacked pressurized teal and yellow air cylinders outside, brass pressure gauges, hanging rubber diving fins under a striped nautical awning, industrial compressor pipes
```

#### `workshop_exo` (`res://assets/buildings/workshop_exo.png` — `192×192 px`)
```text
2D indie game pixel art building sprite, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, 1:1 square canvas in 2.5D top-down RPG perspective: a rugged coastal Exo-Cargo Riggers & Salvage Crane workshop garage with yellow-and-black hazard stripes, heavy hydraulic gantry hoist arm, stacked salvaged titanium crates, orange welding spark glow from the open bay door
```

---

## 5. Master Relic Library (`relics_data.json`)

| ID | Name | Set | Rarity | Value | Min Depth | `size_3d` (X×Y×Z) | `target_px` | Weight | Fragile |
| :--- | :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `relic_keyboard` | Barnacle-Crusted Mechanical Keyboard | 21st Century Computing | Common | $150 | 15m | `3 × 1 × 2` | `96 × 32` | 2 | No |
| `relic_mouse` | Optical Gaming Mouse | 21st Century Computing | Common | $110 | 25m | `1 × 1 × 1` | `32 × 32` | 1 | No |
| `relic_cup` | Rusty Thermal Mug | Daily Café Life | Common | $80 | 10m | `1 × 2 × 1` | `32 × 64` | 1 | **Yes** |
| `relic_toaster` | Chrome Bread Warmer | Daily Café Life | Rare | $240 | 85m | `2 × 2 × 2` | `64 × 64` | 3 | No |
| `relic_mask` | Cracked Gas Mask | Resource War Remnants | Rare | $280 | 95m | `2 × 2 × 1` | `64 × 64` | 1 | **Yes** |
| `relic_dogtag` | Tarnished Titanium Dogtags | Resource War Remnants | Common | $190 | 45m | `1 × 1 × 1` | `32 × 32` | 1 | No |
| `relic_core` | Sunken AI Server Core | 21st Century Computing | Legendary | $650 | 160m | `2 × 3 × 2` | `64 × 96` | 5 | **Yes** |
| `relic_console` | Ancient Handheld Console | Daily Café Life | Rare | $380 | 110m | `2 × 2 × 1` | `64 × 64` | 2 | **Yes** |
| `blueprint_tube` | Pre-War Architectural Blueprint | Survivor Technology | Rare | $200 | 40m | `2 × 1 × 1` | `64 × 32` | 1 | No |

---

### Ready-to-Copy Relic AI Prompts

#### 1. `relic_keyboard` — `res://assets/relics/relic_keyboard.png` (`3×1×2` → `96×32 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, wide 3:1 horizontal aspect ratio (3x1x2 grid volume): a weathered retro mechanical computer keyboard with faded beige and teal keycaps, faint glowing cyan RGB strips along the chassis, light sea-salt patina, slight 3/4 isometric top-down angle
```

#### 2. `relic_mouse` — `res://assets/relics/relic_mouse.png` (`1×1×1` → `32×32 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, compact 1:1 square aspect ratio (1x1x1 grid volume): a sleek dark-slate optical gaming mouse with glowing electric-blue scroll wheel, tiny frayed cord stub, subtle ocean corrosion, clean readable silhouette
```

#### 3. `relic_cup` — `res://assets/relics/relic_cup.png` (`1×2×1` → `32×64 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, tall 1:2 vertical aspect ratio (1x2x1 grid volume): a tall insulated stainless-steel and burnt-orange coffee thermal tumbler mug with plastic sip lid, chipped paint, rust streaks, and delicate hairline ceramic crack
```

#### 4. `relic_toaster` — `res://assets/relics/relic_toaster.png` (`2×2×2` → `64×64 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, chunky 1:1 cubic aspect ratio (2x2x2 grid volume): a retro curved brushed-chrome two-slice kitchen toaster with brass lever handle, golden warm highlights, minor seawater oxidation and barnacle flecks along the base
```

#### 5. `relic_mask` — `res://assets/relics/relic_mask.png` (`2×2×2` → `64×64 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, bulky 1:1 square aspect ratio (2x2x2 grid volume): a weathered military rubber gas mask with olive-drab twin filter canisters, cracked circular greenish-tinted glass eyepieces, and tarnished brass buckles
```

#### 6. `relic_dogtag` — `res://assets/relics/relic_dogtag.png` (`1×1×1` → `32×32 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, compact 1:1 square aspect ratio (1x1x1 grid volume): a pair of notched brushed-titanium military dogtags overlapping on a coiled silver ball-chain, subtle salt tarnish and metallic glint
```

#### 7. `relic_core` — `res://assets/relics/relic_core.png` (`2×3×2` → `64×96 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, tall 2:3 vertical monolith aspect ratio (2x3x2 grid volume): a sleek armored dark-titanium vertical AI server tower core with exposed crystalline glass chamber glowing magenta and cyan inside, gold heat-sink fins, deep-sea kelp strands
```

#### 8. `relic_console` — `res://assets/relics/relic_console.png` (`2×1×1` → `64×32 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, wide 2:1 horizontal aspect ratio (2x1x1 grid volume): a retro handheld video game console with coral-pink and warm-gray plastic shell, dark D-pad on left, two round buttons on right, and a glowing turquoise LCD glass screen with tiny water-damage sheen
```

#### 9. `blueprint_tube` — `res://assets/relics/relic_blueprint.png` (`2×1×1` → `64×32 px`)
```text
2D indie game pixel art icon, Dave the Diver and Stardew Valley style, crisp dark outlines (#181D1F), rich painterly pixel shading, sea-weathered post-apocalyptic charm, centered composition, pure transparent background, no text, no UI frame, wide 2:1 horizontal aspect ratio (2x1x1 grid volume): a watertight brushed-steel cylindrical scroll tube with brass end-caps and a glowing cobalt-blue architectural blueprint scroll peeking slightly out
```
