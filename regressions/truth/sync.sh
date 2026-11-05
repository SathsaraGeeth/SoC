#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

python3 - <<'PY'
from pathlib import Path
import re

root = Path.cwd()
cfg_path = root / "regressions" / "truth" / "soc.yaml"
isa_path = root / "rtl" / "isa" / "isa.yaml"

def parse_simple_yaml(path):
    out = {}
    for lineno, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if ":" not in line:
            raise SystemExit(f"{path}:{lineno}: expected key: value")
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise SystemExit(f"{path}:{lineno}: bad key {key!r}")
        if value in ("true", "false"):
            out[key] = int(value == "true")
        elif re.fullmatch(r"0[xX][0-9a-fA-F]+|[0-9]+", value):
            out[key] = int(value, 0)
        else:
            raise SystemExit(f"{path}:{lineno}: {key} must be an integer literal or true/false")
    return out

def require(cfg, key):
    if key not in cfg:
        raise SystemExit(f"{cfg_path}: missing {key}")
    return cfg[key]

def parse_isa_xlen(path):
    in_meta = False
    for lineno, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if re.fullmatch(r"meta\s*:", line.strip()):
            in_meta = True
            continue
        if in_meta and line[:1] not in (" ", "\t"):
            break
        if in_meta:
            match = re.fullmatch(r"\s*xlen\s*:\s*(0[xX][0-9a-fA-F]+|[0-9]+)\s*", line)
            if match:
                return int(match.group(1), 0)
    raise SystemExit(f"{path}: missing meta.xlen")

def ceil_log2(value):
    if value < 1:
        raise SystemExit("values used for log2 must be positive")
    return (value - 1).bit_length()

def replace_define(text, name, value, comment=None):
    suffix = f" {comment}" if comment else ""
    line = f"#define {name:<23} {value}{suffix}"
    pattern = re.compile(rf"^#define\s+{re.escape(name)}\b.*$", re.MULTILINE)
    text, n = pattern.subn(line, text)
    if n != 1:
        raise SystemExit(f"expected one #define {name}, found {n}")
    return text

def replace_param(text, name, value, comment=None):
    suffix = f" {comment}" if comment else ""
    line = f"parameter int {name:<22} = {value};{suffix}"
    pattern = re.compile(rf"^parameter\s+int\s+{re.escape(name)}\s*=.*$", re.MULTILINE)
    text, n = pattern.subn(line, text)
    if n != 1:
        raise SystemExit(f"expected one parameter int {name}, found {n}")
    return text

def replace_typed_param(text, param_type, name, value, comment=None):
    suffix = f" {comment}" if comment else ""
    line = f"parameter {param_type} {name:<17} = {value};{suffix}"
    pattern = re.compile(
        rf"^parameter\s+{re.escape(param_type)}\s+{re.escape(name)}\s*=.*$",
        re.MULTILINE,
    )
    text, n = pattern.subn(line, text)
    if n != 1:
        raise SystemExit(f"expected one parameter {param_type} {name}, found {n}")
    return text

def update(path, fn):
    full = root / path
    old = full.read_text()
    new = fn(old)
    if new != old:
        full.write_text(new)
        print(f"updated {path}")
    else:
        print(f"ok {path}")

def write_if_changed(path, text):
    full = root / path
    old = full.read_text() if full.exists() else None
    if text != old:
        full.write_text(text)
        print(f"updated {path}")
    else:
        print(f"ok {path}")

cfg = parse_simple_yaml(cfg_path)
isa_xlen = parse_isa_xlen(isa_path)
grid_x = require(cfg, "grid_x")
grid_y = require(cfg, "grid_y")
# "singe_region" is kept as a compatibility alias for the original config
# spelling. Prefer "single_region" in new configurations.
if "single_region" in cfg and "singe_region" in cfg:
    raise SystemExit(f"{cfg_path}: specify only one of single_region or singe_region")
