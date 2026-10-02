# Tabelle di bilanciamento (generate da tools/gen_balance.py)

> NON modificare a mano: rigenerare con `python3 tools/gen_balance.py`. Le stesse tabelle in JSON sono in `data/`, in CSV in `data/csv/`.

Unita': distanze in celle, velocita' in celle/s, tempi in secondi (mostrati anche leggibili), DPS = danno al secondo.


## Edificio Centrale (Faro Madre)

| Liv | Costo (Cogs) | Tempo | HP | Deposito Cogs/Sap | XP |
|---|---|---|---|---|---|
| 1 | 0 | 0s | 900 | 500 | 0 |
| 2 | 1.000 | 5m | 1.120 | 1.000 | 17 |
| 3 | 3.000 | 1h | 1.410 | 2.000 | 60 |
| 4 | 15.000 | 4h | 1.760 | 4.000 | 120 |
| 5 | 40.000 | 12h | 2.200 | 8.000 | 207 |
| 6 | 150.000 | 1g | 2.750 | 16.000 | 293 |
| 7 | 320.000 | 1g 12h | 3.430 | 32.000 | 360 |
| 8 | 850.000 | 2g | 4.290 | 64.000 | 415 |
| 9 | 1.500.000 | 2g 12h | 5.360 | 128.000 | 464 |
| 10 | 2.600.000 | 3g | 6.710 | 256.000 | 509 |


## Sblocchi per livello di Edificio Centrale (quantita' massime)

| Hall | cog_mine | sap_well | shard_drill | cog_vault | sap_cistern | shard_crate | barracks | army_camp | laboratory | spell_forge | clan_hall | boltpost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 2 | 0 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 |
| 2 | 3 | 3 | 0 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 2 |
| 3 | 4 | 4 | 0 | 2 | 2 | 0 | 1 | 2 | 1 | 0 | 0 | 2 |
| 4 | 5 | 5 | 0 | 2 | 2 | 0 | 1 | 2 | 1 | 0 | 1 | 3 |
| 5 | 6 | 6 | 1 | 3 | 3 | 1 | 1 | 3 | 1 | 1 | 1 | 3 |
| 6 | 6 | 6 | 1 | 3 | 3 | 1 | 1 | 3 | 1 | 1 | 1 | 4 |
| 7 | 7 | 7 | 2 | 4 | 4 | 1 | 1 | 4 | 1 | 1 | 1 | 4 |
| 8 | 7 | 7 | 2 | 4 | 4 | 2 | 1 | 4 | 1 | 1 | 1 | 5 |
| 9 | 7 | 7 | 3 | 4 | 4 | 2 | 1 | 4 | 1 | 1 | 1 | 5 |
| 10 | 8 | 8 | 3 | 4 | 4 | 2 | 1 | 4 | 1 | 1 | 1 | 6 |

| Hall | lobber | skyspear | arc_coil | ballista | thumper | frost_spire | cinder_spout | storm_pylon | wall | bomb_trap | spring_pad | snare_trap | air_mine |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 25 | 0 | 0 | 0 | 0 |
| 2 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 50 | 1 | 0 | 0 | 0 |
| 3 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 75 | 1 | 2 | 0 | 0 |
| 4 | 2 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 100 | 2 | 2 | 1 | 0 |
| 5 | 2 | 2 | 1 | 1 | 0 | 0 | 0 | 0 | 125 | 2 | 3 | 1 | 1 |
| 6 | 3 | 2 | 2 | 1 | 1 | 0 | 0 | 0 | 150 | 3 | 3 | 2 | 1 |
| 7 | 3 | 3 | 2 | 2 | 1 | 1 | 0 | 0 | 175 | 3 | 4 | 2 | 2 |
| 8 | 4 | 3 | 3 | 2 | 2 | 1 | 1 | 0 | 200 | 4 | 4 | 2 | 2 |
| 9 | 4 | 4 | 3 | 3 | 2 | 2 | 1 | 1 | 225 | 4 | 5 | 3 | 3 |
| 10 | 4 | 4 | 3 | 3 | 2 | 2 | 2 | 2 | 250 | 4 | 5 | 3 | 3 |


## Livello massimo per Hall

| Hall | cog_mine | sap_well | shard_drill | cog_vault | sap_cistern | shard_crate | barracks | army_camp | laboratory | spell_forge | clan_hall | boltpost | lobber | skyspear |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 1 | 0 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 0 |
| 2 | 2 | 2 | 0 | 2 | 2 | 0 | 2 | 2 | 0 | 0 | 0 | 2 | 2 | 0 |
| 3 | 3 | 3 | 0 | 3 | 3 | 0 | 3 | 3 | 1 | 0 | 0 | 3 | 3 | 2 |
| 4 | 4 | 4 | 0 | 4 | 4 | 0 | 4 | 4 | 2 | 0 | 1 | 4 | 4 | 3 |
| 5 | 5 | 5 | 1 | 5 | 5 | 1 | 5 | 4 | 3 | 1 | 2 | 5 | 5 | 4 |
| 6 | 6 | 6 | 2 | 6 | 6 | 2 | 6 | 5 | 4 | 2 | 3 | 6 | 6 | 5 |
| 7 | 7 | 7 | 3 | 7 | 7 | 3 | 7 | 6 | 5 | 3 | 3 | 7 | 7 | 7 |
| 8 | 8 | 8 | 4 | 8 | 8 | 4 | 8 | 7 | 6 | 4 | 4 | 8 | 8 | 8 |
| 9 | 9 | 9 | 5 | 9 | 9 | 5 | 9 | 8 | 7 | 5 | 5 | 9 | 9 | 9 |
| 10 | 10 | 10 | 6 | 10 | 10 | 6 | 10 | 8 | 8 | 5 | 5 | 10 | 10 | 10 |

| Hall | arc_coil | ballista | thumper | frost_spire | cinder_spout | storm_pylon | wall | bomb_trap | spring_pad | snare_trap | air_mine |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 |
| 2 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 1 | 0 | 0 | 0 |
| 3 | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 2 | 1 | 0 | 0 |
| 4 | 2 | 0 | 0 | 0 | 0 | 0 | 4 | 2 | 2 | 1 | 0 |
| 5 | 3 | 2 | 0 | 0 | 0 | 0 | 5 | 3 | 2 | 2 | 1 |
| 6 | 5 | 4 | 2 | 0 | 0 | 0 | 6 | 3 | 3 | 3 | 2 |
| 7 | 6 | 5 | 4 | 3 | 0 | 0 | 7 | 4 | 4 | 3 | 3 |
| 8 | 8 | 7 | 6 | 5 | 4 | 0 | 8 | 4 | 4 | 4 | 4 |
| 9 | 9 | 9 | 8 | 8 | 7 | 5 | 9 | 5 | 5 | 5 | 5 |
| 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 5 | 5 | 5 | 5 |


## Economia, depositi, militari


### cog_mine (2x2, sblocco Hall 1, costo in sap)

