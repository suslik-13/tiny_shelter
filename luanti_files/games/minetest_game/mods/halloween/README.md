# halloween

A temporary Halloween mod for the minetest servers.

The mod changes **only the look** of existing nodes, items, mobs and the unified_inventory window. It registers nothing (no nodes,
items, crafts or entities) and writes nothing into the map, node metadata, inventories or mob
staticdata. After the event the mod folder can simply be deleted and everything goes back to normal.

## What changes

| What             | Halloween look                                  | Nodes / items                                            |
|------------------|-------------------------------------------------|----------------------------------------------------------|
| Apples           | apple wrapped in cobweb                         | `default:apple`                                          |
| Torches          | glowing skull (floor, wall and ceiling)         | `default:torch`, `default:torch_wall`, `default:torch_ceiling` |
| Locked chests    | small coffin                                    | `default:chest_locked*` (including big chests from `connected_chests`) |
| Unlocked chests  | glowing jack-o'-lantern                         | `default:chest*` (including big chests from `connected_chests`) |
| Armor and shields| skeleton bones painted on top                   | every tool with an `armor_head/torso/legs/feet/shield` group (3d_armor, shields, etc.) |
| Sheep            | skeleton with a pumpkin head                    | all `mobs_animal:sheep_*` entities                       |
| Inventory window | cobwebs, cracks and spiders on the background, pumpkins, skulls, bones and coffins along the bottom | `unified_inventory` (only if the mod is on the server) |

Node behaviour (light, hardness, drops, formspecs, chest protection) stays the same. Only `tiles`,
`mesh`, `node_box`, `selection_box` and `inventory_image`/`wield_image` change, plus `texture`/`preview`
for armor.

## Screenshots

**Unlocked chests:** jack-o'-lanterns (single, open, big chest from `connected_chests`).

**Locked chests:** coffins (closed, open, big locked chest).

![Chests](screenshots/chests.jpg)

**Torches:** glowing skulls on the floor, on a wall and under a ceiling (at night).

![Torches](screenshots/torches.jpg)

**Apples:** wrapped in cobweb.

![Apples](screenshots/apples.jpg)

**Armor:** bones painted on top of steel, gold and diamond armor (on armor stands).

![Armor](screenshots/armor.jpg)

**Sheep:** skeletons with a pumpkin head.

![Sheep](screenshots/sheep.jpg)

**Items in the hotbar and in hand:** apple, skull, pumpkin, coffin and armor with a skull badge.

![Hotbar](screenshots/hotbar.jpg)

**unified_inventory:** crafting page, crafting guide, armor page (3d_armor_ui), bags page
and the lite layout (`unified_inventory_lite`).

![Inventory: crafting](screenshots/ui_craft.jpg)
![Inventory: crafting guide](screenshots/ui_craftguide.jpg)
![Inventory: armor](screenshots/ui_armor.jpg)
![Inventory: bags](screenshots/ui_bags.jpg)
![Inventory: lite layout](screenshots/ui_lite.jpg)

## How it works

- Everything happens in `minetest.register_on_mods_loaded` through `minetest.override_item`, so node
  definitions change only in the server's memory.
- If a mod is missing on a server (for example `connected_chests` or `shields`), that part is skipped.
  All dependencies in `mod.conf` are optional.
- **Sheep:** the texture is changed only on the live object (`set_properties`). The mob's own fields
  (`base_texture` etc.) are left alone, so the Halloween texture never ends up in saved staticdata.
  mobs_animal resets the texture on shearing, dyeing and wool regrowth, so the mod checks it again
  every 0.5 s.
- **unified_inventory:** the mod wraps `unified_inventory.get_formspec`. Right after the standard
  background it inserts its own `background[]` elements, so cracks, cobwebs (black and white, in the
  corners and in the empty areas) and sitting spiders are drawn under the slots, buttons and text.
  The window gets 0.75 taller: a strip of graveyard ground at the bottom with pumpkins, skulls, bones
  and coffins. Two spiders go down and up on their threads (`animated_image[]`) in the free areas
  left of the craft grid and above the trash slot. Both layouts (full and `unified_inventory_lite`) are
  supported. Nothing is stored anywhere, only the formspec sent to the client changes; without
  `unified_inventory` this part is skipped.
- **survival_shelter** runs an older mobs_animal with a different sheep model and a separate model for
  shaved sheep. The mod detects this by the presence of `models/mobs_sheep_shaved.b3d` and uses the
  `halloween_sheep_old*.png` textures.

## Installation

The mod lives in `minetest_game/mods/halloween` on the server.
Mods inside the game load automatically, so there is no need to enable it in `world.mt`. Just
restart the server.

## Removing after Halloween

1. Delete the `minetest_game/mods/halloween` folder from the server.
2. Restart the server.

After the restart players see the normal apples, torches, chests, armor, sheep and inventory window again.
If a client still shows the old textures from its cache, reconnecting is enough.

## Files

```
halloween/
├── mod.conf
├── init.lua          — all texture-swap logic
├── textures/         — generated textures (halloween_*.png, halloween_ui_*.png for unified_inventory)
├── models/           — skull meshes for floor, wall and ceiling torches (.obj)
├── screenshots/      — screenshots for this README (not used by the game)
└── tools/            — texture and model generator (only in the tiny_shelter copy)
    ├── gen_textures.py
    ├── b3d.py        — reader for the sheep .b3d models
    └── masks/        — armor masks for 3d_armor
```

## Regenerating textures

All PNG and OBJ files are produced by `tools/gen_textures.py` (requires Python 3, `numpy`, `Pillow`):

```bash
python3 tools/gen_textures.py
```

Without arguments the script generates everything except the sheep (including the `halloween_ui_*`
textures for the inventory window). To redraw the sheep, pass three
arguments in the form `<model.b3d>:<tex1.png>,<tex2.png>,...`:

- **NEW**: `mobs_sheep.b3d` + `mobs_sheep_base.png`, `mobs_sheep_wool.png` from the server;
- **OLD**: the same files from survival_shelter (older mobs_animal);
- **OLD_SHAVED**: `mobs_sheep_shaved.b3d` + `mobs_sheep_shaved.png` from survival_shelter.

After regenerating, copy `textures/` and `models/` into the mod copies on the server.
