`timescale 1ns / 1ps



/////////////////////////////////// TX //////////////////////////////////////////


module uart_tx #(parameter clk_frq = 1000000, parameter baud_rate = 9600)
  (input clk, rst, newd, input[7:0] tx_data, output reg done_tx, output reg tx);
  
localparam clkcount = (clk_frq/baud_rate);

integer count = 0;
integer counts = 0;
  

reg uclk = 0;

  typedef enum bit[1:0]{idle = 2'b00, start = 2'b01, transfer = 2'b10, done = 2'b11}state_t; 
 
state_t state;
  
  
  //generating uclk
  always@(posedge clk)
    begin
    if (rst) begin        //to fix bugs in vivado
        count <= 0;
        uclk <= 0;
      end
      else if (rst) begin        
        count <= 0;
        uclk <= 0;
      end
      else if(count < clkcount/2)
        count <= count + 1;
      else begin
        count <= 0;
        uclk <= ~uclk;
      end 
    end  
  
  reg[7:0] din;
  
  
  always @(posedge uclk)
    begin 
      if(rst)
        begin 
          state<=idle;
        end 
      else 
        begin 
          case(state)
            idle:
              begin 
                counts <= 0;
                tx <= 1'b1;
                done_tx <= 1'b0;
                
                if(newd)
                  begin 
                    state <= transfer;
                    din <= tx_data;
                    tx <= 1'b0;
                  end 
                else 
                  begin 
                    state<=idle;
                  end 
              end 
            transfer:
              begin 
                if(counts < 8)
                  begin 
                    tx <= din[counts];
                    counts<= counts+1 ;
                    state <= transfer;
                  end 
                else 
                  begin 
                    counts <= 0;
                    tx <= 1'b1;
                    state <= idle;
                    done_tx <= 1'b1;
                  end 
              end 
            
            
            default:
              state <= idle;
            
            
          endcase 
          
        end 
     
    end 
  
  
endmodule 


//////////////////////////////// RX ///////////////////////////////////////////


module uart_rx #(parameter clk_frq = 1000000, parameter baud_rate = 9600)
  (input clk, rst, rx, output reg done_rx, output reg [7:0] rx_data);
  
localparam clkcount = (clk_frq/baud_rate);

integer count = 0;
integer counts = 0;
  

reg uclk = 0;
  
  typedef enum bit[1:0]{idle = 2'b00, start = 2'b01, transfer = 2'b10, done = 2'b11}state_t;   
  
state_t state;  
  
  //uclk generation 
  always@(posedge clk)
    begin
      if(count < clkcount/2)
        count <= count + 1;
      else begin
        count <= 0;
        uclk <= ~uclk;
      end 
    end  
  
  always @(posedge uclk)
    begin 
      if(rst)
        begin 
          rx_data <= 8'h00;
          counts <= 0;
          done_rx <= 1'b0;
        end 
      else 
        begin 
          case(state)
              idle:
                begin 
                  counts <= 0; 
                  done_rx <= 1'b0;
                  rx_data <= 8'b0;

                  if(rx == 1'b0)
                    begin 
                      state <= start;
                    end 
                  else 
                    begin 
                      state<=idle;
                    end                   
                end   
              
              start:
                begin 
                  if(counts < 8)
                    begin 
                      counts++;
                      rx_data <= {rx, rx_data[7:1]}; //shift
                    end 
                  else 
                    begin 
                      counts <= 0;
                      state <= idle;
                      done_rx <= 1'b1;
                    end                   
                end 
              
             default:
              begin 
                state <= idle;
              end 
            
            
          endcase
        end 
      
    end 
  
    
endmodule 


//////////////////////////////////TOP MODULE ////////////////////////////////////////

module top #(parameter clk_frq = 1000000, parameter baud_rate = 9600)
  (input clk, rst, rx, newd, input[7:0] tx_data, output tx, done_tx, done_rx, output [7:0] rx_data );
  
  uart_tx 
  #(clk_frq, baud_rate) 
  utx   
  (
    .clk(clk),
    .rst(rst),
    .newd(newd),
    .tx_data(tx_data),
    .done_tx(done_tx),  
    .tx(tx)            
  );   
 
  uart_rx 
  #(clk_frq, baud_rate)
  rtx
  (clk, rst, rx, done_rx, rx_data);       
  
endmodule

//////////////////////////// INTERFACE ////////////////////////////////////////////


interface uart_if;
  logic clk;
  logic uclk_tx;
  logic uclk_rx;
  logic rst;
  logic rx;
  logic [7:0] tx_data;
  logic newd;
  logic tx;
  logic [7:0] rx_data;
  logic done_tx;
  logic done_rx;
  
endinterface
