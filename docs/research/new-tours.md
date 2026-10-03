# Two more Kraków tours: research and proposal

Status: research only, 2026-10-03. Nothing in the app, server or pack was changed. Drafted by a Claude Code subagent for the lead to review.

**Recommendation:**
1. **`kazimierz`: "Kazimierz: Two Faiths, One Town"**. 11 stops, 2.15 km, about 60 min.
2. **`scholars-saints`: "Scholars and Saints"**. 10 stops, 2.25 km, about 55 min.

Ship each one as **its own course** (`krakow-kazimierz`, `krakow-scholars`), next to the bundled `krakow` Royal Route.

Scholars and Saints needs **no map work**: all 10 stops are inside the current offline map. Kazimierz needs the map **extended by 5 OSM tiles** to the south and east.

## 0. What was checked

| Item | Finding | Source |
|---|---|---|
| Pack read | `entry/src/main/resources/rawfile/packs/krakow/` (`data/course/krakow/pack` does not exist yet in the main checkout) | manifest `2026.10.03-41e1482c` |
| Pack bbox (POIs) | `[49.9786, 19.7969, 50.1278, 20.2023]`, the whole city. Every candidate stop below is already in `pois.json` (4,290 POIs). | `manifest.json` |
| **Offline base map** (`map-detail.json`) | bounds `[-541.7, -987.4, 744.7, 671.2]` m from origin 50.06143, 19.93658, which is **lat 50.0525–50.0675, lng 19.929–19.947**. That is the 3×3 OSM tile grid of `scripts/pack/20-fetch-osm-tiles.mjs` (0.006° lng × 0.005° lat tiles). It covers the Old Town and Wawel. It does **not** cover Kazimierz south of Miodowa/Józefa, Skałka, the Vistula or Podgórze. | `data/raw/osm/oldtown-tile{1..9}.osm.gz`, `scripts/pack/60-mapdata.mjs` |
| Royal Route | 11 stops; Barbican → … → Kanonicza → Wawel (`data/tours/royal-route.json`) | |
| Wikidata / Wikipedia | Every QID, coordinate (P625), label and en/pl/zh sitelink below was fetched live from `wbgetentities`. Article length and revision come from `action=query&prop=info`. Story hooks come from `prop=extracts`. | www.wikidata.org/w/api.php, {en,pl,zh}.wikipedia.org/w/api.php |
| Routing | **The public OSRM foot server responded** (`routing.openstreetmap.de/routed-foot`). For each tour: one `table` call, the optimal order with a fixed start and end (exact DP, as the app does), then one `route` call in that order. Distances and times below are OSRM foot. | |

## 1. Candidates and scores

Scores run from 1 to 5, and higher is better. "Wiki" counts the stops with an **EN and a PL** article.

