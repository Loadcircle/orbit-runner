"""Procedurally synthesises every sound effect and music loop of Orbit Runner.

    python assets_source/audio/generate_audio.py

Writes 16-bit mono WAV files to audio/sfx/ and audio/music/. Everything is
original and generated from simple oscillators, noise and envelopes, so there
are no third-party samples or licences involved. Deterministic (fixed seeds).
"""
import os
import wave

import numpy as np

SR = 32000
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")


# ---------------------------------------------------------------- primitives

def t_axis(duration):
    return np.arange(int(SR * duration)) / SR


def note_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def phase_from_freq(freq):
    return 2 * np.pi * np.cumsum(freq) / SR


def osc(kind, freq, duration=None, duty=0.5):
    if np.isscalar(freq):
        freq = np.full(int(SR * duration), float(freq))
    ph = phase_from_freq(freq)
    if kind == "sine":
        return np.sin(ph)
    if kind == "square":
        return np.where((ph / (2 * np.pi)) % 1.0 < duty, 1.0, -1.0)
    if kind == "saw":
        return 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    if kind == "tri":
        return 2.0 * np.abs(2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(kind)


def noise(duration, seed=0):
    return np.random.default_rng(seed).uniform(-1, 1, int(SR * duration))


def env(n, attack=0.005, decay=0.1, sustain=0.0, release=0.05, hold=None):
    """ADSR envelope over n samples (times in seconds)."""
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = max(1, int(release * SR))
    e = np.zeros(n)
    a_end = min(a, n)
    e[:a_end] = np.linspace(0, 1, a)[:a_end]
    d_end = min(a + d, n)
    if d_end > a:
        e[a:d_end] = np.linspace(1, sustain, d)[: d_end - a]
    s_end = n - r if hold is None else min(n, a + d + int(hold * SR))
    if s_end > d_end:
        e[d_end:s_end] = sustain
    start = max(s_end, d_end)
    if start < n:
        level = e[start - 1] if start > 0 else sustain
        e[start:] = np.linspace(level, 0, n - start)
    return e


def exp_decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def lowpass_fast(x, cutoff):
    """Moving-average low-pass (cheap, good enough for chiptune timbres)."""
    width = max(1, int(SR / (cutoff * 2.2)))
    kernel = np.ones(width) / width
    return np.convolve(x, kernel, mode="same")


def highpass_fast(x, cutoff):
    return x - lowpass_fast(x, cutoff)


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x * (peak / m)


def soft_clip(x, drive=1.2):
    return np.tanh(x * drive) / np.tanh(drive)


def write(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def sweep(f0, f1, duration, curve=1.0):
    n = int(SR * duration)
    k = np.linspace(0, 1, n) ** curve
    return f0 + (f1 - f0) * k


def mix_at(buf, x, start):
    s = int(start * SR)
    e = min(len(buf), s + len(x))
    if s < len(buf):
        buf[s:e] += x[: e - s]


# ---------------------------------------------------------------- sound effects

def sfx():
    out = {}
    d = 0.16
    x = osc("square", sweep(320, 760, d, 0.6), duty=0.35) * env(int(SR * d), 0.002, 0.14) * 0.5
    x += osc("sine", sweep(640, 1500, d, 0.6)) * env(int(SR * d), 0.002, 0.1) * 0.3
    out["jump"] = x
    d = 0.12
    out["land"] = lowpass_fast(noise(d, 1), 600) * exp_decay(int(SR * d), 0.03) * 1.6 + \
        osc("sine", sweep(140, 60, d)) * exp_decay(int(SR * d), 0.04) * 0.6
    d = 0.28
    n = noise(d, 2)
    out["dash"] = (highpass_fast(n, 900) * env(int(SR * d), 0.02, 0.25) * 0.6
                   + osc("saw", sweep(300, 900, d), ) * env(int(SR * d), 0.01, 0.2) * 0.15)
    d = 0.32
    out["slide"] = lowpass_fast(noise(d, 3), 1200) * env(int(SR * d), 0.03, 0.05, 0.6, 0.15) * 0.9
    d = 0.22
    out["yoyo_throw"] = (highpass_fast(noise(d, 4), 1500) * env(int(SR * d), 0.03, 0.18) * 0.4
                         + osc("tri", sweep(500, 1100, d)) * env(int(SR * d), 0.01, 0.2) * 0.35)
    d = 0.45
    x = np.zeros(int(SR * d))
    for i, m in enumerate([76, 83, 88]):
        tone = osc("sine", note_hz(m), d) + 0.3 * osc("sine", note_hz(m) * 2.76, d)
        mix_at(x, tone * exp_decay(int(SR * d), 0.18) * 0.3, i * 0.03)
    out["yoyo_deploy"] = x
    d = 0.2
    out["yoyo_return"] = osc("tri", sweep(1200, 500, d)) * env(int(SR * d), 0.005, 0.18) * 0.35
    d = 0.42
    f = sweep(220, 720, d, 0.5) * (1 + 0.06 * np.sin(2 * np.pi * 18 * t_axis(d)))
    out["bounce_yoyo"] = (osc("sine", f) * env(int(SR * d), 0.003, 0.4) * 0.7
                          + osc("square", f * 0.5, duty=0.25) * env(int(SR * d), 0.003, 0.15) * 0.15)
    d = 0.5
    f = sweep(150, 460, d, 0.45) * (1 + 0.1 * np.sin(2 * np.pi * 26 * t_axis(d)) * np.linspace(1, 0, int(SR * d)))
    rattle = np.zeros(int(SR * d))
    mix_at(rattle, lowpass_fast(noise(0.06, 5), 900) * exp_decay(int(SR * 0.06), 0.02) * 0.5, 0.0)
    out["trampoline"] = osc("sine", f) * env(int(SR * d), 0.002, 0.48) * 0.8 + rattle
    d = 0.4
    out["boost"] = (osc("saw", sweep(200, 1000, d, 0.7)) * env(int(SR * d), 0.01, 0.38) * 0.3
                    + highpass_fast(noise(d, 6), 2000) * env(int(SR * d), 0.05, 0.3) * 0.25)
    d = 0.55
    x = np.zeros(int(SR * d))
    rng = np.random.default_rng(7)
    for k in range(9):
        c = lowpass_fast(noise(0.04, 10 + k), 2500) * exp_decay(int(SR * 0.04), 0.012)
        mix_at(x, c * rng.uniform(0.4, 1.0), rng.uniform(0, d - 0.05))
    out["crumble"] = x
    d = 0.7
    x = np.zeros(int(SR * d))
    for i, m in enumerate([76, 83]):
        tone = osc("sine", note_hz(m), 0.6) + 0.25 * osc("sine", note_hz(m) * 3, 0.6)
        mix_at(x, tone * exp_decay(int(SR * 0.6), 0.2) * 0.4, i * 0.1)
    out["checkpoint"] = x
    d = 0.6
    x = np.zeros(int(SR * d))
    for i, m in enumerate([84, 88, 91, 96]):
        tone = osc("sine", note_hz(m), 0.4) + 0.2 * osc("sine", note_hz(m) * 2.0, 0.4)
        mix_at(x, tone * exp_decay(int(SR * 0.4), 0.12) * 0.3, i * 0.055)
    out["gem"] = x
    d = 0.09
    out["spark"] = osc("square", sweep(1200, 1700, d), duty=0.25) * env(int(SR * d), 0.001, 0.08) * 0.3
    d = 1.4
    x = np.zeros(int(SR * d))
    for i, m in enumerate([72, 76, 79, 84]):
        tone = osc("square", note_hz(m), 0.3, duty=0.3) * 0.4 + osc("sine", note_hz(m), 0.3) * 0.4
        mix_at(x, tone * env(int(SR * 0.3), 0.005, 0.25), i * 0.11)
    for m in [72, 76, 79, 84]:
        mix_at(x, osc("tri", note_hz(m), 0.9) * env(int(SR * 0.9), 0.01, 0.2, 0.4, 0.5) * 0.25, 0.48)
    out["goal"] = x
    d = 0.55
    out["fail"] = (osc("square", sweep(520, 140, d, 0.8), duty=0.4) * env(int(SR * d), 0.005, 0.5) * 0.35
                   + lowpass_fast(noise(d, 8), 500) * exp_decay(int(SR * d), 0.08) * 0.4)
    d = 1.0
    x = np.zeros(int(SR * d))
    for i, m in enumerate([79, 83, 86, 91]):
        mix_at(x, osc("sine", note_hz(m), 0.8) * exp_decay(int(SR * 0.8), 0.3) * 0.25, i * 0.04)
    out["medal"] = x
    d = 1.0
    x = np.zeros(int(SR * d))
    for i, m in enumerate([72, 79, 84, 88, 91]):
        tone = osc("sine", note_hz(m), 0.5) + 0.3 * osc("sine", note_hz(m) * 2.76, 0.5)
        mix_at(x, tone * exp_decay(int(SR * 0.5), 0.15) * 0.25, i * 0.07)
    out["achievement"] = x
    d = 0.45
    x = np.zeros(int(SR * d))
    for i, m in enumerate([88, 95]):
        mix_at(x, osc("square", note_hz(m), 0.25, duty=0.25) * exp_decay(int(SR * 0.25), 0.07) * 0.3, i * 0.08)
    out["purchase"] = x
    d = 0.04
    out["ui_click"] = osc("square", 1400, d, duty=0.3) * exp_decay(int(SR * d), 0.008) * 0.3
    d = 0.16
    x = np.zeros(int(SR * d))
    mix_at(x, osc("tri", note_hz(81), 0.07) * env(int(SR * 0.07), 0.002, 0.06) * 0.4, 0.0)
    mix_at(x, osc("tri", note_hz(88), 0.09) * env(int(SR * 0.09), 0.002, 0.08) * 0.4, 0.06)
    out["ui_confirm"] = x
    x = np.zeros(int(SR * d))
    mix_at(x, osc("tri", note_hz(84), 0.07) * env(int(SR * 0.07), 0.002, 0.06) * 0.4, 0.0)
    mix_at(x, osc("tri", note_hz(77), 0.09) * env(int(SR * 0.09), 0.002, 0.08) * 0.4, 0.06)
    out["ui_back"] = x
    for name, x in out.items():
        write(os.path.join(SFX_DIR, name + ".wav"), normalize(np.asarray(x, dtype=float), 0.8))
    return list(out)


# ---------------------------------------------------------------- music

def kick(n_dur=0.25):
    d = n_dur
    return osc("sine", sweep(130, 42, d, 0.4)) * exp_decay(int(SR * d), 0.07) * 0.9


def snare(seed):
    d = 0.18
    return (highpass_fast(noise(d, seed), 1200) * exp_decay(int(SR * d), 0.045) * 0.5
            + osc("sine", 190, d) * exp_decay(int(SR * d), 0.03) * 0.3)


def hat(seed, open_hat=False):
    d = 0.12 if open_hat else 0.04
    return highpass_fast(noise(d, seed), 5000) * exp_decay(int(SR * d), 0.035 if open_hat else 0.01) * 0.25


def chord_notes(root, quality):
    third = 4 if quality == "maj" else 3
    return [root, root + third, root + 7]


def song(name, bpm, key_root, progression, bars, seed, lead_kind="square", swing=0.0, pad=True, lead_octave=12,
         energy=1.0):
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar_len = beat * 4
    total = bars * bar_len
    n = int(SR * total) + SR
    out = np.zeros(n)
    drums = np.zeros(n)
    bass = np.zeros(n)
    lead = np.zeros(n)
    pads = np.zeros(n)
    scale = [0, 2, 4, 7, 9]  # major pentatonic keeps melodies bright
    # A 4-bar motif reused with variations: A A' B A''.
    motif = []
    for step in range(16):
        if rng.random() < 0.72:
            motif.append((step, int(rng.integers(0, 5)), int(rng.choice([1, 1, 2]))))
    for bar in range(bars):
        t0 = bar * bar_len
        root_off, quality = progression[bar % len(progression)]
        root = key_root + root_off
        section = (bar // 4) % 4
        # Drums
        for b in range(4):
            bt = t0 + b * beat
            if b in (0, 2) or (energy > 1.0 and b == 3 and bar % 2 == 1):
                mix_at(drums, kick(), bt)
            if b in (1, 3):
                mix_at(drums, snare(seed + bar * 4 + b), bt)
            for h in range(2):
                off = h * beat * 0.5 + (swing * beat * 0.5 if h == 1 else 0.0)
                mix_at(drums, hat(seed + bar * 8 + b * 2 + h, open_hat=(h == 1 and b == 3)), bt + off)
        # Bass: root / fifth eighth-notes
        for e in range(8):
            m = root - 24 + (7 if e % 4 == 3 else 0) + (12 if e % 8 == 6 else 0)
            dur = beat * 0.45
            tone = osc("tri", note_hz(m), dur) * env(int(SR * dur), 0.004, 0.12, 0.5, 0.05) * 0.55
            mix_at(bass, tone, t0 + e * beat * 0.5)
        # Pad: sustained chord
        if pad:
            for m in chord_notes(root, quality):
                tone = (osc("saw", note_hz(m), bar_len) + osc("saw", note_hz(m) * 1.004, bar_len)) * 0.5
                pads_tone = lowpass_fast(tone, 1400) * env(int(SR * bar_len), 0.25, 0.3, 0.7, 0.4) * 0.12
                mix_at(pads, pads_tone, t0)
        # Lead: motif with variations; rests in the first bars of the track.
        if bar >= 2:
            variation = section
            bar_motif = [m for m in motif if m[0] // 4 == bar % 4] or motif[:3]
            for step, degree, length in bar_motif:
                local_step = step % 4 * 2 + (1 if variation == 1 and rng.random() < 0.3 else 0)
                st = t0 + local_step * beat * 0.5
                deg = (degree + (2 if variation == 2 else 0)) % 5
                octave = 12 if (variation == 3 and degree > 2) else 0
                m = key_root + lead_octave + scale[deg] + octave
                # Pull towards chord tones on strong beats.
                if local_step % 4 == 0:
                    tones = chord_notes(root + lead_octave, quality)
                    m = min(tones, key=lambda c: abs(c - m))
                dur = beat * 0.5 * length * 0.9
                vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t_axis(dur))
                tone = osc(lead_kind, note_hz(m) * vib, duty=0.4) if lead_kind in ("square", "saw", "tri") else \
                    osc("sine", note_hz(m) * vib)
                tone = tone * env(int(SR * dur), 0.006, 0.12, 0.55, 0.06) * 0.22
                mix_at(lead, tone, st)
                # Soft echo for space.
                mix_at(lead, tone * 0.3, st + beat * 0.75)
    out = drums * 0.8 * energy + bass * 0.9 + pads + lowpass_fast(lead, 5000) * 1.0
    out = out[: int(SR * total)]
    # Short fades at the loop seam to avoid clicks.
    fade = int(SR * 0.01)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    write(os.path.join(MUSIC_DIR, name + ".wav"), normalize(soft_clip(normalize(out, 0.95), 1.3), 0.85))
    return name


def victory_jingle():
    d = 3.2
    x = np.zeros(int(SR * d))
    seq = [67, 72, 76, 79, 84]
    for i, m in enumerate(seq):
        tone = osc("square", note_hz(m), 0.22, duty=0.35) * 0.35 + osc("tri", note_hz(m), 0.22) * 0.3
        mix_at(x, tone * env(int(SR * 0.22), 0.005, 0.18), i * 0.13)
    for m in [72, 76, 79, 84, 60]:
        tone = osc("saw", note_hz(m), 2.2) * 0.5 + osc("saw", note_hz(m) * 1.005, 2.2) * 0.5
        mix_at(x, lowpass_fast(tone, 2000) * env(int(SR * 2.2), 0.02, 0.4, 0.5, 1.2) * 0.18, 0.7)
    mix_at(x, kick(), 0.7)
    write(os.path.join(MUSIC_DIR, "victory_jingle.wav"), normalize(x, 0.85))


def main():
    names = sfx()
    print("sfx:", ", ".join(names))
    song("menu_theme", 100, 60, [(0, "maj"), (9, "min"), (5, "maj"), (7, "maj")], 16, 101, lead_kind="tri",
         energy=0.6)
    song("sky_isles", 126, 67, [(0, "maj"), (7, "maj"), (9, "min"), (5, "maj")], 24, 202, lead_kind="square")
    song("toyworks", 136, 65, [(0, "maj"), (9, "min"), (2, "min"), (7, "maj")], 24, 303, lead_kind="square",
         swing=0.25, energy=1.2)
    song("solar_ruins", 120, 62, [(0, "maj"), (10, "maj"), (5, "maj"), (0, "maj")], 24, 404, lead_kind="saw",
         energy=1.1)
    victory_jingle()
    print("music: done")


if __name__ == "__main__":
    main()
