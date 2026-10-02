# LANTERNREACH — Game Design Document

Versione 1.0 · Fase 1 · Motore: Godot 4.3 (GDScript) · Piattaforma: Android, orizzontale

> Tutti i numeri citati qui sono generati da `tools/gen_balance.py` e vivono in `data/*.json` (e `data/csv/`).
> Le tabelle complete (ogni livello di ogni edificio, truppa, difesa) sono in [`docs/BALANCE_TABLES.md`](docs/BALANCE_TABLES.md); la verifica dei tempi in [`docs/BALANCE_REPORT.md`](docs/BALANCE_REPORT.md).
> Decisioni di design ambigue: [`DECISIONS.md`](DECISIONS.md).

---

## 0. Ricerca: pattern ricorrenti del genere (sintesi)

Il genere "base-building + attacco asincrono" converge su un insieme stabile di pattern. Li sintetizzo qui e indico come Lanternreach li usa **senza copiarne l'identità**.

| Pattern ricorrente | Perche' funziona | Scelta in Lanternreach |
|---|---|---|
| Edificio centrale che limita quantità e livelli di tutto il resto | Scansione chiara della progressione, gate unico | Faro Madre, 10 livelli, tabella sblocchi completa (§2.3) |
| Due risorse base + una rara a metà progressione | Doppio sink (costruzione vs esercito), la rara dà una meta tardiva | Cogs (ingranaggi), Sap (linfa), Starshards (rara, Hall 5+) |
| Estrattori con capacità interna + depositi saccheggiabili | Tensione "raccogli spesso vs rischi" e protezione | §3 |
| Timer reali con costruttori limitati | Ritmo di sessione breve e frequente; scarsità = valore dell'accelerazione | 2→5 costruttori, §4 |
| Valuta premium con curva di accelerazione non lineare | Sconto a scalare sulle attese lunghe | Qui **solo guadagnabile in gioco**, formula §4.3 |
| Difese con ruoli distinti e raggio minimo (mortaio) | Interazione truppe/difese leggibile | 9 difese, §5 |
| Mura che deviano il percorso o costringono ad attaccare | Scelta tattica di apertura | Costo-percorso A* con mura "pesate", §9.3 |
| Stelle (50% / centro / 100%) + timer 3 min | Obiettivi parziali, nessun "tutto o niente" | §9.5, identico concetto, numeri propri |
| Basi avversarie asincrone, scudo dopo attacco subito | Difesa senza online sincrono | Simulata offline, §10.3 |
| Trofei/leghe, missioni, obiettivi | Orizzonti a breve/medio/lungo termine | §11 |

Nota di metodo: la ricerca è una sintesi della conoscenza di dominio sul genere (struttura delle economie, curve tempo/costo, pattern di UX). **Non ho eseguito ricerche web in tempo reale in questa sessione**; i numeri finali non sono copiati da nessun titolo, ma derivati e verificati col nostro generatore (§13).

---

## 1. Concept

- **Titolo**: **Lanternreach** (it: *Il Regno delle Lanterne*).
- **Ambientazione**: un arcipelago di isole sospese nel vento, tenute vive da lanterne di vetro che bruciano linfa solare. I **Lanternari** (il giocatore) ricostruiscono i villaggi attorno al Faro Madre. La **Marea d'Ombra** (Gloomtide, nemici) è una nebbia fungina con "Mirelings" che vuole spegnere i fari e rubare ingranaggi e linfa.
- **Tono**: caldo, giocoso, un po' "da fiaba meccanica". Violenza stilizzata (nessun sangue): le truppe "si spengono" in uno sbuffo di scintille.
- **Pubblico**: 10+ anni, sessioni di 3–8 minuti, 3–6 al giorno.
- **Loop principale**: **raccogli** (estrattori, ostacoli, bottino) → **costruisci** (edifici/difese, costruttori limitati) → **addestra** (caserma, laboratorio, incantesimi) → **attacca** (campagna o basi avversarie) → **potenzia** (Hall, lab, trofei) → di nuovo raccogli.
- **Pilastri**: (1) leggibilità immediata su 5″, (2) ogni sessione ha un'azione utile in <30 s, (3) nessun pagamento reale, nessun timer bloccante in tutorial, (4) determinismo della simulazione (replay).
- **Monetizzazione**: nessuna (valuta premium "Glimmers" ottenibile solo giocando).

---

## 2. Villaggio

### 2.1 Griglia isometrica
- Griglia **44×44 celle**. Area edificabile = **40×40 centrali** (offset 2); la cornice esterna di **2 celle** è sempre libera ed è l'area di schieramento base in battaglia.
- Proiezione isometrica 2:1: cella = rombo 64×32 px (sprite pensati per 2× e 4× zoom). Ordinamento di profondità per `y_iso + z`.
- **Footprint**: 1×1 (mura, trappole piccole, ostacoli piccoli), 2×2, 3×3, 4×4. Footprint per edificio: vedi §2.4.

### 2.2 Modalità modifica
- Ingresso: **long-press** su un edificio (o pulsante "Modifica" nel pannello). Edificio sollevato di 8 px con ombra.
- **Sposta**: trascinamento con snap alla cella; ghost verde (valido) / rosso (invalido).
- **Ruota**: tutti i footprint sono quadrati, quindi la rotazione è solo **speculare visiva** (↻ inverte lo sprite) e non cambia la validità.
- **Conferma ✓ / Annulla ✗**: la posizione originale viene memorizzata; Annulla ripristina. Auto-salvataggio solo dopo ✓.
- **Validazione**: nessuna sovrapposizione di footprint; tutte le celle dentro 2..41; ostacoli bloccano (vanno rimossi prima); mura possono toccarsi. Edifici in costruzione possono essere spostati.
- **Mura in linea**: trascinando lungo una riga/colonna si posano segmenti contigui fino al limite di quantità e di risorse; anteprima con contatore costo.

### 2.3 Edificio centrale: **Faro Madre** (`lantern_hall`)
4×4, 10 livelli, livello 1 pre-piazzato e già in funzione.

