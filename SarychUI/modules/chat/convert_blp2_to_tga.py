"""Convert Meme Pack BLP2 textures to TGA for WoW 3.3.5 chat compatibility."""
import os
import struct
import sys

try:
    from PIL import Image
except ImportError:
    print("Pillow required: pip install pillow")
    sys.exit(1)


def unpack_rgb565(color):
    r = ((color >> 11) & 0x1F) * 255 // 31
    g = ((color >> 5) & 0x3F) * 255 // 63
    b = (color & 0x1F) * 255 // 31
    return r, g, b


def decode_dxt1_block(block, alpha=False):
    c0, c1 = struct.unpack_from("<HH", block, 0)
    bits = struct.unpack_from("<I", block, 4)[0]
    colors = [unpack_rgb565(c0), unpack_rgb565(c1)]
    if c0 > c1:
        colors += [
            tuple((2 * colors[0][i] + colors[1][i]) // 3 for i in range(3)),
            tuple((colors[0][i] + 2 * colors[1][i]) // 3 for i in range(3)),
        ]
    else:
        colors += [
            tuple((colors[0][i] + colors[1][i]) // 2 for i in range(3)),
            (0, 0, 0),
        ]
    out = []
    for y in range(4):
        for x in range(4):
            idx = (bits >> (2 * (y * 4 + x))) & 3
            r, g, b = colors[idx]
            a = 0 if (idx == 3 and c0 <= c1 and not alpha) else 255
            out.append((r, g, b, a))
    return out


def decode_dxt3_block(block):
    alpha = []
    for i in range(8):
        a = block[i]
        alpha.extend([((a >> 4) & 0xF) * 17, (a & 0xF) * 17])
    color = decode_dxt1_block(block[8:16], alpha=True)
    for i, px in enumerate(color):
        r, g, b, _ = px
        color[i] = (r, g, b, alpha[i])
    return color


def decode_dxt5_block(block):
    a0, a1 = block[0], block[1]
    abits = int.from_bytes(block[2:8], "little")
    alpha = []
    if a0 > a1:
        alphas = [a0, a1] + [((6 - i) * a0 + (1 + i) * a1) // 7 for i in range(1, 7)]
    else:
        alphas = [a0, a1] + [((4 - i) * a0 + (1 + i) * a1) // 5 for i in range(1, 5)] + [0, 255]
    for i in range(16):
        idx = (abits >> (3 * i)) & 7
        alpha.append(alphas[idx])
    color = decode_dxt1_block(block[8:16], alpha=True)
    for i, px in enumerate(color):
        r, g, b, _ = px
        color[i] = (r, g, b, alpha[i])
    return color


def decode_dxt(data, width, height, fmt):
    blocks_x = max(1, width // 4)
    blocks_y = max(1, height // 4)
    img = Image.new("RGBA", (width, height))
    pixels = img.load()
    offset = 0
    block_size = 16
    for by in range(blocks_y):
        for bx in range(blocks_x):
            block = data[offset : offset + block_size]
            offset += block_size
            if fmt == "dxt1":
                px = decode_dxt1_block(block)
            elif fmt == "dxt3":
                px = decode_dxt3_block(block)
            else:
                px = decode_dxt5_block(block)
            i = 0
            for y in range(4):
                for x in range(4):
                    sx, sy = bx * 4 + x, by * 4 + y
                    if sx < width and sy < height:
                        pixels[sx, sy] = px[i]
                    i += 1
    return img


def read_blp2(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"BLP2":
        raise ValueError(f"Not BLP2: {path}")
    compression = data[8]
    alpha_encoding = data[10]
    width, height = struct.unpack_from("<II", data, 12)
    offset, length = struct.unpack_from("<II", data, 20)
    payload = data[offset : offset + length]

    if compression == 1:
        raise ValueError(f"JPEG BLP2 not supported: {path}")
    if compression == 3:
        raise ValueError(f"Raw BLP2 not supported: {path}")
    if compression != 2:
        raise ValueError(f"Unknown compression {compression}: {path}")

    if alpha_encoding in (0,):
        fmt = "dxt1"
    elif alpha_encoding in (1,):
        fmt = "dxt3"
    else:
        fmt = "dxt5"

    return decode_dxt(payload, width, height, fmt)


WOW_EMOJI_SIZE = 32


def save_wow_tga(img, dst):
    """Match ElvUI chat emoji TGA: 32x32, RGBA, RLE compression."""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    if img.size != (WOW_EMOJI_SIZE, WOW_EMOJI_SIZE):
        img = img.resize((WOW_EMOJI_SIZE, WOW_EMOJI_SIZE), Image.LANCZOS)
    img.save(dst, format="TGA", compression="tga_rle")


def convert_dir(src_dir, overwrite=True):
    converted = 0
    failed = []
    blp_src = os.path.join(src_dir, "meme_pack_v2")
    if not os.path.isdir(blp_src):
        blp_src = src_dir
    for name in sorted(os.listdir(blp_src)):
        if not name.lower().endswith(".blp"):
            continue
        src = os.path.join(blp_src, name)
        dst = os.path.join(src_dir, os.path.splitext(name)[0] + ".tga")
        if not overwrite and os.path.exists(dst):
            continue
        try:
            img = read_blp2(src)
            save_wow_tga(img, dst)
            converted += 1
            print(f"OK {name} -> {os.path.basename(dst)}")
        except Exception as exc:
            failed.append((name, str(exc)))
            print(f"FAIL {name}: {exc}")
    print(f"Converted: {converted}, failed: {len(failed)}")
    return converted, failed


if __name__ == "__main__":
    default = os.path.normpath(
        os.path.join(os.path.dirname(__file__), "..", "..", "media", "chat_emojis")
    )
    target = sys.argv[1] if len(sys.argv) > 1 else default
    convert_dir(target)
