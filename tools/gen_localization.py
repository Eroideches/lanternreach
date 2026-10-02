#!/usr/bin/env python3
"""Genera localization/strings.csv (chiavi, en, it) e verifica che ogni chiave usata nel codice esista.

Le chiavi dinamiche (building.<id>, troop.<id>, ach.<id>.name, campaign.NN.name, ...) sono generate dai dati.
Uso: python3 tools/gen_localization.py
"""
import csv
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
OUT = os.path.join(ROOT, "localization", "strings.csv")

S = {}


def k(key, en, it):
    S[key] = (en, it)


# ------------------------------------------------------------------ UI base
for key, en, it in [
    ("ui.back", "Back", "Indietro"), ("ui.cells", "cells", "celle"), ("ui.hall_short", "Hall", "Faro"),
    ("ui.in_progress", "In progress", "In corso"), ("ui.instant", "Instant", "Istantaneo"), ("ui.lv", "Lv", "Lv"),
    ("ui.max_level", "Maximum level reached", "Livello massimo raggiunto"), ("ui.next", "Next", "Avanti"),
    ("ui.no", "No", "No"), ("ui.ok", "OK", "OK"), ("ui.requires_hall", "Requires Mother Lantern Lv %d", "Richiede Faro Madre Lv %d"),
    ("ui.time", "Time", "Tempo"), ("ui.yes", "Yes", "Sì"),
    ("time.d", "d", "g"), ("time.h", "h", "h"), ("time.m", "m", "m"), ("time.s", "s", "s"),
    ("boot.loading", "Loading...", "Caricamento..."),
    ("player.default_name", "Lanternkeeper", "Lanternaro"),
    ("hud.attack", "ATTACK!", "ATTACCA!"), ("hud.max", "Max:", "Max:"), ("hud.quests", "Goals", "Obiettivi"),
    ("hud.army", "Army", "Esercito"), ("hud.shop", "Shop", "Negozio"), ("hud.clan", "Clan", "Clan"),
    ("hud.log", "Defense", "Difese"), ("hud.settings", "Options", "Opzioni"),
    ("act.cancel", "Cancel", "Annulla"), ("act.clan", "Clan", "Clan"), ("act.collect", "Collect", "Raccogli"),
    ("act.info", "Info", "Info"), ("act.move_title", "Move building", "Sposta edificio"),
    ("act.rearm", "Rearm traps", "Riarma trappole"), ("act.remove", "Remove", "Rimuovi"),
    ("act.research", "Research", "Ricerca"), ("act.speedup", "Speed up", "Accelera"), ("act.spells", "Spells", "Incantesimi"),
    ("act.train", "Train", "Addestra"), ("act.upgrade", "Upgrade", "Potenzia"),
    ("act.wall_hint", "drag from the wall to draw a line", "trascina dal muro per tracciare una fila"),
    ("act.walls_all", "Upgrade all", "Potenzia tutte"),
    ("army.finish_now", "Finish now", "Completa ora"), ("army.queue_empty", "Training queue empty", "Coda di addestramento vuota"),
    ("army.ready_hint", "Ready army (tap - or drag out to remove; drag a card here to add)", "Esercito pronto (tocca - o trascina fuori per rimuovere; trascina qui una carta per aggiungere)"),
    ("army.space", "Space", "Spazio"), ("army.spells_title", "Spells", "Incantesimi"), ("army.title", "Army", "Esercito"),
    ("army.req_barracks", "Barracks Lv %d", "Caserma Lv %d"), ("army.req_forge", "Forge Lv %d", "Forgia Lv %d"),
    ("army.tab.troop", "Troops", "Truppe"), ("army.tab.spell", "Spells", "Incantesimi"),
    ("attack.campaign", "Campaign: the Gloomtide", "Campagna: la Marea d'Ombra"), ("attack.find", "Find a match", "Cerca avversario"),
    ("attack.locked", "Win the previous level first", "Vinci prima il livello precedente"),
    ("attack.no_army", "Train some troops first!", "Addestra prima delle truppe!"), ("attack.pvp", "Multiplayer", "Multigiocatore"),
    ("attack.pvp_desc", "Raid other Lanternkeepers' villages: steal Cogs and Sap and win trophies.", "Assalta i villaggi di altri Lanternari: ruba Cogs e Sap e vinci trofei."),
    ("attack.shield_warning", "Attacking removes your shield.", "Attaccare rimuove il tuo scudo."),
    ("attack.title", "Attack", "Attacca"), ("attack.your_army", "Your army", "Il tuo esercito"),
    ("battle.cannot_deploy", "You can't deploy here", "Non puoi schierare qui"), ("battle.destruction", "Destruction: %d%%", "Distruzione: %d%%"),
    ("battle.end", "End battle", "Termina"), ("battle.ends_in", "Battle ends in", "La battaglia termina tra"),
    ("battle.home", "Return home", "Torna a casa"), ("battle.loot_available", "Available loot:", "Bottino disponibile:"),
    ("battle.next", "Next", "Prossimo"), ("battle.replay", "Replay", "Replay"),
    ("battle.scouting", "Scouting: the battle starts in", "Ricognizione: la battaglia inizia tra"),
    ("battle.surrender_confirm", "End the battle now? Troops already deployed are lost.", "Terminare la battaglia adesso? Le truppe schierate vanno perse."),
    ("builders.buy", "Hire builder #%d", "Ingaggia il costruttore n. %d"), ("builders.count", "Free builders: %d / %d", "Costruttori liberi: %d / %d"),
    ("builders.max", "You have all the builders!", "Hai già tutti i costruttori!"), ("builders.queue", "Queued jobs: %d", "Lavori in coda: %d"),
    ("builders.title", "Builders", "Costruttori"),
    ("clan.badge", "Badge", "Stemma"), ("clan.browse", "Join a clan", "Unisciti a un clan"), ("clan.chat_placeholder", "Write a message...", "Scrivi un messaggio..."),
    ("clan.create", "Create clan", "Crea clan"), ("clan.description", "Description", "Descrizione"), ("clan.join", "Join", "Entra"),
    ("clan.join_fail", "You can't join this clan (trophies or Clan Hall missing)", "Non puoi entrare in questo clan (trofei o Sala del Clan mancanti)"),
    ("clan.leave", "Leave", "Esci"), ("clan.name", "Name", "Nome"), ("clan.name_short", "The name is too short", "Il nome è troppo corto"),
    ("clan.need_hall", "Build the Clan Hall (Mother Lantern Lv 4) to create or join a clan.", "Costruisci la Sala del Clan (Faro Madre Lv 4) per creare o unirti a un clan."),
    ("clan.send", "Send", "Invia"), ("clan.title", "Clan", "Clan"), ("clan.trophy_min", "Min. trophies", "Trofei minimi"),
    ("clan.role.leader", "Leader", "Capo"), ("clan.role.co", "Co-leader", "Vice"), ("clan.role.member", "Member", "Membro"),
    ("clan.desc.0", "Friendly clan, all are welcome!", "Clan amichevole, tutti benvenuti!"),
    ("clan.desc.1", "We attack every day. Active players only.", "Attacchiamo ogni giorno. Solo giocatori attivi."),
    ("clan.desc.2", "Keepers of the night lanterns.", "Custodi delle lanterne notturne."),
    ("clan.desc.3", "Gears, sap and good company.", "Ingranaggi, linfa e buona compagnia."),
    ("clan.chat.welcome", "A new Lanternkeeper joined the clan!", "Un nuovo Lanternaro è entrato nel clan!"),
    ("clan.bot.0", "Welcome! Have fun!", "Benvenuto! Divertiti!"), ("clan.bot.1", "Who wants to attack together tonight?", "Chi attacca stasera?"),
    ("clan.bot.2", "My Lobber finally reached level 5!", "Il mio Lobber è finalmente al livello 5!"),
    ("clan.bot.3", "Tip: build walls around your storages.", "Consiglio: metti le mura intorno ai depositi."),
    ("clan.bot.4", "Great raid, well done!", "Bell'assalto, complimenti!"), ("clan.bot.5", "Anyone up for the Gloomtide campaign?", "Qualcuno sta facendo la campagna della Marea d'Ombra?"),
    ("clan.bot.6", "Remember to collect your mines!", "Ricordatevi di raccogliere le miniere!"), ("clan.bot.7", "Lanterns up!", "Lanterne in alto!"),
    ("dlg.buy_missing", "You are missing some resources. Buy them for %d Glimmers?", "Ti mancano delle risorse. Acquistarle per %d Glimmers?"),
    ("dlg.cancel_job", "Cancel this job? You will get back 50% of the resources.", "Annullare il lavoro? Recupererai il 50% delle risorse."),
    ("dlg.speedup", "Finish now for %d Glimmers?", "Completare subito per %d Glimmers?"),
    ("err.busy", "Busy: already working", "Occupato: già in lavorazione"), ("err.hall_required", "Upgrade the Mother Lantern first", "Prima potenzia il Faro Madre"),
    ("err.invalid_place", "You can't place it there", "Non puoi posizionarlo lì"), ("err.limit", "Limit reached for your Mother Lantern level", "Limite raggiunto per il livello del Faro Madre"),
    ("err.locked", "Not unlocked yet", "Non ancora sbloccato"), ("err.max_level", "Already at maximum level", "Già al livello massimo"),
    ("err.no_builder", "All builders are busy", "Tutti i costruttori sono occupati"), ("err.no_glimmers", "Not enough Glimmers", "Glimmers insufficienti"),
    ("err.no_resources", "Not enough resources", "Risorse insufficienti"), ("err.no_space", "Not enough space in the army camps", "Spazio insufficiente negli accampamenti"),
    ("err.no_space_map", "No free space on the island", "Nessuno spazio libero sull'isola"), ("err.queue_full", "The builder queue is full", "La coda dei costruttori è piena"),
    ("lab.idle", "No research in progress", "Nessuna ricerca in corso"), ("lab.req", "Lab Lv %d", "Lab Lv %d"),
    ("lang.it", "Italiano", "Italiano"), ("lang.en", "English", "English"),
    ("leagues.bonus", "+%d%% loot", "+%d%% bottino"), ("leagues.title", "Leagues", "Leghe"), ("leagues.your", "Your trophies: %s", "I tuoi trofei: %s"),
    ("log.ago", "%s ago", "%s fa"), ("log.destruction", "destruction %d%%", "distruzione %d%%"), ("log.empty", "No attacks so far!", "Nessun attacco subito. Per ora!"),
    ("log.no_shield", "No active shield", "Nessuno scudo attivo"), ("log.replay", "Replay", "Replay"), ("log.shield", "Shield active: %s", "Scudo attivo: %s"),
    ("log.title", "Defense log", "Registro difese"),
    ("quests.claim", "Claim", "Riscuoti"), ("quests.claimed", "Claimed", "Riscosso"), ("quests.completed", "Completed!", "Completato!"),
    ("quests.daily_hint", "Today's missions (renewed at midnight)", "Missioni di oggi (si rinnovano a mezzanotte)"),
    ("quests.day", "Day %d", "Giorno %d"), ("quests.title", "Goals", "Obiettivi"),
    ("quests.tab.daily", "Daily", "Giornaliere"), ("quests.tab.achievements", "Achievements", "Imprese"),
    ("results.defeat", "Defeat", "Sconfitta"), ("results.home", "Return to village", "Torna al villaggio"),
    ("results.replay", "Watch replay", "Guarda il replay"), ("results.victory", "Victory!", "Vittoria!"),
    ("settings.credits", "Credits", "Crediti"),
    ("settings.credits_text", "Lanternreach by EroideGames. Original art and audio generated procedurally (CC0). Fonts: Lilita One (Juan Montoreano) and Nunito (The Nunito Project Authors), SIL Open Font License. Engine: Godot 4.3 (MIT).",
     "Lanternreach di EroideGames. Grafica e audio originali generati proceduralmente (CC0). Font: Lilita One (Juan Montoreano) e Nunito (The Nunito Project Authors), licenza SIL Open Font. Motore: Godot 4.3 (MIT)."),
    ("settings.language", "Language", "Lingua"), ("settings.name", "Name", "Nome"), ("settings.quality", "Graphics quality", "Qualità grafica"),
    ("settings.q_high", "High", "Alta"), ("settings.q_low", "Low", "Bassa"), ("settings.music", "Music", "Musica"), ("settings.sfx", "Sound effects", "Effetti sonori"),
    ("settings.reset", "Delete data", "Cancella i dati"), ("settings.reset_confirm1", "Do you really want to delete all your progress?", "Vuoi davvero cancellare tutti i progressi?"),
    ("settings.reset_confirm2", "Last confirmation: this cannot be undone.", "Ultima conferma: l'operazione non si può annullare."),
    ("settings.reset_yes", "Delete", "Cancella"), ("settings.shake", "Screen shake", "Scossa dello schermo"), ("settings.title", "Settings", "Impostazioni"),
    ("shop.title", "Shop", "Negozio"), ("shop.tab.economy", "Economy", "Economia"), ("shop.tab.defense", "Defenses", "Difese"),
    ("shop.tab.army", "Army", "Esercito"), ("shop.tab.trap", "Traps", "Trappole"),
    ("toast.built", "%s ready (Lv %d)!", "%s pronto (Lv %d)!"), ("toast.league", "New league: %s!", "Nuova lega: %s!"),
    ("toast.level_up", "Level %d reached!", "Livello %d raggiunto!"), ("toast.queued", "Added to the builders' queue", "Aggiunto alla coda dei costruttori"),
    ("toast.research_done", "Research complete: %s Lv %d", "Ricerca completata: %s Lv %d"), ("toast.walls_upgraded", "%d walls upgraded", "%d mura potenziate"),
    ("stat.dps", "Damage per second", "Danno al secondo"), ("stat.hp", "Hitpoints", "Punti vita"), ("stat.range", "Range", "Raggio"),
    ("stat.targets", "Targets", "Bersagli"), ("stat.prod", "Production per hour", "Produzione oraria"), ("stat.capacity", "Capacity", "Capacità"),
    ("stat.army_capacity", "Army capacity", "Capacità esercito"), ("stat.max_troop_level", "Max troop level", "Livello max truppe"),
    ("stat.spell_slots", "Spell slots", "Slot incantesimi"), ("stat.clan_slots", "Clan members", "Membri del clan"), ("stat.unlocks", "Unlocks", "Sblocca"),
    ("stat.damage", "Damage", "Danno"), ("stat.launch_max_space", "Launch capacity", "Capacità di lancio"), ("stat.freeze_seconds", "Freeze", "Congelamento"),
    ("stat.speed", "Speed", "Velocità"), ("stat.preference", "Favorite target", "Bersaglio preferito"), ("stat.radius", "Radius", "Raggio"),
    ("stat.duration", "Duration", "Durata"),
    ("targets.ground", "Ground", "Terra"), ("targets.air", "Air", "Aria"), ("targets.ground+air", "Ground and air", "Terra e aria"), ("targets.none", "-", "-"),
    ("pref.any", "Any building", "Qualsiasi edificio"), ("pref.defenses", "Defenses", "Difese"), ("pref.resources", "Resources", "Risorse"),
    ("pref.walls", "Walls", "Mura"), ("pref.allies", "Allies (heals)", "Alleati (cura)"),
    ("role.melee_basic", "Basic melee", "Mischia base"), ("role.ranged", "Ranged", "Distanza"), ("role.tank", "Tank", "Tank"),
    ("role.looter", "Looter", "Saccheggiatore"), ("role.wall_breaker", "Wall breaker", "Distruttore di mura"), ("role.anti_defense", "Anti-defense", "Anti-difesa"),
    ("role.flyer", "Flyer", "Volante"), ("role.healer", "Healer", "Guaritore"), ("role.heavy_flyer", "Heavy flyer", "Volante pesante"), ("role.elite", "Elite", "Élite"),
    ("tut.welcome", "Welcome, Lanternkeeper! The Gloomtide has dimmed our island. Let's rebuild the village around the Mother Lantern together!",
     "Benvenuto, Lanternaro! La Marea d'Ombra ha spento la nostra isola. Ricostruiamo insieme il villaggio attorno al Faro Madre!"),
    ("tut.build_mine", "Open the Shop and build a Cog Mine: drag it where you like and confirm.", "Apri il Negozio e costruisci una Miniera di Cogs: trascinala dove vuoi e conferma."),
    ("tut.wait_build", "Your builder is at work... this first job will be finished for free!", "Il costruttore è al lavoro... questo primo lavoro lo completiamo gratis!"),
    ("tut.build_well", "Now we need Sap: build a Sap Well from the Shop.", "Ora serve la Sap: costruisci un Pozzo di Sap dal Negozio."),
    ("tut.collect", "Mines fill up over time, even when the game is closed. Tap the Cog Mine to collect!", "Le miniere si riempiono col tempo, anche a gioco chiuso. Tocca la Miniera di Cogs per raccogliere!"),
    ("tut.build_barracks", "Time to train an army: build the Barracks (Shop > Army).", "È ora di addestrare un esercito: costruisci la Caserma (Negozio > Esercito)."),
    ("tut.train", "Open the Army and train at least 5 Coglings.", "Apri l'Esercito e addestra almeno 5 Ingranelli."),
    ("tut.attack", "Attack! Choose the first Gloomtide village on the campaign map.", "All'attacco! Scegli il primo villaggio della Marea d'Ombra sulla mappa della campagna."),
    ("tut.battle_deploy", "Select a troop below, then tap or drag on the free area around the village to deploy.", "Seleziona una truppa in basso, poi tocca o trascina nell'area libera intorno al villaggio per schierarla."),
    ("tut.build_defense", "Great victory! Now protect the village: build a Boltpost (Shop > Defenses).", "Grande vittoria! Ora proteggi il villaggio: costruisci un Boltpost (Negozio > Difese)."),
    ("tut.upgrade_hall", "Upgrading the Mother Lantern unlocks new buildings. Tap it and choose Upgrade.", "Potenziare il Faro Madre sblocca nuovi edifici. Toccalo e scegli Potenzia."),
    ("tut.hall_speed", "This one too is on me: it will be ready in a moment!", "Anche questo te lo regalo: sarà pronto in un attimo!"),
    ("tut.done", "You are ready, Lanternkeeper! Here are 50 Glimmers to start. Long press a building to move it. Good luck!",
     "Sei pronto, Lanternaro! Ecco 50 Glimmers per iniziare. Tieni premuto un edificio per spostarlo. Buona fortuna!"),
    ("tut.skip", "Skip tutorial", "Salta il tutorial"), ("tut.skip_confirm", "Skip the tutorial?", "Saltare il tutorial?"),
]:
    k(key, en, it)

