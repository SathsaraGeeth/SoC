#!/usr/bin/env python3
"""Run matched sys_core workloads and write a static performance report."""
from __future__ import annotations

import argparse
import csv
import json
import re
import shlex
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BUILD = ROOT / "build/perf/sys_core"
WORKLOAD_DIR = HERE / "workloads"
MAX_COMMANDS = 40000
WORKLOAD_ORDER = [
    "native_1x1.asm", "dense_1x1.asm", "native_256.asm", "dense_256.asm",
]
SOURCES = [
    "rtl/isa/isa_pkg.sv", "rtl/core/core_pkg.sv", "rtl/soc/topology_pkg.sv",
    "rtl/memory/memory_pkg.sv", "rtl/sys_arr/sys_cnfg_pkg.sv",
    "rtl/sys_arr/mac_fp8_fp8_fp8_61_cnfg_pkg.sv", "rtl/sys_arr/common.sv",
    "rtl/sys_arr/mac20i_v2.sv", "rtl/sys_arr/mac_fp8_fp8_fp8_61_v2.sv",
    "rtl/sys_arr/mmacu_core_v2.sv", "rtl/sys_arr/sys_address_generator.sv",
    "rtl/common/fifo/circular_buffer.sv", "rtl/sys_arr/sys_core.sv",
]
FIFO_NAMES = ["Command", "Address A", "Address B", "Address D", "Output"]
CLOCK_GHZ = 1.0
ARRAY_MACS = 64
PEAK_TOPS = ARRAY_MACS * 2 * CLOCK_GHZ / 1000
PORT_PEAK_GBPS = 8 * CLOCK_GHZ


