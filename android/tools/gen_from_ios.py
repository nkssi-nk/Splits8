#!/usr/bin/env python3
"""아이폰 파일에서 안드로이드 shared 코드를 만듦 (손으로 옮기다 틀리지 않게).

  python3 android/tools/gen_from_ios.py      (저장소 맨 위에서)

만드는 것
  - L10nKo.kt : Resources/iOS·Watch/ko.lproj/Localizable.strings → 한국어 표
  - Bench.kt  : Shared/Benchmarks.swift 의 중간값 표 (HyroxBench)

아이폰 문구나 표가 바뀌면 이 스크립트를 다시 돌리면 됨.
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
    items = sorted(merged.items())
    chunks = [items[i:i + 150] for i in range(0, len(items), 150)]
    lines = [
        "// 자동 생성 — 직접 고치지 말 것. android/tools/gen_from_ios.py",
        "// 원본: Resources/iOS/ko.lproj · Resources/Watch/ko.lproj Localizable.strings",
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


if __name__ == "__main__":
    n = gen_l10n()
    b = gen_bench()
    print("L10nKo:", n, "entries")
    print("Bench rows:", b)
    sys.exit(0)