| Liv | Costo (Cogs) | Tempo | HP | Deposito Cogs/Sap |
|---|---|---|---|---|
| 1 | — (iniziale) | — | 900 | 500 |
| 2 | 1.000 | 5 m | 1.130 | 1.000 |
| 3 | 3.000 | 1 h | 1.410 | 2.000 |
| 4 | 15.000 | 4 h | 1.760 | 4.000 |
| 5 | 40.000 | 12 h | 2.200 | 8.000 |
| 6 | 150.000 | 1 g | 2.750 | 16.000 |
| 7 | 320.000 | 1 g 12 h | 3.440 | 32.000 |
| 8 | 850.000 | 2 g | 4.300 | 64.000 |
| 9 | 1.500.000 | 2 g 12 h | 5.370 | 128.000 |
| 10 | 2.600.000 | 3 g | 6.710 | 256.000 |

Un solo Hall; durante il suo potenziamento il costruttore è occupato ma l'Hall continua a funzionare. Ogni potenziamento costa al massimo l'80% della capacità di Cogs raggiungibile al livello precedente (verifica automatica, §13.4).

#### Tabella completa di sblocchi (quantità massima per livello di Hall)

| Hall | Mine Cog | Pozzi Sap | Trivelle Shard | Depositi Cog | Cisterne Sap | Casse Shard | Caserma | Accamp. | Lab | Forgia Inc. | Sala Clan |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 2 | – | 1 | 1 | – | 1 | 1 | – | – | – |
| 2 | 3 | 3 | – | 1 | 1 | – | 1 | 1 | – | – | – |
| 3 | 4 | 4 | – | 2 | 2 | – | 1 | 2 | 1 | – | – |
| 4 | 5 | 5 | – | 2 | 2 | – | 1 | 2 | 1 | – | 1 |
| 5 | 6 | 6 | 1 | 3 | 3 | 1 | 1 | 3 | 1 | 1 | 1 |
| 6 | 6 | 6 | 1 | 3 | 3 | 1 | 1 | 3 | 1 | 1 | 1 |
| 7 | 7 | 7 | 2 | 4 | 4 | 1 | 1 | 4 | 1 | 1 | 1 |
| 8 | 7 | 7 | 2 | 4 | 4 | 2 | 1 | 4 | 1 | 1 | 1 |
| 9 | 7 | 7 | 3 | 4 | 4 | 2 | 1 | 4 | 1 | 1 | 1 |
| 10 | 8 | 8 | 3 | 4 | 4 | 2 | 1 | 4 | 1 | 1 | 1 |

| Hall | Boltpost | Lobber | Skyspear | Arc Coil | Ballista | Thumper | Frost Spire | Cinder Spout | Storm Pylon | Mura | Bomba | Molla | Laccio | Mina aria |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | – | – | – | – | – | – | – | – | 25 | – | – | – | – |
| 2 | 2 | 1 | – | – | – | – | – | – | – | 50 | 1 | – | – | – |
| 3 | 2 | 1 | 1 | – | – | – | – | – | – | 75 | 1 | 2 | – | – |
| 4 | 3 | 2 | 1 | 1 | – | – | – | – | – | 100 | 2 | 2 | 1 | – |
| 5 | 3 | 2 | 2 | 1 | 1 | – | – | – | – | 125 | 2 | 3 | 1 | 1 |
| 6 | 4 | 3 | 2 | 2 | 1 | 1 | – | – | – | 150 | 3 | 3 | 2 | 1 |
| 7 | 4 | 3 | 3 | 2 | 2 | 1 | 1 | – | – | 175 | 3 | 4 | 2 | 2 |
| 8 | 5 | 4 | 3 | 3 | 2 | 2 | 1 | 1 | – | 200 | 4 | 4 | 2 | 2 |
| 9 | 5 | 4 | 4 | 3 | 3 | 2 | 2 | 1 | 1 | 225 | 4 | 5 | 3 | 3 |
| 10 | 6 | 4 | 4 | 3 | 3 | 2 | 2 | 2 | 2 | 250 | 4 | 5 | 3 | 3 |

**Livello massimo di ciascun tipo con Hall *h*** (`data/max_level_by_hall.json`): `req_hall(L) = min(10, unlock + ⌊(L−1)·(10−unlock+1)/livelli⌋)`. Esempio: Boltpost (sblocco 1, 10 liv.) → livello max = Hall; Storm Pylon (sblocco 9) → liv. 1–5 con Hall 9, liv. 6–10 con Hall 10.

### 2.4 Footprint e ruoli degli edifici
| Edificio | Footprint | Sblocco | Livelli |
|---|---|---|---|
| Faro Madre | 4×4 | 1 | 10 |
| Mina di Cogs / Pozzo di Sap | 2×2 | 1 | 10 |
| Trivella Shard | 2×2 | 5 | 6 |
| Deposito Cogs / Cisterna Sap | 3×3 | 1 | 10 |
| Cassa Shard | 2×2 | 5 | 6 |
| Caserma | 3×3 | 1 | 10 |
| Accampamento | 4×4 | 1 | 8 |
| Laboratorio | 4×4 | 3 | 8 |
| Forgia Incantesimi | 3×3 | 5 | 5 |
| Sala del Clan | 4×4 | 4 | 5 |
| Difese | 2×2 o 3×3 (§5) | 1–9 | 10 |
| Mura | 1×1 | 1 | 10 |
| Trappole | 1×1 / 2×2 | 2–5 | 5 |

### 2.5 Ostacoli naturali
Spawn casuale su celle libere, **1 ogni 6 h**, massimo **40** sulla mappa; ricompare nel tempo.

| Ostacolo | Peso | Footprint | Gemme (Glimmers) | Costo rimozione | Tempo |
|---|---|---|---|---|---|
| Alberello | 45% | 1×1 | 0–1 | 15 × Hall (Cogs o Sap) | 10 s |
| Masso | 35% | 2×2 | 0–2 | 30 × Hall | 1 m |
| Glowshroom | 15% | 2×2 | 1–3 | 60 × Hall | 10 m |
| Cristallo lunare | 5% | 2×2 | 3–6 | 120 × Hall | 1 h |

La rimozione **occupa un costruttore** (così la scarsità dei costruttori resta un vincolo reale). Gemme medie ≈ 4,4/giorno se il giocatore ripulisce tutto (§13).

