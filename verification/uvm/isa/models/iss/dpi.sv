/*
 * Comments:
 * 1. DPIC boundary
 */

package iss_dpi_pkg;
    typedef struct {
        longint unsigned commit_pc;
        byte    unsigned commit_valid;
        longint unsigned rf_pc;
        byte    unsigned rf_we;
        int     unsigned rf_we_addr;
        longint unsigned rf_we_data;
        longint unsigned csr_pc;
        byte    unsigned csr_we;
        int     unsigned csr_we_addr;
        longint unsigned csr_we_data;
        longint unsigned mem_pc;
        byte    unsigned mem_req_we;
        longint unsigned mem_req_addr;
        longint unsigned mem_req_wdata;
        longint unsigned mem_req_wmask;
    } arch_commit_trace_t;

    import "DPI-C" context function int iss_dpi_init(
        input int thread_id, input string image_path);

    import "DPI-C" context function int iss_set_pc(
        input int thread_id, input longint unsigned pc);

    import "DPI-C" context function void iss_finish();

    import "DPI-C" context function void iss_step_raw(
        input  int               thread_id,
        output longint  unsigned commit_pc,
        output byte     unsigned commit_valid,
        output longint  unsigned rf_pc,
        output byte     unsigned rf_we,
        output int      unsigned rf_we_addr,
        output longint  unsigned rf_we_data,
        output longint  unsigned csr_pc,
        output byte     unsigned csr_we,
        output int      unsigned csr_we_addr,
        output longint  unsigned csr_we_data,
        output longint  unsigned mem_pc,
        output byte     unsigned mem_req_we,
        output longint  unsigned mem_req_addr,
        output longint  unsigned mem_req_wdata,
        output longint  unsigned mem_req_wmask);

    function automatic void iss_step(
        input int thread_id,
        output arch_commit_trace_t trace_out);

        iss_step_raw(
            thread_id,
            trace_out.commit_pc,
            trace_out.commit_valid,
            trace_out.rf_pc,
            trace_out.rf_we,
            trace_out.rf_we_addr,
            trace_out.rf_we_data,
            trace_out.csr_pc,
            trace_out.csr_we,
            trace_out.csr_we_addr,
            trace_out.csr_we_data,
            trace_out.mem_pc,
            trace_out.mem_req_we,
            trace_out.mem_req_addr,
            trace_out.mem_req_wdata,
            trace_out.mem_req_wmask
        );
    endfunction
endpackage: iss_dpi_pkg