| Liv | Hall req | Costo | Tempo | HP | XP | prod_per_hour | capacity |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 120 | 10s | 250 | 3 | 200 | 1600 |
| 2 | 2 | 282 | 21s | 295 | 4 | 276 | 2210 |
| 3 | 3 | 663 | 3m 30s | 347 | 14 | 381 | 3050 |
| 4 | 4 | 1.560 | 21m | 410 | 35 | 526 | 4210 |
| 5 | 5 | 3.660 | 1h 24m | 483 | 70 | 725 | 5800 |
| 6 | 6 | 8.600 | 4h 11m 40s | 569 | 122 | 1000 | 8000 |
| 7 | 7 | 20.200 | 8h 23m 20s | 671 | 173 | 1380 | 11000 |
| 8 | 8 | 47.500 | 12h 36m 40s | 791 | 213 | 1910 | 15300 |
| 9 | 9 | 112.000 | 16h 48m 20s | 933 | 245 | 2630 | 21000 |
| 10 | 10 | 262.000 | 1g 1h 11m | 1.100 | 301 | 3630 | 29000 |


### sap_well (2x2, sblocco Hall 1, costo in cogs)

| Liv | Hall req | Costo | Tempo | HP | XP | prod_per_hour | capacity |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 120 | 10s | 250 | 3 | 200 | 1600 |
| 2 | 2 | 282 | 21s | 295 | 4 | 276 | 2210 |
| 3 | 3 | 663 | 3m 30s | 347 | 14 | 381 | 3050 |
| 4 | 4 | 1.560 | 21m | 410 | 35 | 526 | 4210 |
| 5 | 5 | 3.660 | 1h 24m | 483 | 70 | 725 | 5800 |
| 6 | 6 | 8.600 | 4h 11m 40s | 569 | 122 | 1000 | 8000 |
| 7 | 7 | 20.200 | 8h 23m 20s | 671 | 173 | 1380 | 11000 |
| 8 | 8 | 47.500 | 12h 36m 40s | 791 | 213 | 1910 | 15300 |
| 9 | 9 | 112.000 | 16h 48m 20s | 933 | 245 | 2630 | 21000 |
| 10 | 10 | 262.000 | 1g 1h 11m | 1.100 | 301 | 3630 | 29000 |


### shard_drill (2x2, sblocco Hall 5, costo in sap)

| Liv | Hall req | Costo | Tempo | HP | XP | prod_per_hour | capacity |
|---|---|---|---|---|---|---|---|
| 1 | 5 | 20.000 | 10s | 400 | 3 | 25 | 200 |
| 2 | 6 | 40.700 | 42s | 498 | 6 | 36 | 288 |
| 3 | 7 | 82.900 | 7m | 621 | 20 | 53 | 424 |
| 4 | 8 | 169.000 | 42m | 773 | 50 | 76 | 608 |
| 5 | 9 | 344.000 | 2h 48m 20s | 963 | 100 | 111 | 888 |
| 6 | 10 | 700.000 | 8h 23m 20s | 1.200 | 173 | 160 | 1280 |


### cog_vault (3x3, sblocco Hall 1, costo in sap)

| Liv | Hall req | Costo | Tempo | HP | XP | capacity |
|---|---|---|---|---|---|---|
| 1 | 1 | 200 | 10s | 500 | 3 | 1500 |
| 2 | 2 | 487 | 27s | 595 | 5 | 3500 |
| 3 | 3 | 1.190 | 4m 30s | 709 | 16 | 9000 |
| 4 | 4 | 2.880 | 27m | 843 | 40 | 25000 |
| 5 | 5 | 7.020 | 1h 48m | 1.000 | 80 | 60000 |
| 6 | 6 | 17.100 | 5h 23m 20s | 1.200 | 139 | 130000 |
| 7 | 7 | 41.600 | 10h 48m 20s | 1.420 | 197 | 260000 |
| 8 | 8 | 101.000 | 16h 11m 40s | 1.690 | 241 | 480000 |
| 9 | 9 | 246.000 | 21h 36m 40s | 2.020 | 278 | 800000 |
| 10 | 10 | 600.000 | 1g 8h 30m | 2.400 | 342 | 1200000 |


### sap_cistern (3x3, sblocco Hall 1, costo in cogs)

| Liv | Hall req | Costo | Tempo | HP | XP | capacity |
|---|---|---|---|---|---|---|
| 1 | 1 | 200 | 10s | 500 | 3 | 1500 |
| 2 | 2 | 487 | 27s | 595 | 5 | 3500 |
| 3 | 3 | 1.190 | 4m 30s | 709 | 16 | 9000 |
| 4 | 4 | 2.880 | 27m | 843 | 40 | 25000 |
| 5 | 5 | 7.020 | 1h 48m | 1.000 | 80 | 60000 |
| 6 | 6 | 17.100 | 5h 23m 20s | 1.200 | 139 | 130000 |
| 7 | 7 | 41.600 | 10h 48m 20s | 1.420 | 197 | 260000 |
| 8 | 8 | 101.000 | 16h 11m 40s | 1.690 | 241 | 480000 |
| 9 | 9 | 246.000 | 21h 36m 40s | 2.020 | 278 | 800000 |
| 10 | 10 | 600.000 | 1g 8h 30m | 2.400 | 342 | 1200000 |


### shard_crate (2x2, sblocco Hall 5, costo in cogs)

| Liv | Hall req | Costo | Tempo | HP | XP | capacity |
|---|---|---|---|---|---|---|
| 1 | 5 | 30.000 | 10s | 500 | 3 | 1000 |
| 2 | 6 | 52.700 | 36s | 646 | 6 | 1780 |
| 3 | 7 | 92.400 | 6m | 835 | 18 | 3180 |
| 4 | 8 | 162.000 | 36m | 1.080 | 46 | 5660 |
| 5 | 9 | 285.000 | 2h 24m | 1.390 | 92 | 10100 |
| 6 | 10 | 500.000 | 7h 11m 40s | 1.800 | 160 | 18000 |


### barracks (3x3, sblocco Hall 1, costo in sap)

| Liv | Hall req | Costo | Tempo | HP | XP | troops_unlocked |
|---|---|---|---|---|---|---|
| 1 | 1 | 150 | 10s | 450 | 3 | cogling |
| 2 | 2 | 369 | 36s | 531 | 6 | cogling,slingwisp |
| 3 | 3 | 910 | 6m | 627 | 18 | cogling,slingwisp,bulwark |
| 4 | 4 | 2.240 | 36m | 740 | 46 | cogling,slingwisp,bulwark,magpie |
| 5 | 5 | 5.520 | 2h 24m | 873 | 92 | cogling,slingwisp,bulwark,magpie,kegger |
| 6 | 6 | 13.600 | 7h 11m 40s | 1.030 | 160 | cogling,slingwisp,bulwark,magpie,kegger,rustjaw |
| 7 | 7 | 33.500 | 14h 23m 20s | 1.220 | 227 | cogling,slingwisp,bulwark,magpie,kegger,rustjaw,kitewing |
| 8 | 8 | 82.400 | 21h 36m 40s | 1.440 | 278 | cogling,slingwisp,bulwark,magpie,kegger,rustjaw,kitewing,mender |
| 9 | 9 | 203.000 | 1g 4h 53m | 1.690 | 322 | cogling,slingwisp,bulwark,magpie,kegger,rustjaw,kitewing,mender,dirigible |
| 10 | 10 | 500.000 | 1g 19h 20m | 2.000 | 394 | cogling,slingwisp,bulwark,magpie,kegger,rustjaw,kitewing,mender,dirigible,ember_warden |


### army_camp (4x4, sblocco Hall 1, costo in sap)

