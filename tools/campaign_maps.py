#!/usr/bin/env python3
"""Layout della campagna (25 livelli) disegnati a mano con un mini-linguaggio di piazzamento.

Sintassi (una istruzione per riga):
  <id> x y                         edificio con angolo in alto a sinistra in (x, y); id = chiave Balance
  #rect x0 y0 x1 y1 [gap x,y ...]  mura sul perimetro del rettangolo (varchi opzionali)
  #line x0 y0 x1 y1 [gap x,y ...]  mura su una linea orizzontale o verticale

Il convertitore verifica: nessuna sovrapposizione, area 2..41, quantita' <= limiti dell'Edificio Centrale,
difese ESATTAMENTE come nella composizione del GDD (data/campaign.json), mura <= tetto del livello.
Output: data/campaign_layouts.json (+ riepilogo a schermo).
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

LEVELS = {}

# Slot standard (vedi commento in fondo): anello interno 17..26, anello esterno 12..31, Hall in 20..23.
LEVELS[1] = """
lantern_hall 20 20
boltpost 25 21
cog_mine 15 18
sap_well 26 16
"""

LEVELS[2] = """
lantern_hall 20 20
boltpost 25 20
boltpost 17 23
cog_mine 14 16
cog_mine 28 26
sap_well 27 15
cog_vault 20 26
sap_cistern 13 21
barracks 24 25
bomb_trap 23 24
#line 18 18 26 18 gap 22,18
"""

LEVELS[3] = """
lantern_hall 20 20
lobber 26 21
boltpost 17 20
boltpost 21 26
cog_mine 9 9
cog_mine 33 11
cog_mine 11 33
sap_well 32 31
sap_well 34 20
cog_vault 15 15
sap_cistern 25 15
army_camp 13 25
bomb_trap 23 17
#rect 19 19 24 24 gap 24,22
"""

LEVELS[4] = """
lantern_hall 20 20
lobber 27 20
boltpost 16 21
boltpost 21 27
cog_mine 12 14
cog_mine 30 12
cog_mine 14 30
sap_well 31 30
sap_well 30 24
cog_vault 13 20
cog_vault 26 26
sap_cistern 26 13
sap_cistern 17 13
barracks 13 25
laboratory 33 16
army_camp 8 18
bomb_trap 19 26
spring_pad 26 22
spring_pad 22 17
#rect 18 18 25 25 gap 25,21
"""

LEVELS[5] = """
lantern_hall 20 20
lobber 26 20
boltpost 15 21
boltpost 21 26
skyspear 18 18
cog_mine 9 12
cog_mine 33 9
cog_mine 9 32
sap_well 32 32
sap_well 34 22
cog_vault 14 14
cog_vault 27 27
sap_cistern 27 13
sap_cistern 13 27
barracks 6 22
laboratory 34 15
army_camp 22 33
bomb_trap 24 18
spring_pad 19 25
spring_pad 25 25
#rect 17 17 25 25 gap 17,21 gap 25,23
"""

LEVELS[6] = """
lantern_hall 20 20
boltpost 4 20
boltpost 8 20
boltpost 13 20
lobber 30 20
skyspear 17 20
cog_mine 4 14
cog_mine 4 26
cog_mine 36 14
sap_well 36 26
sap_well 38 20
cog_vault 25 20
cog_vault 34 20
sap_cistern 10 15
sap_cistern 10 25
barracks 26 26
laboratory 26 14
clan_hall 16 26
army_camp 16 14
bomb_trap 15 23
bomb_trap 28 19
spring_pad 24 24
spring_pad 33 24
snare_trap 11 21
#line 9 19 34 19 gap 12,19 gap 29,19
#line 9 24 34 24 gap 12,24 gap 29,24
"""

LEVELS[7] = """
lantern_hall 20 20
arc_coil 18 18
lobber 27 17
lobber 14 24
boltpost 24 24
boltpost 14 16
boltpost 27 27
skyspear 24 18
cog_mine 7 8
cog_mine 34 7
cog_mine 7 34
cog_mine 34 34
sap_well 20 6
sap_well 20 36
cog_vault 28 21
cog_vault 11 20
sap_cistern 20 27
sap_cistern 20 13
barracks 6 20
laboratory 33 20
clan_hall 9 27
army_camp 28 9
army_camp 9 10
bomb_trap 23 26
bomb_trap 17 22
spring_pad 26 23
spring_pad 22 16
snare_trap 16 26
#rect 17 17 26 26 gap 17,21 gap 26,22
"""

LEVELS[8] = """
lantern_hall 20 20
arc_coil 18 24
lobber 25 27
lobber 13 20
boltpost 24 18
boltpost 18 18
boltpost 26 22
skyspear 20 10
cog_mine 6 30
cog_mine 9 34
cog_mine 33 33
cog_mine 36 29
cog_mine 36 7
sap_well 30 36
sap_well 4 26
cog_vault 14 26
cog_vault 28 13
cog_vault 29 25
sap_cistern 13 14
sap_cistern 21 26
sap_cistern 16 10
shard_drill 34 15
shard_crate 24 33
barracks 5 18
laboratory 32 20
clan_hall 4 9
spell_forge 23 13
army_camp 10 4
army_camp 26 3
army_camp 16 33
bomb_trap 23 25
bomb_trap 17 16
spring_pad 28 16
spring_pad 12 24
spring_pad 22 30
snare_trap 26 9
air_mine 21 17
#rect 17 17 26 26 gap 21,17 gap 26,24
#line 13 12 30 12 gap 21,12
#line 12 13 12 28 gap 12,20
"""

LEVELS[9] = """
lantern_hall 20 20
skyspear 20 18
skyspear 22 24
lobber 24 13
lobber 13 24
boltpost 18 22
boltpost 24 20
boltpost 28 28
arc_coil 14 14
ballista 27 21
cog_mine 4 4
cog_mine 8 4
cog_mine 36 4
cog_mine 36 36
cog_mine 4 36
sap_well 8 36
sap_well 32 36
sap_well 36 32
cog_vault 14 18
cog_vault 18 27
sap_cistern 27 16
sap_cistern 21 28
shard_drill 4 20
shard_crate 36 20
barracks 20 4
laboratory 20 36
clan_hall 9 9
spell_forge 30 8
army_camp 9 28
army_camp 29 30
army_camp 4 12
bomb_trap 17 25
bomb_trap 25 18
spring_pad 15 21
spring_pad 26 25
spring_pad 21 16
snare_trap 23 27
air_mine 19 26
#rect 17 17 26 26 gap 26,19 gap 18,26
#line 12 12 31 12 gap 22,12
#line 12 13 12 31 gap 12,22
#line 13 31 31 31 gap 22,31
"""

LEVELS[10] = """
lantern_hall 20 20
skyspear 18 18
skyspear 24 24
lobber 23 13
lobber 13 22
boltpost 24 18
boltpost 18 24
boltpost 28 26
arc_coil 20 18
ballista 27 19
cog_mine 3 3
cog_mine 7 3
cog_mine 37 3
cog_mine 37 37
cog_mine 3 37
cog_mine 7 37
sap_well 33 37
sap_well 37 33
sap_well 3 33
cog_vault 14 18
cog_vault 18 27
cog_vault 13 13
sap_cistern 27 14
sap_cistern 22 27
sap_cistern 28 28
shard_drill 37 19
shard_crate 3 19
barracks 19 3
laboratory 18 36
clan_hall 33 8
spell_forge 8 8
army_camp 8 26
army_camp 30 31
army_camp 26 3
bomb_trap 16 21
bomb_trap 26 22
spring_pad 22 16
spring_pad 21 26
spring_pad 15 15
snare_trap 29 23
air_mine 25 16
#rect 17 17 26 26 gap 22,17
#rect 12 12 31 31 gap 12,16 gap 31,27
"""

LEVELS[11] = """
lantern_hall 20 20
thumper 13 20
lobber 27 22
lobber 22 13
skyspear 18 18
skyspear 24 24
boltpost 24 18
boltpost 18 24
boltpost 28 14
boltpost 14 27
arc_coil 20 18
ballista 28 27
cog_mine 3 3
cog_mine 7 3
cog_mine 37 3
cog_mine 37 37
cog_mine 3 37
cog_mine 7 37
sap_well 33 37
sap_well 37 33
sap_well 3 33
sap_well 33 3
cog_vault 13 13
cog_vault 18 27
cog_vault 27 18
sap_cistern 14 24
sap_cistern 24 27
sap_cistern 22 28
shard_drill 37 19
shard_crate 3 19
barracks 19 3
laboratory 18 36
clan_hall 33 8
spell_forge 8 8
army_camp 8 26
army_camp 30 31
army_camp 26 3
bomb_trap 16 21
bomb_trap 26 21
bomb_trap 21 16
spring_pad 22 26
spring_pad 15 16
spring_pad 29 21
snare_trap 16 30
snare_trap 30 16
air_mine 25 16
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 11 11 32 32 gap 11,16 gap 32,27 gap 21,32
#line 11 21 12 21
#line 31 22 32 22
"""

LEVELS[12] = """
lantern_hall 20 20
thumper 27 27
lobber 13 13
lobber 27 13
lobber 13 27
skyspear 18 18
skyspear 24 24
boltpost 24 18
boltpost 18 24
boltpost 20 13
boltpost 13 21
arc_coil 22 24
arc_coil 24 20
ballista 29 20
cog_mine 3 3
cog_mine 7 3
cog_mine 37 3
cog_mine 37 37
cog_mine 3 37
cog_mine 7 37
sap_well 33 37
sap_well 37 33
sap_well 3 33
sap_well 33 3
cog_vault 17 13
cog_vault 13 17
cog_vault 21 28
sap_cistern 28 24
sap_cistern 24 13
sap_cistern 17 28
shard_drill 37 19
shard_crate 3 19
barracks 19 3
laboratory 18 36
clan_hall 33 8
spell_forge 8 8
army_camp 8 26
army_camp 30 31
army_camp 26 3
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
snare_trap 15 30
snare_trap 30 15
air_mine 25 16
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31
"""

LEVELS[13] = """
lantern_hall 20 30
thumper 15 30
lobber 26 26
lobber 13 26
lobber 20 26
skyspear 25 30
skyspear 24 34
boltpost 18 34
boltpost 10 30
boltpost 31 30
boltpost 28 34
arc_coil 22 35
arc_coil 14 35
ballista 29 26
cog_mine 3 3
cog_mine 7 3
cog_mine 11 3
cog_mine 15 3
cog_mine 19 3
cog_mine 23 3
sap_well 27 3
sap_well 31 3
sap_well 35 3
sap_well 39 3
sap_well 3 8
cog_vault 6 26
cog_vault 34 26
cog_vault 7 33
sap_cistern 34 33
sap_cistern 9 13
sap_cistern 29 13
shard_drill 3 20
shard_crate 39 20
barracks 15 12
laboratory 20 12
clan_hall 24 13
spell_forge 33 8
army_camp 6 18
army_camp 34 18
army_camp 19 18
bomb_trap 23 33
bomb_trap 17 29
bomb_trap 28 29
spring_pad 12 33
spring_pad 31 34
spring_pad 21 34
snare_trap 16 24
snare_trap 24 24
air_mine 20 29
#line 4 24 39 24 gap 15,24 gap 28,24
#rect 12 28 29 37 gap 20,28
#line 2 31 4 31
"""

LEVELS[14] = """
lantern_hall 20 20
thumper 27 27
frost_spire 20 18
lobber 13 13
lobber 27 13
lobber 13 27
skyspear 18 18
skyspear 24 24
skyspear 18 24
boltpost 24 18
boltpost 20 13
boltpost 13 21
boltpost 28 21
arc_coil 22 24
arc_coil 24 20
ballista 21 28
ballista 17 28
cog_mine 3 3
cog_mine 7 3
cog_mine 37 3
cog_mine 37 37
cog_mine 3 37
cog_mine 7 37
cog_mine 11 37
sap_well 33 37
sap_well 37 33
sap_well 3 33
sap_well 33 3
sap_well 29 3
sap_well 3 29
sap_well 37 29
cog_vault 17 13
cog_vault 13 17
cog_vault 24 13
cog_vault 28 24
sap_cistern 7 13
sap_cistern 33 13
sap_cistern 7 23
sap_cistern 33 23
shard_drill 19 37
shard_drill 23 37
shard_crate 3 19
barracks 19 3
laboratory 14 3
clan_hall 24 3
spell_forge 8 8
army_camp 8 28
army_camp 31 29
army_camp 30 7
army_camp 3 9
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
snare_trap 15 30
snare_trap 30 15
air_mine 25 16
air_mine 19 22
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31
#line 12 26 16 26
"""

LEVELS[15] = """
lantern_hall 20 20
thumper 26 28
frost_spire 18 24
lobber 13 13
lobber 28 13
lobber 13 28
skyspear 18 18
skyspear 24 24
skyspear 24 18
boltpost 20 13
boltpost 13 21
boltpost 28 21
boltpost 20 28
arc_coil 22 24
arc_coil 18 20
ballista 28 17
ballista 16 28
cog_mine 3 3
cog_mine 3 7
cog_mine 3 11
cog_mine 3 15
cog_mine 3 19
cog_mine 3 23
cog_mine 3 27
sap_well 39 3
sap_well 39 7
sap_well 39 11
sap_well 39 15
sap_well 39 19
sap_well 39 23
sap_well 39 27
cog_vault 7 35
cog_vault 34 35
cog_vault 7 3
cog_vault 34 3
sap_cistern 20 37
sap_cistern 20 3
sap_cistern 13 35
sap_cistern 27 35
shard_drill 9 9
shard_drill 33 9
shard_crate 9 29
barracks 15 4
laboratory 25 4
clan_hall 7 17
spell_forge 33 17
army_camp 8 22
army_camp 31 22
army_camp 31 28
army_camp 8 28
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
snare_trap 15 31
snare_trap 30 31
air_mine 25 16
air_mine 19 23
#rect 17 17 26 26 gap 22,17 gap 17,23 gap 26,21
#rect 12 12 31 32 gap 12,16 gap 31,27 gap 21,32
"""

# ------------------------- Hall 8: introduzione Cinder Spout, mine d'aria, tre Frost Spire (max 1 a Hall 8)
LEVELS[16] = """
lantern_hall 20 20
thumper 27 27
frost_spire 20 18
lobber 13 13
lobber 27 13
lobber 13 27
skyspear 18 18
skyspear 24 24
skyspear 18 24
boltpost 24 18
boltpost 20 13
boltpost 13 21
boltpost 28 21
boltpost 21 28
arc_coil 22 24
arc_coil 24 20
ballista 17 28
ballista 28 17
cog_mine 3 3
cog_mine 7 3
cog_mine 37 3
cog_mine 37 37
cog_mine 3 37
cog_mine 7 37
cog_mine 11 37
sap_well 33 37
sap_well 37 33
sap_well 3 33
sap_well 33 3
sap_well 29 3
sap_well 3 29
sap_well 37 29
cog_vault 17 13
cog_vault 13 17
cog_vault 24 13
cog_vault 28 24
sap_cistern 7 13
sap_cistern 33 13
sap_cistern 7 23
sap_cistern 33 23
shard_drill 19 37
shard_drill 23 37
shard_crate 3 19
shard_crate 39 19
barracks 19 3
laboratory 14 3
clan_hall 24 3
spell_forge 8 8
army_camp 8 28
army_camp 31 29
army_camp 30 7
army_camp 3 9
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
snare_trap 15 30
snare_trap 30 15
air_mine 25 16
air_mine 19 22
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31
#line 2 26 11 26
#line 32 26 41 26
#line 32 12 32 12
"""

LEVELS[17] = """
lantern_hall 20 20
cinder_spout 18 18
thumper 27 27
thumper 13 13
frost_spire 24 24
lobber 27 13
lobber 13 27
lobber 20 29
lobber 29 20
skyspear 24 18
skyspear 18 24
skyspear 20 14
arc_coil 22 24
arc_coil 24 20
arc_coil 14 20
boltpost 20 18
boltpost 18 20
boltpost 34 20
boltpost 20 34
boltpost 8 20
ballista 17 28
ballista 28 16
cog_mine 3 3
cog_mine 7 3
cog_mine 37 3
cog_mine 37 37
cog_mine 3 37
cog_mine 7 37
cog_mine 11 37
sap_well 33 37
sap_well 37 33
sap_well 3 33
sap_well 33 3
sap_well 29 3
sap_well 3 29
sap_well 37 29
cog_vault 7 13
cog_vault 33 13
cog_vault 7 25
cog_vault 33 25
sap_cistern 13 7
sap_cistern 25 7
sap_cistern 13 33
sap_cistern 25 33
shard_drill 19 38
shard_drill 19 2
shard_crate 3 19
shard_crate 39 19
barracks 18 7
laboratory 37 9
clan_hall 3 9
spell_forge 30 30
army_camp 8 29
army_camp 3 13
army_camp 37 13
army_camp 9 2
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
snare_trap 15 30
snare_trap 30 15
air_mine 25 16
air_mine 19 22
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31 gap 21,12
#line 32 21 33 21
"""

LEVELS[18] = """
lantern_hall 20 20
cinder_spout 24 24
thumper 13 27
thumper 27 13
frost_spire 18 18
lobber 13 13
lobber 27 27
lobber 20 29
lobber 29 20
skyspear 24 18
skyspear 18 24
skyspear 14 20
arc_coil 22 24
arc_coil 24 20
arc_coil 20 14
boltpost 20 18
boltpost 18 20
boltpost 34 20
boltpost 20 34
boltpost 8 20
ballista 6 6
ballista 33 33
cog_mine 3 37
cog_mine 7 37
cog_mine 11 37
cog_mine 37 3
cog_mine 37 7
cog_mine 33 3
cog_mine 29 3
sap_well 3 3
sap_well 7 3
sap_well 3 7
sap_well 11 3
sap_well 37 37
sap_well 33 39
sap_well 39 29
cog_vault 7 13
cog_vault 33 13
cog_vault 7 25
cog_vault 33 25
sap_cistern 13 7
sap_cistern 25 7
sap_cistern 13 33
sap_cistern 25 33
shard_drill 19 38
shard_drill 19 2
shard_crate 3 19
shard_crate 39 19
barracks 18 7
laboratory 37 9
clan_hall 3 9
spell_forge 29 36
army_camp 8 29
army_camp 3 13
army_camp 37 14
army_camp 2 31
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
snare_trap 15 30
snare_trap 30 15
air_mine 25 16
air_mine 19 22
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31 gap 21,12
#line 32 21 33 21
"""

LEVELS[19] = """
lantern_hall 20 20
cinder_spout 24 24
thumper 13 27
thumper 27 13
frost_spire 18 18
frost_spire 24 18
lobber 13 13
lobber 27 27
lobber 20 29
lobber 29 20
skyspear 18 24
skyspear 14 20
skyspear 20 14
arc_coil 22 24
arc_coil 20 18
arc_coil 34 20
boltpost 18 20
boltpost 24 20
boltpost 20 34
boltpost 8 20
boltpost 20 8
ballista 6 6
ballista 33 33
cog_mine 3 37
cog_mine 7 37
cog_mine 11 37
cog_mine 37 3
cog_mine 37 7
cog_mine 33 3
cog_mine 29 3
sap_well 3 3
sap_well 7 3
sap_well 3 7
sap_well 11 3
sap_well 37 37
sap_well 33 39
sap_well 39 29
cog_vault 7 13
cog_vault 33 13
cog_vault 7 25
cog_vault 33 25
sap_cistern 13 7
sap_cistern 25 7
sap_cistern 13 33
sap_cistern 25 33
shard_drill 19 38
shard_drill 15 2
shard_drill 25 38
shard_crate 3 19
shard_crate 39 19
barracks 29 36
laboratory 37 9
clan_hall 3 9
spell_forge 8 30
army_camp 3 13
army_camp 37 14
army_camp 2 31
army_camp 23 2
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
spring_pad 26 26
snare_trap 15 30
snare_trap 30 15
snare_trap 10 10
air_mine 25 16
air_mine 19 22
air_mine 10 33
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31 gap 21,12
#line 32 21 33 21
#line 2 17 5 17
"""

LEVELS[20] = """
lantern_hall 20 20
storm_pylon 20 13
cinder_spout 24 24
thumper 13 27
thumper 27 13
frost_spire 18 18
frost_spire 24 18
lobber 13 13
lobber 27 27
lobber 20 29
lobber 29 20
skyspear 18 24
skyspear 14 20
skyspear 34 20
skyspear 20 34
arc_coil 22 24
arc_coil 20 18
arc_coil 8 20
boltpost 18 20
boltpost 24 20
boltpost 20 8
boltpost 4 20
boltpost 38 20
ballista 6 6
ballista 33 33
ballista 6 33
cog_mine 7 37
cog_mine 11 37
cog_mine 37 3
cog_mine 37 7
cog_mine 33 3
cog_mine 29 3
cog_mine 15 38
sap_well 3 3
sap_well 7 3
sap_well 3 7
sap_well 11 3
sap_well 37 37
sap_well 33 39
sap_well 39 29
cog_vault 7 13
cog_vault 33 13
cog_vault 7 25
cog_vault 33 25
sap_cistern 13 7
sap_cistern 25 7
sap_cistern 13 33
sap_cistern 25 33
shard_drill 19 38
shard_drill 15 2
shard_drill 25 38
shard_crate 3 18
shard_crate 39 16
barracks 29 36
laboratory 37 9
clan_hall 2 9
spell_forge 2 28
army_camp 3 13
army_camp 37 24
army_camp 23 2
army_camp 9 39
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
spring_pad 26 26
snare_trap 15 30
snare_trap 30 15
snare_trap 10 10
air_mine 25 16
air_mine 19 22
air_mine 10 31
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31 gap 21,12
#line 32 22 33 22
#line 2 23 6 23
#line 37 22 41 22
#line 17 2 21 2
"""

LEVELS[21] = """
lantern_hall 20 20
storm_pylon 20 13
cinder_spout 18 18
thumper 27 27
thumper 13 13
frost_spire 24 24
frost_spire 18 24
lobber 27 13
lobber 13 27
lobber 20 29
lobber 29 20
skyspear 24 18
skyspear 14 20
skyspear 34 20
skyspear 20 34
arc_coil 22 24
arc_coil 20 18
arc_coil 8 20
boltpost 18 20
boltpost 24 20
boltpost 20 8
boltpost 4 20
boltpost 38 20
ballista 6 6
ballista 33 33
ballista 6 33
cog_mine 7 37
cog_mine 11 37
cog_mine 37 3
cog_mine 37 7
cog_mine 33 3
cog_mine 29 3
cog_mine 15 38
sap_well 3 3
sap_well 7 3
sap_well 3 7
sap_well 11 3
sap_well 37 37
sap_well 33 39
sap_well 39 29
cog_vault 7 13
cog_vault 33 13
cog_vault 7 25
cog_vault 33 25
sap_cistern 13 7
sap_cistern 25 7
sap_cistern 13 33
sap_cistern 25 33
shard_drill 19 38
shard_drill 15 2
shard_drill 25 38
shard_crate 3 18
shard_crate 39 16
barracks 29 36
laboratory 37 9
clan_hall 2 9
spell_forge 2 28
army_camp 3 13
army_camp 37 24
army_camp 23 2
army_camp 9 39
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
spring_pad 26 26
snare_trap 15 30
snare_trap 30 15
snare_trap 10 10
air_mine 25 16
air_mine 19 22
air_mine 10 31
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31 gap 21,12
#line 13 21 16 21
#line 27 22 30 22
#line 21 13 21 16
#line 22 27 22 30
"""

LEVELS[22] = """
lantern_hall 20 20
storm_pylon 13 13
cinder_spout 18 18
thumper 27 27
thumper 13 27
frost_spire 24 24
frost_spire 18 24
lobber 27 13
lobber 20 29
lobber 29 20
lobber 20 13
skyspear 24 18
skyspear 14 20
skyspear 34 20
arc_coil 22 24
arc_coil 20 18
arc_coil 8 20
boltpost 18 20
boltpost 24 20
boltpost 20 8
boltpost 4 20
boltpost 38 20
boltpost 20 34
ballista 6 6
ballista 33 33
cog_mine 7 37
cog_mine 11 37
cog_mine 37 3
cog_mine 37 7
cog_mine 33 3
cog_mine 29 3
cog_mine 15 38
cog_mine 3 33
sap_well 3 3
sap_well 7 3
sap_well 3 7
sap_well 11 3
sap_well 37 37
sap_well 33 39
sap_well 39 29
sap_well 39 33
cog_vault 7 13
cog_vault 33 13
cog_vault 7 25
cog_vault 33 25
sap_cistern 13 7
sap_cistern 25 7
sap_cistern 13 33
sap_cistern 25 33
shard_drill 19 38
shard_drill 15 2
shard_drill 25 38
shard_crate 3 18
shard_crate 39 16
barracks 29 36
laboratory 37 9
clan_hall 2 9
spell_forge 2 28
army_camp 3 13
army_camp 37 24
army_camp 23 2
army_camp 8 38
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
spring_pad 26 26
snare_trap 15 30
snare_trap 30 15
snare_trap 10 10
air_mine 25 16
air_mine 19 22
air_mine 10 31
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31 gap 21,12
#rect 2 17 9 26 gap 9,21
#rect 34 17 41 26 gap 34,22
"""

LEVELS[23] = """
lantern_hall 20 20
storm_pylon 13 13
cinder_spout 18 18
cinder_spout 24 24
thumper 27 27
thumper 13 27
frost_spire 24 18
frost_spire 18 24
lobber 27 13
lobber 20 29
lobber 29 20
lobber 20 13
skyspear 14 20
skyspear 34 20
skyspear 20 34
skyspear 20 8
arc_coil 22 24
arc_coil 20 18
arc_coil 8 20
boltpost 18 20
boltpost 24 20
boltpost 4 20
boltpost 38 20
boltpost 28 9
boltpost 9 28
ballista 6 6
ballista 33 33
ballista 33 6
cog_mine 7 37
cog_mine 11 37
cog_mine 37 3
cog_mine 37 7
cog_mine 29 3
cog_mine 15 38
cog_mine 3 33
cog_mine 3 37
sap_well 3 3
sap_well 7 3
sap_well 3 7
sap_well 11 3
sap_well 37 37
sap_well 33 39
sap_well 39 29
sap_well 39 33
cog_vault 7 13
cog_vault 33 13
cog_vault 7 24
cog_vault 33 24
sap_cistern 13 6
sap_cistern 24 6
sap_cistern 13 33
sap_cistern 24 33
shard_drill 19 38
shard_drill 15 2
shard_drill 28 38
shard_crate 3 17
shard_crate 39 16
barracks 29 35
laboratory 37 10
clan_hall 2 9
spell_forge 2 28
army_camp 3 12
army_camp 37 25
army_camp 22 2
army_camp 8 38
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
spring_pad 26 26
snare_trap 15 30
snare_trap 30 15
snare_trap 10 10
air_mine 25 16
air_mine 19 22
air_mine 10 31
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31 gap 21,12
#rect 2 17 9 26 gap 9,21
#rect 34 17 41 26 gap 34,22
"""

LEVELS[24] = """
lantern_hall 20 20
storm_pylon 13 13
storm_pylon 28 28
cinder_spout 18 18
cinder_spout 24 24
thumper 27 13
thumper 13 27
frost_spire 24 18
frost_spire 18 24
lobber 20 29
lobber 29 20
lobber 20 13
lobber 13 20
skyspear 34 20
skyspear 20 34
skyspear 20 8
skyspear 6 20
arc_coil 22 24
arc_coil 20 18
arc_coil 24 20
boltpost 18 20
boltpost 4 20
boltpost 38 20
boltpost 28 9
boltpost 9 28
boltpost 20 38
ballista 6 6
ballista 34 34
ballista 33 6
cog_mine 7 37
cog_mine 11 37
cog_mine 37 3
cog_mine 37 7
cog_mine 29 3
cog_mine 15 38
cog_mine 3 33
cog_mine 3 37
sap_well 3 3
sap_well 7 3
sap_well 3 7
sap_well 11 3
sap_well 37 38
sap_well 33 39
sap_well 39 29
sap_well 39 33
cog_vault 7 13
cog_vault 33 13
cog_vault 7 24
cog_vault 33 24
sap_cistern 13 5
sap_cistern 24 5
sap_cistern 13 33
sap_cistern 24 33
shard_drill 15 2
shard_drill 28 38
shard_drill 24 38
shard_crate 3 17
shard_crate 39 16
barracks 29 34
laboratory 37 10
clan_hall 2 9
spell_forge 2 28
army_camp 3 12
army_camp 37 25
army_camp 20 2
army_camp 8 38
bomb_trap 16 22
bomb_trap 26 21
bomb_trap 21 16
bomb_trap 15 25
spring_pad 22 26
spring_pad 16 16
spring_pad 27 17
spring_pad 16 26
spring_pad 26 26
snare_trap 15 30
snare_trap 30 15
snare_trap 10 10
air_mine 25 16
air_mine 19 22
air_mine 10 31
#rect 17 17 26 26 gap 22,17 gap 17,23
#rect 12 12 31 31 gap 12,16 gap 31,27 gap 21,31 gap 21,12
#rect 2 17 9 26 gap 9,21
#rect 34 17 41 26 gap 34,22
"""

LEVELS[25] = LEVELS[24].replace("storm_pylon 28 28", "storm_pylon 28 27").replace("#rect 2 17 9 26 gap 9,21", "#rect 2 17 9 26").replace("#rect 34 17 41 26 gap 34,22", "#rect 34 17 41 26")


def parse(text, n):
    items, walls = [], []
    for raw in text.strip().splitlines():
        line = raw.strip()
        if not line:
            continue
        parts = line.split()
        if parts[0] in ("#rect", "#line"):
            x0, y0, x1, y1 = map(int, parts[1:5])
            gaps = set()
            if "gap" in parts:
                for tok in parts[parts.index("gap"):]:
                    if tok == "gap":
                        continue
                    gx, gy = map(int, tok.split(","))
                    gaps.add((gx, gy))
            cells = []
            if parts[0] == "#rect":
                for x in range(x0, x1 + 1):
                    cells += [(x, y0), (x, y1)]
                for y in range(y0 + 1, y1):
                    cells += [(x0, y), (x1, y)]
            else:
                if x0 == x1:
                    cells = [(x0, y) for y in range(min(y0, y1), max(y0, y1) + 1)]
                elif y0 == y1:
                    cells = [(x, y0) for x in range(min(x0, x1), max(x0, x1) + 1)]
                else:
                    raise ValueError(f"livello {n}: linea non orizzontale/verticale: {line}")
            for c in cells:
                if c not in gaps:
                    walls.append(c)
        else:
            items.append((parts[0], int(parts[1]), int(parts[2])))
    return items, walls


def main():
    camp = json.load(open(os.path.join(DATA, "campaign.json")))
    unlocks = json.load(open(os.path.join(DATA, "hall_unlocks.json")))
    footprint = {"lantern_hall": 4}
    b = json.load(open(os.path.join(DATA, "buildings.json")))
    footprint.update(b["footprints"])
    d = json.load(open(os.path.join(DATA, "defenses.json")))
    for r in d["levels"]:
        footprint[r["id"]] = r["size"]
    t = json.load(open(os.path.join(DATA, "traps.json")))
    for r in t["levels"]:
        footprint[r["id"]] = r["size"]
    order = d["order"]
    out = {}
    errors = []
    for n in range(1, 26):
        lv = camp[n - 1]
        hall = lv["hall_level"]
        items, walls = parse(LEVELS[n], n)
        # priorita': mura (scheletro del progetto) e Hall restano fisse; gli altri edifici, se collidono,
        # vengono spostati alla cella libera piu' vicina (spirale), mantenendo l'intento del disegno.
        wallset = []
        for c in walls:
            if c[0] < 2 or c[1] < 2 or c[0] > 41 or c[1] > 41:
                errors.append(f"L{n}: muro fuori area {c}")
            elif c not in wallset:
                wallset.append(c)
        prio = {"lantern_hall": 0}
        for k in order:
            prio[k] = 1
        for k in ("cog_vault", "sap_cistern", "shard_crate"):
            prio[k] = 2
        for k in ("bomb_trap", "spring_pad", "snare_trap", "air_mine"):
            prio[k] = 4
        items_sorted = sorted(enumerate(items), key=lambda e: (prio.get(e[1][0], 3), e[0]))
        occ = {}
        wallcells = set(wallset)
        counts = {}
        placed = []
        moved = 0

        def free(f, x, y):
            if x < 2 or y < 2 or x + f - 1 > 41 or y + f - 1 > 41:
                return False
            for dx in range(f):
                for dy in range(f):
                    if (x + dx, y + dy) in occ or (x + dx, y + dy) in wallcells:
                        return False
            return True
        for _, (bid, x, y) in items_sorted:
            if bid not in footprint:
                errors.append(f"L{n}: id sconosciuto {bid}")
                continue
            f = footprint[bid]
            if bid == "lantern_hall":
                # la Hall ha precedenza anche sulle mura: rimuove i muri sovrapposti
                for dx in range(f):
                    for dy in range(f):
                        wallcells.discard((x + dx, y + dy))
            if not free(f, x, y):
                found = None
                for r in range(1, 9):
                    for dx in range(-r, r + 1):
                        for dy in range(-r, r + 1):
                            if max(abs(dx), abs(dy)) == r and found is None and free(f, x + dx, y + dy):
                                found = (x + dx, y + dy)
                if found is None:
                    errors.append(f"L{n}: nessuna posizione libera per {bid} vicino a {x},{y}")
                    continue
                x, y = found
                moved += 1
            for dx in range(f):
                for dy in range(f):
                    occ[(x + dx, y + dy)] = f"{bid}@{x},{y}"
            counts[bid] = counts.get(bid, 0) + 1
            placed.append((bid, x, y))
        items = placed
        uniq_walls = [c for c in wallset if c in wallcells]
        hrow = unlocks[hall - 1]
        for bid, c in counts.items():
            allowed = 1 if bid == "lantern_hall" else hrow.get(bid, 0)
            if c > allowed:
                errors.append(f"L{n}: {bid} x{c} > consentiti {allowed} a Hall {hall}")
        for k in order:
            if counts.get(k, 0) != lv[k]:
                errors.append(f"L{n}: {k} = {counts.get(k, 0)}, attesi {lv[k]}")
        if counts.get("lantern_hall", 0) != 1:
            errors.append(f"L{n}: serve esattamente un lantern_hall")
        if len(uniq_walls) > lv["walls"]:
            errors.append(f"L{n}: mura {len(uniq_walls)} > tetto {lv['walls']}")
        out[str(n)] = {"buildings": [{"id": i, "x": x, "y": y} for (i, x, y) in items] + [{"id": "wall", "x": x, "y": y} for (x, y) in uniq_walls],
                       "walls": len(uniq_walls), "counts": counts}
        print(f"L{n:2d} Hall {hall:2d}: edifici {len(items):3d}  mura {len(uniq_walls):3d}/{lv['walls']}  spostati {moved}")
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    with open(os.path.join(DATA, "campaign_layouts.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
    print("OK -> data/campaign_layouts.json")


if __name__ == "__main__":
    main()
