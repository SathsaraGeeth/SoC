#!/usr/bin/env python3
"""Run the 32-context frontend while sweeping dynamically active contexts."""
from __future__ import annotations
import argparse, json, os, re, subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
THREADS = (1, 2, 4, 8, 16, 32)
WORKLOADS = {"packet": 0}

def compile_workload(build: Path) -> tuple[Path, int]:
    clang=Path(os.environ.get("CLANG",REPO/"compiler/llvm-project/build/bin/clang"))
    objcopy=Path(os.environ.get("LLVM_OBJCOPY",REPO/"compiler/llvm-project/build/bin/llvm-objcopy"))
    linker=Path(os.environ.get("LLD",REPO/"compiler/llvm-project/build/bin/lld"))
    if not clang.is_file() or not objcopy.is_file() or not linker.is_file():
        raise RuntimeError("project clang/lld/llvm-objcopy not found; set CLANG, LLD and LLVM_OBJCOPY")
    obj=build/"workload.o"; elf=build/"workload.elf"; binary=build/"workload.bin"; image=build/"workload.hex"
    subprocess.run([str(clang),"--target=riscv64","-march=rv64im_zicsr","-mabi=lp64","-O2",
                    "-nostdlib","-ffreestanding","-fno-builtin",f"-DPERF_ITERATIONS=512",
                    "-c",str(HERE/"workload.c"),"-o",str(obj)],check=True,cwd=REPO)
    subprocess.run([str(linker),"-flavor","gnu","-m","elf64lriscv","--image-base=0",
                    "-Ttext=0","-e","main","--no-relax",str(obj),"-o",str(elf)],check=True,cwd=REPO)
    subprocess.run([str(objcopy),"-O","binary","--only-section=.text",str(elf),str(binary)],check=True)
    raw=binary.read_bytes(); words=max(1,(len(raw)+7)//8); raw+=bytes(words*8-len(raw))
    image.write_text("".join(f"{int.from_bytes(raw[n:n+8],'little'):016x}\n" for n in range(0,len(raw),8)))
    return image, words

def report_html(payload: dict) -> str:
    data=json.dumps(payload,separators=(",",":"),sort_keys=True).replace("</","<\\/")
    return f'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Frontend performance</title><style>
:root{{--bg:#09111d;--panel:#111d2c;--line:#263b54;--text:#e7f0fa;--muted:#91a5bc;--cyan:#42d3ff;--gold:#ffc857;--green:#5de2a5}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:14px system-ui,sans-serif}}main{{max-width:1480px;margin:auto;padding:24px}}
h1{{margin:0 0 4px}}h2{{font-size:17px;margin:0 0 12px}}.muted{{color:var(--muted)}}.toolbar{{display:flex;gap:18px;align-items:end;margin:22px 0}}
label{{display:grid;gap:5px;color:var(--muted)}}select{{background:var(--panel);color:var(--text);border:1px solid var(--line);padding:8px;border-radius:6px}}
.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin-bottom:14px}}.card,.panel{{background:var(--panel);border:1px solid var(--line);border-radius:9px;padding:14px}}
.card b{{display:block;font-size:24px;margin-top:5px}}.grid{{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:14px 0}}canvas{{width:100%;height:300px;background:#0b1522;border-radius:5px}}
table{{width:100%;border-collapse:collapse}}th,td{{padding:8px;border-bottom:1px solid var(--line);text-align:right}}th:first-child,td:first-child{{text-align:left}}
@media(max-width:850px){{.grid{{grid-template-columns:1fr}}}} </style></head><body><main>
<h1>Frontend performance dashboard</h1><div class=muted>32 hardware threads · dynamically active-thread sweep</div>
<div class=toolbar><label>Workload<select id=workload></select></label><label>Detailed point<select id=point></select></label></div>
<div class=cards id=cards></div><div class=grid><section class=panel><h2>Sweep utilization</h2><canvas id=scaling></canvas></section><section class=panel><h2>Consume → refill latency</h2><canvas id=refill></canvas></section></div>
<div class=grid><section class=panel><h2>Decoded instructions presented each cycle</h2><canvas id=presented></canvas></section><section class=panel><h2>Per-thread backend consumption</h2><canvas id=perthread></canvas></section></div>
<section class=panel><h2>All sweep points</h2><table><thead><tr><th>Active threads</th><th>Slot utilization</th><th>Port valid</th><th>Port accepts/cycle</th><th>Consumes/cycle</th><th>Avg refill</th><th>Max refill</th><th>Request stalls</th><th>Response stalls</th></tr></thead><tbody id=rows></tbody></table></section>
<script>const D={data};
const W=document.querySelector('#workload'),P=document.querySelector('#point'),CARDS=document.querySelector('#cards'),ROWS=document.querySelector('#rows'),SCALING=document.querySelector('#scaling'),REFILL=document.querySelector('#refill'),PRESENTED=document.querySelector('#presented'),PERTHREAD=document.querySelector('#perthread');Object.keys(D.workloads).forEach(n=>W.add(new Option(n,n)));
function points(){{return D.workloads[W.value]}}function selected(){{return points()[+P.value]}}
function fit(c){{let d=devicePixelRatio||1;c.width=c.clientWidth*d;c.height=300*d;let g=c.getContext('2d');g.scale(d,d);return [g,c.clientWidth,300]}}
function axes(g,w,h,max,label){{g.strokeStyle='#263b54';g.fillStyle='#91a5bc';g.font='12px system-ui';for(let i=0;i<=4;i++){{let y=18+(h-48)*i/4;g.beginPath();g.moveTo(42,y);g.lineTo(w-10,y);g.stroke();g.fillText((max*(1-i/4)).toFixed(max<=1?2:0),3,y+4)}}g.fillText(label,45,14)}}
function lineChart(c,series,max,label){{let [g,w,h]=fit(c);g.clearRect(0,0,w,h);axes(g,w,h,max,label);let colors=['#42d3ff','#ffc857','#5de2a5'];series.forEach((s,j)=>{{g.strokeStyle=colors[j];g.lineWidth=2;g.beginPath();s.values.forEach((v,i)=>{{let x=45+(w-60)*i/Math.max(1,s.values.length-1),y=18+(h-48)*(1-v/max);i?g.lineTo(x,y):g.moveTo(x,y);g.fillStyle='#91a5bc';if(j===0)g.fillText(s.labels[i],x-5,h-8)}});g.stroke();g.fillStyle=colors[j];g.fillText(s.name,50+j*150,34)}})}}
function bars(c,obj,label){{let [g,w,h]=fit(c),a=Object.entries(obj).map(([k,v])=>[+k,+v]),max=Math.max(1,...a.map(x=>x[1]));axes(g,w,h,max,label);let bw=(w-60)/Math.max(1,a.length);a.forEach(([k,v],i)=>{{let bh=(h-50)*v/max;g.fillStyle='#42d3ff';g.fillRect(45+i*bw,h-30-bh,Math.max(1,bw-2),bh);g.fillStyle='#91a5bc';if(a.length<35||i%4===0)g.fillText(k,47+i*bw,h-8)}})}}
function refreshPoint(){{let p=selected(),pct=x=>(100*x).toFixed(2)+'%';CARDS.innerHTML=[['Active threads',p.active],['Decoded-slot utilization',pct(p.decoded_slot_utilization)],['Instruction-port utilization',pct(p.instruction_port_utilization)],['Consumes / cycle',p.backend_consume_rate.toFixed(4)],['Average refill',p.average_refill_latency.toFixed(2)+' cycles'],['Maximum refill',p.maximum_refill_latency+' cycles']].map(x=>`<div class=card><span>${{x[0]}}</span><b>${{x[1]}}</b></div>`).join('');bars(REFILL,p.refill_histogram,'refills');bars(PRESENTED,p.presented_histogram,'cycles');bars(PERTHREAD,Object.fromEntries(p.threads.map(t=>[t.id,t.consumed])),'instructions')}}
function refreshWorkload(){{let ps=points();P.innerHTML=ps.map((p,i)=>`<option value=${{i}}>${{p.active}} active</option>`).join('');P.value=ps.length-1;let max=Math.max(...ps.flatMap(p=>[p.decoded_slot_utilization,p.instruction_port_utilization,p.instruction_port_accept_rate]),1);lineChart(SCALING,[{{name:'decoded slots',labels:ps.map(p=>p.active),values:ps.map(p=>p.decoded_slot_utilization)}},{{name:'port valid',labels:ps.map(p=>p.active),values:ps.map(p=>p.instruction_port_utilization)}},{{name:'port accepted',labels:ps.map(p=>p.active),values:ps.map(p=>p.instruction_port_accept_rate)}}],max,'fraction');ROWS.innerHTML=ps.map(p=>`<tr><td>${{p.active}}</td><td>${{(100*p.decoded_slot_utilization).toFixed(2)}}%</td><td>${{(100*p.instruction_port_utilization).toFixed(2)}}%</td><td>${{p.instruction_port_accept_rate.toFixed(4)}}</td><td>${{p.backend_consume_rate.toFixed(4)}}</td><td>${{p.average_refill_latency.toFixed(2)}}</td><td>${{p.maximum_refill_latency}}</td><td>${{p.req_blocked}}</td><td>${{p.resp_blocked}}</td></tr>`).join('');refreshPoint()}}
W.onchange=refreshWorkload;P.onchange=refreshPoint;window.onresize=()=>{{refreshWorkload()}};refreshWorkload();</script></main></body></html>'''

def parse(text: str) -> dict:
    def items(line: str) -> dict: return {k:int(v) for k,v in (x.split("=") for x in line.split())}
    total = re.search(r"^PERF_FRONTEND (.+)$", text, re.M)
    if not total: raise RuntimeError("simulation produced no frontend results")
    out = items(total.group(1)); cycles=out["cycles"]; active=out["active"]
    out["decoded_slot_utilization"] = out["presented_slot_cycles"]/(cycles*active)
    out["instruction_port_utilization"] = out["req_valid_cycles"]/cycles
    out["instruction_port_accept_rate"] = out["req_accepts"]/cycles
    out["presented_histogram"] = {int(m[0]):int(m[1]) for m in re.findall(r"^PERF_PRESENT_HIST count=(\d+) cycles=(\d+)$",text,re.M)}
    out["refill_histogram"] = {int(m[0]):int(m[1]) for m in re.findall(r"^PERF_REFILL_HIST latency=(\d+) count=(\d+)$",text,re.M)}
    out["threads"] = [items(m.group(1)) for m in re.finditer(r"^PERF_THREAD (.+)$",text,re.M)]
    out["consumed"] = sum(t["consumed"] for t in out["threads"])
    out["backend_consume_rate"] = out["consumed"]/cycles
    count=sum(t["refill_count"] for t in out["threads"])
    out["average_refill_latency"] = sum(t["refill_sum"] for t in out["threads"])/count if count else 0
    out["maximum_refill_latency"] = max((t["refill_max"] for t in out["threads"]),default=0)
    return out

def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument("--output",type=Path,default=REPO/"build/perf/frontend-results.json")
    ap.add_argument("--workloads",nargs="+",choices=WORKLOADS,default=list(WORKLOADS))
    ap.add_argument("--report-from",type=Path,help="generate HTML from an existing JSON result without simulating"); args=ap.parse_args()
    if args.report_from:
        payload=json.loads(args.report_from.read_text()); html=HERE/"report.html"
        html.parent.mkdir(parents=True,exist_ok=True); html.write_text(report_html(payload)); print(f"report: {html}"); return 0
    build=REPO/"build/perf/frontend"; build.mkdir(parents=True,exist_ok=True); binary=build/"frontend_perf"
    program_hex,program_words=compile_workload(build)
    sources=["rtl/isa/isa_pkg.sv","rtl/core/core_pkg.sv","rtl/soc/topology_pkg.sv","rtl/memory/memory_pkg.sv",
             "rtl/core/frontend/frontend_pkg.sv","rtl/core/frontend/decoder.sv","rtl/core/frontend/frontend.sv",
             "verification/perf/frontend/frontend_tb.sv"]
    cmd=["verilator","--binary","--timing","-Wno-fatal","-Wno-DECLFILENAME","-Wno-VARHIDDEN",
         "--Mdir",str(build/"obj"),"-o",str(binary),*map(lambda x:str(REPO/x),sources),"--top-module","frontend_perf_tb",
         "-Gcore_pkg.NUM_HW_THRDS=32"]
    # Package parameters cannot be overridden portably; materialize a tiny source snapshot with 32 contexts.
    pkg=(REPO/"rtl/core/core_pkg.sv").read_text(); pkg=re.sub(r"(NUM_HW_THRDS\s*=\s*)\d+",r"\g<1>32",pkg,count=1)
    snap=build/"core_pkg.sv"; snap.write_text(pkg); cmd[cmd.index(str(REPO/"rtl/core/core_pkg.sv"))]=str(snap); cmd=cmd[:-1]
    subprocess.run(cmd,check=True,cwd=REPO)
    payload={"hardware_threads":32,"active_thread_sweep":list(THREADS),"workloads":{}}
    for name,wid in WORKLOADS.items():
        if name not in args.workloads: continue
        points=[]
        for n in THREADS:
            run=subprocess.run([str(binary),f"+ACTIVE_THREADS={n}",f"+PROGRAM_HEX={program_hex}",
                                f"+PROGRAM_WORDS={program_words}"],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True)
            points.append(parse(run.stdout)); print(f"{name:6s} {n:2d} threads: slot={points[-1]['decoded_slot_utilization']:.3f} refill={points[-1]['average_refill_latency']:.2f}")
        payload["workloads"][name]=points
    args.output.parent.mkdir(parents=True,exist_ok=True); args.output.write_text(json.dumps(payload,indent=2)+"\n")
    html=HERE/"report.html"; html.write_text(report_html(payload))
    print(f"results: {args.output}\nreport: {html}"); return 0
if __name__ == "__main__": raise SystemExit(main())