def fifo_depths() -> list[int]:
    text = (ROOT / "rtl/sys_arr/sys_cnfg_pkg.sv").read_text()
    names = ("CMD_BUFF_D", "A_ADDR_BUFF", "B_ADDR_BUFF", "D_ADDR_BUFF", "RES_BUFF_D")
    values = []
    for name in names:
        match = re.search(rf"parameter int {name}\s*=\s*(.+?)\s*;", text)
        if not match:
            raise RuntimeError(f"cannot read {name} from sys_cnfg_pkg.sv")
        expression = match.group(1)
        if name == "RES_BUFF_D" and not expression.isdigit():
            maximum = int(re.search(r"parameter int MAX_DENSE_MAT_SZ\s*=\s*(\d+)", text).group(1))
            array_m = int(re.search(r"parameter int M\s*=\s*(\d+)", text).group(1))
            values.append(maximum * maximum // array_m)
        else:
            values.append(int(expression))
    return values


def parse_workload(path: Path) -> dict:
    commands, label, mode = [], path.stem.replace("_", " ").title(), None
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            if not commands:
                label = line[1:].strip() or label
            continue
        fields = shlex.split(line)
        kind = fields[0].lower()
        args = dict(item.split("=", 1) for item in fields[1:] if "=" in item)
        mac_type = {"int8": 0, "fp8": 1}[args.get("mac", "int8").lower()]
        if kind == "matmul":
            mode = fields[1].lower()
            a_tiles = int(args.get("a_tiles", "1"), 0)
            b_tiles = int(args.get("b_tiles", "1"), 0)
            repeat = int(args.get("repeat", "1"), 0)
            stride = int(args.get("stride", "0"), 0)
            a_base, b_base, d_base = (int(args[name], 0) for name in ("a", "b", "d"))
            for group in range(repeat):
                a, b, d = (base + group * stride for base in (a_base, b_base, d_base))
                if mode == "dense":
                    operation = (0x01 << 24) | (1 << 23) | (1 << 22) | (1 << 21) | (mac_type << 19)
                    operation |= a_tiles << 48 | b_tiles << 32 | a << 64 | b << 128
                    writeback = (0x02 << 24) | (1 << 23) | (mac_type << 19) | d << 64
                    values = (operation, writeback)
                    commands.extend([[f"{(value >> (64 * word)) & ((1 << 64) - 1):016x}" for word in range(4)]
                                     for value in values])
                else:
                    for a_idx in range(a_tiles):
                        for b_idx in range(b_tiles):
                            for q_idx in range(a_tiles):
                                operation = (0x01 << 24) | (int(q_idx == 0) << 23)
                                operation |= (int(q_idx + 1 == a_tiles) << 22) | (mac_type << 19)
                                operation |= (a + (q_idx * a_tiles + a_idx) * 64) << 64
                                operation |= (b + (q_idx * b_tiles + b_idx) * 64) << 128
                                commands.append([f"{(operation >> (64 * word)) & ((1 << 64) - 1):016x}" for word in range(4)])
                            writeback = (0x02 << 24) | (mac_type << 19) | (d + (a_idx * b_tiles + b_idx) * 64) << 64
                            commands.append([f"{(writeback >> (64 * word)) & ((1 << 64) - 1):016x}" for word in range(4)])
            continue
        if kind == "tile":
            mode = fields[1].lower()
            stride = int(args.get("stride", "0"), 0)
            for index in range(int(args.get("repeat", "1"), 0)):
                operation = (0x01 << 24) | (1 << 23) | (1 << 22) | (int(mode == "dense") << 21) | (mac_type << 19)
                operation |= int(args.get("a_tiles", "1"), 0) << 48 | int(args.get("b_tiles", "1"), 0) << 32
                operation |= (int(args.get("a", "0"), 0) + index * stride) << 64
                operation |= (int(args.get("b", "0"), 0) + index * stride) << 128
                writeback = (0x02 << 24) | (int(mode == "dense") << 23) | (mac_type << 19)
                writeback |= (int(args.get("d", "0"), 0) + index * stride) << 64
                commands.extend([[f"{(value >> (64 * word)) & ((1 << 64) - 1):016x}" for word in range(4)]
                                 for value in (operation, writeback)])
            continue
        if kind == "chain":
            mode, count = fields[1].lower(), int(args["count"], 0)
            repeat, stride = int(args.get("repeat", "1"), 0), int(args.get("stride", "0"), 0)
            for group in range(repeat):
                for index in range(count):
                    offset = (group * count + index) * stride
                    operation = (0x01 << 24) | (int(index == 0) << 23) | (int(index + 1 == count) << 22)
                    operation |= (int(mode == "dense") << 21) | (mac_type << 19)
                    operation |= (int(args.get("a", "0"), 0) + offset) << 64
                    operation |= (int(args.get("b", "0"), 0) + offset) << 128
                    commands.append([f"{(operation >> (64 * word)) & ((1 << 64) - 1):016x}" for word in range(4)])
                writeback = (0x02 << 24) | (int(mode == "dense") << 23) | (mac_type << 19)
                writeback |= (int(args.get("d", "0"), 0) + group * stride) << 64
                commands.append([f"{(writeback >> (64 * word)) & ((1 << 64) - 1):016x}" for word in range(4)])
            continue
        command = 0
        if kind == "delegation":
            tid = int(args.get("tid", "0"), 0)
            command = (0x03 << 24) | (tid << 128) | (tid << 64)
        elif kind == "operation":
            mode = fields[1].lower()
            command = (0x01 << 24) | (int(args.get("start") == "1") << 23)
            command |= (int(args.get("last") == "1") << 22) | (int(mode == "dense") << 21) | (mac_type << 19)
            command |= int(args.get("a_tiles", "1"), 0) << 48 | int(args.get("b_tiles", "1"), 0) << 32
            command |= int(args.get("a", "0"), 0) << 64 | int(args.get("b", "0"), 0) << 128
        elif kind == "writeback":
            command = (0x02 << 24) | (int(fields[1].lower() == "dense") << 23) | (mac_type << 19)
            command |= int(args.get("d", "0"), 0) << 64
        elif kind == "release":
            command = 0x04 << 24
        else:
            raise ValueError(f"{path.name}: unknown command {kind}")
        encoded = [f"{(command >> (64 * word)) & ((1 << 64) - 1):016x}" for word in range(4)]
        commands.extend([encoded] * int(args.get("repeat", "1"), 0))
    if mode not in {"native", "dense"}:
        raise ValueError(f"{path.name}: needs an operation command")
    size = path.stem.split("_")[-1]
    source = "\n".join(line for line in path.read_text().splitlines() if line.strip() and not line.lstrip().startswith("#"))
    return {"file": path.name, "label": label, "description": f"{mode.title()} {size} workload", "mode": mode,
            "size": size, "source": source, "commands": commands}


def write_workload_mem(spec: dict, path: Path) -> None:
    words = [f"{len(spec['commands']):016x}"]
    words.extend(word for command in spec["commands"] for word in command)
    words.extend(["0"] * ((MAX_COMMANDS - len(spec["commands"])) * 4))
    path.write_text("\n".join(words) + "\n")


def read_result(path: Path, spec: dict) -> dict:
    with path.open(newline="") as stream:
        raw = next(csv.DictReader(stream))
    row = {key: int(value, 16) if key == "fifo_levels" else int(value) for key, value in raw.items()}
    cycles = max(1, row["accel_cycles"])
    row.update({key: spec[key] for key in ("file", "label", "description", "mode", "size", "source")},
               mac_rate=row["mac_cycles"] / cycles, stall_rate=row["stall_cycles"] / cycles,
               fifo=[(row["fifo_levels"] >> shift) & 0xff for shift in (0, 8, 16, 24, 48)])
    row["observed_tops"] = row["mac_rate"] * PEAK_TOPS
    row["peak_compute_usage"] = row["observed_tops"] / PEAK_TOPS
    for stream, count in (("a", row["a_loaded"]), ("b", row["b_loaded"]), ("d", row["d_stored"])):
        row[f"{stream}_gbps"] = count / cycles * PORT_PEAK_GBPS
    with path.with_name("fifo_trace.csv").open(newline="") as stream:
        row["trace"] = list(csv.DictReader(stream))
    return row


def validate(rows: list[dict]) -> None:
    errors = []
    for row in rows:
        name = row["file"]
        if not row["accel_cycles"] or not row["mac_cycles"]:
            errors.append(f"{name}: no active accelerator/MAC data")
        if row.get("sample_cycles") and row["accel_cycles"] >= row["sample_cycles"]:
            errors.append(f"{name}: accelerator remained busy through the measurement window")
        if row["mode"] == "native" and (row["a_loaded"] < row["mac_cycles"] or row["b_loaded"] < row["mac_cycles"]):
            errors.append(f"{name}: MACs exceed input-vector handshakes")
        if row["mode"] == "dense" and (not row["dense_macs"] or row["native_macs"]):
            errors.append(f"{name}: dense/native mix is inconsistent")
        if row["mode"] == "native" and (not row["native_macs"] or row["dense_macs"]):
            errors.append(f"{name}: native/dense mix is inconsistent")
    for size in {row["size"] for row in rows}:
        modes = {row["mode"] for row in rows if row["size"] == size}
        if modes != {"native", "dense"}:
            errors.append(f"{size}: missing matched native/dense workload")
    if errors:
        raise RuntimeError("counter sanity check failed:\n  " + "\n  ".join(errors))


def report_html(payload: dict) -> str:
    data = json.dumps(payload, separators=(",", ":")).replace("</", "<\\/")
    return f'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>sys_core &middot; Performance Report</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500;600&display=swap" rel="stylesheet">
<style>
:root{{
  --bg:#0a0e14; --bg-alt:#0d1219; --panel:#11161f; --panel-raised:#141b26; --line:#212b38; --line-soft:#1a222d;
  --text:#e6edf6; --muted:#8493a8; --faint:#57677e;
  --teal:#3ecfc0; --amber:#f0b03e; --rose:#e0667a; --violet:#9b8cf2;
  --sans:'IBM Plex Sans',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  --mono:'IBM Plex Mono',ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
}}
*{{box-sizing:border-box}}
body{{margin:0;background:radial-gradient(1200px 600px at 15% -10%,#101823 0%,var(--bg) 55%);color:var(--text);font:14px/1.5 var(--sans);-webkit-font-smoothing:antialiased}}
main{{max-width:1520px;margin:auto;padding:0 28px 60px}}

.masthead{{display:flex;justify-content:space-between;align-items:flex-end;gap:24px;padding:38px 0 22px;border-bottom:1px solid var(--line)}}
.masthead h1{{margin:0;font-size:22px;font-weight:600;letter-spacing:-.01em}}
.masthead .kicker{{display:block;font:600 11px/1 var(--mono);letter-spacing:.14em;text-transform:uppercase;color:var(--teal);margin-bottom:8px}}
.meta{{display:flex;gap:22px;flex-wrap:wrap;font:12px var(--mono);color:var(--muted)}}
.meta b{{color:var(--text);font-weight:500}}

.eyebrow{{font:600 11px/1 var(--mono);letter-spacing:.14em;text-transform:uppercase;color:var(--faint);margin:38px 0 14px;display:flex;align-items:center;gap:10px}}
.eyebrow::after{{content:'';flex:1;height:1px;background:var(--line)}}

.toolbar{{display:flex;gap:20px;align-items:end;margin:0 0 20px}}
label{{display:grid;gap:7px;color:var(--muted);font-size:12px}}
select{{min-width:340px;background:var(--panel);color:var(--text);border:1px solid var(--line);border-radius:7px;padding:9px 12px;font:13px var(--sans)}}
select:focus-visible{{outline:2px solid var(--teal);outline-offset:1px}}

.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(172px,1fr));gap:10px}}
.card,.panel{{background:var(--panel);border:1px solid var(--line);border-radius:10px}}
.card{{padding:16px}}
.card span{{display:block;color:var(--faint);font:11px var(--mono);letter-spacing:.06em;text-transform:uppercase;margin-bottom:9px}}
.card b{{display:block;font:600 21px/1.1 var(--mono);color:var(--text)}}
.card.accent b{{color:var(--teal)}}

.panel{{padding:18px}}
table{{width:100%;border-collapse:collapse;font-size:13px}}
th,td{{padding:9px 12px;border-bottom:1px solid var(--line-soft);text-align:right;font-variant-numeric:tabular-nums}}
th{{font:600 10.5px var(--mono);letter-spacing:.08em;text-transform:uppercase;color:var(--faint);border-bottom:1px solid var(--line)}}
th:first-child,td:first-child{{text-align:left}}
tbody tr:hover{{background:var(--panel-raised)}}
td:first-child,th:first-child{{font-family:var(--sans)}}

pre{{margin:0;overflow:auto;color:#b9c8db;line-height:1.6;font:12.5px/1.6 var(--mono);max-height:340px}}
.legend{{color:var(--muted);margin:0 0 14px;font-size:12.5px}}

.grid{{display:grid;grid-template-columns:1.3fr 1fr;gap:14px}}
canvas{{width:100%;background:var(--bg-alt);border:1px solid var(--line-soft);border-radius:7px}}
@media(max-width:900px){{.grid{{grid-template-columns:1fr}} .masthead{{flex-direction:column;align-items:flex-start}}}}

footer{{margin-top:44px;padding-top:16px;border-top:1px solid var(--line);color:var(--faint);font:11px var(--mono);display:flex;justify-content:space-between}}
</style></head><body><main>

<div class="masthead">
  <div><span class="kicker">DPI-C perf_vec</span><h1>sys_core Performance Report</h1></div>
  <div class="meta"><span>Sample interval&nbsp;&nbsp;<b>10 cycles</b></span><span>Memory latency&nbsp;&nbsp;<b>4&ndash;10 cycles</b></span><span>Peak throughput&nbsp;&nbsp;<b>{PEAK_TOPS:.3f} TOPS</b></span></div>
</div>

<div class="toolbar" style="margin-top:24px"><label>Workload<select id="workload"></select></label></div>
<div class="cards" id="cards"></div>

<div class="eyebrow">Workload source</div>
<div class="panel"><pre id="source"></pre></div>

<div class="eyebrow">Performance counters</div>
<div class="panel"><table><thead><tr><th>Counter</th><th>Value</th><th>Normalized</th></tr></thead><tbody id="counterRows"></tbody></table></div>

<div class="eyebrow">Workload comparison</div>
<div class="panel"><table><thead><tr><th>Workload</th><th>Mode</th><th>Accel. cycles</th><th>MAC cycles</th><th>Stall cycles</th><th>A reads</th><th>B reads</th><th>D writes</th><th>A GB/s</th><th>B GB/s</th><th>D GB/s</th><th>Observed TOPS</th><th>Peak usage</th></tr></thead><tbody id="comparison"></tbody></table></div>

<div class="grid" style="margin-top:38px">
<section><div class="eyebrow">Counter comparison</div><div class="panel"><canvas id="bars" height="320"></canvas></div></section>
<section><div class="eyebrow">FIFO occupancy statistics</div><div class="panel"><table><thead><tr><th>FIFO</th><th>Depth</th><th>Max</th><th>Mean</th><th>Nonempty</th><th>Full</th></tr></thead><tbody id="fifoStats"></tbody></table></div></section>
</div>

<div class="eyebrow">FIFO occupancy heatmap</div>
<div class="panel"><div class="legend">Instantaneous FIFO levels sampled from perf_vec every 10 cycles across the full captured interval; compressed columns take the maximum of their samples. Dark is empty, amber is full.</div><canvas id="heatmap"></canvas></div>

<footer><span>sys_core / perf harness</span><span id="genInfo"></span></footer>

<script>const D={data};const W=document.querySelector('#workload'),cards=document.querySelector('#cards'),source=document.querySelector('#source'),counterRows=document.querySelector('#counterRows'),comparison=document.querySelector('#comparison'),bars=document.querySelector('#bars'),fifoStats=document.querySelector('#fifoStats'),heatmap=document.querySelector('#heatmap');const names=['Command','Address A','Address B','Address D','Output'];const fields=['command','addr_a','addr_b','addr_d','output'];const depths=D.fifo_depths;
D.workloads.forEach((x,i)=>W.add(new Option(x.label,i)));W.value=D.workloads.length-1;const pct=x=>(100*x).toFixed(2)+'%';
document.querySelector('#genInfo').textContent=D.workloads.length+' workload(s) captured';
function color(q){{q=Math.max(0,Math.min(1,q));const hue=192-160*q;return `hsl(${{hue}} 72% ${{12+46*q}}%)`}}
function selected(){{return D.workloads[+W.value]}}function fit(c,h){{let d=devicePixelRatio||1;c.width=c.clientWidth*d;c.height=h*d;let g=c.getContext('2d');g.scale(d,d);return[g,c.clientWidth,h]}}
function refresh(){{const x=selected(),cycles=Math.max(1,x.accel_cycles);cards.innerHTML=[['Accelerator cycles',x.accel_cycles.toLocaleString()],['MAC-active cycles',x.mac_cycles.toLocaleString()],['Compute utilization',pct(x.mac_cycles/cycles)],['Observed throughput',x.observed_tops.toFixed(4)+' TOPS','accent'],['Theoretical peak','{PEAK_TOPS:.3f} TOPS'],['Peak usage',pct(x.peak_compute_usage)],['A / B / D bandwidth',x.a_gbps.toFixed(2)+' / '+x.b_gbps.toFixed(2)+' / '+x.d_gbps.toFixed(2)+' GB/s'],['Per-port peak','{PORT_PEAK_GBPS:.1f} GB/s'],['FIFO samples',x.trace.length.toLocaleString()],['Sample interval','10 cycles'],['Memory latency',D.latency]].map(v=>`<div class="card${{v[2]?' accent':''}}"><span>${{v[0]}}</span><b>${{v[1]}}</b></div>`).join('');source.textContent=x.source;
const counters=[['Accelerator cycles',x.accel_cycles,pct(x.accel_cycles/cycles)],['MAC-active cycles',x.mac_cycles,pct(x.mac_cycles/cycles)],['Stall cycles',x.stall_cycles,pct(x.stall_cycles/cycles)],['A memory reads',x.a_loaded,x.a_gbps.toFixed(3)+' GB/s · '+pct(x.a_gbps/{PORT_PEAK_GBPS})+' of port peak'],['B memory reads',x.b_loaded,x.b_gbps.toFixed(3)+' GB/s · '+pct(x.b_gbps/{PORT_PEAK_GBPS})+' of port peak'],['D memory writes',x.d_stored,x.d_gbps.toFixed(3)+' GB/s · '+pct(x.d_gbps/{PORT_PEAK_GBPS})+' of port peak'],['Dense MAC cycles',x.dense_macs,pct(x.dense_macs/cycles)],['Native MAC cycles',x.native_macs,pct(x.native_macs/cycles)],['FIFO levels (packed peak)','0x'+x.fifo_levels.toString(16).padStart(16,'0'),'perf_vec']];counterRows.innerHTML=counters.map(v=>`<tr><td>${{v[0]}}</td><td>${{typeof v[1]=='number'?v[1].toLocaleString():v[1]}}</td><td>${{v[2]}}</td></tr>`).join('');drawBars();drawHeat();drawStats()}}
comparison.innerHTML=D.workloads.map(x=>`<tr><td>${{x.label}}</td><td>${{x.mode}}</td><td>${{x.accel_cycles.toLocaleString()}}</td><td>${{x.mac_cycles.toLocaleString()}}</td><td>${{x.stall_cycles.toLocaleString()}}</td><td>${{x.a_loaded.toLocaleString()}}</td><td>${{x.b_loaded.toLocaleString()}}</td><td>${{x.d_stored.toLocaleString()}}</td><td>${{x.a_gbps.toFixed(2)}}</td><td>${{x.b_gbps.toFixed(2)}}</td><td>${{x.d_gbps.toFixed(2)}}</td><td>${{x.observed_tops.toFixed(4)}}</td><td>${{pct(x.peak_compute_usage)}}</td></tr>`).join('');
function drawBars(){{let[g,w,h]=fit(bars,320),keys=[['MAC','mac_cycles'],['Stall','stall_cycles'],['A load','a_loaded'],['B load','b_loaded'],['D store','d_stored']],max=Math.max(1,...D.workloads.flatMap(x=>keys.map(k=>x[k[1]]))),group=(w-58)/D.workloads.length,bw=(group-12)/keys.length,colors=['#3ecfc0','#f0b03e','#9b8cf2','#5b9ee8','#e0667a'];g.font='11px "IBM Plex Mono",monospace';g.fillStyle='#8493a8';D.workloads.forEach((x,i)=>{{keys.forEach((k,j)=>{{let v=x[k[1]],bh=(h-62)*v/max;g.fillStyle=colors[j];g.fillRect(48+i*group+j*bw,h-35-bh,Math.max(1,bw-2),bh)}});g.fillStyle='#8493a8';g.fillText(x.mode+' '+x.size,48+i*group,h-14)}});keys.forEach((k,i)=>{{g.fillStyle=colors[i];g.fillText(k[0],48+i*75,14)}})}}
function values(x,n){{return x.trace.map(r=>+r[fields[n]])}}function drawStats(){{let x=selected();fifoStats.innerHTML=names.map((n,i)=>{{let a=values(x,i),sum=a.reduce((p,v)=>p+v,0),non=a.filter(v=>v>0).length,full=a.filter(v=>v>=depths[i]).length;return `<tr><td>${{n}}</td><td>${{depths[i]}}</td><td>${{Math.max(0,...a)}}</td><td>${{(sum/Math.max(1,a.length)).toFixed(3)}}</td><td>${{pct(non/Math.max(1,a.length))}}</td><td>${{pct(full/Math.max(1,a.length))}}</td></tr>`}}).join('')}}
function drawHeat(){{let x=selected(),t=x.trace,height=42+names.length*30,[g,w]=fit(heatmap,height),left=150,plot=Math.max(1,Math.floor(w-left-8));g.font='12px "IBM Plex Mono",monospace';g.textBaseline='middle';names.forEach((n,r)=>{{let a=values(x,r),y=28+r*30;g.fillStyle='#c7d3e2';g.fillText(n,5,y+13);for(let px=0;px<plot;px++){{let begin=Math.floor(px*a.length/plot),end=Math.max(begin+1,Math.floor((px+1)*a.length/plot)),v=0;for(let i=begin;i<end&&i<a.length;i++)v=Math.max(v,a[i]);g.fillStyle=color(v/depths[r]);g.fillRect(left+px,y,1,26)}}}});g.fillStyle='#8493a8';g.textBaseline='alphabetic';g.fillText(t.length?t[0].cycle+' cycles':'0 cycles',left,14);g.textAlign='right';g.fillText(t.length?t[t.length-1].cycle+' cycles':'0 cycles',w-8,14);g.textAlign='left'}}
W.onchange=refresh;window.onresize=()=>{{drawBars();drawHeat()}};refresh();</script></main></body></html>'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-from", type=Path, help="regenerate from build results.json")
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    if args.report_from:
        payload = json.loads(args.report_from.read_text())
    else:
        specs = [parse_workload(WORKLOAD_DIR / name) for name in WORKLOAD_ORDER]
        if any(len(spec["commands"]) > MAX_COMMANDS for spec in specs):
            raise RuntimeError(f"each workload must contain at most {MAX_COMMANDS} commands")
        exe = BUILD / "sys_core_perf"
        cmd = ["verilator", "--cc", "--exe", "--build", "--timing", "-Wno-fatal", "--top-module", "sys_core", "--Mdir", str(BUILD / "obj"), "-o", str(exe)]
        subprocess.run(cmd + [str(ROOT / source) for source in SOURCES] + [str(HERE / "perf_main.cpp")], check=True, cwd=ROOT)
        rows = []
        for index, spec in enumerate(specs):
            mem = BUILD / f"workload_{index}.mem"
            write_workload_mem(spec, mem)
            sample = 5000 if spec["size"] == "1x1" else 5000000
            run = [str(exe), f"+WORKLOAD_MEM={mem.name}", f"+SAMPLE_CYCLES={sample}"]
            subprocess.run(run, check=True, cwd=BUILD)
            row = read_result(BUILD / "sys_core_perf.csv", spec)
            row["workload"] = index
            row["sample_cycles"] = sample
            rows.append(row)
        validate(rows)
        payload = {"latency": "4–10 cycles", "fifo_depths": fifo_depths(), "workloads": rows}
        (BUILD / "results.json").write_text(json.dumps(payload, indent=2) + "\n")
    validate(payload["workloads"])
    (BUILD / "report.html").write_text(report_html(payload))
    print(BUILD / "report.html")


if __name__ == "__main__":
    main()