| # | Candidate | Stops / OSRM length | (a) Stories & sources | (b) Walkability | (c) Distinct vs Royal Route | (d) Data we have | (e) Demo & EN/PL/ZH appeal | Total |
|---|---|---|---|---|---|---|---|---|
| **A** | **Kazimierz: Two Faiths, One Town** (Skałka → Augustinian church → Kazimierz Town Hall → Corpus Christi → Plac Nowy → 6 synagogues on Szeroka) | 11 / 2.15 km, 29 min walking | **5**. Wiki 9/11 EN+PL (the other 2 are PL only). 7 stops also have a zh article. Long PL articles (Remuh 32 k, Old Synagogue 40 k chars). | **5**. Linear, flat, mostly quiet streets, 137–302 m legs | **5**. New district, new themes (Jewish heritage, the royal town of Casimir the Great). 0 stops shared. | **3**. All 11 POIs are in pois.json. Only 2/11 are inside the map, so 5 more OSM tiles are needed. | **5**. Kazimierz is the second most visited area; Schindler's List filmed nearby (do not lean on it). Chinese zh articles exist for 6 synagogues and churches. | **23** |
| **B** | **Scholars and Saints** (Jagiellonian University colleges, Copernicus, St Anne's, Pope's Window, Franciscans with Wyspiański glass, Dominicans) | 10 / 2.25 km, 30 min walking | **4**. Wiki 8/10 EN+PL (Collegium Iuridicum is PL only). The EN stubs of St Joseph (Poselska) and the Dominicans need the PL article. | **5**. A compact Old Town loop to the south; ends 400 m from Wawel | **3**. Same Old Town, but a different theme (learning, faith, John Paul II) and 0 stops shared | **5**. 10/10 in the map, all in pois.json, routes inside the current tiles | **4**. Copernicus (哥白尼) is a strong hook for Chinese visitors. The Pope's Window and Wojtyła are strong for Polish visitors. | **21** |
| C | **Podgórze: the Ghetto and Schindler** (Bernatek footbridge → Podgórze Market Sq / St Joseph's → Ghetto Heroes Sq → Eagle Pharmacy → ghetto wall on Lwowska → Schindler's Factory) | 7 / 2.26 km, 30 min walking | 3. Wiki 4/7 EN+PL (the bridge, the market square and the wall are PL only); very strong EN "Kraków Ghetto" article (52 k) | 4. Linear, but a long 635 m leg and busy Limanowskiego/Lwowska streets | 5 | 2. 0/7 in the map; needs a new map area across the river | 4. International recognition is high, but it is a hard topic for a cheerful AI demo | 18 |
| D | **Planty ring** (park on the old walls) | ~4 km ring (en.wikipedia "Planty Park": "length of 4 km") | 3. Many monuments, but the statues have thin articles | 3. Too long as a full loop; a half loop overlaps the Royal Route | 2. Barbican, Florian's Gate and Wawel would repeat | 5 | 3 | 16 |
| E | **Vistula, Dragon & bridges** (Skałka → Manggha → Grunwald Bridge → boulevards → Dragon's Den → Dragon statue) | 6 / 1.69 km, 21 min walking | 2. Grunwald Bridge is PL only; Wawel Dragon statue has no zh article | 4. Riverside, but crosses a road bridge | 3. Wawel area overlap | 3. 3/6 in the map | 4. The dragon is fun for families | 16 |
| F | **Nowa Huta** (socialist realist new town) | ~7 km east of Rynek, needs a tram | 4 | 1. Not walkable from the centre | 5 | 1. Outside the map and the OSRM snapshot | 3 | 14 |

Alternative: a **Kazimierz + Podgórze** combination could replace B later, because both need the same southward map extension (Bernatek footbridge is 0.6 km from Corpus Christi).

## 2. Recommended tour 1: Kazimierz

| Field | Value |
|---|---|
| id | `kazimierz` (course `krakow-kazimierz`) |
| Title | en **Kazimierz: Two Faiths, One Town** · pl **Kazimierz: dwie wiary, jedno miasto** · zh **卡齐米日：一城两信** (zh is a draft; needs a native check) |
| Pitch | King Casimir's separate royal town, where Catholic Kraków and the oldest Jewish quarter in Poland lived side by side for five centuries. |
| Persona | **Historian** fits well. The tone must be measured; see §2.2. |
| Route | Fixed start **Skałka** (about 0.7 km south of Wawel, so it can follow the Royal Route) and fixed end **Old Synagogue**. OSRM foot in this order: **2,151 m, 28.8 min walking**. With about 2.5 min dwell × 11, the total is **about 60 min**. Order = exact optimum for the fixed start and end. |
| Map | **Not covered**: only stops 6 and 7 are inside the current map. Tour bbox: lat 50.0483–50.0529, lng 19.9378–19.9488. |

| # | Stop (en / pl) | QID | pois.json id (tier) | lat, lng (Wikidata P625) | EN article | PL article | Leg from previous (OSRM) | Story hooks (source) |
|---|---|---|---|---|---|---|---|---|
| 1 | Skałka (Pauline Church on the Rock) / Skałka, Bazylika św. Michała Archanioła i św. Stanisława | Q1420580 | `poi_wd_Q1420580` (source-extract) | 50.048333, 19.937778 | [Church of St. Michael the Archangel and St. Stanislaus Bishop and Martyr, Kraków](https://en.wikipedia.org/wiki/Church_of_St._Michael_the_Archangel_and_St._Stanislaus_Bishop_and_Martyr,_Krak%C3%B3w) | [Bazylika św. Michała Archanioła i św. Stanisława Biskupa w Krakowie](https://pl.wikipedia.org/wiki/Bazylika_%C5%9Bw._Micha%C5%82a_Archanio%C5%82a_i_%C5%9Bw._Stanis%C5%82awa_Biskupa_w_Krakowie) | start | Bishop Stanisław slain here on the order of King Bolesław II (1079), which led to the king's exile and the bishop's canonisation. The well of St Stanislaus is outside. The crypt of honour holds Długosz, Wyspiański, Szymanowski and Miłosz (EN article). |
| 2 | Augustinian Church of St Catherine / Kościół św. Katarzyny Aleksandryjskiej i św. Małgorzaty | Q11746976 | `poi_wd_Q11746976` (source-extract) | 50.0494, 19.9411 | [Church of St. Catherine of Alexandria and St. Margaret, Kraków](https://en.wikipedia.org/wiki/Church_of_St._Catherine_of_Alexandria_and_St._Margaret,_Krak%C3%B3w) (stub, ground on PL) | [Kościół św. Katarzyny Aleksandryjskiej i św. Małgorzaty w Krakowie](https://pl.wikipedia.org/wiki/Ko%C5%9Bci%C3%B3%C5%82_%C5%9Bw._Katarzyny_Aleksandryjskiej_i_%C5%9Bw._Ma%C5%82gorzaty_w_Krakowie) | 268 m | The nave vault collapsed in the **1443 earthquake** and was rebuilt until 1505; another quake cracked the vault in 1786. The Austrians later turned the church into an arms store (PL article). |
| 3 | Kazimierz Town Hall (Ethnographic Museum) / Ratusz kazimierski | Q15880176 (museum: Q194616) | `poi_wd_Q15880176` (source-extract) | 50.048694, 19.943472 | none for the building; use [Ethnographic Museum of Kraków](https://en.wikipedia.org/wiki/Ethnographic_Museum_of_Krak%C3%B3w) (Q194616, also zh) | [Ratusz kazimierski w Krakowie](https://pl.wikipedia.org/wiki/Ratusz_kazimierski_w_Krakowie) | 261 m | Casimir the Great chartered Kazimierz in 1335; its square market place (195 m a side) was almost as large as Kraków's. The tower clock (1875) is **Kraków's oldest working tower clock** (PL article). |
| 4 | Corpus Christi Basilica / Bazylika Bożego Ciała | Q2084317 | `poi_wd_Q2084317` (source-extract) | 50.049792, 19.944936 | [Corpus Christi Church, Kraków](https://en.wikipedia.org/wiki/Corpus_Christi_Church,_Krak%C3%B3w) | [Bazylika Bożego Ciała w Krakowie](https://pl.wikipedia.org/wiki/Bazylika_Bo%C5%BCego_Cia%C5%82a_w_Krakowie) | 279 m | Founded by Casimir III in 1335. Swedish soldiers stripped it in 1655 (the Deluge), which is why the interior is Baroque, including a **boat-shaped pulpit** (1750) (EN article). |
| 5 | Plac Nowy / Plac Nowy | Q11008519 | `poi_wd_Q11008519` (**name-only**: needs a wiki fetch) | 50.0517, 19.9449 | none | [Plac Nowy w Krakowie](https://pl.wikipedia.org/wiki/Plac_Nowy_w_Krakowie) | 302 m | The round market hall "Okrąglak" (1900) was leased to the Jewish community in 1927 as a **ritual poultry slaughterhouse** (PL article). |
| 6 | Tempel Synagogue / Synagoga Tempel | Q3354482 | `poi_wd_Q3354482` (source-extract) | 50.052917, 19.944444 | [Tempel Synagogue (Kraków)](https://en.wikipedia.org/wiki/Tempel_Synagogue_(Krak%C3%B3w)) | [Synagoga Tempel w Krakowie](https://pl.wikipedia.org/wiki/Synagoga_Tempel_w_Krakowie) | 200 m | A Reform synagogue (1862) modelled on Vienna's Leopoldstädter Tempel. Its gold-leaf dome evokes the **Sigismund Chapel at Wawel**, a link back to the Royal Route. The Nazis used it as ammunition storage; today it hosts Jewish Culture Festival concerts (EN article). |
| 7 | Kupa Synagogue / Synagoga Kupa | Q3507991 | `poi_wd_Q3507991` (source-extract) | 50.05263, 19.94575 | [Kupa Synagogue](https://en.wikipedia.org/wiki/Kupa_Synagogue) | [Synagoga Kupa w Krakowie](https://pl.wikipedia.org/wiki/Synagoga_Kupa_w_Krakowie) | 177 m | "Synagogue of the Poor", 1643, part-funded by the **Jewish goldsmiths' guild**. Its north wall joins the remnants of Kazimierz's medieval town wall. Painted interior with Hebron, Tiberias and Jerusalem (EN article). |
| 8 | Izaak Synagogue / Synagoga Izaaka | Q3109262 | `poi_wd_Q3109262` (source-extract) | 50.051667, 19.946667 | [Izaak Synagogue](https://en.wikipedia.org/wiki/Izaak_Synagogue) | [Synagoga Izaaka Jakubowicza w Krakowie](https://pl.wikipedia.org/wiki/Synagoga_Izaaka_Jakubowicza_w_Krakowie) | 196 m | Founding legend: a poor man dreams of treasure under a bridge in Prague, and finds it in his own stove at home (told by Simcha Bunim of Peshischa). Completed in 1644; its donor was Isaac "the Rich", banker to King Władysław IV (EN article). |
| 9 | Remuh Synagogue and Old Cemetery / Synagoga Remu | Q3618 (cemetery Q115001) | `poi_wd_Q3618` (source-extract) | 50.052672, 19.947258 | [Remah Synagogue](https://en.wikipedia.org/wiki/Remah_Synagogue) (+ [Remah Cemetery](https://en.wikipedia.org/wiki/Remah_Cemetery)) | [Synagoga Remu](https://pl.wikipedia.org/wiki/Synagoga_Remu) | 152 m | Named after **Rabbi Moses Isserles (the ReMA)**, whose commentaries complement the Shulchan Aruch. It was built at the edge of the new Jewish cemetery (1553/1557). The courtyard walls carry memorial inscriptions to Kraków's Jews murdered in the Holocaust (EN article). |
| 10 | Popper ("Stork") Synagogue / Synagoga Poppera | Q3511288 | `poi_wd_Q3511288` (source-extract) | 50.052417, 19.948806 | [Wolf Popper Synagogue](https://en.wikipedia.org/wiki/Wolf_Popper_Synagogue) | [Synagoga Poppera w Krakowie](https://pl.wikipedia.org/wiki/Synagoga_Poppera_w_Krakowie) | 178 m | Founder Wolf Popper was nicknamed **"The Stork"** because he could stand on one leg when lost in thought. The doors depicted an eagle, a leopard, a lion and a deer (EN article). |
| 11 | Old Synagogue (on Szeroka Street) / Synagoga Stara | Q3502453 (street Q9366047) | `poi_wd_Q3502453` (source-extract) | 50.051392, 19.948572 | [Old Synagogue (Kraków)](https://en.wikipedia.org/wiki/Old_Synagogue_(Krak%C3%B3w)) (+ [Szeroka Street, Kraków](https://en.wikipedia.org/wiki/Szeroka_Street,_Krak%C3%B3w)) | [Synagoga Stara w Krakowie](https://pl.wikipedia.org/wiki/Synagoga_Stara_w_Krakowie) | 137 m | The **oldest standing synagogue building in Poland**, a "fortress synagogue". In **1794 Tadeusz Kościuszko spoke here** to win Jewish support for his uprising. Since 1958 it has been a branch of the Historical Museum of Kraków (EN article). |

Alternates: High Synagogue (Q598951, EN/PL/zh) instead of Popper; Szeroka Street (Q9366047, EN/PL) as a separate stop, which is too close to Remuh (70 m, so the trigger circles would overlap).

zh labels: Wikidata has zh for 1, 4, 6–11. For 2, 3 and 5, draft 圣加大利纳教堂 / 卡齐米日市政厅 / 新广场 (to be checked). Note that several zh labels are in traditional script (庫帕猶太會堂, 萊姆猶太會堂, 舊猶太會堂); the app shows zh-hans, so convert them as the Royal Route did.

### 2.2 Tone requirements (sensitive content)
- Stops 6–11 cover the Holocaust (destruction of interiors, executions at the Old Synagogue wall in 1943, the Izaak Torah scrolls of 5 Dec 1939) and the **post-war Kraków pogrom** (Kupa, per the EN article). The Historian should be **factual and respectful**: no "fun facts", no jokes, no exclamation marks, no gamified "prize" language on these stops. Keep `prize` for planning, but do not mention it in narration.
- Present Kazimierz as a living Jewish heritage (Tempel and Remuh are active congregations; the Festival takes place here), not only as a place of loss.
- Etiquette lines: synagogues and the Remuh cemetery are places of worship (head covering, closed on Shabbat). Add one system line per stop where needed; do not claim opening hours.
- Add a **validator rule** for this tour that rejects humorous or trivia framing on stops 6–11, and have a person (ideally a PL native) review the PL and ZH texts of these stops before publishing.

## 3. Recommended tour 2: Scholars and Saints

| Field | Value |
|---|---|
| id | `scholars-saints` (course `krakow-scholars`) |
| Title | en **Scholars and Saints** · pl **Uczeni i święci** · zh **学者与圣徒** (zh is a draft) |
| Pitch | From the college where Copernicus studied to the window where John Paul II talked to the crowds: six centuries of learning and faith in one Old Town walk. |
| Persona | **Historian** works. This is also the natural place to test the planned second persona, for example a "Professor" (dry, curious, academic voice). |
| Route | Fixed start **Collegium Novum** and fixed end **Nowodworski School** (Plac na Groblach, 0.4 km from the Wawel gate). OSRM foot in this order: **2,251 m, 30.0 min walking**. With about 2.3 min dwell × 10, the total is **about 55 min**. |
| Map | **Covered**: 10/10 stops are inside the current map (tour bbox lat 50.0571–50.0621, lng 19.9328–19.9398). |

| # | Stop (en / pl) | QID | pois.json id (tier) | lat, lng | EN article | PL article | Leg (OSRM) | Story hooks (source) |
|---|---|---|---|---|---|---|---|---|
| 1 | Collegium Novum / Collegium Novum UJ | Q2983000 | `poi_wd_Q2983000` (source-extract) | 50.060833, 19.933056 | [Collegium Novum](https://en.wikipedia.org/wiki/Collegium_Novum) | [Collegium Novum Uniwersytetu Jagiellońskiego](https://pl.wikipedia.org/wiki/Collegium_Novum_Uniwersytetu_Jagiello%C5%84skiego) | start | Opened in 1887 for the university's 500th anniversary. **Sonderaktion Krakau**: on 6 Nov 1939 the Nazis arrested 183 professors here (plaque in the Szujski hall). This needs a sober tone (EN article). |
| 2 | Copernicus Monument / Pomnik Mikołaja Kopernika | Q7029919 | `poi_wd_Q7029919` (source-extract) | 50.061111, 19.932778 | [Nicolaus Copernicus Monument, Kraków](https://en.wikipedia.org/wiki/Nicolaus_Copernicus_Monument,_Krak%C3%B3w) (short) | [Pomnik Mikołaja Kopernika w Krakowie](https://pl.wikipedia.org/wiki/Pomnik_Miko%C5%82aja_Kopernika_w_Krakowie) (33 k) | 71 m | Godebski's statue (1900) first stood in the Collegium Maius courtyard and was moved to the Planty in 1953. Copernicus studied at the Kraków Academy, and his father came from Kraków (EN article). |
| 3 | St Anne's Church / Kościół św. Anny | Q1126134 | `poi_wd_Q1126134` (source-extract) | 50.062089, 19.933765 | [Church of St. Anne, Kraków](https://en.wikipedia.org/wiki/Church_of_St._Anne,_Krak%C3%B3w) | [Kościół św. Anny w Krakowie](https://pl.wikipedia.org/wiki/Ko%C5%9Bci%C3%B3%C5%82_%C5%9Bw._Anny_w_Krakowie) | 230 m | The university church. The Gothic church was **demolished in 1689 because it was too small** for the cult of St John Cantius, the university's patron. It was rebuilt by Tylman van Gameren on the model of Sant'Andrea della Valle (EN article). |
| 4 | Collegium Maius / Collegium Maius UJ | Q919596 | `poi_wd_Q919596` (source-extract) | 50.061739, 19.933756 | [Collegium Maius, Kraków](https://en.wikipedia.org/wiki/Collegium_Maius,_Krak%C3%B3w) | [Collegium Maius Uniwersytetu Jagiellońskiego](https://pl.wikipedia.org/wiki/Collegium_Maius_Uniwersytetu_Jagiello%C5%84skiego) | 139 m | The university's oldest building, bought with **Queen Jadwiga's bequest**. **Copernicus studied here in the 1490s**. Professors lived upstairs and taught downstairs. The museum holds the Jagiellonian globe (EN article). |
| 5 | Bishop's Palace (the Papal Window) / Pałac Biskupi | Q616675 | `poi_wd_Q616675` (source-extract) | 50.05954, 19.93513 | [Bishop's Palace, Kraków](https://en.wikipedia.org/wiki/Bishop%27s_Palace,_Krak%C3%B3w) | [Pałac Biskupi w Krakowie](https://pl.wikipedia.org/wiki/Pa%C5%82ac_Biskupi_w_Krakowie) | 404 m | Karol Wojtyła's residence 1958–1978. As John Paul II he **talked to the crowds at night from the window above the entrance**. After his death (2 Apr 2005), about 40,000 people held a vigil here (EN article). |
| 6 | Franciscan Basilica / Bazylika św. Franciszka z Asyżu | Q1328725 | `poi_wd_Q1328725` (source-extract) | 50.059128, 19.935725 | [Basilica of St. Francis of Assisi, Kraków](https://en.wikipedia.org/wiki/Basilica_of_St._Francis_of_Assisi,_Krak%C3%B3w) | [Bazylika św. Franciszka z Asyżu w Krakowie](https://pl.wikipedia.org/wiki/Bazylika_%C5%9Bw._Franciszka_z_Asy%C5%BCu_w_Krakowie) | 71 m | **Wyspiański's** floral murals (1895) and his stained glass, including "God the Father" (made in Innsbruck 1899–1904). St Maximilian Kolbe was a friar here in 1919 (EN article). |
| 7 | Dominican Basilica of the Holy Trinity / Bazylika Świętej Trójcy (Dominikanie) | Q1237964 | `poi_wd_Q1237964` (source-extract) | 50.0593, 19.93955 | [Church of the Holy Trinity, Kraków (Old Town)](https://en.wikipedia.org/wiki/Church_of_the_Holy_Trinity,_Krak%C3%B3w_(Old_Town)) (short) | [Kościół Świętej Trójcy w Krakowie (ul. Stolarska)](https://pl.wikipedia.org/wiki/Ko%C5%9Bci%C3%B3%C5%82_%C5%9Awi%C4%99tej_Tr%C3%B3jcy_w_Krakowie_(ul._Stolarska)) (26 k) | 345 m | Dates from 1223; St Hyacinth and Duke Leszek the Black are buried here. The humanist Callimachus's bronze tomb plate was designed by **Veit Stoss**, a link to St Mary's. The free-standing bell tower burned in the **1850 city fire** (PL article). |
| 8 | St Joseph's (Bernardine Sisters), Poselska / Kościół św. Józefa (ul. Poselska) | Q11746949 | `poi_wd_Q11746949` (source-extract) | 50.05812, 19.93976 | [Church of St. Joseph, Kraków (Old Town)](https://en.wikipedia.org/wiki/Church_of_St._Joseph,_Krak%C3%B3w_(Old_Town)) (stub, ground on PL) | [Kościół św. Józefa w Krakowie (ul. Poselska)](https://pl.wikipedia.org/wiki/Ko%C5%9Bci%C3%B3%C5%82_%C5%9Bw._J%C3%B3zefa_w_Krakowie_(ul._Poselska)) | 206 m | Built 1694–1703 on the site of the demolished Tęczyński palace. Partly burned in the 1850 fire, but the interior survived (PL article). This is the weakest stop; swap it for Collegium Witkowski or Bishop Ciołek Palace if the review prefers. |
| 9 | Collegium Iuridicum / Collegium Iuridicum UJ | Q11691320 | `poi_wd_Q11691320` (**name-only**) | 50.05706, 19.93783 | none | [Collegium Iuridicum Uniwersytetu Jagiellońskiego](https://pl.wikipedia.org/wiki/Collegium_Iuridicum_Uniwersytetu_Jagiello%C5%84skiego) | 258 m | Two houses bought by the university in 1403 and 1406. It is one of only two surviving faculty colleges of the 16th century (with Collegium Minus), with a two-storey arcaded courtyard (PL article). |
| 10 | Nowodworski School / I LO im. Bartłomieja Nowodworskiego | Q4865820 | `poi_wd_Q4865820` (source-extract) | 50.05705, 19.93342 | [Bartłomiej Nowodoworski 1st Secondary School in Kraków](https://en.wikipedia.org/wiki/Bart%C5%82omiej_Nowodoworski_1st_Secondary_School_in_Krak%C3%B3w) | [I Liceum Ogólnokształcące im. Bartłomieja Nowodworskiego w Krakowie](https://pl.wikipedia.org/wiki/I_Liceum_Og%C3%B3lnokszta%C5%82c%C4%85ce_im._Bart%C5%82omieja_Nowodworskiego_w_Krakowie) | 525 m | One of Poland's oldest schools, founded by the university Senate in 1586–1588. **King Jan III Sobieski** is on its alumni list (PL article). |

zh labels: Wikidata has them for 1–7. For 8–10, draft 圣若瑟堂（波塞尔斯卡街） / 雅盖隆大学法学院旧楼 / 诺沃德沃尔斯基中学 (to be checked). Tone: stop 1 (Sonderaktion Krakau) and stop 5 (death of John Paul II) need the same respectful register as §2.2.

## 4. Implementation estimate

### 4.1 Pack pipeline (`scripts/pack/`)
| Step | Work | Size |
|---|---|---|
| Tour JSON | `data/tours/kazimierz.json`, `data/tours/scholars-saints.json` in the `royal-route.json` format: names en/pl/zh, kind, lat/lng with `coordinateCheck` against OSM, `dwellS`, `prize`, `triggerRadiusM` (Remuh/Popper/Old Synagogue are 110–180 m apart, so keep 35 m), `view {look, feature}` with a source quote | 2–3 h each |
| **Generalise the tour input** | `15-fetch-wikidata`, `40-merge-pois`, `50-fetch-osrm`, `90-emit`, `build-pack.sh` and `scripts/voice/*` all hard-code `data/tours/royal-route.json`. Add a `--tour <id>` flag (one pack per course, see §4.4), and give `data/raw/osrm/` and `data/raw/wiki/stops-text-*` per-tour file names. | 2–3 h |
| OSRM legs | One `table` call plus 110 (Kazimierz) / 90 (Scholars) `route` calls at 1 req/s, so about 2 min each. The server works today. `routes.json` must hold a **complete** matrix over its `nodeIds` (`PackParser` `isMatrix`), so this fits one tour per pack. | 15 min |
| **Map extension (Kazimierz only)** | Make the 3×3 grid in `20-fetch-osm-tiles.mjs` configurable. Add a southern tile row lat 50.0475–50.0525 × lng 19.929–19.953 (4 tiles) and one tile lat 50.0525–50.0575 × lng 19.947–19.953, which makes 5 OSM API calls. `60-mapdata` takes its bounds from the tiles, so it needs no logic change. `map-detail.json` grows from 713 KB to roughly 1.1 MB (estimate). Check the label density and the UNESCO layer (Kazimierz is inside the World Heritage property). | 1–2 h |
| Wiki texts | `30-fetch-wiki` stop texts for the new stops. Plac Nowy and Collegium Iuridicum are `name-only` in the pack, so fetch their PL articles. For PL-only stops, ground EN/ZH on PL quotes, as the Royal Route already does for the Cloth Hall. | 15 min |
| AI drafting + validator | `70-narrate --stops` (Historian prompt `historian-v1.md`) gives teaser and full per stop in EN, then `translate-v1` gives PL and ZH, then `review/<poiId>.<lang>.md` claim review, then `80-validate`. Add the Kazimierz tone rule (§2.2). | 21 stops × 3 langs; about half a day including human review |
| Demo walk | `scripts/demo/make-demo-walk.mjs` per tour, if the demo should show them | 30 min |

### 4.2 ElevenLabs credits (eleven_multilingual_v2, 1 character = 1 credit)
Measured from the shipped `rawfile/audio/manifest.json` (1,155 clips, 54,593 characters in total):

| Royal Route, measured | en | pl | zh | Total |
|---|---|---|---|---|
| teaser + full (11 stops) | 12,961 | 12,802 | 4,650 | **30,413** (2,765 per stop) |
| arrival + nav (per-stop and per-leg lines) | 9,052 | 9,358 | 3,151 | 21,561 (1,960 per stop) |
| system (tour-wide; the welcome line contains the tour title) | 1,117 | 1,114 | 388 | 2,619 |

| New tour, estimate | Stories | Arrival + nav | System | **Total** |
|---|---|---|---|---|
| Kazimierz (11 stops) | ~30,400 | ~21,600 | ~2,600 (mostly the same text, so the server cache dedupes it; only the title lines are new) | **~52,000** |
| Scholars and Saints (10 stops) | ~27,700 | ~19,600 | ~2,600 | **~48,000** |
| **Both** | | | | **~100,000 credits** (about 75,000 if the system lines are reused) |

Numeric lines (distance buckets) are not pre-rendered. The server renders them on demand under `TTS_DAILY_CHAR_BUDGET` (docs/SERVER.md §3.1). Run `node scripts/voice/render-elevenlabs.mjs --dry-run --tour …` first for the exact count.

### 4.3 Publishing
`npm run publish-course -- --course krakow-kazimierz --pack <pack dir> --audio <audio dir> --data <DATA_DIR> --seed server/seed --city Kraków` signs with `SIGNING_PRIVATE_KEY` (or `.keys/signing-private.pem`). **Only the lead has the private key.** `publish.ts` merges the new `CourseSummary` into `catalog.json` (it keeps the other courses and replaces any entry with the same id), so publishing the courses one after another is safe. Then redeploy the image with the updated `server/seed`.

### 4.4 One course per tour, or one Kraków course with three tours?
**Recommendation: one course per tour.** The current model is built around it:
- `publish.ts` takes the catalog summary from **`tours[0]`** ("the first tour of the pack is the course's tour"), and `CourseSummary` has one `title/stops/km/minutes`.
- The app picks a tour with `findTour(pack, '')`, which returns **`tours[0]`** of the active pack (`viewmodel/PackView.ets`). The Courses screen and the active course in `CourseRepository` are the tour switcher.
- `routes.json` has a single `nodeIds` matrix, and the allowed TTS set and `audio/manifest.json` are per course.

The cost of this choice: each course repeats `pois.json`, `narrations/*` and `sources.json` (~8.5 MB) on the device. The server stores each blob only once (content-addressed). A single course with three tours would need a tour picker on Home, per-tour catalog rows, a union routes matrix and one larger audio download, which is app work we don't need for the demo. Check whether the new packs should keep `packId: "krakow"` or get their own id: course folders are separate per course id, but the logs show `pack=` by packId.

## 5. Sources
- Wikidata entities via `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=…&props=labels|sitelinks|claims` (retrieved 2026-10-03). EN/PL revision ids are recorded in the scratch output and can be re-fetched with `prop=info`.
- Wikipedia articles linked in the tables (CC BY-SA 4.0). Story hooks are paraphrased from the article intro and history sections.
- OSRM: `https://routing.openstreetmap.de/routed-foot/table/v1/foot/…` and `/route/v1/foot/…` (OSM data, ODbL).
- Repo: `HACKATHON_BRIEF.md`, `docs/ARCHITECTURE.md` §7, `docs/SERVER.md`, `data/tours/royal-route.json`, `data/raw/SOURCES.md`, `server/src/publish.ts`, `entry/src/main/ets/viewmodel/PackView.ets`, `rawfile/audio/manifest.json`.
