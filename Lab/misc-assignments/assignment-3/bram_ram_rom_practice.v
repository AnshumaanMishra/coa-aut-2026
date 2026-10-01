module bram_ram_rom_practice (
    clk,
    reset,
    start,
    done,
    result_out
);
  input clk, reset, start;
  output reg done;
  output reg [31:0] result_out;

  reg rom_en;
  reg [2:0] rom_addr;
  wire [3:0] rom_data;

  address_rom #(
      .ADDR(3),
      .DATA(4)
  ) rom_inst (
      .clka (clk),
      .ena  (rom_en),
      .addra(rom_addr),
      .douta(rom_data)
  );

  reg ram_en, ram_we;
  reg  [ 3:0] ram_addr;
  reg  [31:0] ram_write_data;
  wire [31:0] ram_read_data;

  data_ram #(
      .ADDR(4),
      .DATA(32)
  ) ram_inst (
      .clka (clk),
      .ena  (ram_en),
      .wea  (ram_we),
      .addra(ram_addr),
      .dina (ram_write_data),
      .douta(ram_read_data)
  );

  localparam [2:0]
    IDLE       = 3'b000,
    ROMREQUEST = 3'b001,
    RAMREQUEST = 3'b010,
    WAIT       = 3'b011,
    ACCUMULATE = 3'b100,
    RAMWRITE   = 3'b101,
    RAMREAD    = 3'b110,
    SETRESULT  = 3'b111;

  reg [2:0] current_state, next_state;
  reg [ 3:0] count;
  reg [31:0] acc;

  always @(posedge clk or posedge reset) begin
    if (reset) current_state <= IDLE;
    else current_state <= next_state;
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE:       next_state = start ? ROMREQUEST : IDLE;
      ROMREQUEST: next_state = RAMREQUEST;
      RAMREQUEST: next_state = WAIT;
      WAIT:       next_state = ACCUMULATE;
      ACCUMULATE: next_state = (count == 4'd7) ? RAMWRITE : ROMREQUEST;
      RAMWRITE:   next_state = RAMREAD;
      RAMREAD:    next_state = SETRESULT;
      SETRESULT:  next_state = SETRESULT;
      default:    next_state = IDLE;
    endcase
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      count      <= 4'b0;
      acc        <= 32'b0;
      done       <= 1'b0;
      result_out <= 32'b0;
    end else begin
      case (current_state)
        ACCUMULATE: begin
          acc   <= acc + ram_read_data;
          count <= count + 1'b1;
        end
        SETRESULT: begin
          result_out <= ram_read_data;
          done       <= 1'b1;
        end
        default: ;
      endcase
    end
  end

  always @(*) begin
    rom_en         = 1'b0;
    rom_addr       = 3'b0;
    ram_en         = 1'b0;
    ram_we         = 1'b0;
    ram_addr       = 4'b0;
    ram_write_data = 32'b0;

    case (current_state)
      ROMREQUEST: begin
        rom_en   = 1'b1;
        rom_addr = count[2:0];
      end
      RAMREQUEST: begin
        ram_en   = 1'b1;
        ram_addr = rom_data;
        ram_we   = 1'b0;
      end
      RAMWRITE: begin
        ram_en         = 1'b1;
        ram_addr       = 4'b1111;
        ram_write_data = acc;
        ram_we         = 1'b1;
      end
      RAMREAD: begin
        ram_en   = 1'b1;
        ram_addr = 4'b1111;
        ram_we   = 1'b0;
      end
      default: ;
    endcase
  end

endmodule
