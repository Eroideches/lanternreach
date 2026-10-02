# Crediti

## Asset di terze parti inclusi nel gioco
| Asset | Autore | Licenza | File |
|---|---|---|---|
| **Lilita One** (font titoli) | Juan Montoreano | SIL Open Font License 1.1 | `assets/fonts/LilitaOne-Regular.ttf`, licenza in `assets/fonts/OFL-LilitaOne.txt` |
| **Nunito** (font testo, variabile) | The Nunito Project Authors (Vernon Adams, Cyreal, Jacques Le Bailly) | SIL Open Font License 1.1 | `assets/fonts/Nunito-Variable.ttf`, licenza in `assets/fonts/OFL-Nunito.txt` |

Fonte dei font: repository ufficiale Google Fonts (`github.com/google/fonts`, cartelle `ofl/lilitaone`, `ofl/nunito`).

## Asset originali del progetto
Tutta la grafica (edifici, truppe, effetti, terreno, icone, UI, icona app, splash, logo) e tutto l'audio (43 effetti, 2 musiche) sono **creati per questo progetto** e generati dagli script in `tools/art/`. Nessun campione, sprite o loop di terze parti è usato.

| Categoria | Origine | Licenza |
|---|---|---|
| Grafica (`assets/atlas`, `assets/sprites`, `assets/branding`, `assets/ui`) | generata da `tools/art/*.py` | **CC0 1.0** (pubblico dominio) |
| Audio (`assets/audio`) | sintetizzato da `tools/art/audio.py` | **CC0 1.0** |
| Codice del gioco e degli strumenti | Lanternreach | MIT (vedi `LICENSE`) |

## Strumenti di sviluppo (non inclusi nell'APK)
| Strumento | Licenza | Uso |
|---|---|---|
| Godot Engine 4.3 | MIT | motore di gioco (incluso nell'APK come runtime, licenza MIT: © Juan Linietsky, Ariel Manzur e contributori) |
| CairoSVG | LGPL-3.0 | rasterizzazione SVG→PNG in fase di build degli asset |
| Pillow | MIT-CMU (HPND) | composizione immagini, atlas |
| NumPy | BSD-3-Clause | sintesi audio |
| GUT (Godot Unit Test) 9.3.0 | MIT | framework di test, in `addons/gut` (escluso dall'APK) |
| Xvfb, Mesa llvmpipe | MIT/X11 | display virtuale e rendering software per le catture del gioco reale (solo sviluppo) |