# --------------------------------------------------------- nomi e descrizioni
BUILDINGS = {
    "lantern_hall": ("Mother Lantern", "Faro Madre", "The heart of the village. Its level decides how many buildings you can have and how high they can go.", "Il cuore del villaggio. Il suo livello decide quanti edifici puoi avere e fino a che livello."),
    "cog_mine": ("Cog Mine", "Miniera di Cogs", "Digs up Cogs every hour, even while you are away. Tap it to collect.", "Estrae Cogs ogni ora, anche quando non giochi. Toccala per raccogliere."),
    "sap_well": ("Sap Well", "Pozzo di Sap", "Pumps glowing Sap every hour. Tap it to collect.", "Pompa la Sap luminosa ogni ora. Toccalo per raccogliere."),
    "shard_drill": ("Shard Drill", "Trivella di Shard", "Drills rare Starshards from the island's depths.", "Estrae i rari Starshards dalle profondità dell'isola."),
    "cog_vault": ("Cog Vault", "Deposito di Cogs", "Stores Cogs. Raiders can steal part of its content.", "Conserva i Cogs. Gli assalitori possono rubarne una parte."),
    "sap_cistern": ("Sap Cistern", "Cisterna di Sap", "Stores Sap. Raiders can steal part of its content.", "Conserva la Sap. Gli assalitori possono rubarne una parte."),
    "shard_crate": ("Shard Crate", "Cassa di Shard", "Keeps your Starshards safe.", "Custodisce i tuoi Starshards."),
    "barracks": ("Barracks", "Caserma", "Trains troops. Higher levels unlock new troops.", "Addestra le truppe. I livelli più alti sbloccano nuove truppe."),
    "army_camp": ("Army Camp", "Accampamento", "Houses your army: more camps, bigger army.", "Ospita il tuo esercito: più accampamenti, esercito più grande."),
    "laboratory": ("Laboratory", "Laboratorio", "Researches stronger troop levels, one at a time.", "Ricerca livelli più forti delle truppe, uno alla volta."),
    "spell_forge": ("Spell Forge", "Forgia degli Incantesimi", "Brews spells to support your troops in battle.", "Prepara incantesimi per sostenere le truppe in battaglia."),
    "clan_hall": ("Clan Hall", "Sala del Clan", "Lets you create or join a clan.", "Permette di creare un clan o di unirti a uno."),
    "boltpost": ("Boltpost", "Torre Dardo", "Reliable crossbow tower: hits ground and air, one target at a time.", "Torre con balestra affidabile: colpisce terra e aria, un bersaglio alla volta."),
    "lobber": ("Lobber", "Lanciamortai", "Lobs heavy shells that hit groups on the ground. Cannot hit units too close.", "Lancia proiettili pesanti che colpiscono gruppi a terra. Non colpisce chi è troppo vicino."),
    "skyspear": ("Skyspear", "Lancia Celeste", "Fires spears at flying units only.", "Scaglia lance solo contro le unità volanti."),
    "arc_coil": ("Arc Coil", "Bobina d'Arco", "Lightning that jumps between up to 3 ground units.", "Un fulmine che salta tra fino a 3 unità di terra."),
    "ballista": ("Ballista", "Balista", "Very long range, hits ground and air.", "Gittata lunghissima, colpisce terra e aria."),
    "thumper": ("Thumper", "Martellone", "Slow but devastating hammer: crushes tanks.", "Martello lento ma devastante: schiaccia i tank."),
    "frost_spire": ("Frost Spire", "Guglia di Gelo", "Freezing blasts that slow all units in an area.", "Raffiche gelide che rallentano tutte le unità in un'area."),
    "cinder_spout": ("Cinder Spout", "Bocca di Brace", "Short range flamethrower with huge damage.", "Lanciafiamme a corto raggio con danno enorme."),
    "storm_pylon": ("Storm Pylon", "Pilone della Tempesta", "Area lightning against flying squads.", "Fulmini ad area contro gli stormi volanti."),
    "wall": ("Wall", "Muro", "Slows down attackers. Upgrades are instant.", "Rallenta gli assalitori. I potenziamenti sono istantanei."),
    "bomb_trap": ("Bomb Trap", "Bomba", "Hidden bomb: explodes under ground troops.", "Bomba nascosta: esplode sotto le truppe di terra."),
    "spring_pad": ("Spring Pad", "Molla", "Hidden spring that launches ground troops out of the village.", "Molla nascosta che lancia fuori dal villaggio le truppe di terra."),
    "snare_trap": ("Snare Trap", "Laccio", "Hidden snare that freezes ground troops for a few seconds.", "Laccio nascosto che immobilizza le truppe di terra per alcuni secondi."),
    "air_mine": ("Air Mine", "Mina Aerea", "Hidden mine that explodes near flying units.", "Mina nascosta che esplode vicino alle unità volanti."),
    "sapling": ("Sapling", "Alberello", "", ""), "boulder": ("Boulder", "Masso", "", ""),
    "glowshroom": ("Glowshroom", "Fungo Luminoso", "", ""), "moon_crystal": ("Moon Crystal", "Cristallo Lunare", "", ""),
}
for bid, (en, it, den, dit) in BUILDINGS.items():
    k("building." + bid, en, it)
    if den:
        k("desc." + bid, den, dit)

