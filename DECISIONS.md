# DECISIONS

Decisioni prese dove il brief era ambiguo o lasciava più strade. Formato: **decisione** — motivo.

## Fase 1
1. **Nome e ambientazione: "Lanternreach"**, arcipelago di isole sospese, Lanternari vs Marea d'Ombra — nome/fiaba originali, nessun riferimento a titoli esistenti.
2. **Tre risorse + premium**: Cogs, Sap, Starshards (rara da Hall 5), Glimmers (solo in gioco) — il brief chiede 2 base + 1 rara + premium guadagnabile.
3. **Footprint solo quadrati** (1×1…4×4) — la "rotazione" è solo speculare visiva; elimina la validazione per orientamento.
4. **Zona di schieramento** = cornice esterna di 2 celle + celle libere a >2 celle da ogni edificio — il brief chiede "fuori dal perimetro della base"; la cornice garantisce sempre uno spazio, la regola "a >2 celle" evita schieramento dentro le mura.
5. **% distruzione conta solo edifici non-muro e non-trappola**, pesati 1 ciascuno — numero stabile e leggibile; le mura non devono distorcere la percentuale.
6. **Mura si potenziano istantaneamente (solo costo)** — con 250 segmenti i timer rendevano impraticabile il gioco (verificato dal report: 866 → 250 giorni-costruttore a Hall 10). Eccezione unica alla regola "tutto ha timer".
7. **Tempo massimo 3 giorni raggiunto solo dall'Hall 10**; le difese a L10 tra 36 e 72 h — il brief dice "fino a 3 giorni ai livelli alti".
8. **Una sola Caserma e un solo Laboratorio**; l'Accampamento fino a 4 — semplifica UI/coda; la capacità esercito (20→220) scala con gli accampamenti.
9. **Sblocco truppe = livello Caserma**, livello massimo truppa = livello Laboratorio, Hall 3 sblocca il lab — tre leve chiare di progressione.
10. **Livelli difese massimi con Hall h** secondo `req_hall` lineare (formula in GDD §2.3) — evita 100 numeri scritti a mano e garantisce monotonicità.
11. **Livello giocatore: 30 livelli** invece di 50 — con XP da potenziamenti (~27k) + battaglie, 50 livelli non erano raggiungibili (619k XP).
12. **Costruttori: coda max 3**; costo risorse scalato all'avvio — evita di bloccare risorse in coda.
13. **Valuta premium sommata a ~13/giorno** (ostacoli+missioni+login) più grandi blocchi (obiettivi 3.125, campagna 450, leghe 315) — il 3° costruttore in ~15 giorni.
14. **Campagna: specifica di composizione in Fase 1, coordinate dei layout in Fase 3** — i layout vanno testati col motore (pathfinding/leggibilità); la composizione è già validata dal generatore.
15. **Ricerca di mercato eseguita dalla conoscenza di dominio, non via web** — non ho acceduto a ricerche web in tempo reale; i numeri non sono copiati da nessun titolo e sono validati dal generatore.
16. **Matchmaking e attacchi offline sono simulati localmente**; il clan ha interfaccia `ClanService` astratta — per sostituire il backend con uno online senza toccare la UI.
17. **Starshards rubabili ma con tetto basso** (20→450 per attacco) e depositate nella Cassa Shard — mantiene la rarità.
18. **Tutto generato da `tools/gen_balance.py`** — numeri JSON/CSV/MD sempre allineati; modificare i parametri lì e rigenerare.

