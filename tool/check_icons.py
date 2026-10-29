"""Kiểm tra biểu tượng app không bị rỗng (lỗi dựng ảnh từng làm biểu tượng chỉ còn nền xanh).

Chạy: python3 tool/check_icons.py   (thoát mã 1 nếu có biểu tượng hỏng)
- ic_launcher.png: phần có màu phải phủ >= 60% (ô vuông bo góc màu xanh).
- ic_launcher_foreground.png: hình bạn nhỏ phải phủ >= 4% và có điểm ảnh trắng.
"""
import glob
import struct
import sys
import zlib


def read_png_rgba(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    pos, idat, w = 8, b'', 0
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', chunk[:10])
            assert depth == 8 and ctype in (2, 6), f'{path}: chỉ đọc PNG 8-bit RGB/RGBA'
            bpp = 4 if ctype == 6 else 3
        elif kind == b'IDAT':
            idat += chunk
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    i = 0
    for _ in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line))
        prev = line
    px = []
    for r in rows:
        for x in range(w):
            q = r[x * bpp:(x + 1) * bpp]
            px.append((q[0], q[1], q[2], q[3] if bpp == 4 else 255))
    return w, h, px


def main():
    bad = []
    files = sorted(glob.glob('android_overlay/app/src/main/res/mipmap-*/ic_launcher*.png'))
    if not files:
        bad.append('không tìm thấy biểu tượng nào')
    for f in files:
        w, h, px = read_png_rgba(f)
        cover = sum(1 for p in px if p[3] > 0) / (w * h)
        white = sum(1 for p in px if p[3] > 200 and min(p[:3]) > 230) / (w * h)
        if f.endswith('foreground.png'):
            ok = cover >= 0.04 and white >= 0.02
        else:
            ok = cover >= 0.6 and white >= 0.02
        print(f'{f}: {w}x{h} phủ {cover:.0%}, trắng {white:.0%} {"OK" if ok else "HỎNG"}')
        if not ok:
            bad.append(f)
    if bad:
        print('Biểu tượng hỏng:', ', '.join(bad))
        sys.exit(1)


if __name__ == '__main__':
    main()