TROOPS = {
    "cogling": ("Cogling", "Ingranello", "Cheerful all-rounder with a big wrench. Cheap and quick to train.", "Tuttofare allegro con una grande chiave inglese. Economico e veloce da addestrare."),
    "slingwisp": ("Slingwisp", "Fiondino", "Floating wisp that hits from a distance, even flying targets.", "Spiritello fluttuante che colpisce da lontano, anche bersagli volanti."),
    "bulwark": ("Bulwark", "Baluardo", "Huge shield bearer: draws the fire of nearby defenses.", "Enorme portatore di scudo: attira su di sé il fuoco delle difese vicine."),
    "magpie": ("Magpie", "Gazza", "Fast thief: targets resource buildings and deals double damage to them.", "Ladra veloce: punta agli edifici delle risorse e infligge loro danno doppio."),
    "kegger": ("Kegger", "Barilotto", "Runs to the walls and blows them up.", "Corre verso le mura e le fa saltare in aria."),
    "rustjaw": ("Rustjaw", "Zannaruggine", "Leaps over walls and charges defenses.", "Scavalca le mura e carica le difese."),
    "kitewing": ("Kitewing", "Cervolante", "Flying kite that ignores walls.", "Aquilone volante che ignora le mura."),
    "mender": ("Mender", "Guaritrice", "Flying lantern that heals ground troops around it.", "Lanterna volante che cura le truppe di terra intorno a sé."),
    "dirigible": ("Dirigible", "Dirigibile", "Slow airship that drops bombs on defenses.", "Lenta aeronave che sgancia bombe sulle difese."),
    "ember_warden": ("Ember Warden", "Custode di Brace", "Elite knight: when wounded, flares up with Lantern Surge.", "Cavaliere d'élite: quando è ferito si infiamma con l'Ondata della Lanterna."),
}
for tid, (en, it, den, dit) in TROOPS.items():
    k("troop." + tid, en, it)
    k("desc.troop." + tid, den, dit)
