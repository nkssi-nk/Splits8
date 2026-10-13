#!/usr/bin/env python3
"""아이폰 파일에서 안드로이드 shared 코드를 만듦 (손으로 옮기다 틀리지 않게).

  python3 android/tools/gen_from_ios.py      (저장소 맨 위에서)

만드는 것
  - L10nKo.kt : Resources/iOS·Watch/ko.lproj/Localizable.strings → 한국어 표
  - BenchData.kt : Shared/Benchmarks.swift 의 중간값 표 (HyroxBench)
  - 그림       : Resources/iOS/Assets.xcassets → app/res/drawable-nodpi + IconRes.kt

아이폰 문구나 표가 바뀌면 이 스크립트를 다시 돌리면 됨.

⚠ android 가지 안의 아이폰 폴더는 빌드 21 그대로라 오래됨. 최신 아이폰 가지(예: build23)를
  따로 꺼낸 폴더에 android/ 를 복사해 넣고 거기서 돌린 뒤, 나온 파일만 가져올 것:
    git worktree add --detach ../wt origin/build23 && cp -r android ../wt/ && (cd ../wt && python3 android/tools/gen_from_ios.py)
  안드로이드에만 있는 한국어 문구는 android/tools/ko-android.strings 에 넣음.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "android/shared/src/main/kotlin/com/nkssi/splits8/shared")


def kstr(s: str) -> str:
    """파이썬 문자열 → 코틀린 문자열 글자"""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("\n", "\\n").replace("\t", "\\t") + '"'


def unescape(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


PAIR = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')


def read_strings(path):
    d = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = PAIR.match(line)
            if m:
                d[unescape(m.group(1))] = unescape(m.group(2))
    return d


def gen_l10n():
    ios = read_strings(os.path.join(ROOT, "Resources/iOS/ko.lproj/Localizable.strings"))
    watch = read_strings(os.path.join(ROOT, "Resources/Watch/ko.lproj/Localizable.strings"))
    merged = dict(watch)
    merged.update(ios)  # 같은 열쇠는 아이폰 쪽
    # 안드로이드에만 있는 문구 ("iPhone" → "폰" 등). 같은 열쇠면 이쪽이 이김
    merged.update(read_strings(os.path.join(ROOT, "android/tools/ko-android.strings")))
    items = sorted(merged.items())
    chunks = [items[i:i + 150] for i in range(0, len(items), 150)]
    lines = [
        "// 자동 생성 — 직접 고치지 말 것. android/tools/gen_from_ios.py",
        "// 원본: Resources/iOS/ko.lproj · Resources/Watch/ko.lproj Localizable.strings + android/tools/ko-android.strings",
        "package com.nkssi.splits8.shared",
        "",
        "internal object L10nKo {",
        "    private val map: Map<String, String> by lazy {",
        "        HashMap<String, String>(%d).apply {" % (len(items) * 2),
    ]
    for n in range(len(chunks)):
        lines.append("            part%d(this)" % n)
    lines += ["        }", "    }", "", "    fun get(key: String): String? = map[key]", "    val size: Int get() = map.size", ""]
    for n, ch in enumerate(chunks):
        lines.append("    private fun part%d(m: HashMap<String, String>) {" % n)
        for k, v in ch:
            lines.append("        m[%s] = %s" % (kstr(k), kstr(v)))
        lines.append("    }")
    lines.append("}")
    with open(os.path.join(OUT, "L10nKo.kt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return len(items)


def gen_widget_l10n():
    """아이폰 위젯 확장의 한국어 (Widgets/ko.lproj) → WidgetKo.kt. 앱 표와 열쇠가 겹쳐도 뜻이 달라서 따로 둠 (BEST = 최고 / 최고 기록)"""
    w = read_strings(os.path.join(ROOT, "Widgets/ko.lproj/Localizable.strings"))
    items = sorted(w.items())
    lines = [
        "// 자동 생성 — 직접 고치지 말 것. android/tools/gen_from_ios.py",
        "// 원본: Widgets/ko.lproj/Localizable.strings (아이폰 위젯)",
        "package com.nkssi.splits8.shared",
        "",
        "/** 홈 화면 위젯 한국어 (앱 표보다 먼저 봄) */",
        "object WidgetKo {",
        "    private val map: Map<String, String> = hashMapOf(",
    ]
    for k, v in items:
        lines.append("        %s to %s," % (kstr(k), kstr(v)))
    lines += ["    )", "", "    /** 위젯 글자: 한국어면 위젯 표 → 앱 표 */",
              "    fun t(key: String): String = if (L10n.isKorean) map[key] ?: L10n.t(key) else L10n.t(key)", "}"]
    with open(os.path.join(OUT, "WidgetKo.kt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return len(items)


ROW = re.compile(r"\(band:\s*(\d+),\s*run:\s*(\d+),\s*st:\s*\[([\d,\s]+)\],\s*rox:\s*(\d+)\)")
TABLE = re.compile(r"static let (\w+): \[\(band")


def gen_bench():
    src = open(os.path.join(ROOT, "Shared/Benchmarks.swift"), encoding="utf-8").read()
    tables, cur = {}, None
    for line in src.splitlines():
        t = TABLE.search(line)
        if t:
            cur = t.group(1)
            tables[cur] = []
            continue
        m = ROW.search(line)
        if m and cur:
            st = [int(x) for x in m.group(3).split(",")]
            assert len(st) == 8, line
            tables[cur].append((int(m.group(1)), int(m.group(2)), st, int(m.group(4))))
        if line.strip() == "]":
            cur = None
    want = ["openMen", "openWomen", "proMen", "proWomen", "doublesMen", "doublesWomen", "doublesMixed",
            "proDoublesMen", "proDoublesWomen"]
    assert set(want) <= set(tables), tables.keys()
    lines = [
        "// 자동 생성 — 직접 고치지 말 것. android/tools/gen_from_ios.py",
        "// 원본: Shared/Benchmarks.swift (HYROX 2025/26 시즌 완주 시간대별 중간값)",
        "package com.nkssi.splits8.shared",
        "",
        "internal object BenchData {",
    ]
    for name in want:
        lines.append("    val %s: List<BenchRow> = listOf(" % name)
        for band, run, st, rox in tables[name]:
            lines.append("        BenchRow(%d, %d, listOf(%s), %d)," % (band, run, ", ".join(map(str, st)), rox))
        lines.append("    )")
    lines.append("}")
    with open(os.path.join(OUT, "BenchData.kt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return {k: len(tables[k]) for k in want}


def res_name(ios: str) -> str:
    """아이폰 그림 이름 → 안드로이드 이름 (소문자 · 밑줄): i_chevL → i_chev_l, wordmark-black → wordmark_black"""
    s = re.sub(r"(?<=[a-z0-9])([A-Z])", r"_\1", ios).replace("-", "_")
    return s.lower()


def gen_images():
    """Resources/iOS/Assets.xcassets 의 그림을 app 의 drawable-nodpi 로 복사하고 이름 표(IconRes.kt)를 만듦"""
    import json
    import shutil
    src = os.path.join(ROOT, "Resources/iOS/Assets.xcassets")
    dst = os.path.join(ROOT, "android/app/src/main/res/drawable-nodpi")
    os.makedirs(dst, exist_ok=True)
    names = []
    for d in sorted(os.listdir(src)):
        if not d.endswith(".imageset"):
            continue
        ios = d[: -len(".imageset")]
        files = [f for f in os.listdir(os.path.join(src, d)) if f.lower().endswith((".png", ".jpg", ".jpeg"))]
        if not files:
            continue
        f = max(files, key=lambda x: os.path.getsize(os.path.join(src, d, x)))
        ext = os.path.splitext(f)[1].lower().replace(".jpeg", ".jpg")
        rn = res_name(ios)
        shutil.copyfile(os.path.join(src, d, f), os.path.join(dst, rn + ext))
        names.append((ios, rn))
    lines = [
        "// 자동 생성 — 직접 고치지 말 것. android/tools/gen_from_ios.py",
        "// 아이폰 그림 이름(\"skiErg\", \"i_chevL\") → 안드로이드 그림 번호",
        "package com.nkssi.splits8.ui",
        "",
        "import com.nkssi.splits8.R",
        "",
        "object IconRes {",
        "    private val map: Map<String, Int> = mapOf(",
    ]
    for ios, rn in names:
        lines.append("        %s to R.drawable.%s," % (kstr(ios), rn))
    lines += ["    )", "", "    /** 없으면 null */", "    fun of(name: String): Int? = map[name]", "}"]
    out = os.path.join(ROOT, "android/app/src/main/kotlin/com/nkssi/splits8/ui/IconRes.kt")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return len(names)


if __name__ == "__main__":
    n = gen_l10n()
    b = gen_bench()
    print("L10nKo:", n, "entries")
    print("WidgetKo:", gen_widget_l10n(), "entries")
    print("Bench rows:", b)
    print("Images:", gen_images())
    sys.exit(0)