| Liv | Hall req | Costo | Tempo | HP | XP | army_capacity |
|---|---|---|---|---|---|---|
| 1 | 1 | 250 | 10s | 400 | 3 | 20 |
| 2 | 2 | 717 | 24s | 462 | 4 | 25 |
| 3 | 3 | 2.060 | 4m | 534 | 15 | 30 |
| 4 | 4 | 5.900 | 24m | 617 | 37 | 35 |
| 5 | 6 | 16.900 | 1h 36m | 713 | 75 | 40 |
| 6 | 7 | 48.600 | 4h 48m 20s | 824 | 131 | 45 |
| 7 | 8 | 139.000 | 9h 36m 40s | 952 | 186 | 50 |
| 8 | 9 | 400.000 | 14h 23m 20s | 1.100 | 227 | 55 |


### laboratory (4x4, sblocco Hall 3, costo in sap)

| Liv | Hall req | Costo | Tempo | HP | XP | max_troop_level |
|---|---|---|---|---|---|---|
| 1 | 3 | 5.000 | 10s | 600 | 3 | 1 |
| 2 | 4 | 12.100 | 54s | 713 | 7 | 2 |
| 3 | 5 | 29.500 | 9m | 846 | 23 | 3 |
| 4 | 6 | 71.700 | 54m | 1.010 | 56 | 4 |
| 5 | 7 | 174.000 | 3h 36m 40s | 1.190 | 114 | 5 |
| 6 | 8 | 423.000 | 10h 48m 20s | 1.420 | 197 | 6 |
| 7 | 9 | 1.030.000 | 21h 36m 40s | 1.680 | 278 | 7 |
| 8 | 10 | 2.500.000 | 1g 8h 30m | 2.000 | 342 | 8 |


### spell_forge (3x3, sblocco Hall 5, costo in sap)

| Liv | Hall req | Costo | Tempo | HP | XP | spell_slots |
|---|---|---|---|---|---|---|
| 1 | 5 | 40.000 | 10s | 550 | 3 | 2 |
| 2 | 6 | 99.000 | 48s | 707 | 6 | 3 |
| 3 | 7 | 245.000 | 8m | 908 | 21 | 4 |
| 4 | 8 | 606.000 | 48m | 1.170 | 53 | 5 |
| 5 | 9 | 1.500.000 | 3h 11m 40s | 1.500 | 107 | 6 |


### clan_hall (4x4, sblocco Hall 4, costo in cogs)

| Liv | Hall req | Costo | Tempo | HP | XP | clan_slots |
|---|---|---|---|---|---|---|
| 1 | 4 | 15.000 | 10s | 600 | 3 | 5 |
| 2 | 5 | 40.500 | 30s | 767 | 5 | 10 |
| 3 | 6 | 110.000 | 5m | 980 | 17 | 15 |
| 4 | 8 | 296.000 | 30m | 1.250 | 42 | 20 |
| 5 | 9 | 800.000 | 2h | 1.600 | 84 | 25 |


## Difese


### boltpost (2x2, ruolo single_target, bersagli ground+air, raggio 0-8, intervallo 0.6s, area 0, priorita' nearest)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 250 | 0 | 10s | 380 | 12 | 7.2 |
| 2 | 2 | 621 | 0 | 30s | 449 | 14 | 8.4 |
| 3 | 3 | 1.540 | 0 | 5m | 530 | 16 | 9.9 |
| 4 | 4 | 3.830 | 0 | 30m | 626 | 19 | 11.5 |
| 5 | 5 | 9.520 | 0 | 2h | 740 | 22 | 13.5 |
| 6 | 6 | 23.600 | 0 | 6h | 874 | 26 | 15.8 |
| 7 | 7 | 58.700 | 0 | 12h | 1.030 | 31 | 18.5 |
| 8 | 8 | 146.000 | 800 | 18h | 1.220 | 36 | 21.6 |
| 9 | 9 | 362.000 | 2000 | 1g | 1.440 | 42 | 25.3 |
| 10 | 10 | 900.000 | 4500 | 1g 12h 6m | 1.700 | 49 | 29.6 |


### lobber (3x3, ruolo area, bersagli ground, raggio 3-11, intervallo 3.5s, area 1.6, priorita' highest_hp_cluster)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo |
|---|---|---|---|---|---|---|---|
| 1 | 2 | 800 | 0 | 10s | 400 | 8 | 28.0 |
| 2 | 2 | 1.800 | 0 | 30s | 473 | 9 | 32.8 |
| 3 | 3 | 4.060 | 0 | 5m | 559 | 11 | 38.3 |
| 4 | 4 | 9.160 | 0 | 30m | 660 | 13 | 44.8 |
| 5 | 5 | 20.600 | 0 | 2h | 781 | 15 | 52.5 |
| 6 | 6 | 46.500 | 0 | 6h | 922 | 18 | 61.4 |
| 7 | 7 | 105.000 | 0 | 12h | 1.090 | 21 | 71.8 |
| 8 | 8 | 236.000 | 800 | 18h | 1.290 | 24 | 84.0 |
| 9 | 9 | 532.000 | 2000 | 1g | 1.520 | 28 | 98.3 |
| 10 | 10 | 1.200.000 | 4500 | 1g 12h 6m | 1.800 | 33 | 115.0 |


### skyspear (2x2, ruolo anti_air, bersagli air, raggio 0-10, intervallo 0.8s, area 0, priorita' nearest_air)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo |
|---|---|---|---|---|---|---|---|
| 1 | 3 | 500 | 0 | 10s | 360 | 22 | 17.6 |
| 2 | 3 | 1.180 | 0 | 30s | 425 | 26 | 20.6 |
| 3 | 4 | 2.770 | 0 | 5m | 501 | 30 | 24.1 |
| 4 | 5 | 6.500 | 0 | 30m | 592 | 35 | 28.2 |
| 5 | 6 | 15.300 | 0 | 2h | 699 | 41 | 33.0 |
| 6 | 7 | 36.000 | 0 | 6h | 825 | 48 | 38.6 |
| 7 | 7 | 84.600 | 0 | 12h | 973 | 56 | 45.1 |
| 8 | 8 | 199.000 | 800 | 18h | 1.150 | 66 | 52.8 |
| 9 | 9 | 468.000 | 2000 | 1g | 1.360 | 77 | 61.8 |
| 10 | 10 | 1.100.000 | 4500 | 1g 12h 6m | 1.600 | 90 | 72.3 |


### arc_coil (2x2, ruolo chain_3_targets, bersagli ground, raggio 0-7, intervallo 1.0s, area 0, priorita' lowest_hp)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo |
|---|---|---|---|---|---|---|---|
| 1 | 4 | 3.000 | 0 | 10s | 520 | 30 | 30.0 |
| 2 | 4 | 6.030 | 0 | 36s | 613 | 35 | 35.1 |
| 3 | 5 | 12.100 | 0 | 6m | 724 | 41 | 41.1 |
| 4 | 6 | 24.300 | 0 | 36m | 854 | 48 | 48.0 |
| 5 | 6 | 48.900 | 0 | 2h 24m | 1.010 | 56 | 56.2 |
| 6 | 7 | 98.200 | 0 | 7h 11m 40s | 1.190 | 66 | 65.8 |
| 7 | 8 | 197.000 | 0 | 14h 23m 20s | 1.400 | 77 | 77.0 |
| 8 | 8 | 396.000 | 800 | 21h 36m 40s | 1.650 | 90 | 90.0 |
| 9 | 9 | 796.000 | 2000 | 1g 4h 53m | 1.950 | 105 | 105.3 |
| 10 | 10 | 1.600.000 | 4500 | 1g 19h 20m | 2.300 | 123 | 123.3 |


