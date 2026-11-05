#!/usr/bin/env python3
"""Name the fixed-delay generate block for portable formal references."""

from pathlib import Path
import os

here = Path(__file__).resolve().parent
root = here.parents[3]
output = Path(os.environ["DMCTP_FORMAL_OUTPUT"])
output.mkdir(parents=True, exist_ok=True)

source = (root / "rtl" / "sys_arr" / "common.sv").read_text()
needle = "    end else begin\n        logic [WIDTH-1:0] r_d [DEPTH:0];"
if needle not in source:
    raise RuntimeError("could not locate delayed_pipe generate block")
source = source.replace(
    needle,
    "    end else begin : gen_pipe\n        logic [WIDTH-1:0] r_d [DEPTH:0];",
    1,
)
(output / "common.sv").write_text(source)