## Fase 2
19. **Grafica 100% procedurale vettoriale** (SVG generato da Python → PNG) invece di sprite disegnati a mano — garantisce originalità, coerenza (un solo kit di primitive e luce) e rigenerabilità; nessun asset di terze parti oltre ai font.
20. **Sprite a 2× della griglia logica** (cella 128×64) — nitidi su 1080p con lo zoom predefinito; Godot li scala in base allo zoom della camera.
21. **Animazioni idle come overlay separati** (fumo, bandiere, ingranaggi rotanti, scintille) invece di frame interi dell'edificio — atlas 5–10 volte più leggeri e più varietà (le bandiere hanno 5 colori).
22. **Truppe in 2 direzioni disegnate + specchiatura** (4 direzioni effettive) — previsto dal brief come alternativa alle 8 direzioni; dimezza il peso dei fogli.
23. **Tier visivo ogni 2 livelli** (5 tier) con progressione dei materiali legno → pietra → intonaco/rame → acciaio/ottone → marmo/oro/cristallo, più dettagli aggiuntivi per tier.
24. **Due palette di fazione**: i villaggi della campagna usano la palette Marea d'Ombra; le basi PvP simulate usano quella dei Lanternari (sono altri giocatori). La Marea d'Ombra non usa il verde (riservato al Sap).
25. **Audio sintetizzato** (numpy) in WAV 16 bit 32 kHz mono — originale e CC0 per costruzione; 7,3 MB in totale, ben sotto il budget dell'APK. Il loop musicale è senza giunte (la coda del riverbero viene riavvolta all'inizio).
26. **Area touch minima = 132 px di riferimento** (48 dp sul caso peggiore 5″) con aree di tocco estese per i controlli visivamente piccoli.
27. **Wordmark del logo in tinta piatta crema** (il gradiente SVG nel testo non è supportato da CairoSVG) — leggibile e coerente con lo stile a contorno spesso.

## Fase 3
28. **Sequenza di avvio** (richiesta): splash del motore nero senza immagine → `boot.tscn` con "EroideGames" per 2 s **dissolvenze incluse** (0,4 + 1,2 + 0,4 s) → splash di Lanternreach come schermata di caricamento (minimo 1,6 s) → villaggio/tutorial.
29. **Bilanciamento corretto dopo il test di partita automatica**: i depositi non contenevano il costo del Faro Madre dal livello 4 in su (bloccando la progressione a Hall 3). Capacità dei depositi ridisegnate (1.500 → 1.200.000), costi del Faro ridotti (5M → 2,6M a L10), ricerche del laboratorio legate alla capacità (prima il Dirigibile L8 costava 10,7M di Sap). Il generatore ora verifica capacità ≥ costo a ogni Hall.
30. **Scelta del bersaglio per distanza euclidea dal bordo** invece che per distanza di percorso: calcolare un A* per ogni candidato costerebbe fino a ~100 ricerche per truppa; il percorso reale (con mura pesate) e' comunque calcolato con A* verso il bersaglio scelto.
31. **A\* incrementale con budget per tick** (700 espansioni) e **riuso dei percorsi** tra truppe adiacenti: stesso algoritmo e stesse decisioni, ma costo per tick limitato. Profilo con 150 unità contro una base Hall 10 su CPU da 2,3 GHz (Pentium 4415U, paragonabile a uno smartphone di fascia media): media 1,9 ms per tick, picco 21 ms (prima 12 ms medi e picchi di 382 ms).
32. **Kegger**: il muro bersaglio è il primo sulla linea retta (Bresenham) verso l'edificio più vicino, invece di un A* sincrono che interferirebbe con la ricerca incrementale in corso.
33. **Interfaccia costruita in codice** (UIK + Modal) invece di file .tscn per ogni pannello: un solo stile, meno file da mantenere, testabile in headless.
34. **Layout dell'HUD senza `await`** (posizionamento con `call_deferred`): nei test headless di GUT le coroutine in attesa del frame non ripartivano; la soluzione è anche più robusta nel gioco.
35. **Le gemme (Glimmers) possono comprare le risorse mancanti** con la curva `resource_to_gem_points` (GDD §4.3), sempre con conferma.
36. **Rampa di difficoltà della campagna** (livelli 1–10: punti vita e danni dal 45% al 100%) e **livello 1 semplificato**: la prova del tutorial nell'interfaccia reale ha mostrato che 5 Cogling perdevano il primo attacco; ora lo vincono con 3 stelle.
37. **Gli incassi non riducono mai le risorse**: se il giocatore è già oltre il tetto dei depositi, un guadagno non le abbassa più (bug trovato con le catture del gioco reale).
38. **Verifica visiva del gioco reale** con display virtuale Xvfb e rendering software (llvmpipe), senza aprire finestre sul desktop: `tools/capture.tscn` gioca e fotografa 21 schermate (in `docs/screens/`), tutorial completo compreso.
