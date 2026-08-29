module transition_mem #(parameter N=6, parameter DW=11)(
    input  logic [$clog2(N*N)-1:0] addr,
    output logic signed [DW-1:0]   data
);
logic signed [DW-1:0] memory [0:N*N-1];
initial begin
 memory[0]=65;  memory[1]=176; memory[2]=89;  memory[3]=45;  memory[4]=45;  memory[5]=92;
 memory[6]=103; memory[7]=201; memory[8]=27;  memory[9]=52;  memory[10]=103;memory[11]=26;
 memory[12]=51; memory[13]=27; memory[14]=305;memory[15]=51; memory[16]=52; memory[17]=26;
 memory[18]=51; memory[19]=26; memory[20]=27; memory[21]=305;memory[22]=51; memory[23]=52;
 memory[24]=103;memory[25]=51; memory[26]=27; memory[27]=51; memory[28]=254;memory[29]=26;
 memory[30]=51; memory[31]=27; memory[32]=26; memory[33]=51; memory[34]=52; memory[35]=305;
end
assign data = memory[addr];
endmodule
