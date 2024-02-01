----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.04.2023 14:40:30
-- Design Name: 
-- Module Name: ERROR_DETECTION_LOGIC - BEH
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library xil_defaultlib;  use xil_defaultlib.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;


entity ERROR_DETECTION_LOGIC is
    port ( 
        CLK         : in std_logic;
        RESET       : in std_logic;
        MMU_INPUT0  : in WORD_TYPE;
        MMU_INPUT1  : in WORD_TYPE;
        MMU_INPUT2  : in WORD_TYPE;
        ACC_INPUT0  : in WORD_TYPE;
        ACC_INPUT1  : in WORD_TYPE;
        CHECK_MMU   : in std_logic;
        ERROR       : out std_logic 
    );
end ERROR_DETECTION_LOGIC;

architecture BEH of ERROR_DETECTION_LOGIC is

signal ERROR_MMU_cs : std_logic := '0';
signal ERROR_MMU_ns : std_logic;

signal ERROR_ACC_ns : std_logic;

begin

ERROR <= ERROR_ACC_ns or ERROR_MMU_cs;

ERROR_MMU_DETECTION:
process(MMU_INPUT0, MMU_INPUT1, MMU_INPUT2) is
begin 
    if or(MMU_INPUT0 xnor MMU_INPUT1) or (or MMU_INPUT2) then 
        ERROR_MMU_ns <= '1';
    else
        ERROR_MMU_ns <= '0';
    end if;    
end process;

ERROR_ACC_DETECTION:
process(ACC_INPUT0 , ACC_INPUT1) is
begin 
    if (or(ACC_INPUT0 xnor ACC_INPUT1)) or (or ACC_INPUT0) then 
        ERROR_ACC_ns <= '1';
    else
        ERROR_ACC_ns <= '0';
    end if;    
end process;

SEQ_LOG:
process(CLK) is
begin
    if CLK'event and CLK = '1' then
        if RESET = '1' then 
            ERROR_MMU_cs <= '0';
        else
            if CHECK_MMU = '1' then 
                ERROR_MMU_cs <= ERROR_MMU_ns;
            end if;
        end if;
    end if;
end process;
end BEH;
