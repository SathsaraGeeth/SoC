/* P3---  */
// property rs1_rs2_equal_reads;
//     @(posedge clk)
//     disable iff (!f_past_valid)
//     (rs1_addr == rs2_addr) |=> (rs1_data == rs2_data);
// endproperty: rs1_rs2_equal_reads

// assert property (rs1_rs2_equal_reads) else $error("rs1 and rs2 read same addr but returned different data");
//
// property rs1_rs3_equal_reads;
//     @(posedge clk)
//     disable iff (!f_past_valid)
//     (rs1_addr == rs3_addr) |=> (rs1_data == rs3_data);
// endproperty: rs1_rs3_equal_reads

// assert property (rs1_rs3_equal_reads) else $error("rs1 and rs3 read same addr but returned different data");
//
// property rs2_rs3_equal_reads;
//     @(posedge clk)
//     disable iff (!f_past_valid)
//     (rs2_addr == rs3_addr) |=> (rs2_data == rs3_data);
// endproperty: rs2_rs3_equal_reads

// assert property (rs2_rs3_equal_reads) else $error("rs2 and rs3 read same addr but returned different data");

always_ff @(posedge clk) begin: p_equal_reads
    if (f_past_valid) begin
        if ($past(rs1_addr) == $past(rs2_addr))
            assert (rs1_data == rs2_data);
        if ($past(rs1_addr) == $past(rs3_addr))
            assert (rs1_data == rs3_data);
        if ($past(rs2_addr) == $past(rs3_addr))
            assert (rs2_data == rs3_data);
    end
end: p_equal_reads
/*  ---P3 */
