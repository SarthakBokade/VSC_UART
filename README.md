# VSC_UART
Design and Verification of UART protocol in SystemVerilog

This repository contains a complete UART (Universal Asynchronous Receiver–Transmitter) implementation written in SystemVerilog, along with a self-checking testbench and simulation results. The project focuses on understanding both RTL design and verification flow for a commonly used serial communication protocol.

UART Overview

UART is an asynchronous serial protocol that uses only two data lines:

TX – Transmit

RX – Receive

Each frame contains:Start Bit (0) → Data Bits (LSB first) → Stop Bit (1)

Design Features

Separate TX and RX modules

Baud-rate based bit sampling

Start and stop bit detection

Shift-register based data transfer

FSM-based control logic


Verification Approach

The testbench performs:

Clock and reset generation

Serial data stimulus on RX

Monitoring of TX output

Functional checking using simulation outputs

Correct operation is validated using:

Waveform analysis (UARTwaveform.png)

Console logs (UARTconsole.png)

How to Run Simulation

Using ModelSim / Questa or compatible simulators:

vlog DUT.sv TB.sv
vsim tb
run -all


Observe UART bit timing and data transfer in waveform window.