---

## 3. Economia

### 3.1 Risorse
| Risorsa | ID | Uso principale | Fonte |
|---|---|---|---|
| **Cogs** (ingranaggi) | `cogs` | Difese, mura, trappole, Hall, depositi/cisterne | Mine di Cogs, bottino |
| **Sap** (linfa solare) | `sap` | Truppe, incantesimi, ricerche lab, edifici economici/militari | Pozzi di Sap, bottino |
| **Starshards** (rara, Hall 5+) | `shards` | Difese liv. 8–10, truppa d'élite, ricerca d'élite | Trivelle, bottino (limitato) |
| **Glimmers** (premium, solo in gioco) | `glimmers` | Costruttori, accelerazioni, scudi extra | Ostacoli, obiettivi, missioni, campagna, leghe, login |

Risorse iniziali: 1.500 Cogs, 1.500 Sap, 50 Glimmers, 2 costruttori.

### 3.2 Estrattori
- Produzione oraria `P(L) = 200 × 1.38^(L−1)` (arrotondata a 3 cifre significative): L1 = **200/h**, L6 = 1.000/h, L10 = **3.630/h**.
- **Capacità interna = 8 h di produzione** (L1: 1.600 · L10: 29.000). Raggiunto il tetto la produzione si ferma.
- Trivella Shard: `25 × 1.45^(L−1)` /h (L1 = 25, L6 = 160), capacità interna 8 h.
- Raccolta: tap sull'estrattore (animazione monete/scintille).
- I contenuti si accumulano **anche a gioco chiuso** (§TimeManager in Fase 3).

### 3.3 Depositi
| Livello | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Capacità Deposito Cogs / Cisterna Sap | 1.500 | 3.500 | 9.000 | 25.000 | 60.000 | 130.000 | 260.000 | 480.000 | 800.000 | 1.200.000 |

Capacità per livello scelta in modo che ogni costo disponibile a una data Hall stia nei depositi raggiungibili a quella Hall (§13.4). Cassa Shard (6 livelli): 1.000 · 1.780 · 3.180 · 5.660 · 10.100 · 18.000. La capacità totale = somma dei depositi + deposito dell'Hall; l'eccedenza si perde.

### 3.4 Saccheggio (quanto è rubabile)
- Il bottino per **ciascun deposito** = `contenuto × pct_hall` dove `pct_hall = [50, 40, 30, 25, 22, 20, 18, 16, 14, 12]%` per Hall del difensore 1–10; per ciascun estrattore `50%` del suo contenuto.
- **Tetto per attacco** (Cogs e Sap, ciascuno), per Hall del difensore: **500 · 1.500 · 5.000 · 15.000 · 40.000 · 90.000 · 180.000 · 300.000 · 450.000 · 600.000**. Shards: **0 · 0 · 0 · 0 · 20 · 60 · 120 · 200 · 320 · 450**.
- Il bottino si rilascia **proporzionalmente al danno** inflitto a ciascun deposito/estrattore (progressivo, non tutto alla distruzione).
- Modificatore per differenza di Hall (difensore − attaccante): −3 → ×0,50 · −2 → ×0,70 · −1 → ×0,90 · 0 → ×1 · +1 → ×1,05 · +2 → ×1,10 · +3 → ×1,20.
- Bonus lega (vittorie): vedi §11.1.

### 3.5 Curva di progressione dei tempi
Curva-tempo base per livello (secondi): **10 s, 1 m, 10 m, 1 h, 4 h, 12 h, 1 g, 1 g 12 h, 2 g, 3 g** per L1…L10, moltiplicata per un fattore di edificio (0,25–1,0). **Minimo 10 s, massimo 3 giorni (solo Hall 10)**. Le difese a L10 durano da 36 h a 72 h (es. Boltpost L10 = 36 h; Storm Pylon L10 = 72 h). **Le mura si potenziano istantaneamente** (solo costo). XP ottenuta al completamento = `⌊√tempo_secondi⌋` (min 1).

---

## 4. Costruttori e accelerazioni

