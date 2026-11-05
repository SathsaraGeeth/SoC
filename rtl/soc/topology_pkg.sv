`timescale 1ns/1ps
`default_nettype none
package topology_pkg;


parameter int VIR_ADDR_W             = isa_pkg::XLEN;     // isa.yaml owns XLEN via isa_pkg
parameter int GRID_X                 = 2;                 /* must be even */
parameter int GRID_Y                 = 2;                 /* must be even */
parameter int SINGLE_REGION          = 1;          /* instantiate one cluster and one memory region */
parameter int NUM_MEM                = (SINGLE_REGION != 0) ? 1 : (GRID_X * GRID_Y) / 2;
parameter int NUM_CLUSTER            = (SINGLE_REGION != 0) ? 1 : (GRID_X * GRID_Y) / 2;
parameter int CORES_PER_CLUSTER      = 2;
parameter int SYS_CORES_PER_CLUSTER  = 0;
parameter int THREADS_PER_CLUSTER   = CORES_PER_CLUSTER * core_pkg::NUM_HW_THRDS;
parameter int THREAD_OFFSET_BITS    = $clog2(THREADS_PER_CLUSTER);
parameter int NUM_CORES             = NUM_CLUSTER * CORES_PER_CLUSTER;
parameter int MESH_COORD_BITS        = 4;

function automatic int coord_to_id(
    input int x,
    input int y
);
    return y * GRID_X + x;
endfunction

/* 
topology:- 2D-mesh
- e.g. 4x4 grid
    M C M C
    C M C M
    M C M C
    C M C M
*/


/*
Global Virtual Address Space

the highest order p bits determine the pods it lives
the next n bits determine the nodes it lives
the next m bits determine the spms it lives
the lowest 12 bits determine the offset within the spm

** VIR_ADDR_W - p - n - m is the address space the spm has to pretend it has (using backing storage)

2^m = #SPM
2^n = #nodes
2^p = #pods
*/

endpackage: topology_pkg