### ballista (3x3, ruolo long_range, bersagli ground+air, raggio 2-14, intervallo 1.2s, area 0, priorita' farthest_in_range)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo |
|---|---|---|---|---|---|---|---|
| 1 | 5 | 8.000 | 0 | 10s | 700 | 16 | 19.2 |
| 2 | 5 | 14.800 | 0 | 42s | 826 | 19 | 22.5 |
| 3 | 6 | 27.300 | 0 | 7m | 974 | 22 | 26.3 |
| 4 | 6 | 50.400 | 0 | 42m | 1.150 | 26 | 30.8 |
| 5 | 7 | 93.100 | 0 | 2h 48m 20s | 1.360 | 30 | 36.0 |
| 6 | 8 | 172.000 | 0 | 8h 23m 20s | 1.600 | 35 | 42.1 |
| 7 | 8 | 317.000 | 0 | 16h 48m 20s | 1.890 | 41 | 49.3 |
| 8 | 9 | 586.000 | 800 | 1g 1h 11m | 2.230 | 48 | 57.6 |
| 9 | 9 | 1.080.000 | 2000 | 1g 9h 36m | 2.630 | 56 | 67.4 |
| 10 | 10 | 2.000.000 | 4500 | 2g 2h 16m | 3.100 | 66 | 78.9 |


### thumper (3x3, ruolo slow_high_damage, bersagli ground, raggio 0-6, intervallo 3.5s, area 0, priorita' highest_hp)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 20.000 | 0 | 10s | 900 | 45 | 157.5 |
| 2 | 6 | 34.000 | 0 | 48s | 1.060 | 53 | 184.3 |
| 3 | 7 | 58.000 | 0 | 8m | 1.250 | 62 | 215.6 |
| 4 | 7 | 98.600 | 0 | 48m | 1.470 | 72 | 252.3 |
| 5 | 8 | 168.000 | 0 | 3h 11m 40s | 1.730 | 84 | 295.1 |
| 6 | 8 | 286.000 | 0 | 9h 36m 40s | 2.030 | 99 | 345.3 |
| 7 | 9 | 487.000 | 0 | 19h 11m 40s | 2.390 | 115 | 404.0 |
| 8 | 9 | 828.000 | 800 | 1g 4h 53m | 2.820 | 135 | 472.7 |
| 9 | 10 | 1.410.000 | 2000 | 1g 14h 20m | 3.310 | 158 | 553.1 |
| 10 | 10 | 2.400.000 | 4500 | 2g 9h 30m | 3.900 | 185 | 647.1 |


### frost_spire (2x2, ruolo slow_area, bersagli ground+air, raggio 0-6, intervallo 1.0s, area 2.5, priorita' nearest)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo | slow_fraction |
|---|---|---|---|---|---|---|---|---|
| 1 | 7 | 40.000 | 0 | 10s | 600 | 9 | 9.0 | 0.3 |
| 2 | 7 | 63.300 | 0 | 48s | 706 | 11 | 10.5 | 0.33 |
| 3 | 7 | 100.000 | 0 | 8m | 831 | 12 | 12.3 | 0.36 |
| 4 | 8 | 159.000 | 0 | 48m | 978 | 14 | 14.4 | 0.39 |
| 5 | 8 | 251.000 | 0 | 3h 11m 40s | 1.150 | 17 | 16.9 | 0.42 |
| 6 | 9 | 398.000 | 0 | 9h 36m 40s | 1.360 | 20 | 19.7 | 0.45 |
| 7 | 9 | 630.000 | 0 | 19h 11m 40s | 1.590 | 23 | 23.1 | 0.47 |
| 8 | 9 | 997.000 | 800 | 1g 4h 53m | 1.880 | 27 | 27.0 | 0.49 |
| 9 | 10 | 1.580.000 | 2000 | 1g 14h 20m | 2.210 | 32 | 31.6 | 0.5 |
| 10 | 10 | 2.500.000 | 4500 | 2g 9h 30m | 2.600 | 37 | 37.0 | 0.5 |


### cinder_spout (2x2, ruolo short_range_burst, bersagli ground, raggio 0-4, intervallo 0.2s, area 0, priorita' nearest)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo |
|---|---|---|---|---|---|---|---|
| 1 | 8 | 80.000 | 0 | 10s | 800 | 95 | 19.0 |
| 2 | 8 | 120.000 | 0 | 54s | 943 | 111 | 22.23 |
| 3 | 8 | 179.000 | 0 | 9m | 1.110 | 130 | 26.01 |
| 4 | 8 | 268.000 | 0 | 54m | 1.310 | 152 | 30.43 |
| 5 | 9 | 401.000 | 0 | 3h 36m 40s | 1.540 | 178 | 35.6 |
| 6 | 9 | 599.000 | 0 | 10h 48m 20s | 1.820 | 208 | 41.66 |
| 7 | 9 | 896.000 | 0 | 21h 36m 40s | 2.140 | 244 | 48.74 |
| 8 | 10 | 1.340.000 | 800 | 1g 8h 30m | 2.520 | 285 | 57.02 |
| 9 | 10 | 2.010.000 | 2000 | 1g 19h 20m | 2.970 | 334 | 66.72 |
| 10 | 10 | 3.000.000 | 4500 | 2g 16h 43m | 3.500 | 390 | 78.06 |


### storm_pylon (3x3, ruolo anti_air_area, bersagli air, raggio 0-11, intervallo 1.2s, area 2.0, priorita' nearest_air_cluster)

| Liv | Hall req | Costo Cogs | Shards | Tempo | HP | DPS | Danno/colpo |
|---|---|---|---|---|---|---|---|
| 1 | 9 | 150.000 | 0 | 10s | 900 | 40 | 48.0 |
| 2 | 9 | 213.000 | 0 | 1m | 1.060 | 47 | 56.2 |
| 3 | 9 | 302.000 | 0 | 10m | 1.250 | 55 | 65.7 |
| 4 | 9 | 429.000 | 0 | 1h | 1.470 | 64 | 76.9 |
| 5 | 9 | 608.000 | 0 | 4h | 1.730 | 75 | 89.9 |
| 6 | 10 | 863.000 | 0 | 12h | 2.030 | 88 | 105.2 |
| 7 | 10 | 1.220.000 | 0 | 1g | 2.390 | 103 | 123.1 |
| 8 | 10 | 1.740.000 | 800 | 1g 12h 6m | 2.820 | 120 | 144.1 |
| 9 | 10 | 2.470.000 | 2000 | 2g 3m | 3.310 | 140 | 168.5 |
| 10 | 10 | 3.500.000 | 4500 | 2g 23h 56m | 3.900 | 164 | 197.2 |


## Mura

| Liv | Hall req | Costo/segmento | Tempo | HP |
|---|---|---|---|---|
| 1 | 1 | 50 | 0s | 300 |
| 2 | 2 | 110 | 0s | 390 |
| 3 | 3 | 242 | 0s | 508 |
| 4 | 4 | 531 | 0s | 660 |
| 5 | 5 | 1.170 | 0s | 859 |
| 6 | 6 | 2.570 | 0s | 1.120 |
| 7 | 7 | 5.650 | 0s | 1.450 |
| 8 | 8 | 12.400 | 0s | 1.890 |
| 9 | 9 | 27.300 | 0s | 2.460 |
| 10 | 10 | 60.000 | 0s | 3.200 |


