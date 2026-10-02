#!/usr/bin/env python3
"""Generatore delle tabelle di bilanciamento di Lanternreach.

Unica fonte di verita' dei numeri: produce
  data/*.json          (letti dal gioco, nessun numero hardcoded nel codice GDScript)
  data/csv/*.csv       (stesse tabelle, per revisione/foglio di calcolo)
  docs/BALANCE_TABLES.md  (tabelle complete leggibili)
  docs/BALANCE_REPORT.md  (verifica: tempi/costi per livello dell'Edificio Centrale)

Uso:  python3 tools/gen_balance.py
Tutte le formule sono deterministiche; gli arrotondamenti usano nice().
"""
import csv
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
CSV_DIR = os.path.join(DATA, "csv")
DOCS = os.path.join(ROOT, "docs")
for d in (DATA, CSV_DIR, DOCS):
    os.makedirs(d, exist_ok=True)

HALL_MAX = 10
MAX_TIME = 3 * 86400            # tetto assoluto: 3 giorni
MIN_TIME = 10                   # pavimento: 10 secondi
# Curva-tempo "tier" (secondi) per livello 1..10, poi scalata per edificio.
TIER_TIME = [10, 60, 600, 3600, 14400, 43200, 86400, 129600, 172800, 259200]


# ----------------------------------------------------------------- utilita'
def nice(x):
    """Arrotonda a 3 cifre significative (interi sotto 100)."""
    x = float(x)
    if x < 100:
        return int(round(x))
    p = 10 ** (int(math.floor(math.log10(x))) + 1 - 3)
    return int(round(x / p) * p)


def fmt_time(s):
    s = int(s)
    if s <= 0:
        return "0s"
    d, r = divmod(s, 86400)
    h, r = divmod(r, 3600)
    m, sec = divmod(r, 60)
    parts = []
    if d: parts.append(f"{d}g")
    if h: parts.append(f"{h}h")
    if m: parts.append(f"{m}m")
    if sec and not d: parts.append(f"{sec}s")
    return " ".join(parts)


def fmt_num(n):
    return f"{int(n):,}".replace(",", ".")


def geo(first, last, levels, level):
    """Interpolazione geometrica first(L1) -> last(Lultimo)."""
    if levels == 1:
        return first
    g = (last / first) ** (1.0 / (levels - 1))
    return first * g ** (level - 1)


