#!/usr/bin/env python3
"""Synthesise Sensory SafeScape's audio into assets/audio/.

Design rules (docs/design-review-v1.md, L11):
  * Nothing above the cutoff: every loop is low-pass filtered and rendered at
    three cutoffs (6 kHz, 4 kHz, 2.5 kHz). The app picks the variant from the
    child's "Mute high pitch" / pitch-cutoff setting.
  * Loops are seamless: they are built and filtered circularly (FFT), so the
    last sample flows into the first.
  * Soft attacks only; no clicks, buzzes or sudden peaks.

Output:
  assets/audio/loops/{hum,rain,ocean,marimba}_{6k,4k,2k5}.wav
  assets/audio/sfx/{tap,step,done,wait_end}.wav
"""
import pathlib
import wave

import numpy as np
from scipy import signal

ROOT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio"
BASE_SR = 32000
LOOP_SECONDS = 20.0
VARIANTS = {"6k": (6000, 16000), "4k": (4000, 12000), "2k5": (2500, 8000)}
rng = np.random.default_rng(7)


def save(path, y, sr):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())


def circular_lowpass(y, sr, cutoff):
    """Zero-phase FFT low-pass with a raised-cosine roll-off (0.75..1.0 x cutoff).

    Circular, so a seamless loop stays seamless."""
    spec = np.fft.rfft(y)
    f = np.fft.rfftfreq(len(y), 1 / sr)
    lo = 0.75 * cutoff
    gain = np.where(f <= lo, 1.0, np.where(f >= cutoff, 0.0, 0.5 * (1 + np.cos(np.pi * (f - lo) / (cutoff - lo)))))
    return np.fft.irfft(spec * gain, n=len(y))


def normalise(y, rms_db=-21.0, peak=0.6):
    y = y - y.mean()
    rms = np.sqrt(np.mean(y ** 2)) + 1e-12
    y = y * (10 ** (rms_db / 20) / rms)
    p = np.abs(y).max()
    return y * (peak / p) if p > peak else y


