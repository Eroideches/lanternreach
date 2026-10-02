# Report di verifica del bilanciamento

Generato da `tools/gen_balance.py`. Tutti i numeri sono derivati dalle tabelle in `data/`.


## 1. Tempo totale per completare ogni livello dell'Edificio Centrale

Colonne: **Timer Hall** = solo il timer di potenziamento dell'Hall (limite inferiore, seriale);
**Lavoro costruttori** = tempo-costruttore *aggiuntivo* per portare tutti gli edifici/difese/mura/trappole al massimo consentito da quell'Hall (escluso il laboratorio, che ha coda propria);
**Giorni stimati** = max(timer Hall, lavoro / (costruttori x 0.75)).

| Hall | Timer Hall | Timer Hall cumulato | Lavoro costruttori (incrementale) | Costruttori | Giorni stimati | Giorni cumulati |
|---|---|---|---|---|---|---|
| 1 | 0s | 0s | 1m 30s | 2 | 0.0 | 0.0 |
| 2 | 5m | 5m | 11m 20s | 2 | 0.0 | 0.0 |
| 3 | 1h | 1h 5m | 2h 19m 15s | 3 | 0.0 | 0.0 |
| 4 | 4h | 5h 5m | 13h 39m 17s | 3 | 0.3 | 0.3 |
| 5 | 12h | 17h 5m | 2g 7h 51m | 4 | 0.8 | 1.1 |
| 6 | 1g | 1g 17h 5m | 7g 10h 6m | 4 | 2.5 | 3.6 |
| 7 | 1g 12h | 3g 5h 5m | 19g 15h 33m | 5 | 5.2 | 8.8 |
| 8 | 2g | 5g 5h 5m | 36g 23h 59m | 5 | 9.9 | 18.7 |
| 9 | 2g 12h | 7g 17h 5m | 63g 6m | 5 | 16.8 | 35.5 |
| 10 | 3g | 10g 17h 5m | 119g 22h 3m | 5 | 32.0 | 67.4 |


## 2. Costo risorse incrementale per livello Hall vs. produzione