k("spell.mending_mist", "Mending Mist", "Nebbia Curativa")
k("spell.fervor_surge", "Fervor Surge", "Ondata di Fervore")
k("desc.spell.mending_mist", "Heals all troops inside the area over time.", "Cura nel tempo tutte le truppe nell'area.")
k("desc.spell.fervor_surge", "Troops in the area deal more damage and move faster.", "Le truppe nell'area infliggono più danni e si muovono più veloci.")

LEAGUES = {"wick": "Stoppino", "spark": "Scintilla", "ember": "Brace", "flame": "Fiamma", "blaze": "Rogo", "beacon": "Falò", "lighthouse": "Faro", "sunforge": "Forgiasole"}
for lid, it in LEAGUES.items():
    k("league." + lid, lid.capitalize(), it)

CAMPAIGN_IT = ["Cancello Muschioso", "Conca dei Ciottoli", "Fattoria della Rugiada", "Collina dei Grilli", "Forte dei Cardi",
               "Moli Fangosi", "Cortile Arrugginito", "Cresta dei Calabroni", "Palude dei Funghi", "Il Mulino degli Ingranaggi",
               "Schienarovo", "Scogliere di Ragnatela", "Pontile della Marea", "Vicolo Senza Lanterne", "Frutteto di Brace",
               "Bacino degli Spettri", "Terrazza del Tuono", "Campi Gelati", "Guglia di Fumo", "Palude Specchio",
               "Cittadella degli Ossingranaggi", "Rocca dei Corvi di Tempesta", "Sole Vuoto", "Il Muro della Lunga Notte", "Trono della Regina d'Ombra"]