single_region = cfg.get("single_region", cfg.get("singe_region", 0))
cores_per_cluster = require(cfg, "cores_per_cluster")
sys_cores_per_cluster = require(cfg, "sys_cores_per_cluster")
sys_array_mac_t = require(cfg, "sys_array_mac_t")
sys_array_m = require(cfg, "sys_array_m")
sys_array_max_dense_mat_sz = require(cfg, "sys_array_max_dense_mat_sz")
threads_per_core = require(cfg, "threads_per_core")
mesh_coord_bits = require(cfg, "mesh_coord_bits")
page_words_bits = require(cfg, "page_words_bits")
num_pages_bits = require(cfg, "num_pages_bits")
clock_freq_hz = require(cfg, "clock_freq_hz")

if grid_x <= 0 or grid_y <= 0 or grid_x % 2 or grid_y % 2:
    raise SystemExit("grid_x and grid_y must be positive even values")
if single_region not in (0, 1):
    raise SystemExit("single_region must be false/true (or 0/1)")
if cores_per_cluster <= 0 or threads_per_core <= 0:
    raise SystemExit("cores_per_cluster and threads_per_core must be positive")
if sys_cores_per_cluster < 0:
    raise SystemExit("sys_cores_per_cluster must be non-negative")
if sys_array_mac_t not in (0, 1, 2):
    raise SystemExit("sys_array_mac_t must be 0 (MAC20I), 1 (MACFP8), or 2 (MACFP8INT8)")
if sys_array_m <= 0:
    raise SystemExit("sys_array_m must be positive")
if sys_array_max_dense_mat_sz <= 0 or sys_array_max_dense_mat_sz % sys_array_m:
    raise SystemExit("sys_array_max_dense_mat_sz must be a positive multiple of sys_array_m")
if cores_per_cluster not in (1, 2, 4, 8, 16, 32):
    raise SystemExit("cores_per_cluster must be one of: 1, 2, 4, 8, 16, 32")
if threads_per_core not in (2, 4, 8, 16, 32):
    raise SystemExit("threads_per_core must be one of: 2, 4, 8, 16, 32")
if isa_xlen < 1 or mesh_coord_bits < 1:
    raise SystemExit("isa meta.xlen and mesh_coord_bits must be positive")
if 2 * mesh_coord_bits >= isa_xlen:
    raise SystemExit("mesh-coordinate fields must leave at least one local-address bit")
if page_words_bits + 3 != 12:
    raise SystemExit("page_words_bits must describe a 4 KiB page for the RV64 page engine")

num_regions = 1 if single_region else (grid_x * grid_y) // 2
threads_per_cluster = cores_per_cluster * threads_per_core
thread_offset_bits = ceil_log2(threads_per_cluster)
num_cpu_rw_ports = cores_per_cluster * 4 * 2
num_sys_rw_ports = sys_cores_per_cluster * 3
num_rw_ports = num_cpu_rw_ports + num_sys_rw_ports
num_banks = 2 * num_cpu_rw_ports

def sync_soc_h(text):
    region_comment = "/* generated from single_region */" if single_region else "/* generated from GRID_X * GRID_Y / 2 */"
    text = replace_define(text, "NUM_REGIONS", str(num_regions), region_comment)
    text = replace_define(text, "NUM_CLUSTERS", str(num_regions))
    text = replace_define(text, "VIR_ADDR_BITS", str(isa_xlen))
    text = replace_define(text, "MESH_COORD_BITS", str(mesh_coord_bits))
    text = replace_define(text, "SYS_CORES_PER_CLUSTER", str(sys_cores_per_cluster))
    mac_names = ("SYS_ARRAY_MAC20I", "SYS_ARRAY_MACFP8", "SYS_ARRAY_MACFP8INT8")
    text = replace_define(text, "SYS_ARRAY_MAC_T", mac_names[sys_array_mac_t])
    text = replace_define(text, "SYS_ARRAY_M", str(sys_array_m))
    text = replace_define(text, "SYS_ARRAY_MAX_DENSE_MAT_SZ", str(sys_array_max_dense_mat_sz))
    text = replace_define(text, "THREADS_IN_CLUSTER", str(threads_per_cluster))
    text = replace_define(text, "THREAD_OFFSET_BITS", str(thread_offset_bits), "/* ceil(log2(THREADS_IN_CLUSTER)) */")
    text = replace_define(text, "CLOCK_FREQ_HZ", str(clock_freq_hz))
    return text