## Trappole


### bomb_trap (effetto area_damage, bersagli ground, trigger 1.5, raggio 1.5)

| Liv | Hall req | Costo | Riarmo | Tempo | damage |
|---|---|---|---|---|---|
| 1 | 2 | 400 | 80 | 10s | 60 |
| 2 | 3 | 1.260 | 253 | 15s | 81 |
| 3 | 5 | 4.000 | 800 | 2m 30s | 110 |
| 4 | 7 | 12.600 | 2.530 | 15m | 148 |
| 5 | 9 | 40.000 | 8.000 | 1h | 200 |


### spring_pad (effetto launch_troops_up_to_space, bersagli ground, trigger 1.0, raggio 0.8)

| Liv | Hall req | Costo | Riarmo | Tempo | launch_max_space |
|---|---|---|---|---|---|
| 1 | 3 | 500 | 100 | 10s | 12 |
| 2 | 4 | 1.650 | 331 | 15s | 14 |
| 3 | 6 | 5.480 | 1.100 | 2m 30s | 17 |
| 4 | 7 | 18.100 | 3.630 | 15m | 20 |
| 5 | 9 | 60.000 | 12.000 | 1h | 24 |


### snare_trap (effetto freeze_seconds, bersagli ground, trigger 2.0, raggio 3.5)

| Liv | Hall req | Costo | Riarmo | Tempo | freeze_seconds |
|---|---|---|---|---|---|
| 1 | 4 | 2.000 | 400 | 10s | 3.0 |
| 2 | 5 | 5.890 | 1.180 | 18s | 3.4 |
| 3 | 6 | 17.300 | 3.460 | 3m | 3.9 |
| 4 | 8 | 51.000 | 10.200 | 18m | 4.4 |
| 5 | 9 | 150.000 | 30.000 | 1h 12m | 5.0 |


### air_mine (effetto air_burst, bersagli air, trigger 2.0, raggio 2.5)

| Liv | Hall req | Costo | Riarmo | Tempo | damage |
|---|---|---|---|---|---|
| 1 | 5 | 3.000 | 600 | 10s | 250 |
| 2 | 6 | 8.570 | 1.710 | 18s | 354 |
| 3 | 7 | 24.500 | 4.900 | 3m | 500 |
| 4 | 8 | 70.000 | 14.000 | 18m | 707 |
| 5 | 9 | 200.000 | 40.000 | 1h 12m | 1000 |


## Truppe (per livello)


### cogling - melee_basic (spazio 1, velocita' 2.0, raggio 0.6, bersagli ground, preferenza any, caserma Lv1)

Speciale: `-`


| Liv | HP | DPS | Costo | Addestr. | Lab liv |
|---|---|---|---|---|---|
| 1 | 45 | 11 | 25 sap | 10s | 0 |
| 2 | 51 | 13 | 32 sap | 10s | 2 |
| 3 | 57 | 14 | 42 sap | 11s | 3 |
| 4 | 65 | 16 | 55 sap | 11s | 4 |
| 5 | 73 | 19 | 71 sap | 12s | 5 |
| 6 | 83 | 21 | 93 sap | 12s | 6 |
| 7 | 94 | 24 | 121 sap | 12s | 7 |
| 8 | 106 | 28 | 157 sap | 13s | 8 |


### slingwisp - ranged (spazio 1, velocita' 2.2, raggio 5.0, bersagli ground+air, preferenza any, caserma Lv2)

Speciale: `-`


| Liv | HP | DPS | Costo | Addestr. | Lab liv |
|---|---|---|---|---|---|
| 1 | 33 | 14 | 45 sap | 15s | 0 |
| 2 | 37 | 16 | 58 sap | 16s | 2 |
| 3 | 42 | 18 | 76 sap | 16s | 3 |
| 4 | 48 | 21 | 99 sap | 17s | 4 |
| 5 | 54 | 24 | 129 sap | 17s | 5 |
| 6 | 61 | 27 | 167 sap | 18s | 6 |
| 7 | 69 | 31 | 217 sap | 19s | 7 |
| 8 | 78 | 35 | 282 sap | 19s | 8 |


### bulwark - tank (spazio 5, velocita' 1.4, raggio 0.8, bersagli ground, preferenza defenses, caserma Lv3)

Speciale: `taunt_radius_3`


| Liv | HP | DPS | Costo | Addestr. | Lab liv |
|---|---|---|---|---|---|
| 1 | 420 | 18 | 250 sap | 1m 30s | 0 |
| 2 | 475 | 21 | 325 sap | 1m 34s | 2 |
| 3 | 536 | 23 | 423 sap | 1m 37s | 3 |
| 4 | 606 | 27 | 549 sap | 1m 41s | 4 |
| 5 | 685 | 30 | 714 sap | 1m 44s | 5 |
| 6 | 774 | 35 | 928 sap | 1m 48s | 6 |
| 7 | 874 | 40 | 1.210 sap | 1m 52s | 7 |
| 8 | 988 | 45 | 1.570 sap | 1m 55s | 8 |


### magpie - looter (spazio 1, velocita' 3.4, raggio 0.6, bersagli ground, preferenza resources, caserma Lv4)

Speciale: `x2_damage_vs_resource_buildings`


| Liv | HP | DPS | Costo | Addestr. | Lab liv |
|---|---|---|---|---|---|
| 1 | 28 | 17 | 60 sap | 14s | 0 |
| 2 | 32 | 19 | 78 sap | 15s | 2 |
| 3 | 36 | 22 | 101 sap | 15s | 3 |
| 4 | 40 | 25 | 132 sap | 16s | 4 |
| 5 | 46 | 29 | 171 sap | 16s | 5 |
| 6 | 52 | 33 | 223 sap | 17s | 6 |
| 7 | 58 | 37 | 290 sap | 17s | 7 |
| 8 | 66 | 43 | 376 sap | 18s | 8 |


### kegger - wall_breaker (spazio 2, velocita' 2.6, raggio 0.5, bersagli ground, preferenza walls, caserma Lv5)

Speciale: `suicide_blast_60_x40_vs_walls_radius_1.2`


| Liv | HP | DPS | Costo | Addestr. | Lab liv | Danno esplosione |
|---|---|---|---|---|---|---|
| 1 | 22 | 0 | 120 sap | 30s | 0 | 60 |
| 2 | 25 | 0 | 156 sap | 31s | 2 | 68 |
| 3 | 28 | 0 | 203 sap | 32s | 3 | 78 |
| 4 | 32 | 0 | 264 sap | 34s | 4 | 89 |
| 5 | 36 | 0 | 343 sap | 35s | 5 | 101 |
| 6 | 41 | 0 | 446 sap | 36s | 6 | 116 |
| 7 | 46 | 0 | 579 sap | 37s | 7 | 132 |
| 8 | 52 | 0 | 753 sap | 38s | 8 | 150 |


### rustjaw - anti_defense (spazio 4, velocita' 3.0, raggio 0.8, bersagli ground, preferenza defenses, caserma Lv6)

Speciale: `hops_over_walls;x1.5_damage_vs_defenses`


