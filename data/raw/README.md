# Raw data snapshots

Fetched once and committed, so the app's build never needs the network.

| File | Source | Fetched | Licence |
| --- | --- | --- | --- |
| `osm/oldtown-tile{1..9}.osm.gz` | OSM API `api/0.6/map`, 3×3 bbox tiles covering lon 19.9290–19.9470, lat 50.0525–50.0675 (Kraków Old Town). Overpass was down on 2026-10-03, so we used the OSM API. | 2026-10-03 | © OpenStreetMap contributors, ODbL 1.0 |
| `osrm/royal-route-foot.json` | `routing.openstreetmap.de/routed-foot` through the 11 Royal Route stops in listed order: 2,497 m, 33 min | 2026-10-03 | Route computed from OSM data (ODbL) |

Tile bboxes, as `lon,lat` of the south-west corner, each 0.006° lon × 0.005° lat: rows at lat 50.0525 / 50.0575 / 50.0625, columns at lon 19.9290 / 19.9350 / 19.9410. Tile numbers run row-major from the south-west.
