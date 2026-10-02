# Changelog

## 1.0.0 — Fase 4: GitHub, build e release
- Repository pubblico con README, GDD, ART_DIRECTION, CREDITS, DECISIONS, CHANGELOG e licenza MIT.
- `export_presets.cfg`: preset "Android" (com.lanternreach.game, build Gradle con minSdk 24 / targetSdk 34, arm64-v8a + armeabi-v7a, nessun permesso).
- Workflow `.github/workflows/android-build.yml`: a ogni push su main (e manualmente) importa il progetto, controlla gli script, esegue i test GUT (fallisce su test falliti o SCRIPT ERROR), genera un keystore di debug, esporta l'APK in headless, lo verifica (SDK, firma), lo pubblica come artifact e come allegato di una Release `v<versione>-build.<n>`.

## 0.3.0 — Fase 3: sviluppo
- Progetto Godot 4.3 (renderer Compatibility, orizzontale, stretch `canvas_items`).
- **Avvio**: splash del motore nero, poi "EroideGames" per 2 s (dissolvenze incluse), poi splash di Lanternreach con caricamento.
- **Autoload**:
  - EventBus, Balance (dati JSON), Art (atlas), TimeManager (timestamp reali e protezione orologio);
  - GameState, EconomyManager, Progression;
  - SaveManager (JSON cifrato, migrazioni, autosalvataggio), AudioManager (bus Music/SFX/UI), Router.
- **Villaggio**:
  - griglia isometrica, edifici con overlay animati, cantieri, raccolta con particelle verso l'HUD;
  - modalità modifica con long-press, piazzamento dal negozio, mura tracciate trascinando;
  - camera touch con pan, pinch-zoom, tap e inerzia.
- **Battaglia**:
  - simulazione deterministica a 30 tick/s;
  - A* incrementale con mura pesate e riuso dei percorsi;
  - IA delle difese con priorità e proiettili, trappole, incantesimi;
  - stelle, bottino, trofei, ricognizione, schieramento a trascinamento, replay a 1x/2x/4x.
- **Contenuti**:
  - campagna di 25 livelli disegnati a mano, con rampa di difficoltà;
  - basi procedurali con generatore ad anelli e validazione, attacchi offline con scudo e registro difese.
- **Progressione e clan**: obiettivi, missioni giornaliere, accesso di 7 giorni, leghe, livelli del giocatore; clan locale (crea, cerca, entra, chat simulata).
- **Interfaccia**: kit UI, pannelli modali animati (≤ 300 ms), tutorial interattivo, impostazioni, localizzazione it/en (377 chiavi).
- **Bilanciamento**:
  - depositi e costi del Faro Madre ricalibrati: ogni costo sta nella capacità della Hall corrispondente, con verifica automatica;
  - ricerche del laboratorio legate alla capacità.
- **Test**: 76 test GUT, tra cui 100 battaglie casuali, prestazioni con 150 unità e partita automatica fino al Faro Madre 5. Più verifica nel gioco reale con `tools/capture.tscn`.

## 0.2.0 — Fase 2: direzione artistica
- ART_DIRECTION.md, grafica procedurale vettoriale (edifici in 5 tier e 2 fazioni, truppe animate, effetti, terreno, icone, UI 9-patch, tema), audio sintetizzato (43 effetti, 2 musiche in loop), icona app e splash, CREDITS.md.

## 0.1.0 — Fase 1: game design
- GDD.md, tabelle di bilanciamento generate (JSON/CSV/Markdown) con report di verifica, DECISIONS.md.