| Liv | HP | DPS | Costo | Addestr. | Lab liv |
|---|---|---|---|---|---|
| 1 | 270 | 36 | 300 sap | 2m | 0 |
| 2 | 305 | 41 | 390 sap | 2m 5s | 2 |
| 3 | 345 | 47 | 507 sap | 2m 10s | 3 |
| 4 | 390 | 53 | 659 sap | 2m 14s | 4 |
| 5 | 440 | 61 | 857 sap | 2m 19s | 5 |
| 6 | 497 | 69 | 1.110 sap | 2m 24s | 6 |
| 7 | 562 | 79 | 1.450 sap | 2m 29s | 7 |
| 8 | 635 | 90 | 1.880 sap | 2m 34s | 8 |


### kitewing - flyer (spazio 2, velocita' 3.2, raggio 0.8, bersagli ground, preferenza any, caserma Lv7)

Speciale: `-`


| Liv | HP | DPS | Costo | Addestr. | Lab liv |
|---|---|---|---|---|---|
| 1 | 95 | 26 | 180 sap | 45s | 0 |
| 2 | 107 | 30 | 234 sap | 47s | 2 |
| 3 | 121 | 34 | 304 sap | 49s | 3 |
| 4 | 137 | 39 | 395 sap | 50s | 4 |
| 5 | 155 | 44 | 514 sap | 52s | 5 |
| 6 | 175 | 50 | 668 sap | 54s | 6 |
| 7 | 198 | 57 | 869 sap | 56s | 7 |
| 8 | 223 | 65 | 1.130 sap | 58s | 8 |


### mender - healer (spazio 8, velocita' 2.0, raggio 0.0, bersagli none, preferenza allies, caserma Lv8)

Speciale: `heal_per_s=48;heal_radius=3;heals_ground_only`


| Liv | HP | DPS | Costo | Addestr. | Lab liv | Cura/s |
|---|---|---|---|---|---|---|
| 1 | 520 | 0 | 800 sap | 5m | 0 | 48 |
| 2 | 588 | 0 | 1.040 sap | 5m 12s | 2 | 55 |
| 3 | 664 | 0 | 1.350 sap | 5m 24s | 3 | 62 |
| 4 | 750 | 0 | 1.760 sap | 5m 36s | 4 | 71 |
| 5 | 848 | 0 | 2.280 sap | 5m 48s | 5 | 81 |
| 6 | 958 | 0 | 2.970 sap | 6m | 6 | 92 |
| 7 | 1.080 | 0 | 3.860 sap | 6m 12s | 7 | 105 |
| 8 | 1.220 | 0 | 5.020 sap | 6m 24s | 8 | 120 |


### dirigible - heavy_flyer (spazio 10, velocita' 1.1, raggio 1.0, bersagli ground, preferenza defenses, caserma Lv9)

Speciale: `splash_radius_1.5`


| Liv | HP | DPS | Costo | Addestr. | Lab liv |
|---|---|---|---|---|---|
| 1 | 1.900 | 34 | 2.800 sap | 8m | 0 |
| 2 | 2.150 | 39 | 3.640 sap | 8m 19s | 2 |
| 3 | 2.430 | 44 | 4.730 sap | 8m 38s | 3 |
| 4 | 2.740 | 50 | 6.150 sap | 8m 58s | 4 |
| 5 | 3.100 | 57 | 8.000 sap | 9m 17s | 5 |
| 6 | 3.500 | 65 | 10.400 sap | 9m 36s | 6 |
| 7 | 3.960 | 75 | 13.500 sap | 9m 55s | 7 |
| 8 | 4.470 | 85 | 17.600 sap | 10m 14s | 8 |


### ember_warden - elite (spazio 20, velocita' 1.6, raggio 0.9, bersagli ground, preferenza defenses, caserma Lv10)

Speciale: `lantern_surge:at_50pct_hp_+50pct_dps_and_heal_25pct_over_4s_once`


| Liv | HP | DPS | Costo | Addestr. | Lab liv |
|---|---|---|---|---|---|
| 1 | 3.600 | 95 | 45 shards | 30m | 0 |
| 2 | 4.070 | 108 | 56 shards | 31m 10s | 2 |
| 3 | 4.600 | 123 | 70 shards | 32m 20s | 3 |
| 4 | 5.190 | 141 | 88 shards | 33m 40s | 4 |
| 5 | 5.870 | 160 | 110 shards | 34m 50s | 5 |
| 6 | 6.630 | 183 | 137 shards | 36m | 6 |


## Ricerca laboratorio (costo/tempo per portare la truppa al livello indicato)

| Truppa | Liv | Lab req | Costo | Tempo |
|---|---|---|---|---|
| cogling | 2 | 2 | 6.000 sap | 10m |
| cogling | 3 | 3 | 18.000 sap | 1h |
| cogling | 4 | 4 | 48.000 sap | 4h |
| cogling | 5 | 5 | 120.000 sap | 12h |
| cogling | 6 | 6 | 240.000 sap | 1g |
| cogling | 7 | 7 | 450.000 sap | 1g 12h 6m |
| cogling | 8 | 8 | 720.000 sap | 2g 3m |
| slingwisp | 2 | 2 | 7.000 sap | 10m |
| slingwisp | 3 | 3 | 21.000 sap | 1h |
| slingwisp | 4 | 4 | 56.000 sap | 4h |
| slingwisp | 5 | 5 | 140.000 sap | 12h |
| slingwisp | 6 | 6 | 280.000 sap | 1g |
| slingwisp | 7 | 7 | 525.000 sap | 1g 12h 6m |
| slingwisp | 8 | 8 | 840.000 sap | 2g 3m |
| bulwark | 2 | 2 | 9.000 sap | 10m |
| bulwark | 3 | 3 | 27.000 sap | 1h |
| bulwark | 4 | 4 | 72.000 sap | 4h |
| bulwark | 5 | 5 | 180.000 sap | 12h |
| bulwark | 6 | 6 | 360.000 sap | 1g |
| bulwark | 7 | 7 | 675.000 sap | 1g 12h 6m |
| bulwark | 8 | 8 | 1.080.000 sap | 2g 3m |
| magpie | 2 | 2 | 7.500 sap | 10m |
| magpie | 3 | 3 | 22.500 sap | 1h |
| magpie | 4 | 4 | 60.000 sap | 4h |
| magpie | 5 | 5 | 150.000 sap | 12h |
| magpie | 6 | 6 | 300.000 sap | 1g |
| magpie | 7 | 7 | 562.000 sap | 1g 12h 6m |
| magpie | 8 | 8 | 900.000 sap | 2g 3m |
| kegger | 2 | 2 | 8.000 sap | 10m |
| kegger | 3 | 3 | 24.000 sap | 1h |
| kegger | 4 | 4 | 64.000 sap | 4h |
| kegger | 5 | 5 | 160.000 sap | 12h |
| kegger | 6 | 6 | 320.000 sap | 1g |
| kegger | 7 | 7 | 600.000 sap | 1g 12h 6m |
| kegger | 8 | 8 | 960.000 sap | 2g 3m |
| rustjaw | 2 | 2 | 10.000 sap | 10m |
| rustjaw | 3 | 3 | 30.000 sap | 1h |
| rustjaw | 4 | 4 | 80.000 sap | 4h |
| rustjaw | 5 | 5 | 200.000 sap | 12h |
| rustjaw | 6 | 6 | 400.000 sap | 1g |
| rustjaw | 7 | 7 | 750.000 sap | 1g 12h 6m |
| rustjaw | 8 | 8 | 1.200.000 sap | 2g 3m |
| kitewing | 2 | 2 | 10.000 sap | 10m |
| kitewing | 3 | 3 | 30.000 sap | 1h |
| kitewing | 4 | 4 | 80.000 sap | 4h |
| kitewing | 5 | 5 | 200.000 sap | 12h |
| kitewing | 6 | 6 | 400.000 sap | 1g |
| kitewing | 7 | 7 | 750.000 sap | 1g 12h 6m |
| kitewing | 8 | 8 | 1.200.000 sap | 2g 3m |
| mender | 2 | 2 | 11.500 sap | 10m |
| mender | 3 | 3 | 34.500 sap | 1h |
| mender | 4 | 4 | 92.000 sap | 4h |
| mender | 5 | 5 | 230.000 sap | 12h |
| mender | 6 | 6 | 460.000 sap | 1g |
| mender | 7 | 7 | 862.000 sap | 1g 12h 6m |
| mender | 8 | 8 | 1.380.000 sap | 2g 3m |
| dirigible | 2 | 2 | 13.000 sap | 10m |
| dirigible | 3 | 3 | 39.000 sap | 1h |
| dirigible | 4 | 4 | 104.000 sap | 4h |
| dirigible | 5 | 5 | 260.000 sap | 12h |
| dirigible | 6 | 6 | 520.000 sap | 1g |
| dirigible | 7 | 7 | 975.000 sap | 1g 12h 6m |
| dirigible | 8 | 8 | 1.560.000 sap | 2g 3m |
| ember_warden | 2 | 2 | 300 shards | 13m |
| ember_warden | 3 | 3 | 600 shards | 1h 18m |
| ember_warden | 4 | 4 | 1.200 shards | 5h 11m 40s |
| ember_warden | 5 | 5 | 2.400 shards | 15h 36m 40s |
| ember_warden | 6 | 6 | 4.800 shards | 1g 7h 6m |


