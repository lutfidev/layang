"""Generates assets/audio/gamelan_loop.ogg — a seamless, gamelan-inspired ambient loop.
Run: python3 tools/gen_music.py   (needs numpy + ffmpeg). Pure synthesis, no samples."""
import numpy as np, subprocess, wave, os, sys

RATE = 32000
BPM = 84.0
BEAT = 60.0 / BPM
BEATS = 32
N = int(BEATS * BEAT * RATE)
SLENDRO = [1.0, 1.145, 1.31, 1.505, 1.72, 2.0, 2.29, 2.62]
BASE = 196.0
rng = np.random.default_rng(2026)
out = np.zeros((N, 2), dtype=np.float64)

def bell(freq, start, length, vol, decay, pan=0.0):
    t = np.arange(int(length * RATE)) / RATE
    env = np.exp(-t * decay) * np.minimum(1.0, t * 300.0)
    w = (np.sin(2*np.pi*freq*t)
         + 0.45*np.sin(2*np.pi*freq*2.76*t)*np.exp(-t*decay*2)
         + 0.2*np.sin(2*np.pi*freq*5.4*t)*np.exp(-t*decay*4)
         + 0.15*np.sin(2*np.pi*(freq*1.003)*t)) * env * vol   # slight beating like paired gamelan tuning
    idx = (int(start * RATE) + np.arange(len(w))) % N           # wrap → seamless loop
    out[idx, 0] += w * (1 - pan) * 0.5 * 2
    out[idx, 1] += w * (1 + pan) * 0.5 * 2

deg = 2
for b in range(BEATS * 2):                      # saron melody on 8th notes
    if rng.random() < 0.3:
        continue
    deg = int(np.clip(deg + rng.integers(-2, 3), 0, len(SLENDRO) - 1))
    bell(BASE * 2 * SLENDRO[deg], b * BEAT * 0.5, 1.4, 0.08, 3.2, pan=rng.uniform(-0.4, 0.4))
bass = [0, 2, 3, 2, 0, 4, 3, 2]
for b in range(BEATS):                          # bonang-like low line
    bell(BASE * SLENDRO[bass[b % len(bass)]], b * BEAT, 2.0, 0.07, 2.2, pan=-0.2)
for b in range(0, BEATS, 4):                    # kenong accents
    bell(BASE * 1.5 * SLENDRO[[0, 3, 2, 4][(b // 4) % 4]], b * BEAT, 2.5, 0.05, 1.6, pan=0.3)
for b in (0, 16):                               # gong ageng
    bell(65.4, b * BEAT, 6.0, 0.26, 0.55)
# soft pad (drone)
t = np.arange(N) / RATE
pad = 0.025 * (np.sin(2*np.pi*BASE/2*t) + 0.5*np.sin(2*np.pi*BASE*0.75*t)) * (0.6 + 0.4*np.sin(2*np.pi*t/(N/RATE)))
out[:, 0] += pad; out[:, 1] += pad
out /= np.max(np.abs(out)) * 1.15
pcm = (out * 32767).astype(np.int16)
root = os.path.join(os.path.dirname(__file__), "..")
wav = os.path.join(root, "gamelan_tmp.wav")
with wave.open(wav, "wb") as f:
    f.setnchannels(2); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())
dst = os.path.join(root, "assets", "audio", "gamelan_loop.ogg")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
os.remove(wav)
print("wrote", dst, round(N / RATE, 2), "s")