def loop_noise(n, colour):
    """Circular coloured noise: shape white noise's spectrum (1/f^a)."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / BASE_SR)
    f[0] = f[1]
    spec *= 1 / f ** (colour / 2)
    spec[f < 30] = 0
    return np.fft.irfft(spec, n=n)


def marimba_note(freq, dur, sr=BASE_SR, amp=1.0):
    n = int(dur * sr)
    t = np.arange(n) / sr
    attack = np.minimum(1, t / 0.006)
    body = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.55)
    # Marimba bars: strong 4th partial that dies quickly (soft wooden knock).
    knock = 0.22 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t / 0.05)
    return amp * attack * (body + knock)


def place_circular(n, notes):
    y = np.zeros(n)
    for start, sig in notes:
        idx = (int(start * BASE_SR) + np.arange(len(sig))) % n
        np.add.at(y, idx, sig)
    return y


def whole_cycles(freq):
    return round(freq * LOOP_SECONDS) / LOOP_SECONDS


def make_hum(n):
    t = np.arange(n) / BASE_SR
    y = np.zeros(n)
    # Warm A-major-ish drone with slow, loop-periodic breathing of each voice.
    for fq, amp, period in [(110, 1.0, 10), (165, 0.55, 20), (220, 0.35, 5), (277.2, 0.18, 20), (330, 0.12, 10)]:
        fq = whole_cycles(fq)
        breathe = 0.7 + 0.3 * np.sin(2 * np.pi * t / period + fq)
        y += amp * breathe * (np.sin(2 * np.pi * fq * t) + 0.12 * np.sin(2 * np.pi * 2 * fq * t))
    # Slightly detuned twin (whole cycles too) for a soft chorus.
    y += 0.35 * np.sin(2 * np.pi * whole_cycles(110.35) * t)
    return y


def make_rain(n):
    bed = loop_noise(n, 1.0)  # pink
    bed = bed / np.abs(bed).max()
    t = np.arange(n) / BASE_SR
    bed *= 0.85 + 0.15 * np.sin(2 * np.pi * t / 10)
    drops = []
    for _ in range(int(LOOP_SECONDS * 9)):
        f = rng.uniform(700, 1800)
        d = int(0.06 * BASE_SR)
        tt = np.arange(d) / BASE_SR
        sweep = f * (1 + 0.6 * (1 - np.exp(-tt / 0.01)))
        drops.append((rng.uniform(0, LOOP_SECONDS),
                      rng.uniform(0.04, 0.12) * np.sin(2 * np.pi * np.cumsum(sweep) / BASE_SR) * np.exp(-tt / 0.012)))
    return bed + place_circular(n, drops)


def make_ocean(n):
    y = loop_noise(n, 1.8)  # between pink and brown
    y = y / np.abs(y).max()
    t = np.arange(n) / BASE_SR
    # Two slow swells per loop (10 s each): 4 s rise, 6 s fall like the breath.
    phase = (t % 10) / 10
    swell = np.where(phase < 0.4, np.sin(np.pi / 2 * phase / 0.4) ** 2, np.cos(np.pi / 2 * (phase - 0.4) / 0.6) ** 2)
    return y * (0.15 + 0.85 * swell)


def make_marimba(n):
    # Slow C-major pentatonic lullaby, one note every 1.25 s, tails wrap round.
    scale = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25]
    melody = [2, 3, 4, 3, 2, 1, 0, 1, 2, 4, 5, 4, 3, 2, 1, 2]
    notes = []
    for i, k in enumerate(melody):
        notes.append((i * 1.25, marimba_note(scale[k], 3.0, amp=0.9)))
        if i % 4 == 0:
            notes.append((i * 1.25, marimba_note(scale[k] / 2, 3.5, amp=0.5)))
    return place_circular(n, notes)


def render_loops():
    n = int(LOOP_SECONDS * BASE_SR)
    for name, fn in [("hum", make_hum), ("rain", make_rain), ("ocean", make_ocean), ("marimba", make_marimba)]:
        raw = fn(n)
        for label, (cutoff, sr) in VARIANTS.items():
            y = circular_lowpass(raw, BASE_SR, cutoff)
            y = signal.resample(y, int(LOOP_SECONDS * sr))  # FFT-based, circular
            save(ROOT / "loops" / f"{name}_{label}.wav", normalise(y), sr)


def render_sfx():
    sr = 16000

    def finish(y, peak):
        b, a = signal.butter(4, 3800, fs=BASE_SR)
        y = signal.filtfilt(b, a, y)
        y = signal.resample(y, int(len(y) * sr / BASE_SR))
        fade = int(0.02 * sr)
        y[-fade:] *= np.linspace(1, 0, fade)
        return y / (np.abs(y).max() + 1e-9) * peak

    def seq(total, parts):
        y = np.zeros(int(total * BASE_SR))
        for start, sig in parts:
            i = int(start * BASE_SR)
            y[i:i + len(sig)] += sig[:len(y) - i]
        return y

    # tap: a tiny low water bubble (canvas touch)
    d = int(0.18 * BASE_SR)
    t = np.arange(d) / BASE_SR
    f = 330 + 220 * (1 - np.exp(-t / 0.03))
    tap = np.sin(2 * np.pi * np.cumsum(f) / BASE_SR) * np.minimum(1, t / 0.01) * np.exp(-t / 0.05)
    save(ROOT / "sfx" / "tap.wav", finish(tap, 0.35), sr)
    # step: warm two-note marimba (G4 -> C5) for a finished routine step
    save(ROOT / "sfx" / "step.wav", finish(seq(1.8, [(0, marimba_note(392, 1.6)), (0.16, marimba_note(523.25, 1.6))]), 0.5), sr)
    # done: slow rising arpeggio C4 E4 G4 C5 for a finished routine
    arp = [(i * 0.22, marimba_note(fq, 2.2)) for i, fq in enumerate([261.63, 329.63, 392.0, 523.25])]
    save(ROOT / "sfx" / "done.wav", finish(seq(3.0, arp), 0.5), sr)
    # wait_end: one low, soft marimba note (the wait timer is over)
    save(ROOT / "sfx" / "wait_end.wav", finish(marimba_note(196.0, 2.5), 0.45), sr)


def verify():
    """Fail loudly if any file has energy above its cutoff."""
    for path in sorted(ROOT.rglob("*.wav")):
        with wave.open(str(path)) as w:
            sr = w.getframerate()
            y = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16) / 32767
        label = path.stem.split("_")[-1]
        cutoff = VARIANTS[label][0] if label in VARIANTS else 4000
        spec = np.abs(np.fft.rfft(y)) ** 2
        f = np.fft.rfftfreq(len(y), 1 / sr)
        above = spec[f > cutoff * 1.02].sum() / spec.sum()
        seam = abs(y[0] - y[-1])
        print(f"{path.relative_to(ROOT)}: {sr} Hz, {len(y) / sr:.1f}s, energy>{cutoff}Hz = {above:.2e}, seam jump {seam:.3f}")
        assert above < 1e-4, f"{path} has energy above {cutoff} Hz"


if __name__ == "__main__":
    render_loops()
    render_sfx()
    verify()