camp = json.load(open(os.path.join(DATA, "campaign.json")))
for i, lv in enumerate(camp, start=1):
    k("campaign.%02d.name" % i, lv["name_en"], CAMPAIGN_IT[i - 1])

ACH = {
    "loot_cogs": ("Cog Raider", "Predatore di Cogs", "Loot %s Cogs in total", "Saccheggia %s Cogs in totale"),
    "loot_sap": ("Sap Raider", "Predatore di Sap", "Loot %s Sap in total", "Saccheggia %s Sap in totale"),
    "win_battles": ("Conqueror", "Conquistatore", "Win %s attacks", "Vinci %s attacchi"),
    "earn_stars": ("Star Collector", "Collezionista di stelle", "Earn %s stars in battle", "Ottieni %s stelle in battaglia"),
    "raze_defenses": ("Tower Breaker", "Abbattitorri", "Destroy %s defenses", "Distruggi %s difese"),
    "hold_the_line": ("Hold the Line", "Tieni la linea", "Win %s defenses", "Vinci %s difese"),
    "tidy_up": ("Tidy Island", "Isola in ordine", "Clear %s obstacles", "Rimuovi %s ostacoli"),
    "lantern_rising": ("Rising Lantern", "Lanterna nascente", "Upgrade the Mother Lantern to level %s", "Porta il Faro Madre al livello %s"),
    "trophy_hunter": ("Trophy Hunter", "Cacciatore di trofei", "Reach %s trophies", "Raggiungi %s trofei"),
    "campaign_walker": ("Gloom Walker", "Viandante d'Ombra", "Earn %s campaign stars", "Ottieni %s stelle nella campagna"),
    "spellcaster": ("Spellcaster", "Incantatore", "Cast %s spells", "Lancia %s incantesimi"),
    "barracks_busy": ("Busy Barracks", "Caserma operosa", "Train %s troops", "Addestra %s truppe"),
    "builder_hands": ("Builder's Hands", "Mani d'oro", "Complete %s upgrades", "Completa %s potenziamenti"),
    "wall_wrecker": ("Wall Wrecker", "Sfondamura", "Destroy %s walls", "Distruggi %s mura"),
    "shard_seeker": ("Shard Seeker", "Cercatore di Shard", "Collect %s Starshards", "Raccogli %s Starshards"),
    "join_the_hall": ("Together", "Insieme", "Join or create a clan (%s)", "Entra o crea un clan (%s)"),
}
for aid, (en, it, den, dit) in ACH.items():
    k("ach.%s.name" % aid, en, it)
    k("ach.%s.desc" % aid, den, dit)