def sync_topology_pkg(text):
    text = replace_param(text, "VIR_ADDR_W", "isa_pkg::XLEN", "    // isa.yaml owns XLEN via isa_pkg")
    text = replace_param(text, "GRID_X", str(grid_x), "                /* must be even */")
    text = replace_param(text, "GRID_Y", str(grid_y), "                /* must be even */")
    text = replace_param(text, "SINGLE_REGION", str(single_region), "         /* instantiate one cluster and one memory region */")
    text = replace_param(text, "CORES_PER_CLUSTER", str(cores_per_cluster))
    text = replace_param(text, "SYS_CORES_PER_CLUSTER", str(sys_cores_per_cluster))
    text = replace_param(text, "MESH_COORD_BITS", str(mesh_coord_bits))
    return text

def sync_core_pkg(text):
    text = replace_param(text, "VIR_ADDR_W", "isa_pkg::XLEN")
    text = replace_param(text, "NUM_HW_THRDS", str(threads_per_core))
    return text

def sync_memory_pkg(text):
    text = replace_param(text, "PAGE_WORDS_W", str(page_words_bits))
    text = replace_param(text, "NUM_PAGES_W", str(num_pages_bits))
    return text

def sync_sys_cnfg_pkg(text):
    text = replace_param(text, "M", str(sys_array_m))
    text = replace_param(text, "MAX_DENSE_MAT_SZ", str(sys_array_max_dense_mat_sz))
    mac_names = ("MAC20I_STATIC", "MACFP8_STATIC", "MACFP8INT8_STATIC")
    text = replace_typed_param(text, "mac_static_t", "MAC_T", mac_names[sys_array_mac_t])
    return text

update("kernel/dmtcp/include/soc.h", sync_soc_h)
update("rtl/soc/topology_pkg.sv", sync_topology_pkg)
update("rtl/core/core_pkg.sv", sync_core_pkg)
update("rtl/memory/memory_pkg.sv", sync_memory_pkg)
update("rtl/sys_arr/sys_cnfg_pkg.sv", sync_sys_cnfg_pkg)
write_if_changed("regressions/truth/sim.env", f"""# Generated by regressions/truth/sync.sh; do not edit by hand.
CORES_PER_CLUSTER={cores_per_cluster}
SYS_CORES_PER_CLUSTER={sys_cores_per_cluster}
SYS_ARRAY_MAC_T={sys_array_mac_t}
SYS_ARRAY_M={sys_array_m}
SYS_ARRAY_MAX_DENSE_MAT_SZ={sys_array_max_dense_mat_sz}
THREADS_PER_CORE={threads_per_core}
THREADS_PER_CLUSTER={threads_per_cluster}
NUM_CPU_RW_PORTS={num_cpu_rw_ports}
NUM_SYS_RW_PORTS={num_sys_rw_ports}
NUM_RW_PORTS={num_rw_ports}
NUM_BANKS={num_banks}
""")
write_if_changed("user/include/sysarr/config.h", f"""#ifndef DMCTP_SYSARR_CONFIG_H
#define DMCTP_SYSARR_CONFIG_H

/* Generated by regressions/truth/sync.sh; do not edit by hand. */
#define SYSARR_HW_MAC20I 0
#define SYSARR_HW_MACFP8 1
#define SYSARR_HW_MACFP8INT8 2
#define SYSARR_HW_MAC_T  {sys_array_mac_t}
#define SYSARR_HW_M      {sys_array_m}
#define SYSARR_HW_MAX_DENSE_MAT_SZ {sys_array_max_dense_mat_sz}

#endif
""")
PY