### 4.1 Costruttori
- **2 iniziali**, **3° = 200 Glimmers, 4° = 400, 5° = 800** (totale 1.400, vedi budget §13 / report §3).
- Ogni costruzione/potenziamento/rimozione ostacoli occupa un costruttore fino al termine.
- **Coda**: fino a 3 operazioni pianificate in attesa (si avviano da sole al liberarsi di un costruttore, scalando le risorse **all'avvio**, non alla pianificazione). Annullare in costruzione rimborsa 50%; annullare in coda 100%.

### 4.2 Gemme-costruttore: sblocco
Il costruttore extra appare come "Capanna" decorativa nel villaggio (art in Fase 2).

### 4.3 Accelerazione (formula documentata)
Costo in Glimmers per i secondi restanti `t`: interpolazione **lineare a tratti** sui punti `(t, gemme)`: `(0,0) (60,1) (3600,20) (86400,260) (259200,650) (604800,1000)`.
Esempi: 60 s → 1; 10 min → ⌈2,9⌉ = 3; 1 h → 20; 12 h → ⌈134,8⌉ = 135; 24 h → 260; 3 g → 650.
Acquisto con Glimmers di risorse mancanti: punti `(risorsa, gemme)`: `(100,1) (1k,5) (10k,25) (100k,125) (1M,625) (10M,3000)`.
Accelerare l'addestramento/ricerca/incantesimi usa la stessa curva.

---

## 5. Difese (9)

Raggi in celle; DPS = danno al secondo L1 (×1,17 per livello). Priorità = come l'IA sceglie il bersaglio (§9.4). Tutte hanno 10 livelli; ai livelli 8–10 richiedono Starshards (800 / 2.000 / 4.500).

| Difesa | Footprint | Sblocco | Ruolo | Bersagli | Raggio min–max | Intervallo | DPS L1 → L10 | Danno/colpo L1 → L10 | Area | HP L1 → L10 | Costo L1 → L10 (Cogs) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Boltpost** | 2×2 | 1 | Singolo bersaglio, versatile | terra+aria | 0–8 | 0,6 s | 12 → 49 | 7,2 → 29,6 | – | 380 → 1.700 | 250 → 900k |
| **Lobber** (mortaio) | 3×3 | 2 | Area, terra | terra | 3–11 | 3,5 s | 8 → 33 | 28 → 115 | 1,6 | 400 → 1.800 | 800 → 1,2M |
| **Skyspear** | 2×2 | 3 | Antiaereo | aria | 0–10 | 0,8 s | 22 → 90 | 17,6 → 72 | – | 360 → 1.600 | 500 → 1,1M |
| **Arc Coil** | 2×2 | 4 | Catena su 3 bersagli (−25% a salto) | terra | 0–7 | 1,0 s | 30 → 123 | 30 → 123 | catena | 520 → 2.300 | 3k → 1,6M |
| **Ballista** | 3×3 | 5 | Lungo raggio | terra+aria | 2–14 | 1,2 s | 16 → 66 | 19 → 79 | – | 700 → 3.100 | 8k → 2M |
| **Thumper** | 3×3 | 6 | Lento, altissimo danno | terra | 0–6 | 3,5 s | 45 → 185 | 158 → 647 | – | 900 → 3.900 | 20k → 2,4M |
| **Frost Spire** | 2×2 | 7 | Rallenta in area (30%→50% per 2 s) | terra+aria | 0–6 | 1,0 s | 9 → 37 | 9 → 37 | 2,5 | 600 → 2.600 | 40k → 2,5M |
| **Cinder Spout** | 2×2 | 8 | Corto raggio, DPS massiccio | terra | 0–4 | 0,2 s | 95 → 390 | 19 → 78 | – | 800 → 3.500 | 80k → 3M |
| **Storm Pylon** | 3×3 | 9 | Antiaereo ad area | aria | 0–11 | 1,2 s | 40 → 164 | 48 → 197 | 2,0 | 900 → 3.900 | 150k → 3,5M |

Proiettili: balistica con velocità ~18 celle/s (Boltpost/Skyspear/Ballista), arco parabolico lento ~9 celle/s (Lobber), istantaneo (Arc Coil, Cinder Spout, Frost Spire). Il Lobber **non può colpire entro 3 celle** (raggio minimo). Le difese ignorano le truppe che stanno entrando in zona fino a quando non sono bersaglio valido (aria/terra).

## 6. Mura
Segmenti **1×1**, 10 livelli, **auto-collegamento visivo** (sprite 4 bit: connessioni N/E/S/O). Posa a **trascinamento in linea** (§2.2). Potenziamento **istantaneo**, singolo o "tutte le mura dello stesso livello" in blocco.

| Liv | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| HP | 300 | 390 | 508 | 660 | 859 | 1.120 | 1.450 | 1.890 | 2.460 | 3.200 |
| Costo (Cogs) | 50 | 110 | 242 | 531 | 1.170 | 2.570 | 5.650 | 12.400 | 27.300 | 60.000 |
Quantità massima: 25 (Hall 1) → 250 (Hall 10), +25 a livello.

## 7. Trappole (4) — invisibili finché non scattano
Scattano quando una truppa entra nel **raggio di innesco** (trigger). Dopo l'uso vengono **riarmate automaticamente** dopo la battaglia al costo di **20%** del costo di livello (Cogs). Non contano per la percentuale di distruzione né sono bersagli attaccabili.

| Trappola | Footprint | Sblocco (Hall) | Innesco | Effetto | Livelli |
|---|---|---|---|---|---|
| **Bomb Trap** | 1×1 | 2 | 1,5 celle, terra | Danno ad area (raggio 1,5): 60 → 200 | 5 |
| **Spring Pad** | 1×1 | 3 | 1,0, terra | Scaraventa truppe fino a spazio totale 12 → 24 fuori dalla base | 5 |
| **Snare Trap** | 2×2 | 4 | 2,0, terra | Immobilizza in raggio 3,5 per 3,0 → 5,0 s | 5 |
| **Air Mine** | 1×1 | 5 | 2,0, aria | Detona in aria, raggio 2,5: 250 → 1.000 | 5 |

---

## 8. Truppe (10) e Incantesimi (2)

### 8.1 Truppe
Spazio = capacità esercito occupata. Costi in Sap (tranne l'élite, in Shards). Statistiche L1 → livello massimo (8; élite 6). Crescita per livello: HP ×1,13; DPS ×1,14; costo ×1,30 (élite ×1,25); tempo addestramento +4% per livello.

| Truppa | Ruolo | Spazio | HP | DPS | Veloc. (celle/s) | Raggio | Bersagli | Preferenza | Costo L1 | Addestr. L1 | Caserma |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Cogling** | Mischia base | 1 | 45 → 106 | 11 → 28 | 2,0 | 0,6 | terra | qualsiasi vicino | 25 | 10 s | 1 |
| **Slingwisp** | Distanza | 1 | 33 → 78 | 14 → 35 | 2,2 | 5,0 | terra+aria | qualsiasi vicino | 45 | 15 s | 2 |
| **Bulwark** | Tank (provoca) | 5 | 420 → 988 | 18 → 45 | 1,4 | 0,8 | terra | difese | 250 | 1 m 30 s | 3 |
| **Magpie** | Saccheggiatore | 1 | 28 → 66 | 17 → 43 (×2 vs risorse) | 3,4 | 0,6 | terra | depositi/estrattori | 60 | 14 s | 4 |
| **Kegger** | Distruttore di mura | 2 | 22 → 52 | esplosione 60 → 160 (×40 vs mura, raggio 1,2) | 2,6 | 0,5 | mura | mura | 120 | 30 s | 5 |
| **Rustjaw** | Anti-difesa (salta mura) | 4 | 270 → 635 | 36 → 90 (×1,5 vs difese) | 3,0 | 0,8 | terra | difese | 300 | 2 m | 6 |
| **Kitewing** | Volante | 2 | 95 → 223 | 26 → 65 | 3,2 | 0,8 | terra | qualsiasi vicino | 180 | 45 s | 7 |
| **Mender** | Guaritore (volante) | 8 | 520 → 1.220 | cura 48 → 118 /s, raggio 3 (solo terra) | 2,0 | – | alleati | alleato più ferito | 800 | 5 m | 8 |
| **Dirigible** | Volante pesante | 10 | 1.900 → 4.470 | 34 → 85, area 1,5 | 1,1 | 1,0 | terra | difese | 2.800 | 8 m | 9 |
| **Ember Warden** (élite) | Unità d'élite | 20 | 3.600 → 6.630 | 95 → 183 | 1,6 | 0,9 | terra | difese | 45 Shards | 30 m | 10 |

*Lantern Surge* (Ember Warden): una volta, quando scende sotto il 50% di HP → +50% DPS e cura 25% HP in 4 s.
Il **Bulwark** ha *taunt*: le difese bersagliano preferenzialmente unità con taunt entro 3 celle.

### 8.2 Incantesimi
Lo spazio spell occupa 2 per slot; slot = livello Forgia + 1 (2…6).
| Incantesimo | Raggio | Durata | Effetto L1 → L5 | Costo L1 → L5 | Livelli |
|---|---|---|---|---|---|
| **Mending Mist** (cura area) | 5,0 | 8 s | cura 28 → 58 HP/s | 4.000 → 9.770 Sap | 5 |
| **Fervor Surge** (potenziamento) | 4,0 | 6 s | +30% → +50% danno, +25% → +40% velocità | 6.500 → 15.900 Sap | 5 |

### 8.3 Caserma, Accampamento, Laboratorio
- **Caserma** (1, livelli 1–10): coda di addestramento = capacità esercito (si addestra con risorse; le truppe si vedono "marciare" in coda). Il livello sblocca la truppa (tabella sopra). Annullare un addestramento rimborsa 100%. Troppe truppe in coda per la capacità: rifiutate.
- **Accampamento** (fino a 4): capacità `[20, 25, 30, 35, 40, 45, 50, 55]` per livello → **max 20 (H1) → 220 (H10)** spazi.
- **Laboratorio** (Hall 3+, 8 livelli): il livello massimo di ricerca per truppa è `≤ livello lab`. Ricerca di truppa al livello L → costo `base(L) × fattore(truppa)` Sap con base L2…L8 = 10k · 30k · 80k · 200k · 400k · 750k · 1,2M e fattore Cogling 0,6 · Slingwisp 0,7 · Magpie 0,75 · Kegger 0,8 · Bulwark 0,9 · Kitewing/Rustjaw 1,0 · Mender 1,15 · Dirigible 1,3 (élite: `300 × 2^(L−2)` Shards), tempo = curva-tempo indice `L` (L2 = 10 m, L3 = 1 h … L8 = 2 g; élite ×1,3, max 3 g). **Una ricerca alla volta**. Totale ricerche: ~49 giorni.

---

## 9. Combattimento

### 9.1 Schieramento
- Campo = intera griglia 44×44. **Zona di schieramento consentita** = cornice esterna di 2 celle + qualsiasi cella libera a **> 2 celle (Chebyshev) da ogni edificio non-trappola**. Evidenziata in blu con bordo animato; fuori zona il tap mostra un "no".
- Tap su una carta truppa nella barra in basso poi tap in zona → 1 unità; **trascinamento lungo il bordo** → rilascio continuo (1 unità ogni 0,12 s, max 8 al secondo). Incantesimi: tap carta, tap posizione (raggio mostrato).
- Ordine truppe e incantesimi nella barra = ordine scelto in Esercito.

### 9.2 Simulazione deterministica
- **30 tick/s** a passo fisso, separata dal rendering (interpolato a 60 fps). RNG con seed a livello di battaglia (PCG32), stato in array piatti per prestazioni.
- Input registrati come `(tick, tipo, unità_o_incantesimo, x, y)` → replay.

### 9.3 IA delle truppe e pathfinding
1. **Selezione bersaglio** per preferenza (tabella 8.1), poi fallback "nearest building". Per preferenza "difese": difesa più vicina per distanza dal bordo del suo footprint (euclidea; la distanza di percorso per ogni candidato costerebbe un A* per edificio, vedi DECISIONS). Al massimo 24 nuove scelte di bersaglio per tick. Il Mender sceglie l'alleato ferito più vicino.
2. **A\*** su griglia 44×44, 8 direzioni, **no taglio di spigolo** diagonale tra due celle bloccate. Euristica octile.
3. **Mura**: costo di una cella-muro = `HP_muro / DPS_truppa` (secondi per abbatterla); costo cella libera = `1 / velocità`. Il percorso a costo minimo decide: aggirare se più veloce, **attaccare la muro** se il costo medio è inferiore. Il Kegger ignora il costo (abbatte sempre il tratto più economico); il Rustjaw salta (costo muro = 0 per 1 cella).
4. **Ricalcolo**: quando il bersaglio è distrutto, quando un muro sul percorso cade, o ogni 1,0 s se bloccato. **A\* incrementale**: le richieste entrano in coda e la simulazione espande al massimo **700 nodi per tick**, così il costo per tick resta limitato anche quando molte truppe cambiano bersaglio insieme; in attesa del percorso la truppa si avvicina in linea retta senza entrare negli edifici. Oltre 4.000 espansioni la ricerca restituisce un percorso parziale verso il nodo più promettente e ricalcola all'arrivo. **Riuso dei percorsi**: una truppa adiacente a un percorso già calcolato verso lo stesso bersaglio (stesso profilo di costo e stato delle mura) ne segue il tratto restante.
5. **Volanti** ignorano la griglia di ostacoli e volano in linea retta verso il bersaglio.
6. **Raggio d'attacco**: la truppa si ferma a distanza `≤ range` dal bordo del footprint del bersaglio.

### 9.4 IA delle difese
- Ciclo: ogni difesa mantiene un bersaglio; ricalcola ogni `0,5 s` o quando il bersaglio muore/esce dal range.
- **Priorità** (da tabella §5): `nearest` (più vicino), `nearest_air` (aria), `highest_hp_cluster` (centro del gruppo più numeroso, Lobber), `lowest_hp` (Arc Coil), `farthest_in_range` (Ballista), `highest_hp` (Thumper), `nearest_air_cluster` (Storm Pylon).
- **Taunt** del Bulwark ha priorità su tutto entro 3 celle.
- Proiettili simulati con vero tempo di volo; il danno si applica alla posizione del bersaglio all'impatto (area per Lobber/Pylon/Frost).
- **Cambio bersaglio** automatico se compare un bersaglio con priorità più alta (solo per `nearest*` e solo ogni 0,5 s).

### 9.5 Punteggio
- **% distruzione** = (numero edifici non-muro e non-trappola distrutti) ÷ (totale edifici non-muro e non-trappola), arrotondato per difetto.
- ★ (1) a **50%**; ★ (2) alla distruzione del **Faro Madre**; ★ (3) a **100%**. Massimo 3.
- **Timer 3:00** (180 s). La battaglia termina a 3★, a scadenza, quando non restano truppe/incantesimi schierabili e tutte le unità sono morte, o con **Arrenditi** (perde senza costo extra).
- Risultati: stelle, % distruzione, bottino (Cogs/Sap/Shards), trofei, XP. Vittoria = ≥ 1★.

### 9.6 Trofei
`delta = round(base × m)` con `m_vittoria = 1 + clamp((trofei_avv − trofei_giocatore)/400, −0,5, 0,5)` e `m_sconfitta = 1 − clamp(...)`. Base per stelle: **1★ +20 · 2★ +30 · 3★ +40**; **0★ → −25**.

### 9.7 Replay
Salvato (JSON compresso, <20 KB): seed, snapshot base (hash+dati), lista input. Riproduzione = ri-simulazione deterministica a passo fisso a 1×/2×/4×. Test (Fase 3): stesso replay ⇒ stesso risultato bit-a-bit.

### 9.8 Prestazioni di simulazione
Obiettivo: 150 truppe + ~60 edifici a 30 tick/s con A* a cache per bersaglio (campo di costo condiviso per bersaglio), 60 FPS di rendering.

---

## 10. Avversari

### 10.1 Campagna PvE — 25 livelli progettati a mano
Tabella completa in `BALANCE_TABLES.md` e `data/campaign.json`. Sintesi:

| # | Nome | Hall | Difese (B/L/S/A/Ba/T/F/Sp/P) | Mura | Note |
|---|---|---|---|---|---|
| 1 | Mossy Gate | 1 | 1/0/0/0/0/0/0/0/0 | 0 | Tutorial: Faro, una Boltpost, miniera e pozzo |
| 2 | Pebble Hollow | 2 | 2/0/…/0 | 10 | Porta singola nelle mura |
| 3 | Dewdrop Farm | 2 | 2/1/… | 20 | Mine esterne, esca per Magpie |
| 4 | Cricket Hill | 3 | 2/1/… | 30 | Bomb Trap |
| 5 | Thistle Fort | 3 | 2/1/1/… | 40 | Prima Skyspear |
| 6 | Mudwater Docks | 4 | 3/1/1/… | 50 | Base lunga e stretta |
| 7 | Rustbucket Yard | 4 | 3/2/1/1/… | 60 | Arc Coil al centro |
| 8 | Hornet Ridge | 5 | 3/2/1/1/… | 75 | Antiaerea a nord |
| 9 | Fungus Fen | 5 | 3/2/2/1/1/… | 90 | Prima Ballista |
| **10** | **The Gearmill** | 5 | 3/2/2/1/1/… | 110 | **BOSS 1**: doppio anello |
| 11 | Brambleback | 6 | 4/2/2/1/1/1/… | 125 | Thumper |
| 12 | Cobweb Cliffs | 6 | 4/3/2/2/1/1/… | 140 | Difese a scacchiera |
| 13 | Gloomtide Pier | 7 | 4/3/2/2/1/1/… | 150 | Banchina lunga, schieramento a un lato |
| 14 | Lanternless Alley | 7 | 4/3/3/2/2/1/1/… | 165 | Frost Spire |
| 15 | Cinder Orchard | 7 | 4/3/3/2/2/1/1/… | 175 | Depositi distribuiti |
| 16 | Wraith Reservoir | 8 | 5/3/3/2/2/1/1/… | 190 | Mine d'aria |
| 17 | Thunder Terrace | 8 | 5/4/3/3/2/2/1/1/… | 200 | Cinder Spout al centro |
| 18 | Frostbitten Fields | 8 | 5/4/3/3/2/2/1/1/… | 200 | Frost Spire sovrapposte |
| 19 | Smogspire | 9 | 5/4/3/3/2/2/2/1/… | 215 | Torre fumo |
| 20 | Mirror Marsh | 9 | 5/4/4/3/3/2/2/1/1 | 225 | Storm Pylon |
| **21** | **Bonecog Citadel** | 9 | 5/4/4/3/3/2/2/1/1 | 225 | **BOSS 2**: tre compartimenti |
| 22 | Stormcrow Keep | 10 | 6/4/3/3/2/2/2/1/1 | 250 | Hall 10 |
| 23 | Hollow Sun | 10 | 6/4/4/3/3/2/2/2/1 | 250 | Molte trappole |
| 24 | The Long Night Wall | 10 | 6/4/4/3/3/2/2/2/2 | 250 | Mura a lacuna nascosta |
| **25** | **Gloomqueen's Throne** | 10 | 6/4/4/3/3/2/2/2/2 | 250 | **BOSS FINALE** (Hall +30% HP) |

**Rampa di difficoltà** (dati in `campaign.json`, campo `difficulty`): nei livelli 1–10 i punti vita degli edifici e i danni delle difese sono moltiplicati per 0,45 · 0,55 · 0,65 · 0,72 · 0,80 · 0,85 · 0,90 · 0,94 · 0,97 · 1,00 (poi 1,00). Verifica con la simulazione: il livello 1 si vince con 3 stelle con 5 Cogling (l'esercito del tutorial), il livello 2 con ~10, il livello 3 dà 2 stelle con 15 Cogling.

Ogni livello ha layout **disegnato a mano** (coordinate in `data/campaign/NN.json`, Fase 3; la tabella sopra è la specifica di composizione, validata dal generatore: nessun livello eccede i massimi dell'Hall). Livelli difese = `max_level_at_hall − 1` (min 1) per i livelli normali, `max_level_at_hall` per i boss. Bottino: `cap_hall × (0,55 + 0,01·n)` Cogs e Sap, 60% del cap Shards. Ricompensa prima volta a 3★: `5 + n` Glimmers (totale **450**). Rigiocabili senza ricompensa Glimmers.

### 10.2 Basi generate proceduralmente ("PvP" simulato)
1. **Mappa trofei→Hall avversario**: `hall = clamp(1 + ⌊trofei/330⌋, 1, 10)` ± jitter (−1/0/+1 con pesi 20/60/20), non oltre ±1 dal Hall giocatore.
2. **Matchmaking**: trofei avversario ∈ `giocatore ± 150`; costo ricerca per Hall `[10,20,40,80,160,300,500,800,1200,1500]` Cogs; "Prossimo" ripete la ricerca pagando di nuovo.
3. **Generazione layout** (seed = `hash(giocatore_id, contatore_ricerca)`), algoritmo ad anelli:
   1. Piazza il Faro Madre nell'area centrale (`±3` celle dal centro, con rumore).
   2. **Anello 0 (core)**: 1–2 difese ad area/lento-alto-danno (Lobber, Thumper) entro 4 celle dall'Hall; Skyspear/Storm Pylon centrali per coprire l'Hall dall'aria.
   3. **Anello 1** (raggio 4–8): depositi, Arc Coil, Boltpost; **muri** formano un compartimento chiuso con 1–2 varchi (cella di spessore 1).
   4. **Anello 2** (raggio 8–14): estrattori, accampamenti, caserma, laboratorio, difese a lungo raggio (Ballista); secondo anello di mura con 1–3 compartimenti.
   5. **Esterno** (raggio 14–19): mine, sala del clan, ostacoli casuali, un paio di trappole.
   6. **Trappole**: vicino ai varchi dei muri e alle "autostrade" (percorsi più corti verso l'Hall).
   7. **Validazione**: nessuna sovrapposizione; ≥ 85% delle celle edificabili connesse (flood-fill) per evitare sacche irraggiungibili; difese ≥ 60% dentro il secondo anello. Se la validazione fallisce → rigenerazione con `seed+1`, max 8 tentativi, poi layout di riserva da campagna.
   8. Quantità e livelli = `COUNTS[h]` e `max_level_at_hall(h)`, riempiti al 65–100% (variabile).
4. **Plausibilità**: nome avversario da lista generativa (aggettivo+sostantivo), livello giocatore e trofei coerenti.

### 10.3 Attacchi subiti mentre si è offline
- Mentre il gioco è chiuso, il sistema genera attacchi simulati: intervallo casuale **4–10 h**, massimo **3 attacchi in 24 h** (se non c'è scudo).
- L'attacco è simulato col **motore di battaglia deterministico** al momento della riapertura con gli stessi motori (esercito avversario generato di Hall simile, composizione plausibile).
- **Scudo** automatico dopo l'attacco subito: distruzione ≥ 40% → **8 h**; ≥ 70% → **12 h**; 100% → **16 h**. Scudo **iniziale** nuovi giocatori: 24 h. Attaccare (campagna esclusa) interrompe lo scudo.
- Bottino rubato: stessa formula §3.4 applicata ai **tuoi** depositi (mai oltre il tetto Hall).
- **Registro difese**: elenco (timestamp, nome attaccante, stelle, % distruzione, risorse perse, trofei) con **replay**; indicatore di notifica nella schermata villaggio.

---

## 11. Progressione

### 11.1 Trofei e Leghe (8)
| # | Lega | Trofei | Gemme (1ª volta) | Bonus bottino vittorie |
|---|---|---|---|---|
| 1 | Wick | 0–299 | – | – |
| 2 | Spark | 300–599 | 5 | – |
| 3 | Ember | 600–999 | 10 | +5% |
| 4 | Flame | 1000–1399 | 20 | +8% |
| 5 | Blaze | 1400–1799 | 30 | +10% |
| 6 | Beacon | 1800–2399 | 50 | +15% |
| 7 | Lighthouse | 2400–3199 | 80 | +20% |
| 8 | Sunforge | 3200+ | 120 | +25% |

### 11.2 Obiettivi permanenti
16 obiettivi, 3 livelli (Bronzo/Argento/Oro; "Join the Hall" 1 livello): totale **3.125 Glimmers**. Elenco completo in `BALANCE_TABLES.md` (§Obiettivi): saccheggio Cogs/Sap, vittorie, stelle, difese distrutte, difese riuscite, ostacoli, livello Hall, trofei, campagna, incantesimi, truppe addestrate, potenziamenti, mura distrutte, Shards, clan.

### 11.3 Missioni giornaliere
3 al giorno estratte (seed per giorno) da un pool di 8: vincere 1 attacco (2 Glimmers), 5 stelle (2), 20k Cogs saccheggiati (5.000 Sap×Hall), 2 potenziamenti (2), addestrare 30 truppe (1), 3 ostacoli (3), lanciare 3 incantesimi (1), distruggere 10 difese (2). Rinnovo alla mezzanotte locale; non cumulabili. Ricompensa media ≈ **34 Glimmers/settimana**.
**Ciclo di login 7 giorni**: Cogs, Sap, 3 Glimmers, Cogs+Sap, 5 Glimmers, 100 Shards (o 5 Glimmers se Hall < 5), 15 Glimmers; ≈ **28 Glimmers/settimana**. Il ciclo non si azzera se si salta un giorno (si ferma e riparte).

### 11.4 Livello giocatore (XP)
30 livelli; `XP per salire(n) = round(12 · n^1,6)`. XP guadagnata da: completamento potenziamenti (⌊√secondi⌋), battaglie (10 XP/stella + 5 vittoria), obiettivi. Il livello è solo un indicatore di status (nessun blocco).

---

## 12. Clan (struttura dati e UI di base, estensione online futura)
- **Modello dati** (`data/` + `scripts/clan/`): `Clan{id, name, badge, description, trophy_min, members[], created_at}`, `Member{id, name, role(leader|co|member), trophies, donated, received}`, `ChatMessage{id, author, text, ts}`, `DonationRequest{id, member, troop_id, qty, filled}`.
- **Schermate**: Crea clan (nome, stemma tra 12 icone, descrizione, trofei minimi; costo 10.000 Cogs), Vista clan (membri ordinabili per trofei/donazioni), Chat locale con **membri simulati** (bot a risposte pre-scritte, localizzati), Cerca clan (lista generata proceduralmente).
- **Sala del Clan** (Hall 4+): capacità `[5, 10, 15, 20, 25]` membri simulati.
- **Interfaccia astratta `ClanService`** (offline = `LocalClanService`, futuro = `RemoteClanService`) per sostituire il backend senza toccare la UI.

---

## 13. Bilanciamento — verifica quantitativa

Tutte le tabelle: [`docs/BALANCE_TABLES.md`](docs/BALANCE_TABLES.md) e `data/csv/`. Verifica automatica: [`docs/BALANCE_REPORT.md`](docs/BALANCE_REPORT.md).

### 13.1 Tempo totale per completare ogni livello del Faro Madre
`Giorni stimati = max(timer Hall, lavoro_costruttori / (costruttori × 0,75))`, con costruttori `[2,2,3,3,4,4,5,5,5,5]` (ipotesi giocatore attivo che compra i costruttori).

| Hall | Timer Hall | Timer Hall cumulato | Lavoro costruttori (incrementale) | Costruttori | Giorni stimati | Giorni cumulati |
|---|---|---|---|---|---|---|
| 1 | — | — | 1 m 30 s | 2 | 0,0 | 0,0 |
| 2 | 5 m | 5 m | 11 m | 2 | 0,0 | 0,0 |
| 3 | 1 h | 1 h 5 m | 2 h 19 m | 3 | 0,0 | 0,0 |
| 4 | 4 h | 5 h 5 m | 13 h 39 m | 3 | 0,3 | 0,3 |
| 5 | 12 h | 17 h 5 m | 2 g 8 h | 4 | 0,8 | 1,1 |
| 6 | 1 g | 1 g 17 h | 7 g 10 h | 4 | 2,5 | 3,6 |
| 7 | 1 g 12 h | 3 g 5 h | 19 g 16 h | 5 | 5,2 | 8,8 |
| 8 | 2 g | 5 g 5 h | 36 g 24 h | 5 | 9,9 | 18,7 |
| 9 | 2 g 12 h | 7 g 17 h | 63 g | 5 | 16,8 | 35,5 |
| 10 | 3 g | 10 g 17 h | 119 g 22 h | 5 | 32,0 | **67,4** |

Il lavoro dei costruttori (edifici/difese/trappole, escluso lab) a Hall 10 completo = **250 giorni-costruttore**. Il laboratorio ha coda propria (**49 giorni** di ricerche totali).

### 13.2 Equilibrio risorse/tempo
Dall'Hall 6 il rapporto "giorni per accumulare le risorse / giorni di tempo" è **1,2–2,0** (con 4 attacchi/giorno al 60% del tetto bottino). Prima dell'Hall 6 il tratto richiede <3 giorni di risorse: non è un vincolo. Totali Hall 10: **160 M Cogs, 22 M Sap in edifici (più ~22 M Sap di ricerche e il flusso continuo di addestramento), 204k Shards** (difese). Se dopo i test di gioco il rapporto fosse fuori target, si regolano solo `PROD_GROWTH`, `LOOT_CAP`, costi finali in `gen_balance.py`.

### 13.3 Budget Glimmers (tutto guadagnabile)
| Fonte | Totale |
|---|---|
| Obiettivi permanenti | 3.125 |
| Campagna (25 livelli) | 450 |
| Leghe (1ª volta) | 315 |
| Ostacoli (media/giorno) | ≈ 4,4 |
| Missioni (media/settimana) | ≈ 34 |
| Login (per settimana) | ≈ 28 |
Costo costruttori 3–5 = 1.400. Entrate ricorrenti ≈ 13 Glimmers/giorno ⇒ 3° costruttore in ~15 giorni (prima con campagna/obiettivi).

### 13.4 Vincoli verificati automaticamente (`gen_balance.py`)
- **Capacità dei depositi**: a ogni livello di Hall, il costo singolo più alto disponibile (potenziamento del Faro e ricerche del laboratorio compresi) è ≤ 85% della capacità raggiungibile a quella Hall (report §6). Questa verifica è stata aggiunta in Fase 3 dopo che la partita automatica (test) si era bloccata a Hall 3: i depositi non potevano contenere il costo del Faro Madre 4.
- Tempo minimo = 10 s, massimo = 3 g (OK).
- Nessun livello campagna eccede quantità di difese/mura consentite dall'Hall (assert).
- Nessuna sezione "da definire": ogni sistema ha numeri concreti.

---

## 14. Avvio dell'app
1. Splash del motore **nero, senza immagine** (`boot_splash/show_image=false`).
2. `scenes/boot.tscn`: schermo nero e scritta bianca **"EroideGames"** centrata per **2 s in totale, dissolvenze incluse** (0,4 s in entrata, 1,2 s fissa, 0,4 s in uscita).
3. `scenes/main.tscn`: **splash di Lanternreach** (isola sospesa con la lanterna) in dissolvenza; intanto carica il salvataggio, applica il progresso offline, le missioni del giorno e gli attacchi subiti; durata minima 1,6 s.
4. Villaggio (con il tutorial alla prima partita).

## 15. Localizzazione
Tutto il testo in `localization/{it,en}.csv` (chiavi `ui.*`, `building.*`, `troop.*`, `campaign.NN.name`, `ach.*`, `daily.*`); nessuna stringa hardcoded. Default: lingua del sistema (it/en), fallback en.

## 16. Pianificazione per fasi successive
- **Fase 2**: ART_DIRECTION.md, asset, UI, audio, CREDITS.md.
- **Fase 3**: Godot 4.3, autoload (GameState, SaveManager, EconomyManager, TimeManager, AudioManager, EventBus), salvataggio cifrato con versione schema + migrazione, tutorial 10 min, test GUT.
- **Fase 4**: repo GitHub, workflow Android, release.
