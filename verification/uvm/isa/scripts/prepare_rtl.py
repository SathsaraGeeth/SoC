#!/usr/bin/env python3
"""
Keep this until the lints in the core.sv fixed
"""

from pathlib import Path
import os
import re

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "rtl" / "core"
OUTPUT = Path(os.environ.get("DMCTP_BUILD_DIR", ROOT / "build" / "uvm" / "isa")) / "generated"
OUTPUT.mkdir(parents=True, exist_ok=True)


def qualify(text: str, names: list[str]) -> str:
    for name in names:
        text = re.sub(rf"(?<!::)\b{name}\b", f"core_pkg::{name}", text)
    return text


def qualify_with(text: str, package: str, names: list[str]) -> str:
    for name in names:
        text = re.sub(rf"(?<!::)\b{name}\b", f"{package}::{name}", text)
    return text


def move_declarations(text: str, names: list[str], anchor: str) -> str:
    declarations = []
    for name in names:
        pattern = re.compile(
            rf"^[ \t]*logic[^\n;]*\b{name}\b[^\n;]*;\s*$",
            re.MULTILINE,
        )
        match = pattern.search(text)
        if not match:
            raise RuntimeError(f"could not locate declaration for {name}")
        declarations.append(match.group(0).strip())
        text = text[: match.start()] + text[match.end() :]
    if anchor not in text:
        raise RuntimeError(f"could not locate declaration anchor: {anchor}")
    block = "\n" + "\n".join(f"    {line}" for line in declarations) + "\n"
    return text.replace(anchor, anchor + block, 1)


def split_combined_sync_clear(text: str) -> str:
    pattern = re.compile(
        r"(?P<head>^[ \t]*always_ff @\(posedge i_clk or negedge i_rst_n\) begin[^\n]*\n)"
        r"(?P<indent>[ \t]*)if \(!i_rst_n \|\| !i_clr_n\) begin\n"
        r"(?P<body>.*?)"
        r"(?P=indent)end else if",
        re.MULTILINE | re.DOTALL,
    )

    def repl(match: re.Match[str]) -> str:
        head = match.group("head")
        indent = match.group("indent")
        body = match.group("body")
        return (
            f"{head}{indent}if (!i_rst_n) begin\n{body}"
            f"{indent}end else if (!i_clr_n) begin\n{body}"
            f"{indent}end else if"
        )

    return pattern.sub(repl, text)


regfile = qualify((SOURCE / "regfile.sv").read_text(), ["REG_COUNT", "XLEN"])
(OUTPUT / "regfile.sv").write_text(regfile)

csr_names = [
    "XLEN", "CSR_COUNT", "CSR_MSTATUS", "CSR_THREAD_ID", "CSR_MIP", "CSR_MEPC",
    "CSR_MCAUSE", "CSR_MIE", "CSR_SSTATUS", "CSR_SIP", "CSR_SEPC",
    "CSR_SCAUSE", "CSR_STVAL", "CSR_MIDELEG", "CSR_SIE", "CSR_MEDELEG",
]
csr = qualify((SOURCE / "csr.sv").read_text(), csr_names)
(OUTPUT / "csr.sv").write_text(csr)

alu = (SOURCE / "alu.sv").read_text()
alu = qualify(alu, ["XLEN"])
alu = move_declarations(
    alu, ["s1_to_s2", "s2_mul_result"],
    "    logic                                   s0_req_fire;",
)
(OUTPUT / "alu.sv").write_text(alu)

core_names = [
    "XLEN", "CSR_COUNT", "REG_COUNT", "CSR_MTVEC", "CSR_MEPC", "CSR_MCAUSE",
    "CSR_PAGE_MSG_CMD", "CSR_VIRTUAL_THRD_ID", "CSR_PAGE_MSG_ARG0",
    "CSR_PAGE_MSG_ARG1", "REG_BITS",
]
core = qualify((SOURCE / "core.sv").read_text(), core_names)
core = qualify_with(core, "core_pkg", ["VIR_ADDR_W", "NUM_HW_THRDS"])
core = qualify_with(
    core,
    "memory_pkg",
    ["PAGE_MSG_W", "generic_page_msg_t", "page_fault_msg_t",
     "vtid_update_msg_t", "tlb_update_msg_t", "page_transfer_msg_t",
     "page_msg_type_e", "PAGE_MSG_FAULT", "PAGE_MSG_TLB_UPDATE",
     "PAGE_MSG_VTID_UPDATE", "THRD_W", "VTID_W", "PPN_W",
     "TLB_UPDATE_VTID_ARG_W"],
)
core = move_declarations(
    core,
    [
        "s1_p0_issue_thrd_id", "s1_p0_issue_found", "s1_p0_issue_thrd_id_1",
        "s1_p0_issue_found_1", "s1_p0_backend_fb_npc", "s1_p0_backend_fb_valid",
        "s1_p0_backend_fb_redirect", "s1_p0_predict_valid", "s1_p0_predict_valid_1",
    ],
    "    /* ---**/",
)
(OUTPUT / "core.sv").write_text(core)

