----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 13.04.2023 18:53:49
-- Design Name: 
-- Module Name: DSP_SIMD - Behavioral
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity dsp_simd is generic
                     (
                      W : integer := 12   -- Width of Adders
                     );
                port (
                      a0,b0 : in std_logic_vector(W-1 downto 0); 
                      a1,b1 : in std_logic_vector(W-1 downto 0); 
                      a2,b2 : in std_logic_vector(W-1 downto 0); 
                      a3,b3 : in std_logic_vector(W-1 downto 0); 
                      out0  : out std_logic_vector(W-1 downto 0); 
                      out1  : out std_logic_vector(W-1 downto 0); 
                      out2  : out std_logic_vector(W-1 downto 0); 
                      out3  : out std_logic_vector(W-1 downto 0)
                   );
end dsp_simd;
architecture BEH of dsp_simd is

attribute use_dsp : string;
attribute use_dsp of BEH : architecture is "simd";


begin

    out0 <= std_logic_vector(unsigned(a0) + unsigned(b0));
    out1 <= std_logic_vector(unsigned(a1) + unsigned(b1));
    out2 <= std_logic_vector(unsigned(a2) + unsigned(b2));
    out3 <= std_logic_vector(unsigned(a3) + unsigned(b3));

end BEH;
