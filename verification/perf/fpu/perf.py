#!/usr/bin/env python3
"""Measure FPU latency, initiation interval, and iterative blocking."""
from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BUILD = ROOT / "build/perf/fpu"
SOURCES = [
    "rtl/isa/isa_pkg.sv",
    "rtl/core/fpu/fpu_pkg.sv",
    "rtl/core/fpu/fpu_functions_pkg.sv",
    "rtl/core/fpu/fpu_iter.sv",
    "rtl/core/fpu/fpu.sv",
]


def read_results(path: Path) -> list[dict]:
    with path.open(newline="") as stream:
        rows = list(csv.DictReader(stream))
    for row in rows:
        row["samples"] = int(row["samples"])
        row["latency_cycles"] = float(row["latency_cycles"])
        row["ii_cycles"] = float(row["ii_cycles"])
        row["blocking_cycles"] = int(row["blocking_cycles"])
    return rows


def validate(rows: list[dict]) -> None:
    if not rows:
        raise RuntimeError("the FPU performance runner produced no cases")
    for row in rows:
        if row["latency_cycles"] < 0 or row["ii_cycles"] <= 0:
            raise RuntimeError(f"invalid timing result for {row['case']}")
        if row["kind"] == "iterative" and row["blocking_cycles"] <= 0:
            raise RuntimeError(f"no iterative blocking observed for {row['case']}")


def report_html(payload: dict) -> str:
    data = json.dumps(payload, separators=(",", ":")).replace("</", "<\\/")
    return f'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>FPU &middot; Performance Report</title>