decoder = qualify((SOURCE / "decoder.sv").read_text(), ["REG_BITS", "XLEN"])
(OUTPUT / "decoder.sv").write_text(decoder)

fpu_adapter = qualify((SOURCE / "fpu.sv").read_text(), ["XLEN"])
(OUTPUT / "fpu.sv").write_text(fpu_adapter)

memory = (ROOT / "rtl" / "memory" / "memory.sv").read_text()
memory = move_declarations(
    memory,
    ["r_bank_resp_port", "r_bank_resp_thrd"],
    "    logic [THRD_W-1:0]                      r_page_req_thrd;",
)
if os.environ.get("DMCTP_FORMAL_MEMORY") == "1":
    # Formal samples the design on the source clock. Opening the integrated
    # bank clock gates avoids introducing derived clocks into the proof model;
    # the gate-control logic itself remains present and observable.
    memory = memory.replace(
        "w_mem_clk           [b] = i_clk && w_mem_clk_en_latch[b];",
        "w_mem_clk           [b] = i_clk;",
    )
(OUTPUT / "memory.sv").write_text(memory)

mac20i_v2 = (ROOT / "rtl" / "sys_arr" / "mac20i_v2.sv").read_text()
mac20i_v2 = move_declarations(
    mac20i_v2,
    ["r_done_bank", "r_done_bank_rd"],
    "    logic [31:0] w_s2_d;",
)
mac20i_v2 = mac20i_v2.replace("always_ff @(", "always @(")
mac20i_v2 = mac20i_v2.replace(
    "always @(posedge i_clk or negedge i_rst_n) begin\n"
    "        if (!i_rst_n || !i_clr_n) begin\n"
    "            r_done_bank_rd    <= 1'b0;\n"
    "            r_done_bank_wr    <= 1'b0;\n"
    "            r_done_bank_count <= '0;\n"
    "            r_done_bank[0]    <= 1'b0;\n"
    "            r_done_bank[1]    <= 1'b0;\n"
    "        end else if (i_en) begin",
    "always @(posedge i_clk or negedge i_rst_n) begin\n"
    "        if (!i_rst_n) begin\n"
    "            r_done_bank_rd    <= 1'b0;\n"
    "            r_done_bank_wr    <= 1'b0;\n"
    "            r_done_bank_count <= '0;\n"
    "            r_done_bank[0]    <= 1'b0;\n"
    "            r_done_bank[1]    <= 1'b0;\n"
    "        end else if (!i_clr_n) begin\n"
    "            r_done_bank_rd    <= 1'b0;\n"
    "            r_done_bank_wr    <= 1'b0;\n"
    "            r_done_bank_count <= '0;\n"
    "            r_done_bank[0]    <= 1'b0;\n"
    "            r_done_bank[1]    <= 1'b0;\n"
    "        end else if (i_en) begin",
)
(OUTPUT / "mac20i_v2.sv").write_text(mac20i_v2)

mac_fp8_v2 = (ROOT / "rtl" / "sys_arr" / "mac_fp8_fp8_fp8_61_v2.sv").read_text()
mac_fp8_v2 = re.sub(r"(?<!::)\bM\b", "sys_cnfg_pkg::M", mac_fp8_v2)
mac_fp8_v2 = move_declarations(
    mac_fp8_v2,
    ["r_done_bank", "r_done_bank_rd"],
    "    logic [INTL_W-1:0]              w_s4_acc;",
)
mac_fp8_v2 = split_combined_sync_clear(mac_fp8_v2)
(OUTPUT / "mac_fp8_fp8_fp8_61_v2.sv").write_text(mac_fp8_v2)

