package sys_cnfg_pkg;
typedef enum logic [1:0] {MAC20I_STATIC, MACFP8_STATIC, MACFP8INT8_STATIC} mac_static_t;
typedef enum logic [1:0] {MAC20I, MACFP8} mac_t;
parameter int M=2;
parameter int K=2;
parameter int WIDTH_AB=8;
parameter int WIDTH_CD=8;
parameter mac_static_t MAC_T=MAC20I_STATIC;
localparam int FLUSH_W=8;
function automatic int mac_latency(input mac_t kind);
    return kind==MACFP8 ? 13 : 6;
endfunction
function automatic int mac_output_cycle(input mac_t kind,input int b_tiles);
    return 2*M+mac_latency(kind)-3-(((kind==MACFP8)&&(b_tiles>1))?1:0);
endfunction
function automatic int mac_flush(input mac_t kind);
    return kind==MACFP8 ? 10*M+18 : 10*M+7;
endfunction
endpackage: sys_cnfg_pkg

