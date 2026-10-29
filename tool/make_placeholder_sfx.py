"""Tạo hiệu ứng âm thanh GIỮ CHỖ (âm sine đơn giản) cho assets/audio/sfx/.

Thay bằng âm thanh thật khi có design âm thanh: giữ nguyên tên file.
Chạy: python3 tool/make_placeholder_sfx.py
"""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'sfx')


def tone(freqs, ms, volume=0.35, shape='bell'):
    """Chuỗi nốt liên tiếp; mỗi nốt dài ms/len(freqs)."""
    out = []
    per = int(RATE * ms / 1000 / len(freqs))
    for f in freqs:
        for i in range(per):
            t = i / RATE
            k = i / per
            env = (1 - k) ** 2 if shape == 'bell' else min(1, k * 8) * (1 - k)
            v = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t)
            out.append(volume * env * v / 1.25)
    return out


SOUNDS = {
    'tap': tone([880], 70),
    'correct': tone([660, 880, 1320], 360),
    'wrong': tone([392, 330], 380, volume=0.25, shape='soft'),  # nhẹ nhàng, không gay gắt
    'time_up': tone([523, 440, 349], 450, volume=0.25, shape='soft'),
    'level_done': tone([523, 659, 784, 1047, 1319], 900),
    'star': tone([1568, 2093], 220, volume=0.25),
}


def write(name, samples):
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(path, os.path.getsize(path), 'bytes')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for n, s in SOUNDS.items():
        write(n, s)
