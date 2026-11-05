`timescale 1ns/1ps
`default_nettype none

package soc_pkg;
    import isa_pkg::*;
    import core_pkg::*;
    import memory_pkg::*;
    import topology_pkg::*;

    localparam int CORE_THRD_W = $clog2(NUM_HW_THRDS);
    localparam int NUM_SYS_PORTS = memory_pkg::NUM_SYS_RW_PORTS;
    localparam int IPI_WORDS = (THREADS_PER_CLUSTER + XLEN - 1) / XLEN;
    localparam int IPI_WORD_BYTES = XLEN / 8;
    localparam int REGION_OFFSET_BITS = VIR_ADDR_W - 2 * MESH_COORD_BITS;
    localparam int NUM_CARDINAL_DIRS = 4;
    localparam int DIR_NORTH = 0;
    localparam int DIR_EAST  = 1;
    localparam int DIR_SOUTH = 2;
    localparam int DIR_WEST  = 3;

    localparam logic [VIR_ADDR_W-1:0] UART_BASE_ADDR       = 64'h0000_0010_0000_0000;
    localparam logic [VIR_ADDR_W-1:0] UART_END_ADDR        = UART_BASE_ADDR + 64'h37;
    localparam logic [VIR_ADDR_W-1:0] IPI_BASE_ADDR        = 64'h0000_0010_0000_1000;
    localparam logic [VIR_ADDR_W-1:0] IPI_SIZE_BYTES       = 64'h0000_0000_0000_1000;
    localparam logic [VIR_ADDR_W-1:0] IPI_END_ADDR         = IPI_BASE_ADDR + IPI_SIZE_BYTES;
    localparam logic [VIR_ADDR_W-1:0] SYS_MMIO_BASE_ADDR   = 64'h0000_0010_0100_0000;
    localparam logic [VIR_ADDR_W-1:0] SYS_MMIO_END_ADDR    = 64'h0000_0010_0100_0fff;
    localparam logic [VIR_ADDR_W-1:0] TIMER_MMIO_BASE_ADDR = 64'h0000_0010_0200_0000;
    localparam logic [VIR_ADDR_W-1:0] TIMER_MMIO_SIZE      = 64'h0000_0000_0100_0000;

    function automatic int cluster_x(input int id);
        int cluster = 0;
        for (int y = 0; y < GRID_Y; y++) begin
            for (int x = 0; x < GRID_X; x++) begin
                if ((x + y) % 2 == 0) begin
                    if (cluster == id) return x;
                    cluster++;
                end
            end
        end
        return 0;
    endfunction

    function automatic int cluster_y(input int id);
        int cluster = 0;
        for (int y = 0; y < GRID_Y; y++) begin
            for (int x = 0; x < GRID_X; x++) begin
                if ((x + y) % 2 == 0) begin
                    if (cluster == id) return y;
                    cluster++;
                end
            end
        end
        return 0;
    endfunction

    function automatic int memory_id(input int x, input int y);
        int memory = 0;
        for (int yy = 0; yy < GRID_Y; yy++) begin
            for (int xx = 0; xx < GRID_X; xx++) begin
                if ((xx + yy) % 2 != 0) begin
                    if (xx == x && yy == y) return memory;
                    memory++;
                end
            end
        end
        return -1;
    endfunction

    function automatic int core_cluster_id(input int core_id);
        return core_id / CORES_PER_CLUSTER;
    endfunction

    function automatic int core_local_id(input int core_id);
        return core_id % CORES_PER_CLUSTER;
    endfunction

    function automatic int cluster_core_id(
        input int cluster_id,
        input int local_core_id
    );
        return cluster_id * CORES_PER_CLUSTER + local_core_id;
    endfunction

    function automatic int neighbor_memory_id(
        input int core_id,
        input int direction
    );
        int c_x = cluster_x(core_cluster_id(core_id));
        int c_y = cluster_y(core_cluster_id(core_id));

        case (direction)
            DIR_NORTH: return (c_y > 0)          ? memory_id(c_x, c_y - 1) : -1;
            DIR_EAST:  return (c_x < GRID_X - 1) ? memory_id(c_x + 1, c_y) : -1;
            DIR_SOUTH: return (c_y < GRID_Y - 1) ? memory_id(c_x, c_y + 1) : -1;
            DIR_WEST:  return (c_x > 0)          ? memory_id(c_x - 1, c_y) : -1;
            default:   return -1;
        endcase
    endfunction

    function automatic int neighbor_memory_port(
        input int core_id,
        input int direction,
        input logic is_data
    );
        int port_base = core_local_id(core_id) * NUM_CARDINAL_DIRS * 2;
        int direction_offset;

        case (direction)
            DIR_NORTH: direction_offset = 4;
            DIR_EAST:  direction_offset = 6;
            DIR_SOUTH: direction_offset = 0;
            DIR_WEST:  direction_offset = 2;
            default:   direction_offset = 0;
        endcase
        return port_base + direction_offset + int'(is_data);
    endfunction

    function automatic int cluster_home_memory_id(input int cluster_id);
        int c_x = cluster_x(cluster_id);
        int c_y = cluster_y(cluster_id);

        return (c_x % 2 == 0) ? memory_id(c_x + 1, c_y)
                              : memory_id(c_x - 1, c_y);
    endfunction

    function automatic int cluster_home_direction(input int cluster_id);
        return (cluster_x(cluster_id) % 2 == 0) ? DIR_EAST : DIR_WEST;
    endfunction

    function automatic logic is_ipi_addr(input logic [VIR_ADDR_W-1:0] addr);
        return (addr >= IPI_BASE_ADDR) &&
               (addr < IPI_END_ADDR) &&
               (((addr - IPI_BASE_ADDR) % VIR_ADDR_W'(IPI_WORD_BYTES)) == 0);
    endfunction

    function automatic int ipi_word_index(input logic [VIR_ADDR_W-1:0] addr);
        return int'((addr - IPI_BASE_ADDR) / VIR_ADDR_W'(IPI_WORD_BYTES));
    endfunction

    function automatic logic is_dummy_oob_data_addr(
        input logic [VIR_ADDR_W-1:0] addr,
        input logic [1:0] priv
    );
        return (priv != PRIV_MODE_U) && (addr[31:28] == 4'hf);
    endfunction

    function automatic logic is_sys_mmio_addr(
        input logic [VIR_ADDR_W-1:0] addr,
        input logic [1:0] priv
    );
        return (priv != PRIV_MODE_U) &&
               (addr >= SYS_MMIO_BASE_ADDR) &&
               (addr <= SYS_MMIO_END_ADDR);
    endfunction

    function automatic logic is_timer_mmio_addr(
        input logic [VIR_ADDR_W-1:0] addr,
        input logic [1:0] priv
    );
        return (priv != PRIV_MODE_U) &&
               (addr >= TIMER_MMIO_BASE_ADDR) &&
               (addr < TIMER_MMIO_BASE_ADDR + TIMER_MMIO_SIZE);
    endfunction

    function automatic logic is_soc_mmio_addr(
        input logic [VIR_ADDR_W-1:0] addr,
        input logic [1:0] priv
    );
        return ((priv != PRIV_MODE_U) &&
                (addr >= UART_BASE_ADDR) && (addr <= UART_END_ADDR)) ||
               ((priv != PRIV_MODE_U) && is_ipi_addr(addr)) ||
               is_sys_mmio_addr(addr, priv) ||
               is_timer_mmio_addr(addr, priv) ||
               is_dummy_oob_data_addr(addr, priv);
    endfunction

    function automatic logic [VIR_ADDR_W-1:0] local_region_addr(
        input logic [VIR_ADDR_W-1:0] addr
    );
        return addr & ((VIR_ADDR_W'(1) << REGION_OFFSET_BITS) - 1);
    endfunction

    function automatic logic [VIR_ADDR_W-1:0] memory_req_addr(
        input logic [VIR_ADDR_W-1:0] addr,
        input logic [1:0] priv
    );
        return (priv == PRIV_MODE_U) ? addr : local_region_addr(addr);
    endfunction

    function automatic logic [VIR_ADDR_W-1:0] reset_vector(input int cluster_id);
        int c_x = cluster_x(cluster_id);
        int c_y = cluster_y(cluster_id);
        int m_x = (c_x % 2 == 0) ? c_x + 1 : c_x - 1;

        return (VIR_ADDR_W'(c_y) << (REGION_OFFSET_BITS + MESH_COORD_BITS)) |
               (VIR_ADDR_W'(m_x) << REGION_OFFSET_BITS);
    endfunction

    function automatic logic [THRD_W-1:0] memory_thread_id(
        input int core_id,
        input logic [CORE_THRD_W-1:0] local_thrd_id
    );
        return THRD_W'(core_local_id(core_id) * NUM_HW_THRDS) +
               THRD_W'(local_thrd_id);
    endfunction

    function automatic logic [CORE_THRD_W-1:0] core_thread_id(
        input logic [THRD_W-1:0] memory_thrd_id
    );
        return CORE_THRD_W'(memory_thrd_id % NUM_HW_THRDS);
    endfunction
endpackage: soc_pkg
