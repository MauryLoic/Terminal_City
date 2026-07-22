# Terminal_City — Godot 4 client

Post-apocalyptic MMOFPS in development, inspired by the Neocron
wastelands: irradiated terrain, contaminated river, mutant wildlife.
Godot 4 client, Akka/Pekko UDP server (see PROTOCOL.md).

## Open and play

1. Godot 4.7 → **Import** → select `project.godot`.
2. F5. The player spawns on the south bank of the river.

## Controls

| Key             | Action                                          |
|-----------------|-------------------------------------------------|
| ZQSD / WASD     | Movement (physical keycodes, AZERTY-friendly)   |
| Mouse           | Look — hold left click: fire                    |
| Space           | Jump                                            |
| Shift           | Sprint (drains stamina)                         |
| Ctrl            | Crouch (hold)                                   |
| C               | Crouch (toggle)                                 |
| 1 / 2           | Switch weapon: AK / laser pistol (once crafted) |
| E               | Loot a corpse nearby                            |
| Alt+E           | First / third person view                       |
| I               | Inventory                                       |
| F1              | Server connection panel                         |
| Escape          | Release / recapture the mouse                   |

## The world

Procedurally generated at load time (`world_gen.gd`, fixed seed — same
seed on the server = same world for everyone). Rugged terrain ringed by
dune mountains, toxic river (6 HP/s inside!), stone buildings and
abandoned shacks, dead trees, rocks, scattered junk.

## Current gameplay

- Health + stamina (sprinting drains it, walking regenerates it)
- Neocron-style aim lock: brackets tighten over 1.2 s of sustained aim;
  spread and damage scale with the lock
- Weapons: AK (3-round bursts) and craftable laser pistol (heavy
  hitscan beam that stays visible 3 s, then cooldown)
- Material system: per-surface impact visuals (dirt, stone, wood,
  metal, flesh, acid), mass-based object pushing, three destruction
  tiers (indestructible / slow / fast)
- Vampire bats in packs of two: passive on patrol, the whole pack
  attacks (acid spit) if approached or shot; disengages at distance
- Lootable corpses (E key): weapon/medical components and junk;
  despawn 60 s unlooted, 5 s after looting
- Crafting window (gear wheel): laser pistol with random slots (0-5,
  5 is rare) or S/M/L medkits; failure turns parts into junk
- Grid inventory, right click to drop items on the ground (pickable
  again, despawn 30 s); the whole inventory is lost on death
- Floating health bars above mobs
- All sounds synthesized in code (no audio assets)

## Multiplayer

Complete UDP network client (`network_client.gd`, `Net` autoload):
join/welcome, 20 Hz positions with sequence numbers, shot relaying,
ping, timeout. Remote players are interpolated. The Akka/Pekko server
is to be implemented as a mirror of **PROTOCOL.md**.

## Structure

```
project.godot
scenes/    main, player, remote_player, ak47, private_eye, psi_monk,
           connect_ui, inventory_ui, craft_ui
scripts/   world_gen (terrain + props), player, bullet, laser_beam,
           hit_effects, impact, debris, bat + bat_spawner + acid_glob,
           corpse, pickup, dropped_item, inventory (+ ui), craft_ui,
           mob_health_bars, target_reticle, network_client, sfx, main,
           models (ak47, laser_pistol, private_eye, psi_monk)
```

All assets (3D and audio) are generated in code — to be progressively
replaced by real assets (glTF from Blender, .ogg samples) without
touching the logic.
