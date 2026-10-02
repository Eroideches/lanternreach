"""Audio originale sintetizzato (numpy): ~40 effetti + 2 musiche in loop (villaggio, battaglia).

Tutto e' generato da questo script, quindi originale (rilasciato CC0 nei CREDITS). WAV mono 16 bit 32 kHz.
Le musiche sono costruite per loop perfetto: la coda (riverbero/rilasci) oltre la fine viene sommata all'inizio.
"""
import math
import os
import wave

import numpy as np

SR = 32000
RNG = np.random.default_rng(1234)


# ---------------------------------------------------------------- base
def T(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.05, s=0.6, r=0.1, hold=None):
    """ADSR su n campioni (tempi in secondi)."""
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    h_n = max(0, n - a_n - d_n - r_n) if hold is None else int(hold * SR)
    e = np.concatenate([np.linspace(0, 1, max(1, a_n)), np.linspace(1, s, max(1, d_n)), np.full(h_n, s), np.linspace(s, 0, max(1, r_n))])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def expdec(n, k):
    return np.exp(-np.arange(n) / SR * k)


def sine(f, d, ph=0.0):
    t = T(d)
    if callable(f):
        return np.sin(2 * np.pi * np.cumsum(f(t)) / SR + ph)
    return np.sin(2 * np.pi * f * t + ph)


def sweep(f0, f1, d, curve=1.0):
    t = T(d)
    k = (t / d) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def tri(f, d):
    t = T(d)
    return 2 * np.abs(2 * ((t * f) % 1) - 1) - 1


def saw(f, d, harm=12):
    t = T(d)
    out = np.zeros_like(t)
    for k in range(1, harm + 1):
        if f * k > SR / 2.2:
            break
        out += np.sin(2 * np.pi * f * k * t) / k
    return out * 0.6


def square(f, d, harm=9):
    t = T(d)
    out = np.zeros_like(t)
    for k in range(1, harm * 2, 2):
        if f * k > SR / 2.2:
            break
        out += np.sin(2 * np.pi * f * k * t) / k
    return out * 0.8


def noise(d):
    return RNG.uniform(-1, 1, int(SR * d))


