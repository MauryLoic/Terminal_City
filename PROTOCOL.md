# PROTOCOL.md — Protocole réseau Terminal_City v1

Spec du protocole client Godot <-> serveur (à implémenter côté
Akka/Pekko IO UDP). Transport : **UDP**, un message JSON par datagramme,
encodé UTF-8, sans délimiteur (1 datagramme = 1 message).

Le client est déjà implémenté dans `scripts/network_client.gd` — ce
document décrit le comportement attendu du serveur pour lui répondre.

## Vue d'ensemble

```
Client                                Serveur
  |--- join (retry 1s) --------------->|  crée la session (clé = adresse:port source)
  |<-- welcome (id, seed) -------------|  broadcast "joined" aux autres
  |--- pos (20 Hz, seq++) ------------>|  garde le dernier état si seq > dernier connu
  |<-- state (20 Hz, tous les joueurs)-|  tick serveur
  |--- shoot (événement) ------------->|  broadcast "shot" aux autres
  |--- ping (2 s) -------------------->|
  |<-- pong ---------------------------|  sert aussi de keepalive
  |--- leave ------------------------->|  broadcast "left"
```

- **Identité d'un client = son couple (adresse IP, port source) UDP.**
  Pas de connexion : le serveur maintient une table adresse -> session.
- Le client renvoie `join` toutes les 1 s tant qu'il n'a pas reçu
  `welcome` (UDP peut perdre le premier). Le serveur doit donc répondre
  `welcome` de façon **idempotente** : un `join` d'une adresse déjà
  connue renvoie le même id, sans créer de doublon.
- Timeout : le client se déconnecte après 6 s de silence serveur. Côté
  serveur, expirer une session après ~10 s sans aucun paquet du client
  (le `pos` à 20 Hz et le `ping` à 2 s servent de keepalive).

## Messages client -> serveur

| t       | Champs                                   | Fréquence   |
|---------|------------------------------------------|-------------|
| `join`  | `name` (string), `v` (int, version = 1)  | retry 1 s   |
| `pos`   | `id`, `seq` (int croissant), `x` `y` `z` (float), `ry` (yaw rad), `rx` (pitch rad) | 20 Hz |
| `shoot` | `id`, `o` [x,y,z] origine, `d` [x,y,z] direction | événement |
| `ping`  | `id`, `ts` (int, ms, horloge client)     | 2 s         |
| `leave` | `id`                                     | événement   |

Règle `seq` : UDP ne garantit pas l'ordre. Le serveur ne garde un `pos`
que si `seq` > dernier `seq` connu pour ce joueur, sinon il l'ignore
(paquet arrivé en retard).

## Messages serveur -> client

| t         | Champs                                          | Quand |
|-----------|-------------------------------------------------|-------|
| `welcome` | `id` (int attribué), `seed` (int, seed du monde ; 0 = garder le monde local), `tick` (int, Hz, informatif) | réponse à `join` |
| `state`   | `players`: [{`id`,`x`,`y`,`z`,`ry`,`rx`}, ...]  | tick 20 Hz, à tous |
| `joined`  | `id`, `name`                                    | broadcast à l'arrivée |
| `left`    | `id`                                            | broadcast au départ/timeout |
| `shot`    | `id`, `o` [x,y,z], `d` [x,y,z]                  | broadcast (relai du `shoot`) |
| `pong`    | `ts` (renvoyer tel quel)                        | réponse à `ping` |

Notes :
- `state` peut inclure l'émetteur lui-même, le client filtre son propre id.
- `shot` peut être renvoyé à tous, le client filtre aussi son propre id.
- Le client accepte des champs supplémentaires (il les ignore) : tu peux
  enrichir les messages sans le casser.

## Exemples

```json
{"t":"join","name":"Loic","v":1}
{"t":"welcome","id":3,"seed":1337,"tick":20}
{"t":"pos","id":3,"seq":412,"x":1.25,"y":4.8,"z":57.3,"ry":0.61,"rx":-0.12}
{"t":"state","players":[{"id":3,"x":1.25,"y":4.8,"z":57.3,"ry":0.61,"rx":-0.12},
                         {"id":5,"x":-10.2,"y":3.1,"z":40.0,"ry":2.1,"rx":0.05}]}
{"t":"shoot","id":3,"o":[1.4,6.2,57.0],"d":[0.1,-0.05,-0.99]}
{"t":"shot","id":3,"o":[1.4,6.2,57.0],"d":[0.1,-0.05,-0.99]}
```

## Pistes côté Pekko

- `IO(Udp)` + `Udp.Bind` sur le port 4242 ; l'acteur bound reçoit des
  `Udp.Received(data, senderAddress)` — `senderAddress` est la clé de
  session, et sert d'adresse de retour pour `Udp.Send`.
- Un acteur superviseur qui tient `Map[InetSocketAddress, SessionRef]`
  + un acteur (ou une entrée d'état) par joueur.
- `Timers` pour le tick 20 Hz (`state` broadcast) et le balayage des
  sessions expirées.
- JSON : circe ou play-json ; un ADT scellé `sealed trait Msg` avec un
  codec discriminé sur le champ `t` mappera proprement cette spec.

## Évolutions prévues (v2+)

- Passage au binaire (`StreamPeerBuffer` côté Godot) une fois la v1 stable.
- Validation serveur des tirs (hit registration autoritaire) et des
  déplacements (anti-cheat : vitesse max, collisions).
- Interpolation par snapshots horodatés côté client (actuellement :
  lerp simple vers le dernier état).
