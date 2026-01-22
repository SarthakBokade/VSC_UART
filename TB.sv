`timescale 1ns / 1ps


class transaction;
  
  bit newd; 
  bit tx,rx;
  bit done_tx, done_rx;
  
  rand bit [7:0] tx_data;        
  bit [7:0] rx_data;
    
  typedef enum bit  {write = 1'b0 , read = 1'b1} oper_type;
  
  randc oper_type oper;
  
  function transaction copy();
    
    copy = new();   
    copy.newd = this.newd;
    copy.tx = this.tx;
    copy.rx = this.rx;
    copy.done_tx = this.done_tx;
    copy.done_rx = this.done_rx;
    copy.tx_data = this.tx_data;
    copy.rx_data = this.rx_data;  
    copy.oper = this.oper;
    
  endfunction
  
  
  
  function void display(input string tag);
    
    $display("[%0t] [%s] \t : TX_DATA: 0x%h \t RX_DATA: 0x%h", $time, tag, tx_data, rx_data);
    
  endfunction
  
endclass



class generator;
  
  transaction tr;  
  
  mailbox #(transaction) mbx;    
  mailbox #(transaction) mbxref;
  
  event drvnext;
  event sconext;
  event done;
  
  int count = 0; 
  
 
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    
    this.mbx = mbx;  
    this.mbxref = mbxref; 
    tr = new(); 
    
  endfunction
  
  task run();
    
    repeat(count) begin
      assert(tr.randomize()) else $error("[GEN] : RANDOMIZATION FAILED");
      mbx.put(tr.copy()); 
      mbxref.put(tr.copy());
      tr.display("GEN"); 
      //@(drvnext); //cc
      @(sconext); 
      
    end
    
    ->done; 
    
  endtask
  
endclass




class driver;
  
  //transaction tr; 
  mailbox #(transaction) mbx; 
  virtual uart_if vif; 
  event drvnext; 
  
  bit [7:0] din;
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx; 
    
  endfunction
  
  task reset();
    
    vif.rst <= 1'b1;
    vif.tx_data <= 1'b0;
    vif.newd <= 1'b0;
    vif.rx <= 1'b1; 
    repeat(10) @(posedge vif.clk); 
    vif.rst <= 1'b0; 
    
    repeat(5)@(posedge vif.clk); 
    $display("[DRV] : RESET DONE"); 
    
  endtask
  
  
  task run();
    
    forever begin
      
      transaction tr; 
      
      mbx.get(tr);
      
      if(tr.oper == 1'b0)
        begin 
          @(posedge vif.uclk_tx);
          vif.rst <= 1'b0; 
          vif.tx_data <= tr.tx_data;
          vif.newd <= 1'b1;
          vif.rx <= 1'b1; 
          
          @(posedge vif.uclk_tx); 
          
          vif.newd <= 1'b0;
          tr.display("DRV");
          
          wait(vif.done_tx == 1'b1); 
          ->drvnext;  
          
        end 
    
      else if(tr.oper == 1'b1)
        begin 
          @(negedge vif.uclk_rx); 
          vif.rst <= 1'b0; 
          vif.newd <= 1'b0;
          vif.rx <= 1'b0; 
          
          @(negedge vif.uclk_rx); 
          for(int i =0; i<=7; i++)
            begin 
              vif.rx <= tr.tx_data[i]; 
              @(negedge vif.uclk_rx);  
          end 
          
          
          vif.rx <= 1'b1;
          
          @(negedge vif.uclk_rx);
          
          tr.display("DRV");
          wait(vif.done_rx == 1'b1);  
          vif.rx <= 1'b1;
          ->drvnext;  
          
          
        end 
      
    
      /*
       else if(tr.oper == 1'b1) begin 
         @(negedge vif.uclk_rx); 
         vif.rst <= 1'b0; 
         vif.newd <= 1'b0;
         
         // Start Bit
         vif.rx <= 1'b0;   
         
         // Data Bits
         @(negedge vif.uclk_rx); 
         for(int i =0; i<=7; i++) begin 
            vif.rx <= tr.tx_data[i]; 
            @(negedge vif.uclk_rx);  
         end 
         
         // FIX: Drive Stop Bit (High)
         vif.rx <= 1'b1; 
         
         // Wait one bit period for the Stop bit to stick
         @(negedge vif.uclk_rx); 
         
         tr.display("DRV");
         wait(vif.done_rx == 1'b1);
         ->drvnext;  
      end
      */
      
    end
    
  endtask
  
endclass


 
class monitor;
  
  transaction tr; 
  mailbox #(transaction) mbx; 
  virtual uart_if vif; 
  
  bit [7:0] srx;
  bit [7:0] rrx;
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx; 
    
  endfunction
  
  task run();
    
    forever begin
      
      tr = new();
      @(posedge vif.uclk_tx);      
      
      if ( (vif.newd== 1'b1) && (vif.rx == 1'b1) ) 
        begin 
          @(posedge vif.uclk_tx); 
          for(int i=0; i<=7; i++)
            begin 
              @(posedge vif.uclk_tx);
              
              srx[i] = vif.tx;
            end 
          
          tr.display("MON"); 
         // mbx.put(srx); 
          tr.tx_data = srx; 
          tr.oper = 1'b0;    
          tr.display("MON"); 
          mbx.put(tr);
          
        end 
        
      else if ((vif.rx == 1'b0) && (vif.newd == 1'b0) ) 
        begin
          wait(vif.done_rx == 1);
          rrx = vif.rx_data;     
          tr.display("MON");
          @(posedge vif.uclk_tx); 
         // mbx.put(rrx);
          tr.rx_data = rrx;
          tr.oper = 1'b1;    
          mbx.put(tr);
      end      
        
        
    end
    
  endtask


endclass

class scoreboard;

  transaction tr;
  transaction trref;
  mailbox #(transaction) mbx;    
  mailbox #(transaction) mbxref;  
  event sconext;
  
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    
    this.mbx = mbx;  
    this.mbxref = mbxref; 
    
  endfunction  
  
  task run();
    
    forever begin 
      
      mbx.get(tr);
      mbxref.get(trref);
      tr.display("SCO");
      trref.display("REF");
      
	if (tr.oper == 1'b0) begin // wr
        if (tr.tx_data == trref.tx_data)
           $display("[SCO] : TX DATA MATCHED");
        else
           $display("[SCO] : TX DATA MISMATCH (Exp: %0h, Got: %0h)", trref.tx_data, tr.tx_data);
      end 
      else begin // rd
        if (tr.rx_data == trref.tx_data)
           $display("[SCO] : RX DATA MATCHED");
        else
           $display("[SCO] : RX DATA MISMATCH (Exp: %0h, Got: %0h)", trref.tx_data, tr.rx_data);
      end
      
      $display("--------------------------------------------------");
      ->sconext;
    end 
      
  endtask 
    
endclass 

  
  
  
class environment;

  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgd;
  event nextgs;
  
  virtual uart_if vif;
  
  mailbox #(transaction) gdmbx;
  mailbox #(transaction) msmbx;
  mailbox #(transaction) mbxref;
  
  
  function new(virtual uart_if vif);
    
    gdmbx = new();
    msmbx = new();
    mbxref = new();
    
    gen = new(gdmbx, mbxref);
    drv = new(gdmbx);
    mon = new(msmbx);
    sco = new(msmbx, mbxref);

    this.vif = vif;
    
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
    
  endfunction 
  
  task pre_test();
    
    drv.reset();
    
  endtask 
  
  task test();
    
    fork 
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_none 
    
  endtask 
  
task post_test();
   wait(gen.done.triggered);
   
  // repeat(20) @(posedge vif.clk); 
   
   $finish();
endtask
  
  task run();
    
    pre_test();
    test();
    post_test();
    
  endtask 
  
endclass
 


  module tb();
  
  environment env;
  uart_if vif();
  

top #(1000000, 9600) dut
    (vif.clk, vif.rst, vif.rx, vif.newd, vif.tx_data, vif.tx, vif.done_tx, vif.done_rx, vif.rx_data);
  
initial begin 
    
    vif.clk = 0;
    vif.rst = 1;      
    vif.rx = 1;       
    vif.newd = 0;
    vif.tx_data = 0;
    
  end
  
  always #10 vif.clk <= ~vif.clk;
    
       
  assign vif.uclk_tx = dut.utx.uclk;
  assign vif.uclk_rx = dut.rtx.uclk;
    
  
  initial begin 
    
    env = new(vif);
    env.gen.count = 4;
    env.run();
    
  end 
  
  
  initial begin 
    
    $dumpfile("dump.vcd");
    $dumpvars;
    
  end 
  
endmodule 