<style>
:root{{--bg:#0a0e14;--panel:#11161f;--raised:#141b26;--line:#212b38;--soft:#1a222d;--text:#e6edf6;--muted:#8493a8;--faint:#57677e;--teal:#3ecfc0;--amber:#f0b03e;--rose:#e0667a;--sans:Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;--mono:"IBM Plex Mono",ui-monospace,SFMono-Regular,Menlo,monospace}}
*{{box-sizing:border-box}}body{{margin:0;background:radial-gradient(1000px 500px at 15% -10%,#101823,var(--bg) 55%);color:var(--text);font:14px/1.5 var(--sans)}}main{{max-width:1220px;margin:auto;padding:36px 28px 60px}}header{{display:flex;justify-content:space-between;align-items:end;padding-bottom:22px;border-bottom:1px solid var(--line)}}h1{{margin:6px 0 0;font-size:22px}}.kicker,.eyebrow{{font:600 11px var(--mono);letter-spacing:.14em;text-transform:uppercase}}.kicker{{color:var(--teal)}}.meta{{color:var(--muted);font:12px var(--mono)}}.eyebrow{{color:var(--faint);margin:34px 0 13px;display:flex;align-items:center;gap:10px}}.eyebrow:after{{content:"";height:1px;background:var(--line);flex:1}}.cards{{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}}.card,.panel{{background:var(--panel);border:1px solid var(--line);border-radius:10px}}.card{{padding:16px}}.card span{{display:block;color:var(--faint);font:11px var(--mono);text-transform:uppercase;margin-bottom:8px}}.card b{{font:600 21px var(--mono)}}.card.accent b{{color:var(--teal)}}.panel{{padding:18px;overflow:auto}}table{{width:100%;border-collapse:collapse}}th,td{{padding:10px 12px;border-bottom:1px solid var(--soft);text-align:right;font-variant-numeric:tabular-nums}}th{{color:var(--faint);font:600 10.5px var(--mono);letter-spacing:.08em;text-transform:uppercase}}th:first-child,td:first-child,th:nth-child(2),td:nth-child(2){{text-align:left}}tbody tr:hover{{background:var(--raised)}}.bars{{display:grid;gap:11px}}.bar{{display:grid;grid-template-columns:220px 1fr 70px;gap:12px;align-items:center}}.track{{height:10px;background:var(--soft);border-radius:8px;overflow:hidden}}.fill{{height:100%;background:var(--teal)}}.iter .fill{{background:var(--amber)}}.value{{font:12px var(--mono);text-align:right}}footer{{margin-top:40px;padding-top:15px;border-top:1px solid var(--line);color:var(--faint);font:11px var(--mono)}}@media(max-width:760px){{.cards{{grid-template-columns:1fr 1fr}}header{{display:block}}.bar{{grid-template-columns:130px 1fr 55px}}}}
</style></head><body><main><header><div><span class="kicker"></span><h1>FPU Performance Report</h1></div><div class="meta"></div></header>
<div class="eyebrow">Summary</div><div class="cards" id="cards"></div>
<div class="eyebrow">Measured cases</div><div class="panel"><table><thead><tr><th>Case</th><th>Pattern</th><th>Lane</th><th>Operation</th><th>Samples</th><th>Latency</th><th>II</th><th>Blocking</th></tr></thead><tbody id="rows"></tbody></table></div>
<div class="eyebrow">Latency comparison</div><div class="panel"><div class="bars" id="bars"></div></div>
<footer>fpu / performance harness</footer>
<script>const D={data},R=D.cases,$=s=>document.querySelector(s),fmt=x=>Number.isInteger(x)?x:x.toFixed(2),pipe=R.filter(x=>x.kind==='pipeline'),iter=R.filter(x=>x.kind==='iterative'),max=Math.max(...R.map(x=>x.latency_cycles));$('#cards').innerHTML=[["Pipeline latency range",Math.min(...pipe.map(x=>x.latency_cycles))+"–"+Math.max(...pipe.map(x=>x.latency_cycles))+" cycles","accent"],["Pipeline initiation interval",Math.min(...pipe.map(x=>x.ii_cycles))+" cycles"],["Iterative latency range",Math.min(...iter.map(x=>x.latency_cycles))+"–"+Math.max(...iter.map(x=>x.latency_cycles))+" cycles"],["Maximum lane-1 blocking",Math.max(...iter.map(x=>x.blocking_cycles))+" cycles"]].map(x=>`<div class="card ${{x[2]||''}}"><span>${{x[0]}}</span><b>${{x[1]}}</b></div>`).join('');$('#rows').innerHTML=R.map(x=>`<tr><td>${{x.case}}</td><td>${{x.pattern}}</td><td>${{x.lane}}</td><td>${{x.op}}</td><td>${{x.samples}}</td><td>${{fmt(x.latency_cycles)}}</td><td>${{fmt(x.ii_cycles)}}</td><td>${{x.blocking_cycles}}</td></tr>`).join('');$('#bars').innerHTML=R.map(x=>`<div class="bar ${{x.kind==='iterative'?'iter':''}}"><span>${{x.case}}</span><div class="track"><div class="fill" style="width:${{100*x.latency_cycles/max}}%"></div></div><span class="value">${{fmt(x.latency_cycles)}} cy</span></div>`).join('');</script></main></body></html>'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-from", type=Path,
                        help="regenerate report from an existing results.json")
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    if args.report_from:
        payload = json.loads(args.report_from.read_text())
    else:
        exe = BUILD / "fpu_perf"
        command = [
            "verilator", "--cc", "--exe", "--build", "--timing",
            "-Wno-fatal", "--top-module", "fpu",
            "--Mdir", str(BUILD / "obj"), "-o", str(exe),
        ]
        subprocess.run(
            command + [str(ROOT / source) for source in SOURCES]
            + [str(HERE / "perf_main.cpp")],
            check=True, cwd=ROOT,
        )
        subprocess.run([str(exe)], check=True, cwd=BUILD)
        payload = {"cases": read_results(BUILD / "fpu_perf.csv")}
        validate(payload["cases"])
        (BUILD / "results.json").write_text(
            json.dumps(payload, indent=2) + "\n"
        )
    validate(payload["cases"])
    (BUILD / "report.html").write_text(report_html(payload))
    print(BUILD / "report.html")


if __name__ == "__main__":
    main()