## Incantesimi

| ID | Liv | Raggio | Durata | Costo | Addestr. | Effetto |
|---|---|---|---|---|---|---|
| mending_mist | 1 | 5.0 | 8.0 | 4.000 | 3m | cura 28/s |
| mending_mist | 2 | 5.0 | 8.0 | 5.000 | 3m 30s | cura 34/s |
| mending_mist | 3 | 5.0 | 8.0 | 6.250 | 4m | cura 40/s |
| mending_mist | 4 | 5.0 | 8.0 | 7.810 | 4m 30s | cura 48/s |
| mending_mist | 5 | 5.0 | 8.0 | 9.770 | 5m | cura 58/s |
| fervor_surge | 1 | 4.0 | 6.0 | 6.500 | 4m | +30% danno, +25% velocita' |
| fervor_surge | 2 | 4.0 | 6.0 | 8.120 | 4m 30s | +34% danno, +28% velocita' |
| fervor_surge | 3 | 4.0 | 6.0 | 10.200 | 5m | +38% danno, +31% velocita' |
| fervor_surge | 4 | 4.0 | 6.0 | 12.700 | 5m 30s | +44% danno, +35% velocita' |
| fervor_surge | 5 | 4.0 | 6.0 | 15.900 | 6m | +50% danno, +40% velocita' |


## Leghe

| # | ID | Trofei | Gemme 1a volta | Bonus bottino |
|---|---|---|---|---|
| 1 | wick | 0-299 | 0 | 0% |
| 2 | spark | 300-599 | 5 | 0% |
| 3 | ember | 600-999 | 10 | 5% |
| 4 | flame | 1000-1399 | 20 | 8% |
| 5 | blaze | 1400-1799 | 30 | 10% |
| 6 | beacon | 1800-2399 | 50 | 15% |
| 7 | lighthouse | 2400-3199 | 80 | 20% |
| 8 | sunforge | 3200-+ | 120 | 25% |


## Campagna (25 livelli)

| # | Nome | Hall | Bolt/Lob/Sky/Arc/Bal/Thu/Fro/Spo/Pyl | Mura | Cogs | Sap | Shards | Gemme 3* | Note |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Mossy Gate | 1 | 1/0/0/0/0/0/0/0/0 | 0 | 280 | 280 | 0 | 6 | Tutorial: una sola Boltpost, nessuna mura |
| 2 | Pebble Hollow | 2 | 2/0/0/0/0/0/0/0/0 | 10 | 855 | 855 | 0 | 7 | Introduce le mura: porta singola |
| 3 | Dewdrop Farm | 2 | 2/1/0/0/0/0/0/0/0 | 20 | 870 | 870 | 0 | 8 | Mine esterne, esca per saccheggiatori |
| 4 | Cricket Hill | 3 | 2/1/0/0/0/0/0/0/0 | 30 | 2.950 | 2.950 | 0 | 9 | Introduce trappola bomba |
| 5 | Thistle Fort | 3 | 2/1/1/0/0/0/0/0/0 | 40 | 3.000 | 3.000 | 0 | 10 | Prima difesa antiaerea: volanti penalizzati |
| 6 | Mudwater Docks | 4 | 3/1/1/0/0/0/0/0/0 | 50 | 9.150 | 9.150 | 0 | 11 | Base lunga e stretta, deposito isolato |
| 7 | Rustbucket Yard | 4 | 3/2/1/1/0/0/0/0/0 | 60 | 9.300 | 9.300 | 0 | 12 | Introduce Arc Coil al centro |
| 8 | Hornet Ridge | 5 | 3/2/1/1/0/0/0/0/0 | 75 | 25.200 | 25.200 | 12 | 13 | Antiaerea concentrata a nord |
| 9 | Fungus Fen | 5 | 3/2/2/1/1/0/0/0/0 | 90 | 25.600 | 25.600 | 12 | 14 | Prima Ballista a lungo raggio |
| 10 | The Gearmill | 5 | 3/2/2/1/1/0/0/0/0 | 110 | 26.000 | 26.000 | 12 | 15 | BOSS 1: doppio anello di mura, trappole molle |
| 11 | Brambleback | 6 | 4/2/2/1/1/1/0/0/0 | 125 | 59.400 | 59.400 | 36 | 16 | Introduce Thumper: massimo danno ai tank |
| 12 | Cobweb Cliffs | 6 | 4/3/2/2/1/1/0/0/0 | 140 | 60.300 | 60.300 | 36 | 17 | Difese a scacchiera, trappole snare |
| 13 | Gloomtide Pier | 7 | 4/3/2/2/1/1/0/0/0 | 150 | 122.000 | 122.000 | 72 | 18 | Lunga banchina: schieramento limitato a un lato |
| 14 | Lanternless Alley | 7 | 4/3/3/2/2/1/1/0/0 | 165 | 124.000 | 124.000 | 72 | 19 | Introduce Frost Spire: truppe rallentate |
| 15 | Cinder Orchard | 7 | 4/3/3/2/2/1/1/0/0 | 175 | 126.000 | 126.000 | 72 | 20 | Depositi molto distribuiti |
| 16 | Wraith Reservoir | 8 | 5/3/3/2/2/1/1/0/0 | 190 | 213.000 | 213.000 | 120 | 21 | Mine d'aria: volanti rischiosi |
| 17 | Thunder Terrace | 8 | 5/4/3/3/2/2/1/1/0 | 200 | 216.000 | 216.000 | 120 | 22 | Introduce Cinder Spout al centro |
| 18 | Frostbitten Fields | 8 | 5/4/3/3/2/2/1/1/0 | 200 | 219.000 | 219.000 | 120 | 23 | Tre Frost Spire sovrapposte |
| 19 | Smogspire | 9 | 5/4/3/3/2/2/2/1/0 | 215 | 333.000 | 333.000 | 192 | 24 | Torre fumo: visibilita' ridotta (solo estetica) |
| 20 | Mirror Marsh | 9 | 5/4/4/3/3/2/2/1/1 | 225 | 338.000 | 338.000 | 192 | 25 | Introduce Storm Pylon: volanti in difficolta' |
| 21 | Bonecog Citadel | 9 | 5/4/4/3/3/2/2/1/1 | 225 | 342.000 | 342.000 | 192 | 26 | BOSS 2: tre compartimenti concentrici |
| 22 | Stormcrow Keep | 10 | 6/4/3/3/2/2/2/1/1 | 250 | 462.000 | 462.000 | 270 | 27 | Hall 10, tempo ridotto di attacco consigliato |
| 23 | Hollow Sun | 10 | 6/4/4/3/3/2/2/2/1 | 250 | 468.000 | 468.000 | 270 | 28 | Difese miste ravvicinate, molte trappole |
| 24 | The Long Night Wall | 10 | 6/4/4/3/3/2/2/2/2 | 250 | 474.000 | 474.000 | 270 | 29 | Mura di livello massimo con lacune nascoste |
| 25 | Gloomqueen's Throne | 10 | 6/4/4/3/3/2/2/2/2 | 250 | 480.000 | 480.000 | 270 | 30 | BOSS FINALE: tutte le difese, Hall con aura (+30% HP) |


