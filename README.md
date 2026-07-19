# Terminal_City — wasteland post-nucléaire (client Godot 4)

Prototype d'environnement extérieur inspiré des wastelands de Neocron :
terrain accidenté irradié, rivière contaminée, ciel rougeâtre, végétation
morte. Base client pour le futur serveur Akka/Pekko UDP.

## Ouvrir et jouer

1. Godot 4.7 → **Importer** → sélectionner `project.godot`.
2. F5. Le joueur apparaît sur la rive sud de la rivière.

## Contrôles

Identiques au MiniFPS : ZQSD (keycodes physiques), souris, Espace (saut),
Shift (sprint), clic gauche (tir traçant + impacts), Échap (souris).

## Le monde

Tout est **généré procéduralement au chargement** dans `world_gen.gd`,
avec une seed fixe (1337) — le monde est donc identique à chaque
lancement (important pour le futur multijoueur : même seed côté serveur
= même terrain pour tous).

- **Terrain** 240×240 m : deux couches de bruit fractal (FastNoiseLite),
  mesh construit avec SurfaceTool + collision HeightMapShape3D alignée
  sur la même grille de hauteurs.
- **Rivière** : un lit sinusoïdal est creusé dans la fonction de hauteur
  (smoothstep pour des berges douces), l'eau est un plan vert toxique
  semi-transparent légèrement émissif à y = -1,1. Les creux du terrain
  sous ce niveau forment aussi des mares contaminées.
- **Couleurs du sol** : par vertex selon l'altitude — boue sombre près de
  l'eau, terre brun-rouge, sable rougeâtre sur les hauteurs.
- **Ambiance** : ciel procédural rouge sombre, soleil bas orangé, brume
  de distance rougeâtre (fog exponentiel).
- **Props** : ~35 arbres morts (troncs coniques + branches nues), ~90
  buissons secs, ~45 rochers, posés au sol via `get_height()` et jamais
  dans la rivière.

## Structure

```
project.godot
scenes/main.tscn      environnement (ciel, brume), soleil, monde, joueur
scenes/player.tscn    contrôleur FPS (repris du MiniFPS)
scripts/world_gen.gd  génération du terrain, rivière, eau, props
scripts/main.gd       soleil + spawn du joueur au sol
scripts/player.gd     mouvement, vue souris, tir
scripts/bullet.gd     balle traçante
scripts/impact.gd     étincelles + marque d'impact
```

## Pistes suivantes

- Zone `Area3D` sur l'eau → dégâts de poison au contact (comme les
  zones irradiées de Neocron).
- Compteur Geiger sonore près de zones chaudes.
- Ruines industrielles / carcasses en primitives.
- Réseau : `NetworkClient` autoload en PacketPeerUDP, la seed du monde
  envoyée par le serveur à la connexion.
