always_ff @(posedge clk) begin
    if (!f_past_valid) assume (!rst_n);
    if (f_past_valid && $past(rst_n)) assume (rst_n);
    assume (req_thrd < topology_pkg::THREADS_PER_CLUSTER);
end