mmacu_core_v2 = (ROOT / "rtl" / "sys_arr" / "mmacu_core_v2.sv").read_text()
mmacu_core_v2 = move_declarations(
    mmacu_core_v2,
    [
        "r_flushing", "r_flush_ctr", "r_flush_output_done", "r_flush_cycles",
        "r_flush_k2", "r_flush_dense", "wn_done", "wn_valid_d", "wn_d",
        "w_reuse_a_head", "w_reuse_b_head", "w_reuse_a_empty", "w_reuse_b_empty",
    ],
    "    logic [M*WIDTH_AB-1:0]      w_src_b;",
)
mmacu_reset_pattern = re.compile(
    r"(?P<head>^[ \t]*always_ff @\(posedge i_clk or negedge i_rst_n\) begin\n)"
    r"(?P<indent>[ \t]*)if \(!i_rst_n \|\| !w_dense_mode \|\|\n"
    r"(?P=indent)    \(r_flushing && w_gstall_n && \(r_flush_ctr == r_flush_cycles - 1'b1\)\)\) begin\n"
    r"(?P<body>.*?)(?P=indent)end else",
    re.MULTILINE | re.DOTALL,
)


def split_mmacu_reset(match: re.Match[str]) -> str:
    head = match.group("head")
    indent = match.group("indent")
    body = match.group("body")
    return (
        f"{head}{indent}if (!i_rst_n) begin\n{body}"
        f"{indent}end else if (!w_dense_mode ||\n"
        f"{indent}             (r_flushing && w_gstall_n && "
        f"(r_flush_ctr == r_flush_cycles - 1'b1))) begin\n{body}"
        f"{indent}end else"
    )


mmacu_core_v2 = mmacu_reset_pattern.sub(split_mmacu_reset, mmacu_core_v2)
(OUTPUT / "mmacu_core_v2.sv").write_text(mmacu_core_v2)

sys_core = (ROOT / "rtl" / "sys_arr" / "sys_core.sv").read_text()
sys_core = qualify_with(sys_core, "sys_cnfg_pkg", ["XLEN", "VIR_ADDR_W"])
sys_core = move_declarations(
    sys_core,
    [
        "w_addrA_level", "w_addrB_level", "w_addrD_level", "w_out_level",
        "w_drvA_deq_ready", "w_drvB_deq_ready", "w_d_valid", "w_done_d",
    ],
    "    logic [sys_cnfg_pkg::XLEN-1:0]                r_wb_tid;",
)
(OUTPUT / "sys_core.sv").write_text(sys_core)

soc_pkg = (ROOT / "rtl" / "soc" / "soc_pkg.sv").read_text()
soc_pkg = re.sub(r"^[ \t]*import [^;]+;[ \t]*\n", "", soc_pkg, flags=re.MULTILINE)
soc_pkg = qualify_with(soc_pkg, "core_pkg", ["XLEN", "NUM_HW_THRDS"])
soc_pkg = qualify_with(
    soc_pkg,
    "topology_pkg",
    ["VIR_ADDR_W", "THREADS_PER_CLUSTER", "CORES_PER_CLUSTER", "GRID_X",
     "GRID_Y", "MESH_COORD_BITS"],
)
soc_pkg = qualify_with(soc_pkg, "memory_pkg", ["THRD_W"])
soc_pkg = qualify_with(soc_pkg, "isa_pkg", ["PRIV_MODE_U"])
(OUTPUT / "soc_pkg.sv").write_text(soc_pkg)

router = (ROOT / "rtl" / "soc" / "router.sv").read_text()
router = re.sub(r"^[ \t]*import [^;]+;[ \t]*\n", "", router, flags=re.MULTILINE)
router = qualify_with(router, "core_pkg", ["XLEN", "NUM_HW_THRDS"])
router = qualify_with(router, "topology_pkg", ["VIR_ADDR_W", "MESH_COORD_BITS"])
router = qualify_with(
    router,
    "memory_pkg",
    ["PAGE_MSG_W", "generic_page_msg_t", "PAGE_MSG_FAULT"],
)
router = qualify_with(router, "isa_pkg", ["PRIV_MODE_U"])
router = qualify_with(router, "soc_pkg", ["CORE_THRD_W", "is_soc_mmio_addr"])
router = move_declarations(router, ["data_is_mmio"], "    logic       data_valid_dir;")
router = re.sub(r"\$fatal\(1,.*?\);", "assert (1'b0);", router, flags=re.DOTALL)
(OUTPUT / "router.sv").write_text(router)
