# Shared Map (Project Zomboid, Build 42)

Map areas walked by one player are revealed on every player's world map on the server.

- Clients report newly walked map units (32x32 squares) near the player; the server merges them
  into global ModData and broadcasts them. New joiners request the full set on game start.
- Sandbox option (page "Shared Map"): turn sharing on or off.

## Status
Loads cleanly on a dedicated server; multi-client behaviour is **untested**. Things to verify:
- `WorldMapVisited:isVisited(x, y)` takes squares (assumed), not units.
- The shared set is revealed after joining (request at `OnGameStart` may arrive too early).
- Set `DEBUG = true` in `Fac51SharedMapClient.lua` to log what is sent and received.

## Install for development
Copy `Contents/mods/SharedMap` into `~/Zomboid/mods/` and enable "Shared Map".