def req_hall(unlock, levels, level):
    """Livello minimo di Edificio Centrale per costruire/portare a `level`."""
    if levels == 1:
        return unlock
    return min(HALL_MAX, unlock + (level - 1) * (HALL_MAX - unlock + 1) // levels)


def upgrade_time(scale, level):
    t = TIER_TIME[level - 1] * scale
    return int(min(MAX_TIME, max(MIN_TIME, nice(t) if t >= 100 else round(t))))


def xp_for(time_s):
    return max(1, int(math.isqrt(int(time_s))))


def write_json(name, obj):
    with open(os.path.join(DATA, name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")


def write_csv(name, rows):
    if not rows:
        return
    keys = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    with open(os.path.join(CSV_DIR, name), "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)


def md_table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out) + "\n"


# ------------------------------------------------- edificio centrale (Hall)
# Lanternhall ("Faro Madre"): 4x4, 10 livelli, ID: lantern_hall
# Costi del Faro Madre: ogni potenziamento <= 80% della capacita' Cogs raggiungibile al livello precedente (verificato sotto).
HALL_COST = [0, 1000, 3000, 15000, 40000, 150000, 320000, 850000, 1500000, 2600000]  # in Cogs
HALL_TIME = [0, 300, 3600, 14400, 43200, 86400, 129600, 172800, 216000, 259200]
HALL_CAP = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]  # solo per leggibilita'

# ---------------------------------------------- conteggi per livello Hall
# counts[h-1] = quante copie sono permesse con Hall livello h.
COUNTS = {
    "cog_mine":     [2, 3, 4, 5, 6, 6, 7, 7, 7, 8],
    "sap_well":     [2, 3, 4, 5, 6, 6, 7, 7, 7, 8],
    "shard_drill":  [0, 0, 0, 0, 1, 1, 2, 2, 3, 3],
    "cog_vault":    [1, 1, 2, 2, 3, 3, 4, 4, 4, 4],
    "sap_cistern":  [1, 1, 2, 2, 3, 3, 4, 4, 4, 4],
    "shard_crate":  [0, 0, 0, 0, 1, 1, 1, 2, 2, 2],
    "barracks":     [1] * 10,
    "army_camp":    [1, 1, 2, 2, 3, 3, 4, 4, 4, 4],
    "laboratory":   [0, 0, 1, 1, 1, 1, 1, 1, 1, 1],
    "spell_forge":  [0, 0, 0, 0, 1, 1, 1, 1, 1, 1],
    "clan_hall":    [0, 0, 0, 1, 1, 1, 1, 1, 1, 1],
    # difese
    "boltpost":     [1, 2, 2, 3, 3, 4, 4, 5, 5, 6],
    "lobber":       [0, 1, 1, 2, 2, 3, 3, 4, 4, 4],
    "skyspear":     [0, 0, 1, 1, 2, 2, 3, 3, 4, 4],
    "arc_coil":     [0, 0, 0, 1, 1, 2, 2, 3, 3, 3],
    "ballista":     [0, 0, 0, 0, 1, 1, 2, 2, 3, 3],
    "thumper":      [0, 0, 0, 0, 0, 1, 1, 2, 2, 2],
    "frost_spire":  [0, 0, 0, 0, 0, 0, 1, 1, 2, 2],
    "cinder_spout": [0, 0, 0, 0, 0, 0, 0, 1, 1, 2],
    "storm_pylon":  [0, 0, 0, 0, 0, 0, 0, 0, 1, 2],
    # mura (segmenti)
    "wall":         [25, 50, 75, 100, 125, 150, 175, 200, 225, 250],
    # trappole
    "bomb_trap":    [0, 1, 1, 2, 2, 3, 3, 4, 4, 4],
    "spring_pad":   [0, 0, 2, 2, 3, 3, 4, 4, 5, 5],
    "snare_trap":   [0, 0, 0, 1, 1, 2, 2, 2, 3, 3],
    "air_mine":     [0, 0, 0, 0, 1, 1, 2, 2, 3, 3],
}
# Costo in Starshards (risorsa rara C) aggiuntivo ai livelli alti delle difese.
DEF_SHARDS = {8: 800, 9: 2000, 10: 4500}

# --------------------------------------------------------- edifici (non difesa)
# id, categoria, lato (footprint NxN), unlock_hall, livelli, risorsa costo,
# (costo L1, costo ultimo livello), scala tempo, (hp L1, hp ultimo)
BUILDINGS = [
    dict(id="cog_mine",    cat="economy", size=2, unlock=1, levels=10, res="sap",  cost=(120, 262000),  ts=0.35, hp=(250, 1100)),
    dict(id="sap_well",    cat="economy", size=2, unlock=1, levels=10, res="cogs", cost=(120, 262000),  ts=0.35, hp=(250, 1100)),
    dict(id="shard_drill", cat="economy", size=2, unlock=5, levels=6,  res="sap",  cost=(20000, 700000), ts=0.70, hp=(400, 1200)),
    dict(id="cog_vault",   cat="storage", size=3, unlock=1, levels=10, res="sap",  cost=(200, 600000),  ts=0.45, hp=(500, 2400)),
    dict(id="sap_cistern", cat="storage", size=3, unlock=1, levels=10, res="cogs", cost=(200, 600000),  ts=0.45, hp=(500, 2400)),
    dict(id="shard_crate", cat="storage", size=2, unlock=5, levels=6,  res="cogs", cost=(30000, 500000), ts=0.60, hp=(500, 1800)),
    dict(id="barracks",    cat="military", size=3, unlock=1, levels=10, res="sap", cost=(150, 500000),  ts=0.60, hp=(450, 2000)),
    dict(id="army_camp",   cat="military", size=4, unlock=1, levels=8,  res="sap", cost=(250, 400000),  ts=0.40, hp=(400, 1100)),
    dict(id="laboratory",  cat="military", size=4, unlock=3, levels=8,  res="sap", cost=(5000, 2500000), ts=0.90, hp=(600, 2000)),
    dict(id="spell_forge", cat="military", size=3, unlock=5, levels=5,  res="sap", cost=(40000, 1500000), ts=0.80, hp=(550, 1500)),
    dict(id="clan_hall",   cat="social",  size=4, unlock=4, levels=5,  res="cogs", cost=(15000, 800000), ts=0.50, hp=(600, 1600)),
]
PROD_FIRST, PROD_GROWTH, MINE_CAP_HOURS = 200, 1.38, 8        # cog_mine / sap_well
DRILL_FIRST, DRILL_GROWTH, DRILL_CAP_HOURS = 25, 1.45, 8      # shard_drill
# Capacita' per deposito Cogs/Sap per livello: dimensionata perche' ogni costo disponibile a una Hall stia nei depositi.
VAULT_CAPS = [1500, 3500, 9000, 25000, 60000, 130000, 260000, 480000, 800000, 1200000]
CRATE_CAP = (1000, 18_000)          # capacita' shard_crate (L1 -> L6)
CAMP_CAP = [20, 25, 30, 35, 40, 45, 50, 55]
LAB_CAP_NOTE = "livello laboratorio = livello massimo di ricerca truppe"
FORGE_SLOTS = [2, 3, 4, 5, 6]       # slot incantesimo per livello Spell Forge (2 spazi ciascuno)
CLAN_HALL_SLOTS = [5, 10, 15, 20, 25]  # membri simulati supportati / richieste donazione

DEFENSES = [
    # dps = danno al secondo L1; damage/shot = dps*interval
    dict(id="boltpost",     size=2, unlock=1, targets="ground+air", dps=12, interval=0.6, rmin=0, rmax=8,  splash=0,   hp=(380, 1700),  cost=(250, 900000),     res="cogs", ts=0.5, prio="nearest",     role="single_target"),
    dict(id="lobber",       size=3, unlock=2, targets="ground",     dps=8,  interval=3.5, rmin=3, rmax=11, splash=1.6, hp=(400, 1800),  cost=(800, 1200000),    res="cogs", ts=0.5, prio="highest_hp_cluster", role="area"),
    dict(id="skyspear",     size=2, unlock=3, targets="air",        dps=22, interval=0.8, rmin=0, rmax=10, splash=0,   hp=(360, 1600),  cost=(500, 1100000),    res="cogs", ts=0.5, prio="nearest_air", role="anti_air"),
    dict(id="arc_coil",     size=2, unlock=4, targets="ground",     dps=30, interval=1.0, rmin=0, rmax=7,  splash=0,   hp=(520, 2300),  cost=(3000, 1600000),   res="cogs", ts=0.6, prio="lowest_hp",   role="chain_3_targets"),
    dict(id="ballista",     size=3, unlock=5, targets="ground+air", dps=16, interval=1.2, rmin=2, rmax=14, splash=0,   hp=(700, 3100),  cost=(8000, 2000000),   res="cogs", ts=0.7, prio="farthest_in_range", role="long_range"),
    dict(id="thumper",      size=3, unlock=6, targets="ground",     dps=45, interval=3.5, rmin=0, rmax=6,  splash=0,   hp=(900, 3900),  cost=(20000, 2400000),  res="cogs", ts=0.8, prio="highest_hp",  role="slow_high_damage"),
    dict(id="frost_spire",  size=2, unlock=7, targets="ground+air", dps=9,  interval=1.0, rmin=0, rmax=6,  splash=2.5, hp=(600, 2600),  cost=(40000, 2500000),  res="cogs", ts=0.8, prio="nearest",     role="slow_area"),
    dict(id="cinder_spout", size=2, unlock=8, targets="ground",     dps=95, interval=0.2, rmin=0, rmax=4,  splash=0,   hp=(800, 3500),  cost=(80000, 3000000),  res="cogs", ts=0.9, prio="nearest",     role="short_range_burst"),
    dict(id="storm_pylon",  size=3, unlock=9, targets="air",        dps=40, interval=1.2, rmin=0, rmax=11, splash=2.0, hp=(900, 3900),  cost=(150000, 3500000), res="cogs", ts=1.0, prio="nearest_air_cluster", role="anti_air_area"),
]
DEF_DPS_GROWTH = 1.17
FROST_SLOW = [0.30, 0.33, 0.36, 0.39, 0.42, 0.45, 0.47, 0.49, 0.50, 0.50]  # frazione riduzione velocita'
FROST_SLOW_TIME = 2.0

WALL = dict(id="wall", size=1, unlock=1, levels=10, res="cogs", cost=(50, 60000), ts=0.30, hp=(300, 3200))

TRAPS = [
    dict(id="bomb_trap",  size=1, unlock=2, levels=5, res="cogs", cost=(400, 40000),  ts=0.25, trigger=1.5, radius=1.5, dmg=(60, 200),  targets="ground", effect="area_damage"),
    dict(id="spring_pad", size=1, unlock=3, levels=5, res="cogs", cost=(500, 60000),  ts=0.25, trigger=1.0, radius=0.8, dmg=(0, 0),     targets="ground", effect="launch_troops_up_to_space", space=(12, 24)),
    dict(id="snare_trap", size=2, unlock=4, levels=5, res="cogs", cost=(2000, 150000), ts=0.30, trigger=2.0, radius=3.5, dmg=(0, 0),    targets="ground", effect="freeze_seconds", freeze=(3.0, 5.0)),
    dict(id="air_mine",   size=1, unlock=5, levels=5, res="cogs", cost=(3000, 200000), ts=0.30, trigger=2.0, radius=2.5, dmg=(250, 1000), targets="air",    effect="air_burst"),
]
TRAP_REARM_FRACTION = 0.20   # costo di riarmo = 20% del costo del livello corrente, in Cogs

# -------------------------------------------------------------------- truppe
# dps: danno/s L1. growth hp 1.13, dps 1.14, costo 1.30 per livello.
TROOPS = [
    dict(id="cogling",   role="melee_basic",   size=1,  hp=45,   dps=11, speed=2.0, range=0.6, flying=False, targets="ground", pref="any",        cost=25,   res="sap",    train=10,   barracks=1,  levels=8, special=""),
    dict(id="slingwisp", role="ranged",        size=1,  hp=33,   dps=14, speed=2.2, range=5.0, flying=False, targets="ground+air", pref="any",     cost=45,   res="sap",    train=15,   barracks=2,  levels=8, special=""),
    dict(id="bulwark",   role="tank",          size=5,  hp=420,  dps=18, speed=1.4, range=0.8, flying=False, targets="ground", pref="defenses",   cost=250,  res="sap",    train=90,   barracks=3,  levels=8, special="taunt_radius_3"),
    dict(id="magpie",    role="looter",        size=1,  hp=28,   dps=17, speed=3.4, range=0.6, flying=False, targets="ground", pref="resources",  cost=60,   res="sap",    train=14,   barracks=4,  levels=8, special="x2_damage_vs_resource_buildings"),
    dict(id="kegger",    role="wall_breaker",  size=2,  hp=22,   dps=0,  speed=2.6, range=0.5, flying=False, targets="ground", pref="walls",      cost=120,  res="sap",    train=30,   barracks=5,  levels=8, special="suicide_blast_60_x40_vs_walls_radius_1.2"),
    dict(id="rustjaw",   role="anti_defense",  size=4,  hp=270,  dps=36, speed=3.0, range=0.8, flying=False, targets="ground", pref="defenses",   cost=300,  res="sap",    train=120,  barracks=6,  levels=8, special="hops_over_walls;x1.5_damage_vs_defenses"),
    dict(id="kitewing",  role="flyer",         size=2,  hp=95,   dps=26, speed=3.2, range=0.8, flying=True,  targets="ground", pref="any",        cost=180,  res="sap",    train=45,   barracks=7,  levels=8, special=""),
    dict(id="mender",    role="healer",        size=8,  hp=520,  dps=0,  speed=2.0, range=0.0, flying=True,  targets="none",   pref="allies",     cost=800,  res="sap",    train=300,  barracks=8,  levels=8, special="heal_per_s=48;heal_radius=3;heals_ground_only"),
    dict(id="dirigible", role="heavy_flyer",   size=10, hp=1900, dps=34, speed=1.1, range=1.0, flying=True,  targets="ground", pref="defenses",   cost=2800, res="sap",    train=480,  barracks=9,  levels=8, special="splash_radius_1.5"),
    dict(id="ember_warden", role="elite",      size=20, hp=3600, dps=95, speed=1.6, range=0.9, flying=False, targets="ground", pref="defenses",   cost=45,   res="shards", train=1800, barracks=10, levels=6, special="lantern_surge:at_50pct_hp_+50pct_dps_and_heal_25pct_over_4s_once"),
]
TROOP_HP_G, TROOP_DPS_G, TROOP_COST_G = 1.13, 1.14, 1.30
# Ricerca: costo base per livello di destinazione (Sap) x fattore della truppa; il livello L richiede Lab L (Hall L+2).
RESEARCH_BASE = {2: 10000, 3: 30000, 4: 80000, 5: 200000, 6: 400000, 7: 750000, 8: 1200000}
RESEARCH_FACTOR = {"cogling": 0.6, "slingwisp": 0.7, "magpie": 0.75, "kegger": 0.8, "bulwark": 0.9, "kitewing": 1.0, "rustjaw": 1.0, "mender": 1.15, "dirigible": 1.3}
MENDER_HEAL = 48

SPELLS = [
    dict(id="mending_mist",  size=2, radius=5.0, duration=8.0, cost=4000, res="sap", train=180, levels=5, effect="heal_per_s", value=28, growth=1.20),
    dict(id="fervor_surge",  size=2, radius=4.0, duration=6.0, cost=6500, res="sap", train=240, levels=5, effect="dmg_and_speed", value=0.30, speed=0.25, value_last=0.50, speed_last=0.40),
]

# ---------------------------------------------------------- progressione
LEAGUES = [
    ("wick", 0, 299), ("spark", 300, 599), ("ember", 600, 999), ("flame", 1000, 1399),
    ("blaze", 1400, 1799), ("beacon", 1800, 2399), ("lighthouse", 2400, 3199), ("sunforge", 3200, 99999),
]
LEAGUE_REWARD_GEMS = [0, 5, 10, 20, 30, 50, 80, 120]  # una tantum alla prima volta che si entra
LEAGUE_LOOT_BONUS = [0.00, 0.00, 0.05, 0.08, 0.10, 0.15, 0.20, 0.25]  # bonus saccheggio vittorie in lega

# Loot cap per Hall del difensore (Cogs e Sap, per attacco). Shards: cap separato.
LOOT_CAP = [500, 1500, 5000, 15000, 40000, 90000, 180000, 300000, 450000, 600000]
SHARD_LOOT_CAP = [0, 0, 0, 0, 20, 60, 120, 200, 320, 450]
LOOT_PCT_STORED = [0.50, 0.40, 0.30, 0.25, 0.22, 0.20, 0.18, 0.16, 0.14, 0.12]  # % del contenuto di ciascun deposito
LOOT_PCT_EXTRACTOR = 0.50       # % del contenuto di estrattore
HALL_DIFF_MODIFIER = {"-3": 0.50, "-2": 0.70, "-1": 0.90, "0": 1.00, "1": 1.05, "2": 1.10, "3": 1.20}
# chiave = hall_difensore - hall_attaccante (clamp -3..3)


def level_cap_for_hall(unlock, levels, hall):
    """Livello massimo disponibile con Hall `hall` (0 = non sbloccato)."""
    best = 0
    for L in range(1, levels + 1):
        if req_hall(unlock, levels, L) <= hall:
            best = L
    return best


# ========================================================== COSTRUZIONE TABELLE
tables = {}   # name -> rows (per CSV/MD)
levels_db = {}  # id -> lista livelli (per report)


def build_levels(spec, extra_fn=None, shards=None):
    rows = []
    n = spec["levels"]
    for L in range(1, n + 1):
        t = upgrade_time(spec["ts"], L)
        row = dict(
            id=spec["id"], level=L, req_hall=req_hall(spec["unlock"], n, L),
            cost_res=spec["res"], cost=nice(geo(spec["cost"][0], spec["cost"][1], n, L)),
            cost_shards=(shards or {}).get(L, 0),
            time_s=t, xp=xp_for(t),
            hp=nice(geo(spec["hp"][0], spec["hp"][1], n, L)),
        )
        if extra_fn:
            row.update(extra_fn(L))
        rows.append(row)
    return rows


# --- Hall
hall_rows = []
for L in range(1, 11):
    t = HALL_TIME[L - 1]
    hall_rows.append(dict(
        id="lantern_hall", level=L, req_hall=max(1, L - 1), cost_res="cogs", cost=HALL_COST[L - 1],
        cost_shards=0, time_s=t, xp=xp_for(t) if t else 0,
        hp=nice(900 * 1.25 ** (L - 1)),
        stored_cogs=nice(500 * 2 ** (L - 1)), stored_sap=nice(500 * 2 ** (L - 1)),
    ))
tables["hall"] = hall_rows
levels_db["lantern_hall"] = hall_rows

# --- Economia / storage / military
def econ_extra(spec):
    def f(L):
        n = spec["levels"]
        if spec["id"] in ("cog_mine", "sap_well"):
            p = nice(PROD_FIRST * PROD_GROWTH ** (L - 1))
            return dict(prod_per_hour=p, capacity=nice(p * MINE_CAP_HOURS))
        if spec["id"] == "shard_drill":
            p = nice(DRILL_FIRST * DRILL_GROWTH ** (L - 1))
            return dict(prod_per_hour=p, capacity=nice(p * DRILL_CAP_HOURS))
        if spec["id"] in ("cog_vault", "sap_cistern"):
            return dict(capacity=VAULT_CAPS[L - 1])
        if spec["id"] == "shard_crate":
            return dict(capacity=nice(geo(CRATE_CAP[0], CRATE_CAP[1], n, L)))
        if spec["id"] == "army_camp":
            return dict(army_capacity=CAMP_CAP[L - 1])
        if spec["id"] == "spell_forge":
            return dict(spell_slots=FORGE_SLOTS[L - 1])
        if spec["id"] == "clan_hall":
            return dict(clan_slots=CLAN_HALL_SLOTS[L - 1])
        if spec["id"] == "barracks":
            return dict(troops_unlocked=",".join(t["id"] for t in TROOPS if t["barracks"] <= L))
        if spec["id"] == "laboratory":
            return dict(max_troop_level=L)
        return {}
    return f

by_cat = {}
for spec in BUILDINGS:
    rows = build_levels(spec, econ_extra(spec))
    levels_db[spec["id"]] = rows
    by_cat.setdefault(spec["cat"], []).extend(rows)
tables["economy"] = [r for r in by_cat["economy"]]
tables["storage"] = [r for r in by_cat["storage"]]
tables["military_buildings"] = by_cat["military"] + by_cat["social"]

# --- Difese
def_rows = []
for spec in DEFENSES:
    def extra(L, spec=spec):
        dps = spec["dps"] * DEF_DPS_GROWTH ** (L - 1)
        d = dict(dps=nice(dps), damage_per_shot=round(dps * spec["interval"], 1) if spec["interval"] >= 0.5 else round(dps * spec["interval"], 2),
                 interval_s=spec["interval"], range_min=spec["rmin"], range_max=spec["rmax"],
                 targets=spec["targets"], splash_radius=spec["splash"], priority=spec["prio"], size=spec["size"])
        if spec["id"] == "frost_spire":
            d["slow_fraction"] = FROST_SLOW[L - 1]
            d["slow_seconds"] = FROST_SLOW_TIME
        if spec["id"] == "arc_coil":
            d["chain_targets"] = 3
            d["chain_falloff"] = 0.25
        return d
    s = dict(spec, levels=10)
    rows = build_levels(s, extra, DEF_SHARDS)
    levels_db[spec["id"]] = rows
    def_rows.extend(rows)
tables["defenses"] = def_rows

# --- Mura
# Le mura si potenziano ISTANTANEAMENTE (solo costo): standard di genere, evita centinaia di timer.
wall_rows = build_levels(dict(WALL), lambda L: dict(size=1))
for _r in wall_rows:
    _r["time_s"] = 0
    _r["xp"] = 0
levels_db["wall"] = wall_rows
tables["walls"] = wall_rows

# --- Trappole
trap_rows = []
for spec in TRAPS:
    def extra(L, spec=spec):
        n = spec["levels"]
        d = dict(trigger_radius=spec["trigger"], effect_radius=spec["radius"], targets=spec["targets"], effect=spec["effect"], size=spec["size"],
                 rearm_cost=nice(geo(spec["cost"][0], spec["cost"][1], n, L) * TRAP_REARM_FRACTION))
        if spec["dmg"][1]:
            d["damage"] = nice(geo(spec["dmg"][0], spec["dmg"][1], n, L))
        if "space" in spec:
            d["launch_max_space"] = nice(geo(spec["space"][0], spec["space"][1], n, L))
        if "freeze" in spec:
            d["freeze_seconds"] = round(geo(spec["freeze"][0], spec["freeze"][1], n, L), 1)
        return d
    s = dict(spec, hp=(1, 1))
    rows = build_levels(s, extra)
    for r in rows:
        r.pop("hp")
    levels_db[spec["id"]] = rows
    trap_rows.extend(rows)
tables["traps"] = trap_rows

# --- Truppe (per livello) + costi ricerca laboratorio
troop_rows, lab_rows = [], []
for t in TROOPS:
    for L in range(1, t["levels"] + 1):
        hp = nice(t["hp"] * TROOP_HP_G ** (L - 1))
        dps = nice(t["dps"] * TROOP_DPS_G ** (L - 1)) if t["dps"] else 0
        if t["res"] == "shards":
            unit_cost = nice(t["cost"] * 1.25 ** (L - 1))
        else:
            unit_cost = nice(t["cost"] * TROOP_COST_G ** (L - 1))
        row = dict(id=t["id"], level=L, role=t["role"], size=t["size"], hp=hp, dps=dps, speed=t["speed"], range=t["range"],
                   flying=t["flying"], targets=t["targets"], preference=t["pref"], cost_res=t["res"], cost=unit_cost,
                   train_s=nice(t["train"] * (1 + 0.04 * (L - 1))), barracks_req=t["barracks"], lab_req=L if L > 1 else 0, special=t["special"])
        if t["id"] == "mender":
            row["heal_per_s"] = nice(MENDER_HEAL * TROOP_DPS_G ** (L - 1))
        if t["id"] == "kegger":
            row["blast_damage"] = nice(60 * TROOP_DPS_G ** (L - 1))
        troop_rows.append(row)
        if L >= 2:
            if t["res"] == "shards":
                cost, res = nice(300 * 2 ** (L - 2)), "shards"
                ts = 1.3
            else:
                cost, res = nice(RESEARCH_BASE[L] * RESEARCH_FACTOR[t["id"]]), "sap"
                ts = 1.0
            tm = int(min(MAX_TIME, max(MIN_TIME, TIER_TIME[L] * ts if L < 10 else MAX_TIME)))
            lab_rows.append(dict(id=t["id"], level=L, lab_req=L, cost_res=res, cost=cost, time_s=nice(tm) if tm >= 100 else tm, xp=xp_for(tm)))
tables["troops"] = troop_rows
tables["lab_research"] = lab_rows

# --- Incantesimi
spell_rows = []
for s in SPELLS:
    for L in range(1, s["levels"] + 1):
        row = dict(id=s["id"], level=L, size=s["size"], radius=s["radius"], duration_s=s["duration"],
                   cost_res=s["res"], cost=nice(s["cost"] * 1.25 ** (L - 1)), train_s=s["train"] + 30 * (L - 1), forge_req=L)
        if s["effect"] == "heal_per_s":
            row["heal_per_s"] = nice(s["value"] * s["growth"] ** (L - 1))
        else:
            row["damage_bonus"] = round(geo(s["value"], s["value_last"], s["levels"], L), 3)
            row["speed_bonus"] = round(geo(s["speed"], s["speed_last"], s["levels"], L), 3)
        spell_rows.append(row)
tables["spells"] = spell_rows

# --- Hall unlocks
unlock_rows = []
for h in range(1, 11):
    row = dict(hall_level=h)
    for k, v in COUNTS.items():
        row[k] = v[h - 1]
    unlock_rows.append(row)
tables["hall_unlocks"] = unlock_rows

# --- Max level per tipo ad ogni Hall
spec_index = {s["id"]: dict(s) for s in BUILDINGS}
for s in DEFENSES:
    spec_index[s["id"]] = dict(s, levels=10)
spec_index["wall"] = dict(WALL)
for s in TRAPS:
    spec_index[s["id"]] = dict(s)
maxlvl_rows = []
for h in range(1, 11):
    row = dict(hall_level=h)
    for k, s in spec_index.items():
        row[k] = level_cap_for_hall(s["unlock"], s["levels"], h)
    maxlvl_rows.append(row)
tables["max_level_by_hall"] = maxlvl_rows

# --- Leghe
league_rows = []
for i, (lid, lo, hi) in enumerate(LEAGUES):
    league_rows.append(dict(id=lid, index=i + 1, trophies_min=lo, trophies_max=hi, first_reach_gems=LEAGUE_REWARD_GEMS[i], win_loot_bonus=LEAGUE_LOOT_BONUS[i]))
tables["leagues"] = league_rows

# --- Livelli XP giocatore (1..30)
xp_rows = []
cum = 0
for n in range(1, 31):
    need = round(12 * n ** 1.6)
    xp_rows.append(dict(level=n, xp_to_next=need, xp_cumulative_start=cum))
    cum += need
tables["xp_levels"] = xp_rows

# --- Campagna (25 livelli), ordine difese: bolt,lobber,sky,arc,ballista,thumper,frost,spout,pylon
DEF_ORDER = ["boltpost", "lobber", "skyspear", "arc_coil", "ballista", "thumper", "frost_spire", "cinder_spout", "storm_pylon"]
CAMPAIGN = [
    # nome, hall, difese[9], mura, tema/trucco
    ("Mossy Gate",           1, [1,0,0,0,0,0,0,0,0],   0, "Tutorial: una sola Boltpost, nessuna mura"),
    ("Pebble Hollow",        2, [2,0,0,0,0,0,0,0,0],  10, "Introduce le mura: porta singola"),
    ("Dewdrop Farm",         2, [2,1,0,0,0,0,0,0,0],  20, "Mine esterne, esca per saccheggiatori"),
    ("Cricket Hill",         3, [2,1,0,0,0,0,0,0,0],  30, "Introduce trappola bomba"),
    ("Thistle Fort",         3, [2,1,1,0,0,0,0,0,0],  40, "Prima difesa antiaerea: volanti penalizzati"),
    ("Mudwater Docks",       4, [3,1,1,0,0,0,0,0,0],  50, "Base lunga e stretta, deposito isolato"),
    ("Rustbucket Yard",      4, [3,2,1,1,0,0,0,0,0],  60, "Introduce Arc Coil al centro"),
    ("Hornet Ridge",         5, [3,2,1,1,0,0,0,0,0],  75, "Antiaerea concentrata a nord"),
    ("Fungus Fen",           5, [3,2,2,1,1,0,0,0,0],  90, "Prima Ballista a lungo raggio"),
    ("The Gearmill",         5, [3,2,2,1,1,0,0,0,0], 110, "BOSS 1: doppio anello di mura, trappole molle"),
    ("Brambleback",          6, [4,2,2,1,1,1,0,0,0], 125, "Introduce Thumper: massimo danno ai tank"),
    ("Cobweb Cliffs",        6, [4,3,2,2,1,1,0,0,0], 140, "Difese a scacchiera, trappole snare"),
    ("Gloomtide Pier",       7, [4,3,2,2,1,1,0,0,0], 150, "Lunga banchina: schieramento limitato a un lato"),
    ("Lanternless Alley",    7, [4,3,3,2,2,1,1,0,0], 165, "Introduce Frost Spire: truppe rallentate"),
    ("Cinder Orchard",       7, [4,3,3,2,2,1,1,0,0], 175, "Depositi molto distribuiti"),
    ("Wraith Reservoir",     8, [5,3,3,2,2,1,1,0,0], 190, "Mine d'aria: volanti rischiosi"),
    ("Thunder Terrace",      8, [5,4,3,3,2,2,1,1,0], 200, "Introduce Cinder Spout al centro"),
    ("Frostbitten Fields",   8, [5,4,3,3,2,2,1,1,0], 200, "Tre Frost Spire sovrapposte"),
    ("Smogspire",            9, [5,4,3,3,2,2,2,1,0], 215, "Torre fumo: visibilita' ridotta (solo estetica)"),
    ("Mirror Marsh",         9, [5,4,4,3,3,2,2,1,1], 225, "Introduce Storm Pylon: volanti in difficolta'"),
    ("Bonecog Citadel",      9, [5,4,4,3,3,2,2,1,1], 225, "BOSS 2: tre compartimenti concentrici"),
    ("Stormcrow Keep",      10, [6,4,3,3,2,2,2,1,1], 250, "Hall 10, tempo ridotto di attacco consigliato"),
    ("Hollow Sun",          10, [6,4,4,3,3,2,2,2,1], 250, "Difese miste ravvicinate, molte trappole"),
    ("The Long Night Wall", 10, [6,4,4,3,3,2,2,2,2], 250, "Mura di livello massimo con lacune nascoste"),
    ("Gloomqueen's Throne", 10, [6,4,4,3,3,2,2,2,2], 250, "BOSS FINALE: tutte le difese, Hall con aura (+30% HP)"),
]
# Rampa di difficolta' dei primi livelli: punti vita degli edifici e danni delle difese (1,0 = valori pieni).
CAMPAIGN_DIFFICULTY = [0.45, 0.55, 0.65, 0.72, 0.8, 0.85, 0.9, 0.94, 0.97, 1.0]
camp_rows = []
for i, (name, hall, defs, walls, gimmick) in enumerate(CAMPAIGN, start=1):
    for j, k in enumerate(DEF_ORDER):
        assert defs[j] <= COUNTS[k][hall - 1], f"campagna {i}: {k} {defs[j]} > max {COUNTS[k][hall-1]} a Hall {hall}"
    assert walls <= COUNTS["wall"][hall - 1], f"campagna {i}: troppe mura"
    cap = LOOT_CAP[hall - 1]
    boss = i in (10, 20, 25)
    row = dict(level=i, name_key=f"campaign.{i:02d}.name", name_en=name, hall_level=hall, walls=walls,
               loot_cogs=nice(cap * (0.55 + 0.01 * i)), loot_sap=nice(cap * (0.55 + 0.01 * i)),
               loot_shards=nice(SHARD_LOOT_CAP[hall - 1] * 0.6), boss=boss, first_3star_gems=5 + i, gimmick=gimmick,
               difficulty=CAMPAIGN_DIFFICULTY[i - 1] if i <= len(CAMPAIGN_DIFFICULTY) else 1.0)
    for j, k in enumerate(DEF_ORDER):
        row[k] = defs[j]
    camp_rows.append(row)
tables["campaign"] = camp_rows

# ------------------------------------------------- achievements / daily / ecc.
ACHIEVEMENTS = [
    ("loot_cogs", "cogs_looted_total", [(100000, 10), (5000000, 50), (50000000, 200)]),
    ("loot_sap", "sap_looted_total", [(100000, 10), (5000000, 50), (50000000, 200)]),
    ("win_battles", "attack_wins", [(10, 10), (100, 50), (1000, 200)]),
    ("earn_stars", "stars_total", [(30, 10), (300, 50), (3000, 250)]),
    ("raze_defenses", "defenses_destroyed", [(25, 10), (250, 50), (2500, 200)]),
    ("hold_the_line", "defense_wins", [(5, 10), (50, 50), (500, 200)]),
    ("tidy_up", "obstacles_cleared", [(10, 5), (100, 30), (500, 100)]),
    ("lantern_rising", "hall_level", [(3, 20), (6, 60), (10, 200)]),
    ("trophy_hunter", "trophies_best", [(400, 15), (1200, 60), (3200, 200)]),
    ("campaign_walker", "campaign_stars", [(15, 15), (45, 45), (75, 120)]),
    ("spellcaster", "spells_cast", [(25, 5), (250, 20), (2500, 60)]),
    ("barracks_busy", "troops_trained", [(100, 5), (1000, 20), (10000, 60)]),
    ("builder_hands", "upgrades_done", [(10, 10), (100, 40), (500, 120)]),
    ("wall_wrecker", "walls_destroyed", [(100, 5), (1000, 20), (10000, 60)]),
    ("shard_seeker", "shards_collected", [(1000, 10), (50000, 50), (1000000, 150)]),
    ("join_the_hall", "clan_joined", [(1, 10)]),
]
ach_rows = []
for aid, metric, tiers in ACHIEVEMENTS:
    for ti, (target, gems) in enumerate(tiers, start=1):
        ach_rows.append(dict(id=aid, tier=ti, metric=metric, target=target, reward_gems=gems, name_key=f"ach.{aid}.name", desc_key=f"ach.{aid}.desc"))
tables["achievements"] = ach_rows

DAILY_MISSIONS = [
    ("win_attack", "attack_wins", 1, 2, 0), ("earn_stars", "stars_total", 5, 2, 0), ("loot_cogs", "cogs_looted", 20000, 0, 5000),
    ("spend_upgrade", "upgrades_started", 2, 2, 0), ("train_troops", "troops_trained", 30, 1, 0), ("clear_obstacle", "obstacles_cleared", 3, 3, 0),
    ("cast_spell", "spells_cast", 3, 1, 0), ("destroy_defense", "defenses_destroyed", 10, 2, 0),
]
daily_rows = [dict(id=m[0], metric=m[1], target=m[2], reward_gems=m[3], reward_sap_per_hall=m[4], name_key=f"daily.{m[0]}.name") for m in DAILY_MISSIONS]
tables["daily_missions"] = daily_rows
LOGIN_CYCLE = [
    dict(day=1, reward="cogs", amount_per_hall=300), dict(day=2, reward="sap", amount_per_hall=300), dict(day=3, reward="gems", amount=3),
    dict(day=4, reward="cogs_sap", amount_per_hall=500), dict(day=5, reward="gems", amount=5), dict(day=6, reward="shards_or_gems", amount=100, fallback_gems=5),
    dict(day=7, reward="gems", amount=15),
]
OBSTACLES = [
    dict(id="sapling",     size=1, weight=45, gems=[0, 1], remove_cost_per_hall=15, remove_time_s=10),
    dict(id="boulder",     size=2, weight=35, gems=[0, 2], remove_cost_per_hall=30, remove_time_s=60),
    dict(id="glowshroom",  size=2, weight=15, gems=[1, 3], remove_cost_per_hall=60, remove_time_s=600),
    dict(id="moon_crystal", size=2, weight=5,  gems=[3, 6], remove_cost_per_hall=120, remove_time_s=3600),
]
OBSTACLE_RULES = dict(max_on_map=40, spawn_interval_s=21600, remove_uses_builder=True, remove_cost_res="random_cogs_or_sap")

BUILDER_PRICES = [dict(builder=3, gems=200), dict(builder=4, gems=400), dict(builder=5, gems=800)]
SPEEDUP_POINTS = [[0, 0], [60, 1], [3600, 20], [86400, 260], [259200, 650], [604800, 1000]]    # (secondi residui, gemme)
RES_TO_GEM_POINTS = [[100, 1], [1000, 5], [10000, 25], [100000, 125], [1000000, 625], [10000000, 3000]]  # (risorsa, gemme)

# --------------------------------------------------------------- scrittura
write_json("hall.json", hall_rows)
write_json("hall_unlocks.json", unlock_rows)
write_json("max_level_by_hall.json", maxlvl_rows)
write_json("buildings.json", dict(
    economy=tables["economy"], storage=tables["storage"], military=tables["military_buildings"],
    footprints={s["id"]: s["size"] for s in BUILDINGS} | {"lantern_hall": 4},
    unlock_hall={s["id"]: s["unlock"] for s in BUILDINGS} | {"lantern_hall": 1},
    counts_by_hall={k: v for k, v in COUNTS.items() if k in {s["id"] for s in BUILDINGS}},
))
write_json("defenses.json", dict(levels=def_rows, unlock_hall={s["id"]: s["unlock"] for s in DEFENSES},
                                 counts_by_hall={s["id"]: COUNTS[s["id"]] for s in DEFENSES}, order=DEF_ORDER))
write_json("walls.json", dict(levels=wall_rows, counts_by_hall=COUNTS["wall"], drag_line_placement=True))
write_json("traps.json", dict(levels=trap_rows, counts_by_hall={s["id"]: COUNTS[s["id"]] for s in TRAPS}, rearm_fraction=TRAP_REARM_FRACTION))
write_json("troops.json", dict(levels=troop_rows, lab=lab_rows, spells=spell_rows))
write_json("leagues.json", league_rows)
write_json("xp_levels.json", xp_rows)
write_json("campaign.json", camp_rows)
write_json("achievements.json", ach_rows)
write_json("daily.json", dict(missions=daily_rows, missions_per_day=3, login_cycle=LOGIN_CYCLE))
write_json("obstacles.json", dict(types=OBSTACLES, rules=OBSTACLE_RULES))
write_json("economy.json", dict(
    resources=["cogs", "sap", "shards"], premium="glimmers",
    starting=dict(cogs=1500, sap=1500, shards=0, glimmers=50, builders=2),
    builders=dict(initial=2, max=5, prices=BUILDER_PRICES),
    speedup_points=SPEEDUP_POINTS, resource_to_gem_points=RES_TO_GEM_POINTS,
    loot=dict(cap_by_hall=LOOT_CAP, shard_cap_by_hall=SHARD_LOOT_CAP, pct_stored_by_hall=LOOT_PCT_STORED,
              pct_extractor=LOOT_PCT_EXTRACTOR, hall_diff_modifier=HALL_DIFF_MODIFIER),
    shield=dict(thresholds=[[0.40, 28800], [0.70, 43200], [1.00, 57600]], newbie_s=86400, offline_attacks_max_per_24h=3,
                offline_attack_interval_s=[14400, 36000]),
    trophies=dict(win_base=[0, 20, 30, 40], loss_base=25, diff_scale=400, diff_clamp=0.5),
    battle=dict(tick_rate=30, duration_s=180, star_percent=0.5, grid=44, buildable=40, border=2, no_deploy_margin=2),
    matchmaking=dict(trophy_window=150, search_cost_cogs_per_hall=[10, 20, 40, 80, 160, 300, 500, 800, 1200, 1500]),
    clan=dict(create_cost_cogs=10000, member_cap=25, chat_history=100),
))

# CSV
for name, rows in tables.items():
    write_csv(f"{name}.csv", rows)
write_csv("builders.csv", BUILDER_PRICES)

# ==================================================== BALANCE_TABLES.md
md = ["# Tabelle di bilanciamento (generate da tools/gen_balance.py)\n",
      "> NON modificare a mano: rigenerare con `python3 tools/gen_balance.py`. Le stesse tabelle in JSON sono in `data/`, in CSV in `data/csv/`.\n",
      "Unita': distanze in celle, velocita' in celle/s, tempi in secondi (mostrati anche leggibili), DPS = danno al secondo.\n"]
md.append("\n## Edificio Centrale (Faro Madre)\n")
md.append(md_table(["Liv", "Costo (Cogs)", "Tempo", "HP", "Deposito Cogs/Sap", "XP"],
                   [[r["level"], fmt_num(r["cost"]), fmt_time(r["time_s"]), fmt_num(r["hp"]), fmt_num(r["stored_cogs"]), r["xp"]] for r in hall_rows]))
md.append("\n## Sblocchi per livello di Edificio Centrale (quantita' massime)\n")
keys = list(COUNTS.keys())
for chunk in (keys[:12], keys[12:]):
    md.append(md_table(["Hall"] + chunk, [[r["hall_level"]] + [r[k] for k in chunk] for r in unlock_rows]))
md.append("\n## Livello massimo per Hall\n")
mk = list(spec_index.keys())
for chunk in (mk[:14], mk[14:]):
    md.append(md_table(["Hall"] + chunk, [[r["hall_level"]] + [r[k] for k in chunk] for r in maxlvl_rows]))
md.append("\n## Economia, depositi, militari\n")
for spec in BUILDINGS:
    rows = levels_db[spec["id"]]
    extra = [k for k in rows[0] if k not in ("id", "level", "req_hall", "cost_res", "cost", "cost_shards", "time_s", "xp", "hp")]
    md.append(f"\n### {spec['id']} ({spec['size']}x{spec['size']}, sblocco Hall {spec['unlock']}, costo in {spec['res']})\n")
    md.append(md_table(["Liv", "Hall req", "Costo", "Tempo", "HP", "XP"] + extra,
                       [[r["level"], r["req_hall"], fmt_num(r["cost"]), fmt_time(r["time_s"]), fmt_num(r["hp"]), r["xp"]] + [r[k] for k in extra] for r in rows]))
md.append("\n## Difese\n")
for spec in DEFENSES:
    rows = levels_db[spec["id"]]
    md.append(f"\n### {spec['id']} ({spec['size']}x{spec['size']}, ruolo {spec['role']}, bersagli {spec['targets']}, raggio {spec['rmin']}-{spec['rmax']}, intervallo {spec['interval']}s, area {spec['splash']}, priorita' {spec['prio']})\n")
    extra = ["slow_fraction"] if spec["id"] == "frost_spire" else []
    md.append(md_table(["Liv", "Hall req", "Costo Cogs", "Shards", "Tempo", "HP", "DPS", "Danno/colpo"] + extra,
                       [[r["level"], r["req_hall"], fmt_num(r["cost"]), r["cost_shards"], fmt_time(r["time_s"]), fmt_num(r["hp"]), r["dps"], r["damage_per_shot"]] + [r[k] for k in extra] for r in rows]))
md.append("\n## Mura\n")
md.append(md_table(["Liv", "Hall req", "Costo/segmento", "Tempo", "HP"], [[r["level"], r["req_hall"], fmt_num(r["cost"]), fmt_time(r["time_s"]), fmt_num(r["hp"])] for r in wall_rows]))
md.append("\n## Trappole\n")
for spec in TRAPS:
    rows = levels_db[spec["id"]]
    md.append(f"\n### {spec['id']} (effetto {spec['effect']}, bersagli {spec['targets']}, trigger {spec['trigger']}, raggio {spec['radius']})\n")
    extra = [k for k in ("damage", "launch_max_space", "freeze_seconds") if k in rows[0]]
    md.append(md_table(["Liv", "Hall req", "Costo", "Riarmo", "Tempo"] + extra, [[r["level"], r["req_hall"], fmt_num(r["cost"]), fmt_num(r["rearm_cost"]), fmt_time(r["time_s"])] + [r[k] for k in extra] for r in rows]))
md.append("\n## Truppe (per livello)\n")
for t in TROOPS:
    rows = [r for r in troop_rows if r["id"] == t["id"]]
    md.append(f"\n### {t['id']} - {t['role']} (spazio {t['size']}, velocita' {t['speed']}, raggio {t['range']}, bersagli {t['targets']}, preferenza {t['pref']}, caserma Lv{t['barracks']})\n")
    md.append(f"Speciale: `{t['special'] or '-'}`\n\n")
    md.append(md_table(["Liv", "HP", "DPS", "Costo", "Addestr.", "Lab liv"] + (["Cura/s"] if t["id"] == "mender" else []) + (["Danno esplosione"] if t["id"] == "kegger" else []),
                       [[r["level"], fmt_num(r["hp"]), r["dps"], f"{fmt_num(r['cost'])} {r['cost_res']}", fmt_time(r["train_s"]), r["lab_req"]] + ([r["heal_per_s"]] if t["id"] == "mender" else []) + ([r["blast_damage"]] if t["id"] == "kegger" else []) for r in rows]))
md.append("\n## Ricerca laboratorio (costo/tempo per portare la truppa al livello indicato)\n")
md.append(md_table(["Truppa", "Liv", "Lab req", "Costo", "Tempo"], [[r["id"], r["level"], r["lab_req"], f"{fmt_num(r['cost'])} {r['cost_res']}", fmt_time(r["time_s"])] for r in lab_rows]))
md.append("\n## Incantesimi\n")
md.append(md_table(["ID", "Liv", "Raggio", "Durata", "Costo", "Addestr.", "Effetto"],
                   [[r["id"], r["level"], r["radius"], r["duration_s"], fmt_num(r["cost"]), fmt_time(r["train_s"]),
                     (f"cura {r['heal_per_s']}/s" if "heal_per_s" in r else f"+{int(r['damage_bonus']*100)}% danno, +{int(r['speed_bonus']*100)}% velocita'")] for r in spell_rows]))
md.append("\n## Leghe\n")
md.append(md_table(["#", "ID", "Trofei", "Gemme 1a volta", "Bonus bottino"], [[r["index"], r["id"], f"{r['trophies_min']}-{r['trophies_max'] if r['trophies_max'] < 99999 else '+'}", r["first_reach_gems"], f"{int(r['win_loot_bonus']*100)}%"] for r in league_rows]))
md.append("\n## Campagna (25 livelli)\n")
md.append(md_table(["#", "Nome", "Hall", "Bolt/Lob/Sky/Arc/Bal/Thu/Fro/Spo/Pyl", "Mura", "Cogs", "Sap", "Shards", "Gemme 3*", "Note"],
                   [[r["level"], r["name_en"], r["hall_level"], "/".join(str(r[k]) for k in DEF_ORDER), r["walls"], fmt_num(r["loot_cogs"]), fmt_num(r["loot_sap"]), fmt_num(r["loot_shards"]), r["first_3star_gems"], r["gimmick"]] for r in camp_rows]))
md.append("\n## Obiettivi permanenti\n")
md.append(md_table(["ID", "Livello", "Metrica", "Target", "Gemme"], [[r["id"], r["tier"], r["metric"], fmt_num(r["target"]), r["reward_gems"]] for r in ach_rows]))
md.append("\n## Missioni giornaliere (3 al giorno estratte dal pool)\n")
md.append(md_table(["ID", "Metrica", "Target", "Gemme", "Sap x Hall"], [[r["id"], r["metric"], fmt_num(r["target"]), r["reward_gems"], r["reward_sap_per_hall"]] for r in daily_rows]))
md.append("\n## Livelli giocatore (1-30)\n")
md.append(md_table(["Liv", "XP per salire", "XP cumulativo"], [[r["level"], fmt_num(r["xp_to_next"]), fmt_num(r["xp_cumulative_start"])] for r in xp_rows if r["level"] <= 50]))
with open(os.path.join(DOCS, "BALANCE_TABLES.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(md))

# ================================================= REPORT DI VERIFICA
def cum_time(rows, upto):
    return sum(r["time_s"] for r in rows if r["level"] <= upto)

def cum_cost(rows, upto, key="cost"):
    return sum(r[key] for r in rows if r["level"] <= upto)

BUILDERS_AT_HALL = [2, 2, 3, 3, 4, 4, 5, 5, 5, 5]   # assunzione: giocatore attivo che compra i costruttori
BUILDER_EFFICIENCY = 0.75                           # frazione di tempo in cui i costruttori sono occupati

rep = ["# Report di verifica del bilanciamento\n", "Generato da `tools/gen_balance.py`. Tutti i numeri sono derivati dalle tabelle in `data/`.\n"]
# 1) Edificio centrale
rep.append("\n## 1. Tempo totale per completare ogni livello dell'Edificio Centrale\n")
rep.append("Colonne: **Timer Hall** = solo il timer di potenziamento dell'Hall (limite inferiore, seriale);\n"
           "**Lavoro costruttori** = tempo-costruttore *aggiuntivo* per portare tutti gli edifici/difese/mura/trappole al massimo consentito da quell'Hall (escluso il laboratorio, che ha coda propria);\n"
           "**Giorni stimati** = max(timer Hall, lavoro / (costruttori x 0.75)).\n")
tot_prev_time, tot_prev_cost = 0, {"cogs": 0, "sap": 0, "shards": 0}
rows_rep = []
cum_days = 0.0
cum_hall_timer = 0
per_hall = []
for h in range(1, 11):
    tot_time = 0
    tot_cost = {"cogs": 0, "sap": 0, "shards": 0}
    for k, s in spec_index.items():
        cnt = COUNTS[k][h - 1]
        lvl = level_cap_for_hall(s["unlock"], s["levels"], h)
        if cnt == 0 or lvl == 0:
            continue
        rows = levels_db[k]
        tot_time += cnt * cum_time(rows, lvl)
        c = cum_cost(rows, lvl)
        tot_cost[s["res"]] += cnt * c
        tot_cost["shards"] += cnt * cum_cost(rows, lvl, "cost_shards")
    # Hall stesso
    tot_time += cum_time(hall_rows, h)
    tot_cost["cogs"] += cum_cost(hall_rows, h)
    d_time = tot_time - tot_prev_time
    d_cost = {k: tot_cost[k] - tot_prev_cost[k] for k in tot_cost}
    tot_prev_time, tot_prev_cost = tot_time, tot_cost
    hall_timer = HALL_TIME[h - 1]
    cum_hall_timer += hall_timer
    days = max(hall_timer, d_time / (BUILDERS_AT_HALL[h - 1] * BUILDER_EFFICIENCY)) / 86400
    cum_days += days
    per_hall.append((h, hall_timer, d_time, d_cost, days, cum_days))
    rows_rep.append([h, fmt_time(hall_timer), fmt_time(cum_hall_timer), fmt_time(d_time), BUILDERS_AT_HALL[h - 1], f"{days:.1f}", f"{cum_days:.1f}"])
rep.append(md_table(["Hall", "Timer Hall", "Timer Hall cumulato", "Lavoro costruttori (incrementale)", "Costruttori", "Giorni stimati", "Giorni cumulati"], rows_rep))

# 2) Risorse vs produzione
rep.append("\n## 2. Costo risorse incrementale per livello Hall vs. produzione\n")
rep.append("Produzione/giorno = (n. estrattori x produzione/h x 24) con estrattori al livello massimo consentito, **limitata dalla capacita' dei depositi** nell'ipotesi che il giocatore raccolga una volta al giorno (cap = capacita' interna estrattori + depositi). 'Bottino' stimato = 4 attacchi/giorno al 60% del cap Hall. Giorni risorse = costo Cogs / (produzione + bottino).\n")
rows_res = []
for (h, hall_timer, d_time, d_cost, days, cd) in per_hall:
    mine_lvl = level_cap_for_hall(1, 10, h)
    prod_h = COUNTS["sap_well"][h - 1] * nice(PROD_FIRST * PROD_GROWTH ** (mine_lvl - 1))
    prod_day = prod_h * 24
    vault_lvl = level_cap_for_hall(1, 10, h)
    storage_cap = COUNTS["cog_vault"][h - 1] * VAULT_CAPS[vault_lvl - 1] + float(hall_rows[h - 1]["stored_cogs"])
    loot_day = 4 * 0.6 * LOOT_CAP[h - 1]
    income = min(prod_day, storage_cap + COUNTS["sap_well"][h - 1] * nice(prod_h / max(1, COUNTS["sap_well"][h - 1]) * MINE_CAP_HOURS)) + loot_day
    need = max(d_cost["cogs"], d_cost["sap"])
    d_res = need / income if income else 0
    rows_res.append([h, fmt_num(d_cost["cogs"]), fmt_num(d_cost["sap"]), fmt_num(d_cost["shards"]), fmt_num(prod_day), fmt_num(loot_day), f"{d_res:.1f}", f"{days:.1f}", f"{(d_res / days) if days else 0:.2f}"])
rep.append(md_table(["Hall", "Cogs richiesti", "Sap richiesti", "Shards", "Prod/giorno (ognuna)", "Bottino/giorno", "Giorni risorse", "Giorni tempo", "Rapporto risorse/tempo"], rows_res))
rep.append("\nObiettivo di design: rapporto risorse/tempo tra 0.5 e 2.0 **dall'Hall 6 in poi**. Hall 1-5: l'intero tratto richiede < 3 giorni di risorse e le risorse iniziali, il bottino della campagna e i tutorial lo rendono irrilevante; nel report il rapporto li' non e' un vincolo di design. La colonna Sap esclude ricerche di laboratorio e addestramento truppe (principale pozzo di Sap, vedi sezione 4).\n")

# 3) Gemme
rep.append("\n## 3. Budget valuta premium (Glimmers) ottenibile solo giocando\n")
ach_total = sum(r["reward_gems"] for r in ach_rows)
camp_total = sum(r["first_3star_gems"] for r in camp_rows)
league_total = sum(LEAGUE_REWARD_GEMS)
obst_avg = sum(o["weight"] * sum(o["gems"]) / 2 for o in OBSTACLES) / sum(o["weight"] for o in OBSTACLES)
obst_year = obst_avg * (86400 / OBSTACLE_RULES["spawn_interval_s"]) * 365
daily_week = 3 * (sum(m[3] for m in DAILY_MISSIONS) / len(DAILY_MISSIONS)) * 7
login_week = sum(c.get("amount", 0) for c in LOGIN_CYCLE if c["reward"] == "gems") + 5
rep.append(md_table(["Fonte", "Totale (gemme)"], [
    ["Obiettivi permanenti (tutti i livelli)", ach_total], ["Campagna: 25 livelli, 3 stelle, 1a volta", camp_total],
    ["Leghe (prima volta in ciascuna)", league_total], ["Ostacoli: media/giorno", f"{obst_avg * 4:.1f}"],
    ["Missioni giornaliere: media/settimana", f"{daily_week:.0f}"], ["Login 7 giorni: per settimana", login_week],
]))
rep.append(f"\nCosto costruttori 3-5: {sum(b['gems'] for b in BUILDER_PRICES)} gemme. "
           f"Entrate ricorrenti ~ {(daily_week + login_week) / 7 + obst_avg * 4:.1f} gemme/giorno; "
           f"un giocatore attivo puo' pagarsi il 3 costruttore in ~{200 / ((daily_week + login_week) / 7 + obst_avg * 4):.0f} giorni (anche prima grazie a campagna/obiettivi).\n")

# 4) Totali di sistema
rep.append("\n## 4. Totali di sistema (tutto al massimo con Hall 10)\n")
total_time_all = sum(per_hall[i][2] for i in range(10)) + 0
total_cost_all = {k: sum(per_hall[i][3][k] for i in range(10)) for k in ("cogs", "sap", "shards")}
lab_total_time = sum(r["time_s"] for r in lab_rows)
lab_total_cost = {"sap": sum(r["cost"] for r in lab_rows if r["cost_res"] == "sap"), "shards": sum(r["cost"] for r in lab_rows if r["cost_res"] == "shards")}
rep.append(md_table(["Voce", "Valore"], [
    ["Lavoro costruttori totale (edifici, difese, mura, trappole, Hall)", f"{fmt_time(total_time_all)} ({total_time_all / 86400:.0f} giorni-costruttore)"],
    ["Cogs totali", fmt_num(total_cost_all["cogs"])], ["Sap totali", fmt_num(total_cost_all["sap"])], ["Shards totali (difese)", fmt_num(total_cost_all["shards"])],
    ["Ricerca laboratorio totale (coda singola)", f"{fmt_time(lab_total_time)} ({lab_total_time / 86400:.0f} giorni)"],
    ["Costo ricerca Sap / Shards", f"{fmt_num(lab_total_cost['sap'])} / {fmt_num(lab_total_cost['shards'])}"],
    ["Durata stimata fino a Hall 10 completo (costruttori)", f"~{cum_days:.0f} giorni"],
    ["Livelli giocatore: XP cumulato a livello 30 (cap)", fmt_num(xp_rows[-1]["xp_cumulative_start"] + xp_rows[-1]["xp_to_next"])],
    ["XP totale ottenibile dai potenziamenti (somma radice tempo)", fmt_num(sum(sum(r['xp'] for r in rows) for rows in levels_db.values()))],
]))

# 5) Tempi minimi/massimi
rep.append("\n## 5. Controllo estremi tempi\n")
all_times = [(k, r["level"], r["time_s"]) for k, rows in levels_db.items() for r in rows if r["time_s"] > 0]
mn = min(all_times, key=lambda x: x[2]); mx = max(all_times, key=lambda x: x[2])
rep.append(f"Tempo minimo: {mn[0]} L{mn[1]} = {fmt_time(mn[2])} (vincolo >= 10s: {'OK' if mn[2] >= 10 else 'FALLITO'}). "
           f"Tempo massimo: {mx[0]} L{mx[1]} = {fmt_time(mx[2])} (vincolo <= 3 giorni: {'OK' if mx[2] <= MAX_TIME else 'FALLITO'}).\n")

# 6) Capacita' dei depositi vs costi: ogni singolo costo disponibile a una Hall deve stare nei depositi di quella Hall
rep.append("\n## 6. Capacità dei depositi vs costo singolo più alto\n")
rep.append("Capacità = deposito del Faro Madre + (n. depositi x capacità al livello massimo consentito). Ogni costo (potenziamento del Faro compreso, ricerche del laboratorio comprese) deve essere <= capacità della Hall in cui è disponibile, con margine.\n")
cap_rows = []
cap_fail = []
for h in range(1, 11):
    vl = level_cap_for_hall(1, 10, h)
    cap = float(hall_rows[h - 1]["stored_cogs"]) + COUNTS["cog_vault"][h - 1] * VAULT_CAPS[vl - 1]
    worst = {"cogs": (0, ""), "sap": (0, "")}
    if h < 10:
        worst["cogs"] = (HALL_COST[h], "Faro Madre -> %d" % (h + 1))
    for k_id, s_ in spec_index.items():
        ml = level_cap_for_hall(s_["unlock"], s_["levels"], h)
        for r_ in levels_db[k_id]:
            if r_["level"] <= ml and r_["cost"] > worst[s_["res"]][0]:
                worst[s_["res"]] = (r_["cost"], "%s L%d" % (k_id, r_["level"]))
    lab_cap = level_cap_for_hall(3, 8, h)
    for r_ in lab_rows:
        if r_["cost_res"] == "sap" and r_["lab_req"] <= lab_cap and r_["cost"] > worst["sap"][0]:
            worst["sap"] = (r_["cost"], "ricerca %s L%d" % (r_["id"], r_["level"]))
    ok = worst["cogs"][0] <= cap * 0.85 and worst["sap"][0] <= cap * 0.85
    if not ok:
        cap_fail.append(h)
    cap_rows.append([h, fmt_num(cap), f"{fmt_num(worst['cogs'][0])} ({worst['cogs'][1]})", f"{fmt_num(worst['sap'][0])} ({worst['sap'][1]})", "OK" if ok else "FALLITO"])
rep.append(md_table(["Hall", "Capacità (ciascuna risorsa)", "Costo Cogs più alto", "Costo Sap più alto", "Esito (<= 85%)"], cap_rows))
assert not cap_fail, f"capacita' insufficiente a Hall {cap_fail}"

with open(os.path.join(DOCS, "BALANCE_REPORT.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(rep))

print("OK: tabelle generate. Hall timer cumulato:", fmt_time(cum_hall_timer), "| giorni stimati Hall10:", f"{cum_days:.0f}")