## Obiettivi permanenti

| ID | Livello | Metrica | Target | Gemme |
|---|---|---|---|---|
| loot_cogs | 1 | cogs_looted_total | 100.000 | 10 |
| loot_cogs | 2 | cogs_looted_total | 5.000.000 | 50 |
| loot_cogs | 3 | cogs_looted_total | 50.000.000 | 200 |
| loot_sap | 1 | sap_looted_total | 100.000 | 10 |
| loot_sap | 2 | sap_looted_total | 5.000.000 | 50 |
| loot_sap | 3 | sap_looted_total | 50.000.000 | 200 |
| win_battles | 1 | attack_wins | 10 | 10 |
| win_battles | 2 | attack_wins | 100 | 50 |
| win_battles | 3 | attack_wins | 1.000 | 200 |
| earn_stars | 1 | stars_total | 30 | 10 |
| earn_stars | 2 | stars_total | 300 | 50 |
| earn_stars | 3 | stars_total | 3.000 | 250 |
| raze_defenses | 1 | defenses_destroyed | 25 | 10 |
| raze_defenses | 2 | defenses_destroyed | 250 | 50 |
| raze_defenses | 3 | defenses_destroyed | 2.500 | 200 |
| hold_the_line | 1 | defense_wins | 5 | 10 |
| hold_the_line | 2 | defense_wins | 50 | 50 |
| hold_the_line | 3 | defense_wins | 500 | 200 |
| tidy_up | 1 | obstacles_cleared | 10 | 5 |
| tidy_up | 2 | obstacles_cleared | 100 | 30 |
| tidy_up | 3 | obstacles_cleared | 500 | 100 |
| lantern_rising | 1 | hall_level | 3 | 20 |
| lantern_rising | 2 | hall_level | 6 | 60 |
| lantern_rising | 3 | hall_level | 10 | 200 |
| trophy_hunter | 1 | trophies_best | 400 | 15 |
| trophy_hunter | 2 | trophies_best | 1.200 | 60 |
| trophy_hunter | 3 | trophies_best | 3.200 | 200 |
| campaign_walker | 1 | campaign_stars | 15 | 15 |
| campaign_walker | 2 | campaign_stars | 45 | 45 |
| campaign_walker | 3 | campaign_stars | 75 | 120 |
| spellcaster | 1 | spells_cast | 25 | 5 |
| spellcaster | 2 | spells_cast | 250 | 20 |
| spellcaster | 3 | spells_cast | 2.500 | 60 |
| barracks_busy | 1 | troops_trained | 100 | 5 |
| barracks_busy | 2 | troops_trained | 1.000 | 20 |
| barracks_busy | 3 | troops_trained | 10.000 | 60 |
| builder_hands | 1 | upgrades_done | 10 | 10 |
| builder_hands | 2 | upgrades_done | 100 | 40 |
| builder_hands | 3 | upgrades_done | 500 | 120 |
| wall_wrecker | 1 | walls_destroyed | 100 | 5 |
| wall_wrecker | 2 | walls_destroyed | 1.000 | 20 |
| wall_wrecker | 3 | walls_destroyed | 10.000 | 60 |
| shard_seeker | 1 | shards_collected | 1.000 | 10 |
| shard_seeker | 2 | shards_collected | 50.000 | 50 |
| shard_seeker | 3 | shards_collected | 1.000.000 | 150 |
| join_the_hall | 1 | clan_joined | 1 | 10 |


## Missioni giornaliere (3 al giorno estratte dal pool)

| ID | Metrica | Target | Gemme | Sap x Hall |
|---|---|---|---|---|
| win_attack | attack_wins | 1 | 2 | 0 |
| earn_stars | stars_total | 5 | 2 | 0 |
| loot_cogs | cogs_looted | 20.000 | 0 | 5000 |
| spend_upgrade | upgrades_started | 2 | 2 | 0 |
| train_troops | troops_trained | 30 | 1 | 0 |
| clear_obstacle | obstacles_cleared | 3 | 3 | 0 |
| cast_spell | spells_cast | 3 | 1 | 0 |
| destroy_defense | defenses_destroyed | 10 | 2 | 0 |


## Livelli giocatore (1-30)

| Liv | XP per salire | XP cumulativo |
|---|---|---|
| 1 | 12 | 0 |
| 2 | 36 | 12 |
| 3 | 70 | 48 |
| 4 | 110 | 118 |
| 5 | 158 | 228 |
| 6 | 211 | 386 |
| 7 | 270 | 597 |
| 8 | 334 | 867 |
| 9 | 404 | 1.201 |
| 10 | 478 | 1.605 |
| 11 | 556 | 2.083 |
| 12 | 640 | 2.639 |
| 13 | 727 | 3.279 |
| 14 | 818 | 4.006 |
| 15 | 914 | 4.824 |
| 16 | 1.013 | 5.738 |
| 17 | 1.117 | 6.751 |
| 18 | 1.224 | 7.868 |
| 19 | 1.334 | 9.092 |
| 20 | 1.448 | 10.426 |
| 21 | 1.566 | 11.874 |
| 22 | 1.687 | 13.440 |
| 23 | 1.811 | 15.127 |
| 24 | 1.939 | 16.938 |
| 25 | 2.070 | 18.877 |
| 26 | 2.204 | 20.947 |
| 27 | 2.341 | 23.151 |
| 28 | 2.481 | 25.492 |
| 29 | 2.624 | 27.973 |
| 30 | 2.771 | 30.597 |
