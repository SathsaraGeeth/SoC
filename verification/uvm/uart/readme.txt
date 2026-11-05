export DSIM_LICENSE=$HOME/metrics-ca/dsim-license.json
export LD_LIBRARY_PATH=/home/geeth/AltairDSim/2026/llvm_small/lib:$LD_LIBRARY_PATH
export PYGPI_PYTHON_BIN=$(which python)
Jafxyv-8suqdo-sijduk
LU8HD-4LU2I-D9YLY-0Z21

cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/uart -B build/uvm/uart
cmake --build build/uvm/uart --target dsim_build
cmake --build build/uvm/uart --target dsim_run

# Generated UVM UART files, logs, waves, and databases belong only under:
# /mnt/fileserver/prj/dmctp/build/uvm/uart
