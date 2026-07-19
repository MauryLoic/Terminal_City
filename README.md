# Terminal_City — client Godot 4

MMOFPS post-apocalyptique en cours de développement, inspiré des
wastelands de Neocron : terrain irradié, rivière contaminée, faune
mutante. Client Godot 4, serveur Akka/Pekko UDP (voir PROTOCOL.md).

## Ouvrir et jouer

1. Godot 4.7 → **Importer** → sélectionner `project.godot`.
2. F5. Le joueur apparaît sur la rive sud de la rivière.

## Contrôles

| Touche          | Action                                        |
|-----------------|-----------------------------------------------|
| ZQSD            | Déplacement (keycodes physiques, AZERTY ok)   |
| Souris          | Regarder — clic gauche maintenu : tir continu |
| Espace          | Sauter                                        |
| Shift           | Sprint (consomme l'endurance)                 |
| Ctrl            | S'accroupir (maintenu)                        |
| C               | S'accroupir (verrouillé)                      |
| Alt+E           | Vue 1re / 3e personne                         |
| I               | Inventaire                                    |
| F1              | Panneau de connexion au serveur               |
| Échap           | Libérer / recapturer la souris                |

## Le monde

Généré procéduralement au chargement (`world_gen.gd`, seed fixe — même
seed côté serveur = même monde pour tous). Terrain accidenté ceint de
dunes-montagnes, rivière toxique (6 PV/s dedans !), bâtisses en pierre
et cabanes abandonnées, arbres morts, rochers, débris.

## Gameplay actuel

- Vie + endurance (le sprint draine, marcher régénère)
- Système de matériaux : impacts visuels par surface (terre, pierre,
  bois, métal, chair, acide), objets poussables selon leur masse,
  destruction à trois vitesses (indestructible / lente / rapide)
- Chauves-souris vampires en meutes de deux : passives en patrouille,
  toute la meute attaque (crachats d'acide) si on approche ou tire ;
  désengagement à distance ; loot de trousses de soin ; respawn 10 s
- Inventaire en grille, perdu intégralement à la mort
- Sons synthétisés en code (aucun asset audio)

## Multijoueur

Client réseau UDP complet (`network_client.gd`, autoload `Net`) :
join/welcome, positions à 20 Hz avec numéros de séquence, relai des
tirs, ping, timeout. Les joueurs distants sont interpolés. Le serveur
Akka/Pekko est à implémenter en miroir de **PROTOCOL.md**.

## Structure

```
project.godot
scenes/    main, player, remote_player, ak47, private_eye, psi_monk,
           connect_ui, inventory_ui
scripts/   world_gen (terrain + props), player, bullet, impact, debris,
           bat + bat_spawner + acid_glob + pickup, inventory (+ ui),
           network_client, sfx, main, modèles (ak47, private_eye...)
```

Tous les assets (3D et audio) sont générés en code — à remplacer
progressivement par de vrais assets (glTF depuis Blender, samples .ogg)
sans toucher à la logique.
