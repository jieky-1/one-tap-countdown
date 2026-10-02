"""生成 PWA 图标（纯标准库，无需 Pillow）：深色底 + 白色倒计时圆环 + 指针。"""
import math
import struct
import zlib
import os

BG = (26, 29, 41)
FG = (255, 255, 255)


def render(size: int):
    s = size
    cx = cy = (s - 1) / 2
    r_out, r_in = s * 0.36, s * 0.27
    hand_len, hand_w = s * 0.20, max(1.0, s * 0.05)
    ss = 3  # 3x3 超采样抗锯齿

    raw = bytearray()
    for y in range(s):
        raw.append(0)  # filter type 0
        for x in range(s):
            hit = 0
            for j in range(ss):
                for i in range(ss):
                    px = x + (i + 0.5) / ss
                    py = y + (j + 0.5) / ss
                    dx, dy = px - cx, py - cy
                    d = math.hypot(dx, dy)
                    inside = False
                    if r_in <= d <= r_out:
                        ang = math.degrees(math.atan2(dy, dx))  # -90 = 正上方
                        if not (-98 <= ang <= -72):             # 顶部留缺口
                            inside = True
                    if abs(dx) <= hand_w / 2 and -hand_len <= dy <= 0:
                        inside = True                            # 指针
                    if inside:
                        hit += 1
            a = hit / (ss * ss)
            raw += bytes(int(BG[c] + (FG[c] - BG[c]) * a) for c in range(3)) + b"\xff"
    return bytes(raw)


def chunk(typ: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + typ + data +
            struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF))


def write_png(path: str, size: int):
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(render(size), 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(data)
    print(f"{path}  {size}x{size}  {len(data)} bytes")


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "preview")
    write_png(os.path.join(out, "icon-180.png"), 180)
    write_png(os.path.join(out, "icon-512.png"), 512)
