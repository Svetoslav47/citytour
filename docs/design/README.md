# Design mockups

High-fidelity mockups of every screen. They're published in a Claude Design canvas: https://claude.ai/artifact/9L9XYcGJdgWkhohuiXiaeG (private; ask the repo owner for access).

- `mockups/*.dc.html`: the artboard sources, one per screen and state. They implement [`../DESIGN.md`](../DESIGN.md), which is the single source of truth for the UI.
- `generators/`: the Python scripts that produced the artboards.
- `map/`: real Old Town base maps (light and dark), rendered from OpenStreetMap data (© OpenStreetMap contributors, ODbL) fetched through the OSM API in 9 bbox tiles, because Overpass was down. `map-meta.json` holds the 11 Royal Route stops and the OSRM foot route in image pixels: 2,497 m, 33 min (routing.openstreetmap.de). The bbox and projection are in its `image` key.

**Stop numbering:** the real route order is 1 Barbican, 2 St Florian's Gate, 3 St Mary's Basilica, 4 Cloth Hall, 5 Adam Mickiewicz Monument, 6 Town Hall Tower, 7 St Adalbert's Church, 8 Sts Peter and Paul, 9 St Andrew's Church, 10 Kanonicza Street, 11 Wawel Hill.