def fft_filter(x, lo=None, hi=None, soft=1.0):
    """Filtro passa-banda nel dominio della frequenza (rolloff morbido)."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if hi:
        g *= 1 / (1 + (f / hi) ** (4 * soft))
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1)) ** (4 * soft))
    return np.fft.irfft(X * g, n)


def reverb(x, decay=1.2, mix_=0.25, seed=3):
    n_ir = int(decay * SR)
    rng = np.random.default_rng(seed)
    ir = rng.uniform(-1, 1, n_ir) * np.exp(-np.arange(n_ir) / SR * (6.9 / decay))
    ir = fft_filter(ir, hi=5000)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    n = len(x) + n_ir
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    out = np.zeros(n)
    out[:len(x)] += x * (1 - mix_)
    out += y * mix_ * 0.6
    return out


def place(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[:j - i]


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade_tail(x, ms=8):
    n = int(ms / 1000 * SR)
    if len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)
    return x


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    y = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype("<i2").tobytes())


def NOTE(n):
    """Nome nota -> frequenza (es. 'A4', 'F#3', 'Bb2')."""
    names = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
    p, o = (n[:2], n[2:]) if n[1:2] in ("#", "b") else (n[:1], n[1:])
    midi = 12 * (int(o) + 1) + names[p]
    return 440.0 * 2 ** ((midi - 69) / 12)


# --------------------------------------------------------------- strumenti
def pluck(f, d=0.5, bright=1.0):
    x = tri(f, d) * 0.6 + sine(f * 2, d) * 0.25 * bright + sine(f * 3, d) * 0.08 * bright
    return x * expdec(len(x), 6) * env(len(x), 0.003, 0.01, 1, 0.02)


def bell(f, d=1.2):
    x = sine(f, d) + 0.5 * sine(f * 2.76, d) * expdec(int(d * SR), 8) + 0.25 * sine(f * 5.4, d) * expdec(int(d * SR), 14)
    return x * expdec(len(x), 3.2) * env(len(x), 0.002, 0.01, 1, 0.05)


def pad(f, d):
    x = (tri(f, d) * 0.5 + sine(f * 1.003, d) * 0.4 + sine(f * 0.5, d) * 0.3 + saw(f * 0.997, d, 5) * 0.12)
    return x * env(len(x), 0.35, 0.3, 0.75, 0.5)


def bass(f, d):
    x = sine(f, d) * 0.9 + sine(f * 2, d) * 0.2
    return x * env(len(x), 0.008, 0.08, 0.7, 0.08)


def bass_saw(f, d):
    x = fft_filter(saw(f, d, 8), hi=900)
    return x * env(len(x), 0.004, 0.06, 0.6, 0.05)


def brass(f, d):
    x = saw(f, d, 10) * 0.7 + saw(f * 1.006, d, 10) * 0.5
    x = fft_filter(x, hi=2600)
    return x * env(len(x), 0.03, 0.08, 0.7, 0.12)


def lead(f, d):
    t = T(d)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.25, 0, 1)
    x = np.sin(2 * np.pi * np.cumsum(f * vib) / SR) * 0.6 + np.sin(2 * np.pi * np.cumsum(2 * f * vib) / SR) * 0.2 + square(f, d, 5) * 0.18
    return x * env(len(x), 0.02, 0.1, 0.75, 0.1)


def kick(d=0.35, f0=120, f1=42):
    x = sweep(f0, f1, d, 0.35) * expdec(int(d * SR), 9)
    return x + fft_filter(noise(d), hi=2000) * expdec(int(d * SR), 60) * 0.3


def snare(d=0.25):
    n = fft_filter(noise(d), lo=1200, hi=9000) * expdec(int(d * SR), 18)
    return n * 0.8 + sine(190, d) * expdec(int(d * SR), 25) * 0.5


def hat(d=0.06, vol=1.0):
    return fft_filter(noise(d), lo=6000) * expdec(int(d * SR), 70) * 0.5 * vol


def shaker(d=0.09):
    return fft_filter(noise(d), lo=4000, hi=11000) * env(int(d * SR), 0.01, 0.02, 0.6, 0.05) * 0.35


# ------------------------------------------------------------------- SFX
def sfx_all():
    S = {}
    S["ui_click"] = sine(1300, 0.05) * expdec(1600, 60) + tri(2600, 0.05) * expdec(1600, 90) * 0.3
    S["ui_back"] = sweep(900, 520, 0.08) * env(int(0.08 * SR), 0.002, 0.02, 0.5, 0.04)
    S["ui_open"] = sweep(320, 980, 0.16, 0.7) * env(int(0.16 * SR), 0.01, 0.05, 0.6, 0.08) + fft_filter(noise(0.16), lo=2000) * env(int(0.16 * SR), 0.05, 0.05, 0.3, 0.05) * 0.2
    S["ui_close"] = sweep(900, 300, 0.14, 1.3) * env(int(0.14 * SR), 0.005, 0.05, 0.5, 0.07)
    b = np.zeros(int(0.3 * SR))
    for at in (0, 0.13):
        place(b, square(170, 0.09) * env(int(0.09 * SR), 0.004, 0.02, 0.8, 0.02) * 0.6, at)
    S["ui_error"] = b
    S["toggle"] = sine(1600, 0.04) * expdec(1280, 80) + sine(2400, 0.04) * expdec(1280, 120) * 0.4
    # monete-ingranaggio
    b = np.zeros(int(0.7 * SR))
    for i, at in enumerate((0, 0.07, 0.15)):
        f = 1900 + i * 230
        place(b, (sine(f, 0.45) + 0.6 * sine(f * 2.76, 0.45) + 0.3 * sine(f * 4.1, 0.45)) * expdec(int(0.45 * SR), 11) * 0.5, at)
    S["collect_cogs"] = b
    b = np.zeros(int(0.5 * SR))
    place(b, sweep(680, 240, 0.18, 0.6) * expdec(int(0.18 * SR), 14), 0)
    place(b, sweep(500, 900, 0.08) * expdec(int(0.08 * SR), 30) * 0.5, 0.17)
    place(b, sweep(600, 1100, 0.07) * expdec(int(0.07 * SR), 30) * 0.4, 0.28)
    S["collect_sap"] = b
    b = np.zeros(int(1.0 * SR))
    for i, n in enumerate(("E6", "B6", "E7")):
        place(b, bell(NOTE(n), 0.8) * 0.5, i * 0.06)
    S["collect_shard"] = reverb(b, 0.8, 0.3)
    b = np.zeros(int(0.9 * SR))
    for i, n in enumerate(("C6", "E6", "G6", "C7")):
        place(b, bell(NOTE(n), 0.6) * 0.45, i * 0.045)
    S["collect_gem"] = reverb(b, 0.7, 0.3)
    b = np.zeros(int(0.8 * SR))
    for at in (0, 0.2, 0.4):
        place(b, (sine(95, 0.12) * expdec(int(0.12 * SR), 30) + fft_filter(noise(0.12), lo=400, hi=3000) * expdec(int(0.12 * SR), 40) * 0.7), at)
        place(b, (sine(2400, 0.08) + sine(3700, 0.08) * 0.5) * expdec(int(0.08 * SR), 40) * 0.25, at + 0.005)
    S["build_start"] = b
    b = np.zeros(int(1.4 * SR))
    for i, n in enumerate(("C5", "E5", "G5")):
        place(b, (pluck(NOTE(n), 0.3) + pluck(NOTE(n) / 2, 0.3) * 0.4) * 0.6, i * 0.1)
    place(b, (brass(NOTE("C5"), 0.6) + brass(NOTE("E5"), 0.6) + brass(NOTE("G5"), 0.6)) * 0.25, 0.3)
    S["build_complete"] = reverb(b, 1.0, 0.25)
    b = np.zeros(int(1.6 * SR))
    for i, n in enumerate(("C5", "E5", "G5", "C6", "E6", "G6")):
        place(b, bell(NOTE(n), 0.7) * 0.4, i * 0.07)
    place(b, fft_filter(noise(1.0), lo=5000) * env(int(SR), 0.3, 0.2, 0.3, 0.4) * 0.15, 0.2)
    S["upgrade_complete"] = reverb(b, 1.2, 0.3)
    b = np.zeros(int(0.7 * SR))
    place(b, fft_filter(noise(0.4), lo=800, hi=6000) * env(int(0.4 * SR), 0.2, 0.05, 0.4, 0.15) * 0.6, 0)
    place(b, sweep(800, 2600, 0.25, 0.5) * env(int(0.25 * SR), 0.01, 0.05, 0.6, 0.1) * 0.5, 0.25)
    S["speedup"] = b
    S["troop_train"] = sweep(480, 980, 0.09, 0.5) * expdec(int(0.09 * SR), 25)
    b = np.zeros(int(0.35 * SR))
    place(b, sweep(300, 700, 0.07) * expdec(int(0.07 * SR), 35), 0)
    place(b, fft_filter(noise(0.25), lo=500, hi=4000) * env(int(0.25 * SR), 0.03, 0.05, 0.3, 0.15) * 0.4, 0.02)
    S["deploy"] = b
    S["hit_melee"] = (sine(130, 0.18) * expdec(int(0.18 * SR), 22) + fft_filter(noise(0.18), lo=200, hi=2500) * expdec(int(0.18 * SR), 35) * 0.8)
    S["shot_bolt"] = (sweep(420, 180, 0.22, 0.4) * expdec(int(0.22 * SR), 16) * 0.8 + fft_filter(noise(0.22), lo=2000) * expdec(int(0.22 * SR), 60) * 0.5)
    b = np.zeros(int(0.8 * SR))
    place(b, sweep(90, 38, 0.5, 0.5) * expdec(int(0.5 * SR), 7), 0)
    place(b, fft_filter(noise(0.5), hi=900) * expdec(int(0.5 * SR), 10) * 0.9, 0)
    S["shot_mortar"] = b
    S["shot_air"] = fft_filter(noise(0.25), lo=3000) * env(int(0.25 * SR), 0.005, 0.03, 0.5, 0.15) * 0.8 + sweep(1800, 900, 0.25) * expdec(int(0.25 * SR), 12) * 0.25
    b = np.zeros(int(1.4 * SR))
    place(b, fft_filter(noise(1.2), hi=1400) * expdec(int(1.2 * SR), 4.5), 0)
    place(b, sweep(70, 30, 0.8, 0.5) * expdec(int(0.8 * SR), 5) * 0.9, 0)
    place(b, fft_filter(noise(0.1), lo=1500) * expdec(int(0.1 * SR), 40) * 0.6, 0)
    S["explosion"] = b
    b = np.zeros(int(1.6 * SR))
    for i in range(7):
        at = i * 0.11 + RNG.uniform(0, 0.04)
        place(b, fft_filter(noise(0.35), lo=150, hi=2200) * expdec(int(0.35 * SR), 12) * (1 - i * 0.1), at)
    for i in range(5):
        place(b, sine(RNG.uniform(1800, 3200), 0.12) * expdec(int(0.12 * SR), 40) * 0.2, 0.3 + i * 0.13)
    place(b, sine(60, 0.6) * expdec(int(0.6 * SR), 6) * 0.7, 0)
    S["building_destroyed"] = b
    S["wall_break"] = (fft_filter(noise(0.3), lo=600, hi=5000) * expdec(int(0.3 * SR), 20) + sine(110, 0.3) * expdec(int(0.3 * SR), 18) * 0.6)
    b = np.zeros(int(1.4 * SR))
    for i, n in enumerate(("A5", "C#6", "E6")):
        place(b, bell(NOTE(n), 1.0) * 0.35, i * 0.08)
    S["heal"] = reverb(b, 1.0, 0.35)
    b = np.zeros(int(1.2 * SR))
    place(b, fft_filter(noise(0.6), lo=1500, hi=8000) * env(int(0.6 * SR), 0.3, 0.1, 0.4, 0.2) * 0.5, 0)
    for i, n in enumerate(("D6", "A6", "D7")):
        place(b, bell(NOTE(n), 0.6) * 0.35, 0.25 + i * 0.05)
    S["spell_cast"] = reverb(b, 0.9, 0.3)
    S["trap_spring"] = sine(lambda t: 220 + 380 * np.sin(np.clip(t / 0.35, 0, 1) * np.pi) + 25 * np.sin(2 * np.pi * 22 * t), 0.45) * expdec(int(0.45 * SR), 6) * 0.8
    S["trap_bomb"] = S["explosion"][: int(1.0 * SR)].copy()
    b = np.zeros(int(1.1 * SR))
    place(b, fft_filter(noise(0.9), lo=5000) * expdec(int(0.9 * SR), 4) * 0.4, 0)
    for i in range(6):
        place(b, bell(RNG.uniform(2500, 4200), 0.4) * 0.15, i * 0.07)
    S["freeze"] = reverb(b, 0.8, 0.3)
    z = saw(110, 0.45, 20) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 37 * T(0.45))))
    S["zap"] = fft_filter(z + noise(0.45) * 0.4, lo=300, hi=7000) * env(int(0.45 * SR), 0.003, 0.05, 0.6, 0.2) * 0.8
    b = fft_filter(noise(0.8), lo=300, hi=3000) * env(int(0.8 * SR), 0.05, 0.1, 0.6, 0.3) * 0.5
    for i in range(10):
        place(b, noise(0.008) * 0.6, RNG.uniform(0, 0.75))
    S["fire"] = b
    for k in (1, 2, 3):
        b = np.zeros(int(1.2 * SR))
        base = ("E5", "G5", "C6")[k - 1]
        place(b, bell(NOTE(base), 1.0) * 0.5, 0)
        place(b, bell(NOTE(base) * 1.5, 1.0) * 0.3, 0.05)
        S[f"star{k}"] = reverb(b, 1.0, 0.3)
    # vittoria / sconfitta
    b = np.zeros(int(3.0 * SR))
    mel = [("C5", 0, 0.15), ("E5", 0.15, 0.15), ("G5", 0.3, 0.15), ("C6", 0.45, 0.6), ("A5", 1.1, 0.2), ("B5", 1.3, 0.2), ("C6", 1.5, 1.0)]
    for n, at, d in mel:
        place(b, brass(NOTE(n), d + 0.1) * 0.45, at)
    for n in ("C4", "E4", "G4"):
        place(b, pad(NOTE(n), 1.6) * 0.25, 1.4)
    place(b, kick(0.4) * 0.6, 0.45)
    place(b, kick(0.4) * 0.6, 1.5)
    S["victory"] = reverb(b, 1.4, 0.25)
    b = np.zeros(int(2.6 * SR))
    for n, at, d in (("G4", 0, 0.35), ("F4", 0.4, 0.35), ("Eb4", 0.8, 0.35), ("D4", 1.2, 1.0)):
        place(b, brass(NOTE(n), d) * 0.4, at)
    for n in ("D3", "F3", "A3"):
        place(b, pad(NOTE(n), 1.3) * 0.25, 1.2)
    S["defeat"] = reverb(b, 1.4, 0.3)
    S["timer_tick"] = (sine(1000, 0.04) * expdec(1280, 90) + fft_filter(noise(0.04), lo=2000, hi=5000) * expdec(1280, 120) * 0.4)
    b = np.zeros(int(1.5 * SR))
    place(b, bell(NOTE("A4"), 1.4) * 0.6, 0)
    place(b, sine(55, 1.4) * expdec(int(1.4 * SR), 3) * 0.4, 0)
    S["countdown_end"] = b
    S["notify"] = reverb(bell(NOTE("E6"), 0.8) * 0.5 + np.pad(bell(NOTE("B6"), 0.7) * 0.4, (int(0.1 * SR), 0))[: int(0.8 * SR)], 0.6, 0.25)
    b = np.zeros(int(0.6 * SR))
    place(b, fft_filter(noise(0.3), lo=1500, hi=7000) * env(int(0.3 * SR), 0.03, 0.05, 0.5, 0.15) * 0.6, 0)
    place(b, sweep(500, 1000, 0.08) * expdec(int(0.08 * SR), 30) * 0.6, 0.3)
    S["obstacle_clear"] = b
    b = np.zeros(int(1.2 * SR))
    for i, n in enumerate(("G5", "C6", "E6", "G6")):
        place(b, pluck(NOTE(n), 0.4) * 0.5, i * 0.08)
        place(b, bell(NOTE(n), 0.5) * 0.2, i * 0.08)
    S["reward"] = reverb(b, 0.9, 0.25)
    b = np.zeros(int(0.5 * SR))
    place(b, fft_filter(noise(0.3), lo=600, hi=5000) * env(int(0.3 * SR), 0.01, 0.05, 0.4, 0.2) * 0.5, 0)
    place(b, sweep(700, 300, 0.15) * expdec(int(0.15 * SR), 20) * 0.4, 0)
    S["troop_death"] = b
    S["arrow"] = (fft_filter(noise(0.12), lo=2500) * env(int(0.12 * SR), 0.005, 0.02, 0.5, 0.08) + sweep(1400, 700, 0.12) * expdec(int(0.12 * SR), 25) * 0.3)
    S["cheer"] = reverb(sum(sweep(RNG.uniform(300, 500), RNG.uniform(500, 800), 0.6) * env(int(0.6 * SR), 0.05, 0.1, 0.5, 0.3) * 0.15 for _ in range(6)), 0.8, 0.3)
    return {k: fade_tail(norm(v, 0.8)) for k, v in S.items()}


# ------------------------------------------------------------------ musica
def render_loop(events, length, tail=2.5, rev=(1.6, 0.22)):
    buf = np.zeros(int((length + tail) * SR))
    for at, sig, vol in events:
        place(buf, sig * vol, at)
    buf = reverb(buf, *rev)
    n = int(length * SR)
    loop = buf[:n].copy()
    rest = buf[n:]
    loop[: len(rest)] += rest[: n]     # coda riavvolta per loop senza giunte
    return norm(loop, 0.85)


def music_village():
    bpm = 100
    beat = 60 / bpm
    bar = beat * 4
    prog = ["D", "Bm", "G", "A", "D", "Bm", "G", "A", "G", "A", "F#m", "Bm", "G", "A", "D", "D"]
    chords = {"D": ["D", "F#", "A"], "Bm": ["B", "D", "F#"], "G": ["G", "B", "D"], "A": ["A", "C#", "E"], "F#m": ["F#", "A", "C#"]}
    rng = np.random.default_rng(42)
    ev = []
    penta = ["D", "E", "F#", "A", "B"]
    for i, ch in enumerate(prog):
        t0 = i * bar
        tones = chords[ch]
        # pad
        for n in tones:
            ev.append((t0, pad(NOTE(n + "3"), bar + 0.4), 0.10))
        # basso
        root = tones[0]
        ev.append((t0, bass(NOTE(root + "2"), beat * 1.6), 0.45))
        ev.append((t0 + beat * 2, bass(NOTE(root + "2"), beat * 1.4), 0.35))
        # arpeggio pizzicato (crome)
        seq = [tones[0] + "4", tones[1] + "4", tones[2] + "4", tones[1] + "4", tones[0] + "5", tones[2] + "4", tones[1] + "4", tones[2] + "4"]
        for k, n in enumerate(seq):
            ev.append((t0 + k * beat / 2, pluck(NOTE(n), 0.45, 0.8), 0.16 if k % 2 else 0.2))
        # percussioni leggere
        for k in range(8):
            ev.append((t0 + k * beat / 2 + beat / 4, shaker(), 0.5 if k % 2 else 0.3))
        ev.append((t0, kick(0.3, 90, 40), 0.35))
        ev.append((t0 + beat * 2, kick(0.3, 90, 40), 0.25))
        # melodia carillon (dalla 5a battuta)
        if i >= 4:
            rhythm = [(0, 1.0), (1, 0.5), (1.5, 0.5), (2, 1.5), (3.5, 0.5)] if i % 2 == 0 else [(0, 1.5), (1.5, 0.5), (2, 1.0), (3, 1.0)]
            for (pos, dur) in rhythm:
                if rng.random() < 0.85:
                    if pos == 0:
                        n = tones[rng.integers(0, 3)]
                    else:
                        n = penta[rng.integers(0, 5)]
                    octv = "5" if n in ("D", "E", "F#") else "5"
                    ev.append((t0 + pos * beat, bell(NOTE(n + octv), dur * beat + 0.6), 0.24))
    return render_loop(ev, len(prog) * bar)


def music_battle():
    bpm = 132
    beat = 60 / bpm
    bar = beat * 4
    prog = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "A", "Gm", "Gm", "Dm", "Dm", "Bb", "C", "A", "A"]
    chords = {"Dm": ["D", "F", "A"], "Bb": ["Bb", "D", "F"], "C": ["C", "E", "G"], "A": ["A", "C#", "E"], "Gm": ["G", "Bb", "D"]}
    ev = []
    melody = {8: [("D5", 0, 1), ("F5", 1, 1), ("G5", 2, 1.5), ("A5", 3.5, 0.5)], 9: [("Bb5", 0, 2), ("A5", 2, 1), ("G5", 3, 1)],
              10: [("F5", 0, 1.5), ("E5", 1.5, 0.5), ("D5", 2, 2)], 11: [("A4", 0, 1), ("D5", 1, 1), ("F5", 2, 1), ("A5", 3, 1)],
              12: [("Bb5", 0, 1.5), ("A5", 1.5, 0.5), ("G5", 2, 1), ("F5", 3, 1)], 13: [("E5", 0, 1), ("G5", 1, 1), ("C6", 2, 2)],
              14: [("C#6", 0, 2), ("A5", 2, 2)], 15: [("E5", 0, 1), ("C#5", 1, 1), ("A4", 2, 2)]}
    for i, ch in enumerate(prog):
        t0 = i * bar
        tones = chords[ch]
        root = tones[0]
        # basso a crome
        for k in range(8):
            n = root + ("2" if k % 4 != 3 else "3")
            ev.append((t0 + k * beat / 2, bass_saw(NOTE(n), beat / 2 * 0.9), 0.32))
        # batteria
        for k in range(4):
            ev.append((t0 + k * beat, kick(0.3), 0.55 if k in (0, 2) else 0.0))
            if k in (1, 3):
                ev.append((t0 + k * beat, snare(), 0.45))
        for k in range(8):
            ev.append((t0 + k * beat / 2, hat(0.05, 1.0 if k % 2 else 0.6), 0.6))
        if i % 4 == 3:
            for k in range(4):
                ev.append((t0 + 3 * beat + k * beat / 4, snare(0.12), 0.25 + k * 0.06))
        # ottoni in levare
        for k in (0.5, 1.5, 2.5, 3.5):
            for n in tones:
                ev.append((t0 + k * beat, brass(NOTE(n + "4"), beat * 0.4), 0.075))
        # pad
        for n in tones:
            ev.append((t0, pad(NOTE(n + "3"), bar + 0.2), 0.06))
        # melodia eroica (seconda meta')
        for (n, pos, dur) in melody.get(i, []):
            ev.append((t0 + pos * beat, lead(NOTE(n), dur * beat * 0.95), 0.22))
    return render_loop(ev, len(prog) * bar, 2.0, (1.1, 0.18))
