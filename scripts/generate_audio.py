"""Project-original procedural ambient/effect audio; deterministic, no external assets."""
import math, random, struct, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050
rng = random.Random(426)

def save(name, samples):
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in samples))

rain = []
low = 0.0
for i in range(RATE * 12):
    noise = rng.uniform(-1, 1)
    low = low * .94 + noise * .06
    # Smooth periodic modulation makes the loop seam continuous in loudness.
    rain.append((noise * .045 + low * .12) * (.88 + .12 * math.cos(2 * math.pi * i / (RATE * 12))))
save('rain', rain)
for name, duration, frequency in [('phone', .65, 125), ('computer', .7, 540), ('step', .18, 85), ('door', .65, 64)]:
    samples = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        env = min(1, t * 90) * math.exp(-t * (12 if name == 'step' else 5))
        if name == 'phone':
            env *= 1 if t < .18 or .3 < t < .48 else 0
        value = math.sin(2 * math.pi * frequency * t) * .14
        value += rng.uniform(-1, 1) * (.12 if name in ('step', 'door') else .015)
        samples.append(value * env)
    save(name, samples)
print('Generated five original WAV assets.')