Produzione/giorno = (n. estrattori x produzione/h x 24) con estrattori al livello massimo consentito, **limitata dalla capacita' dei depositi** nell'ipotesi che il giocatore raccolga una volta al giorno (cap = capacita' interna estrattori + depositi). 'Bottino' stimato = 4 attacchi/giorno al 60% del cap Hall. Giorni risorse = costo Cogs / (produzione + bottino).

| Hall | Cogs richiesti | Sap richiesti | Shards | Prod/giorno (ognuna) | Bottino/giorno | Giorni risorse | Giorni tempo | Rapporto risorse/tempo |
|---|---|---|---|---|---|---|---|---|
| 1 | 1.940 | 840 | 0 | 9.600 | 1.200 | 0.3 | 0.0 | 436.50 |
| 2 | 13.695 | 2.539 | 0 | 19.872 | 3.600 | 0.9 | 0.0 | 177.20 |
| 3 | 42.351 | 17.118 | 0 | 36.576 | 12.000 | 1.0 | 0.0 | 22.29 |
| 4 | 165.416 | 40.765 | 0 | 63.120 | 36.000 | 1.7 | 0.3 | 6.60 |
| 5 | 471.627 | 154.349 | 0 | 104.400 | 96.000 | 2.4 | 0.8 | 3.03 |
| 6 | 1.542.746 | 378.600 | 0 | 144.000 | 216.000 | 4.3 | 2.5 | 1.73 |
| 7 | 3.828.787 | 1.250.789 | 0 | 231.840 | 432.000 | 5.8 | 5.2 | 1.10 |
| 8 | 13.062.046 | 2.741.900 | 12.000 | 320.880 | 720.000 | 12.5 | 9.9 | 1.27 |
| 9 | 38.182.315 | 7.445.600 | 44.400 | 441.840 | 1.080.000 | 25.1 | 16.8 | 1.49 |
| 10 | 102.858.221 | 9.790.585 | 148.000 | 696.960 | 1.440.000 | 48.1 | 32.0 | 1.51 |


Obiettivo di design: rapporto risorse/tempo tra 0.5 e 2.0 **dall'Hall 6 in poi**. Hall 1-5: l'intero tratto richiede < 3 giorni di risorse e le risorse iniziali, il bottino della campagna e i tutorial lo rendono irrilevante; nel report il rapporto li' non e' un vincolo di design. La colonna Sap esclude ricerche di laboratorio e addestramento truppe (principale pozzo di Sap, vedi sezione 4).


## 3. Budget valuta premium (Glimmers) ottenibile solo giocando

| Fonte | Totale (gemme) |
|---|---|
| Obiettivi permanenti (tutti i livelli) | 3125 |
| Campagna: 25 livelli, 3 stelle, 1a volta | 450 |
| Leghe (prima volta in ciascuna) | 315 |
| Ostacoli: media/giorno | 4.4 |
| Missioni giornaliere: media/settimana | 34 |
| Login 7 giorni: per settimana | 28 |


Costo costruttori 3-5: 1400 gemme. Entrate ricorrenti ~ 13.3 gemme/giorno; un giocatore attivo puo' pagarsi il 3 costruttore in ~15 giorni (anche prima grazie a campagna/obiettivi).


## 4. Totali di sistema (tutto al massimo con Hall 10)

| Voce | Valore |
|---|---|
| Lavoro costruttori totale (edifici, difese, mura, trappole, Hall) | 249g 23h 51m (250 giorni-costruttore) |
| Cogs totali | 160.169.144 |
| Sap totali | 21.823.085 |
| Shards totali (difese) | 204.400 |
| Ricerca laboratorio totale (coda singola) | 49g 5h 26m (49 giorni) |
| Costo ricerca Sap / Shards | 21.893.000 / 9.300 |
| Durata stimata fino a Hall 10 completo (costruttori) | ~67 giorni |
| Livelli giocatore: XP cumulato a livello 30 (cap) | 33.368 |
| XP totale ottenibile dai potenziamenti (somma radice tempo) | 27.111 |


## 5. Controllo estremi tempi

Tempo minimo: cog_mine L1 = 10s (vincolo >= 10s: OK). Tempo massimo: lantern_hall L10 = 3g (vincolo <= 3 giorni: OK).


## 6. Capacità dei depositi vs costo singolo più alto

Capacità = deposito del Faro Madre + (n. depositi x capacità al livello massimo consentito). Ogni costo (potenziamento del Faro compreso, ricerche del laboratorio comprese) deve essere <= capacità della Hall in cui è disponibile, con margine.

| Hall | Capacità (ciascuna risorsa) | Costo Cogs più alto | Costo Sap più alto | Esito (<= 85%) |
|---|---|---|---|---|
| 1 | 2.000 | 1.000 (Faro Madre -> 2) | 250 (army_camp L1) | OK |
| 2 | 4.500 | 3.000 (Faro Madre -> 3) | 717 (army_camp L2) | OK |
| 3 | 20.000 | 15.000 (Faro Madre -> 4) | 5.000 (laboratory L1) | OK |
| 4 | 54.000 | 40.000 (Faro Madre -> 5) | 13.000 (ricerca dirigible L2) | OK |
| 5 | 188.000 | 150.000 (Faro Madre -> 6) | 40.000 (spell_forge L1) | OK |
| 6 | 406.000 | 320.000 (Faro Madre -> 7) | 104.000 (ricerca dirigible L4) | OK |
| 7 | 1.072.000 | 850.000 (Faro Madre -> 8) | 260.000 (ricerca dirigible L5) | OK |
| 8 | 1.984.000 | 1.500.000 (Faro Madre -> 9) | 606.000 (spell_forge L4) | OK |
| 9 | 3.328.000 | 2.600.000 (Faro Madre -> 10) | 1.500.000 (spell_forge L5) | OK |
| 10 | 5.056.000 | 3.500.000 (storm_pylon L10) | 2.500.000 (laboratory L8) | OK |
