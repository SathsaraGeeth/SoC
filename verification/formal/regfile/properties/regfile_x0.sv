/* P1---  */
// property rs1_x0_is_0;
//     @(posedge clk)
//     disable iff (!f_past_valid)
//     (rs1_addr == '0) |=> (rs1_data == '0);
// endproperty: rs1_x0_is_0

// assert property (rs1_x0_is_0) else $error("rs1, x0 read is not 0");
//
// property rs2_x0_is_0;
//     @(posedge clk)
//     disable iff (!f_past_valid)
//     (rs2_addr == '0) |=> (rs2_data == '0);
// endproperty: rs2_x0_is_0

// assert property (rs2_x0_is_0) else $error("rs2, x0 read is not 0");
//
// property rs3_x0_is_0;
//     @(posedge clk)
//     disable iff (!f_past_valid)
//     (rs3_addr == '0) |=> (rs3_data == '0);
// endproperty: rs3_x0_is_0

// assert property (rs3_x0_is_0) else $error("rs3, x0 read is not 0");

always_ff @(posedge clk) begin: p_x0_reads_zero
    if (f_past_valid) begin
        if ($past(rs1_addr) == '0)
            assert (rs1_data == '0);
        if ($past(rs2_addr) == '0)
            assert (rs2_data == '0);
        if ($past(rs3_addr) == '0)
            assert (rs3_data == '0);
    end
end: p_x0_reads_zero
/*  ---P1 */


/* P2---  */
// generate
//     for (genvar r = 1; r < REG_COUNT; r++) begin
//         for (genvar t = 0; t < NUM_HW_THRDS; t++) begin
//             property write_to_x0_does_not_modify_mem;
//                 @(posedge clk)
//                 (we && (rd_addr == '0)) |=>
//                     $stable(dut.gen_banks[r].bank.mem[t]);
//             endproperty: write_to_x0_does_not_modify_mem
//
//             assert property (write_to_x0_does_not_modify_mem) else $error("x0 write modified register storage");
//         end
//     end
// endgenerate

generate
    for (genvar r = 1; r < REG_COUNT; r++) begin: g_x0_register
        for (genvar t = 0; t < NUM_HW_THRDS; t++) begin: g_x0_thread
            always_ff @(posedge clk) begin: p_write_to_x0_does_not_modify_mem
                if (f_past_valid && $past(we) &&
                    ($past(rd_addr) == '0))
                    assert (dut.gen_banks[r].bank.mem[t] ==
                            $past(dut.gen_banks[r].bank.mem[t]));
            end: p_write_to_x0_does_not_modify_mem
        end
    end
endgenerate
/*  ---P2 */