DAILY = {
    "win_attack": ("Win %s attack", "Vinci %s attacco"), "earn_stars": ("Earn %s stars", "Ottieni %s stelle"),
    "loot_cogs": ("Loot %s Cogs", "Saccheggia %s Cogs"), "spend_upgrade": ("Start %s upgrades", "Avvia %s potenziamenti"),
    "train_troops": ("Train %s troops", "Addestra %s truppe"), "clear_obstacle": ("Clear %s obstacles", "Rimuovi %s ostacoli"),
    "cast_spell": ("Cast %s spells", "Lancia %s incantesimi"), "destroy_defense": ("Destroy %s defenses", "Distruggi %s difese"),
}
for did, (en, it) in DAILY.items():
    k("daily." + did, en, it)


def used_keys():
    keys = set()
    for dp, dn, fn in os.walk(os.path.join(ROOT, "scripts")):
        for f in fn:
            if f.endswith(".gd"):
                txt = open(os.path.join(dp, f), encoding="utf-8").read()
                keys.update(re.findall(r'tr\("([a-z0-9_.+]+)"\)', txt))
                keys.update(re.findall(r'translate\("([a-z0-9_.+]+)"\)', txt))
    return keys


def main():
    missing = sorted(k_ for k_ in used_keys() if k_ not in S)
    if missing:
        print("CHIAVI MANCANTI:", missing)
        sys.exit(1)
    # coerenza dei segnaposto tra le lingue
    for key, (en, it) in S.items():
        for ph in ("%s", "%d", "%%"):
            if en.count(ph) != it.count(ph):
                print("segnaposto diversi in", key)
                sys.exit(1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["keys", "en", "it"])
        for key in sorted(S):
            w.writerow([key, S[key][0], S[key][1]])
    print("OK:", len(S), "chiavi ->", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
