"""Generate original short notification arpeggios; requires ffmpeg. No sampled audio."""
import math
from pathlib import Path
import struct
import subprocess
import tempfile
import wave

DEST = Path(__file__).resolve().parents[1] / 'Media'
DEST.mkdir(exist_ok=True)
RATE = 44100
# Generic ascending/descending major arpeggios, independently synthesized.
CUES = {'herb': (523.25, 659.25, 783.99), 'craft': (392.00, 493.88, 587.33, 783.99),
        'ready': (783.99, 659.25, 523.25)}
for name, notes in CUES.items():
    duration = 0.16 * (len(notes) - 1) + 0.45
    data = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        sample = 0.0
        for n, hz in enumerate(notes):
            age = t - n * 0.16
            if 0 <= age <= 0.45:
                envelope = min(1, age / 0.008) * math.exp(-age * 10) * max(0, 1 - age / 0.45)
                sample += 0.22 * envelope * (math.sin(2 * math.pi * hz * age) + 0.22 * math.sin(4 * math.pi * hz * age))
        data.append(struct.pack('<h', int(max(-1, min(1, sample)) * 32767)))
    with tempfile.TemporaryDirectory() as temp:
        wav = Path(temp) / 'cue.wav'
        with wave.open(str(wav), 'wb') as out:
            out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE); out.writeframes(b''.join(data))
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(wav), '-c:a', 'libvorbis',
                        '-q:a', '4', '-map_metadata', '-1', str(DEST / (name + '.ogg'))], check=True)
    print(name + '.ogg:', (DEST / (name + '.ogg')).stat().st_size, 'bytes')
