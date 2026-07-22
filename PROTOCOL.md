# PROTOCOL.md — Terminal_City network protocol v1

Spec of the Godot client <-> server protocol (to be implemented on the
Akka/Pekko IO UDP side). Transport: **UDP**, one JSON message per
datagram, UTF-8 encoded, no delimiter (1 datagram = 1 message).

The client side is already implemented in `scripts/network_client.gd` —
this document describes the server behavior expected to answer it.

## Overview

```
Client                                Server
  |--- join (retry 1s) --------------->|  creates the session (key = source address:port)
  |<-- welcome (id, seed) -------------|  broadcasts "joined" to the others
  |--- pos (20 Hz, seq++) ------------>|  keeps the latest state if seq > last known
  |<-- state (20 Hz, all players) -----|  server tick
  |--- shoot (event) ----------------->|  broadcasts "shot" to the others
  |--- ping (2 s) -------------------->|
  |<-- pong ---------------------------|  also serves as keepalive
  |--- leave ------------------------->|  broadcasts "left"
```

- **A client's identity = its UDP (IP address, source port) pair.**
  There is no connection: the server maintains an address -> session map.
- The client resends `join` every second until it receives `welcome`
  (UDP may drop the first one). The server must therefore answer
  `welcome` **idempotently**: a `join` from a known address returns the
  same id, without creating a duplicate.
- Timeouts: the client disconnects after 6 s of server silence. On the
  server side, expire a session after ~10 s without any packet from the
  client (the 20 Hz `pos` and the 2 s `ping` act as keepalive).

## Client -> server messages

| t       | Fields                                    | Rate      |
|---------|-------------------------------------------|-----------|
| `join`  | `name` (string), `v` (int, version = 1)   | retry 1 s |
| `pos`   | `id`, `seq` (increasing int), `x` `y` `z` (float), `ry` (yaw rad), `rx` (pitch rad) | 20 Hz |
| `shoot` | `id`, `o` [x,y,z] origin, `d` [x,y,z] direction | event |
| `ping`  | `id`, `ts` (int, ms, client clock)        | 2 s       |
| `leave` | `id`                                      | event     |

`seq` rule: UDP does not guarantee ordering. The server only keeps a
`pos` if `seq` > the last known `seq` for that player, otherwise it
ignores it (late packet).

## Server -> client messages

| t         | Fields                                          | When |
|-----------|-------------------------------------------------|------|
| `welcome` | `id` (assigned int), `seed` (int, world seed; 0 = keep the local world), `tick` (int, Hz, informative) | reply to `join` |
| `state`   | `players`: [{`id`,`x`,`y`,`z`,`ry`,`rx`}, ...]  | 20 Hz tick, to everyone |
| `joined`  | `id`, `name`                                    | broadcast on arrival |
| `left`    | `id`                                            | broadcast on leave/timeout |
| `shot`    | `id`, `o` [x,y,z], `d` [x,y,z]                  | broadcast (relay of `shoot`) |
| `pong`    | `ts` (echoed back as-is)                        | reply to `ping` |

Notes:
- `state` may include the sender itself; the client filters its own id.
- `shot` may be sent back to everyone; the client filters its own id too.
- The client accepts extra fields (and ignores them): you can enrich
  messages without breaking it.

## Examples

```json
{"t":"join","name":"Loic","v":1}
{"t":"welcome","id":3,"seed":1337,"tick":20}
{"t":"pos","id":3,"seq":412,"x":1.25,"y":4.8,"z":57.3,"ry":0.61,"rx":-0.12}
{"t":"state","players":[{"id":3,"x":1.25,"y":4.8,"z":57.3,"ry":0.61,"rx":-0.12},
                         {"id":5,"x":-10.2,"y":3.1,"z":40.0,"ry":2.1,"rx":0.05}]}
{"t":"shoot","id":3,"o":[1.4,6.2,57.0],"d":[0.1,-0.05,-0.99]}
{"t":"shot","id":3,"o":[1.4,6.2,57.0],"d":[0.1,-0.05,-0.99]}
{"t":"pong","ts":174951}
```

## Pekko-side hints

- `IO(Udp)` + `Udp.Bind` on port 4242; the bound actor receives
  `Udp.Received(data, senderAddress)` — `senderAddress` is the session
  key, and the return address for `Udp.Send`.
- A supervisor actor holding `Map[InetSocketAddress, SessionRef]`
  + one actor (or one state entry) per player.
- `Timers` for the 20 Hz tick (`state` broadcast) and for sweeping
  expired sessions.
- JSON: circe or play-json; a `sealed trait Msg` ADT with a codec
  discriminated on the `t` field maps this spec cleanly.

## Planned evolutions (v2+)

- Switch to binary (`StreamPeerBuffer` on the Godot side) once v1 is
  stable.
- Server-side shot validation (authoritative hit registration) and
  movement validation (anti-cheat: max speed, collisions).
- Timestamped snapshot interpolation on the client (currently: simple
  lerp toward the latest state).
- Replication of mobs, destruction and loot (currently client-local).
```
