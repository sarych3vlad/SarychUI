import os
import re

SRC = os.path.join(os.path.dirname(__file__), "..", "..", "..", "Meme Pack v2", "WeakAuras", "Media", "Textures")
OUT = os.path.join(os.path.dirname(__file__), "meme_pack_v2_data.lua")
MEDIA_OUT = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "..", "media", "chat_emojis")
)


def safe_name(base: str) -> str:
    if base == "D_":
        return "d_dot"
    if base.startswith("_"):
        return "meme" + base
    return base.lower().replace("-", "_")


def main():
    memes = []
    for fn in sorted(os.listdir(SRC)):
        if not fn.lower().endswith(".blp"):
            continue
        base = os.path.splitext(fn)[0]
        safe = safe_name(base)
        code = ":" + re.sub(r"_+", "_", safe) + ":"
        memes.append((code, f"{safe}.tga"))

    classic = [
        ([":)"], "peepohappy.tga", ":)"),
        ([":(", ":%(", ":%-%("], "peeposad.tga", ":("),
        ([":D", ":%-D", ";D", ";%-D", "=D", "xD", "XD"], "kekw.tga", ":D"),
        ([";)", ";%)", ";%-%)"], "hehe.tga", ";)"),
        ([":P", ":p", ":%-P", ":%-p", "=P", "=p", ";P", ";p", ";%-P", ";%-p"], "blehhhh.tga", ":P"),
        (["<3"], "peepoblush.tga", "<3"),
        (["</3", "<\\3"], "sadge.tga", "</3"),
        ([":angry:", ":%-@", ":@", ">:("], "angrydog.tga", ":angry:"),
        ([":kappa:", ":komrade:"], "kkomrade.tga", ":kappa:"),
        ([":murloc:"], "glorp.tga", ":murloc:"),
        ([":facepalm:"], "pikafacepalm.tga", ":facepalm:"),
        ([":cry:", ":,%(", ":,%-%(", ":'%(", ":'%-%("], "peeposad.tga", None),
        ([":grin:", ":smile:"], "peepohappy.tga", None),
        ([":heart:"], "peepoblush.tga", ":heart:"),
        ([":broken_heart:"], "sadge.tga", None),
        ([":thinking:", ":thonk:"], "thonk.tga", ":thinking:"),
        ([":wink:"], "soysmug.tga", None),
        ([":pog:"], "pog.tga", ":pog:"),
        ([":clown:"], "peepoclown.tga", ":clown:"),
        ([":sus:"], "sus.tga", ":sus:"),
        ([":joy:", ":'%)", ";'%)"] , "pepelaugh.tga", ":joy:"),
        ([":rage:", "D:<"], "reallymad.tga", ":rage:"),
        ([":blush:", ":%$"], "peepoblush.tga", None),
        ([":sob:", ";o;"], "sadding.tga", ":sob:"),
        ([":scream:", ":o", ":%-o", ":%-O", ":O", ":%-0"], "shocked.tga", None),
        ([":sunglasses:", "8%)", "8%-%)"], "soysmug.tga", None),
        ([":thumbs_up:", ":%+1:"], "based.tga", ":thumbs_up:"),
        ([":middle_finger:", ":F", ",,!,,"], "madge.tga", None),
        ([":monkas:", ":monka:"], "monkas.tga", ":monkas:"),
        ([":slight_frown:"], "sadge.tga", None),
        ([":open_mouth:"], "shocked.tga", None),
        ([":stuck_out_tongue:"], "blehhhh.tga", None),
        ([":stuck_out_tongue_closed_eyes:", "XP"], "nyehehehe.tga", None),
        ([":smirk:", ":S", ":%-S"], "sideeye.tga", None),
        ([":scream_cat:", ":o3"], "confusedcat.tga", None),
        ([":semi_colon:", ":;:"], "hmm.tga", None),
        ([":meaw:"], "weirdcat.tga", None),
        ([":poop:"], "eww.tga", None),
        ([":ok_hand:"], "ok.tga", None),
        ([":call_me:"], "based.tga", None),
        ([":heart_eyes:"], "catblush.tga", None),
        ([":sadkitty:"], "sadcat.tga", None),
        ([":zzz:"], "waiting.tga", None),
        ([":%-%)", ":%)"], "peepohappy.tga", None),
    ]

    lines = [
        "-- Meme Pack v2 smiley registry",
        "SarychUI_MemePackV2Data = {",
        "    memes = {",
    ]
    for code, file in memes:
        lines.append(f'        {{ code = "{code}", file = "{file}" }},')
    lines.append("    },")
    lines.append("    classic = {")
    for keys, file, picker in classic:
        keystr = ", ".join('"' + k.replace("\\", "\\\\") + '"' for k in keys)
        pick = "nil" if picker is None else f'"{picker}"'
        lines.append(f'        {{ keys = {{ {keystr} }}, file = "{file}", picker = {pick} }},')
    lines.append("    },")
    lines.append('    buttonIcon = "peepohappy.tga",')
    lines.append("}")

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print(f"memes={len(memes)} classic={len(classic)} -> {OUT}")


if __name__ == "__main__":
    main()
