// Kathy Guo
// kaguo@g.hmc.edu
// 10/27/2026
// AddRoundKey module XORs the current state with its correponding round key.

module AddRoundKey(
    input logic [127:0] state_in,
    input logic [127:0] round_key,
    output logic [127:0] state_out);

    assign state_out = state_in ^ round_key;
endmodule