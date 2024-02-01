-- Copyright 2018 Jonas Fuhrmann. All rights reserved.
--
-- This project is dual licensed under GNU General Public License version 3
-- and a commercial license available on request.
---------------------------------------------------------------------------
-- For non commercial use only:
-- This file is part of tinyTPU.
-- 
-- tinyTPU is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- tinyTPU is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with tinyTPU. If not, see <http://www.gnu.org/licenses/>.

--! @file WEIGHT_BUFFER.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes the weight buffer, a buffer used for neural net weights.
--! @details The buffer can store data from the master (host system). The stored data can then be used for matrix multiplies.

library xil_defaultlib;  use xil_defaultlib.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity WEIGHT_BUFFER is
    generic(
        MATRIX_WIDTH    : natural := 14;
        -- How many tiles can be saved
        TILE_WIDTH      : natural := 32768  --!< The depth of the buffer.
    );
    port(
        CLK, RESET      : in  std_logic;
        ENABLE          : in  std_logic;
        
        -- Port0
        ADDRESS0        : in  WEIGHT_ADDRESS_TYPE; --!< Address of port 0.
        EN0             : in  std_logic; --!< Enable of port 0.
        WRITE_EN0       : in  std_logic; --!< Write enable of port 0.
        WRITE_PORT0     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Write port of port 0.
        READ_PORT0      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Read port of port 0.
        -- Port1
        ADDRESS1        : in  WEIGHT_ADDRESS_TYPE; --!< Address of port 1.
        EN1             : in  std_logic; --!< Enable of port 1.
        WRITE_EN1       : in  std_logic_vector(0 to MATRIX_WIDTH-1); --!< Write enable of port 1.
        WRITE_PORT1     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Write port of port 1.
        READ_PORT1      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) --!< Read port of port 1.
    );
end entity WEIGHT_BUFFER;
 
--! @brief The architecture of the weight buffer component.
architecture BEH of WEIGHT_BUFFER is
    signal READ_PORT0_REG0_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT0_REG0_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal READ_PORT0_REG1_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT0_REG1_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal READ_PORT1_REG0_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT1_REG0_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal READ_PORT1_REG1_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT1_REG1_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);

    signal WRITE_PORT0_BITS : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    signal WRITE_PORT1_BITS : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    signal READ_PORT0_BITS  : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    signal READ_PORT1_BITS  : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);

    type RAM_TYPE is array(0 to TILE_WIDTH-1) of std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    shared variable RAM  : RAM_TYPE
    --synthesis translate_off
        :=
        -- Test values - Identity
        (
            BYTE_ARRAY_TO_BITS((x"60",x"d5",x"84",x"42",x"84",x"6a",x"39",x"d5",x"c6",x"93",x"31",x"fc",x"da",x"9b")),
            BYTE_ARRAY_TO_BITS((x"d2",x"da",x"a7",x"1e",x"8d",x"00",x"d0",x"3f",x"b9",x"c0",x"f7",x"a3",x"41",x"19")),
            BYTE_ARRAY_TO_BITS((x"d6",x"d0",x"a3",x"28",x"9d",x"0e",x"40",x"76",x"9f",x"10",x"b6",x"e3",x"4b",x"48")),
            BYTE_ARRAY_TO_BITS((x"21",x"a1",x"21",x"86",x"15",x"7e",x"1a",x"d7",x"f0",x"f5",x"54",x"aa",x"92",x"4b")),
            BYTE_ARRAY_TO_BITS((x"b2",x"64",x"b6",x"1e",x"9b",x"93",x"ec",x"a0",x"2f",x"d5",x"76",x"b3",x"c7",x"9d")),
            BYTE_ARRAY_TO_BITS((x"8e",x"9d",x"41",x"37",x"fb",x"8d",x"fc",x"f1",x"f8",x"eb",x"17",x"a2",x"3c",x"ea")),
            BYTE_ARRAY_TO_BITS((x"4c",x"1f",x"a4",x"a4",x"56",x"4c",x"a0",x"56",x"23",x"93",x"7b",x"b7",x"be",x"73")),
            BYTE_ARRAY_TO_BITS((x"7a",x"2a",x"d5",x"e6",x"54",x"36",x"17",x"51",x"80",x"f1",x"00",x"90",x"ce",x"af")),
            BYTE_ARRAY_TO_BITS((x"78",x"ec",x"fd",x"c2",x"30",x"f2",x"ab",x"26",x"29",x"90",x"e4",x"8d",x"3a",x"96")),
            BYTE_ARRAY_TO_BITS((x"c3",x"82",x"1f",x"2a",x"d5",x"a0",x"27",x"1f",x"43",x"97",x"d2",x"46",x"e5",x"45")),
            BYTE_ARRAY_TO_BITS((x"db",x"96",x"b6",x"11",x"b1",x"e7",x"90",x"44",x"09",x"c5",x"72",x"b1",x"65",x"59")),
            BYTE_ARRAY_TO_BITS((x"6e",x"ca",x"8f",x"ab",x"bb",x"e1",x"c3",x"f9",x"d0",x"88",x"ab",x"3d",x"f8",x"64")),
            BYTE_ARRAY_TO_BITS((x"8d",x"4b",x"69",x"e5",x"f0",x"26",x"68",x"da",x"85",x"2c",x"81",x"11",x"af",x"15")),
            BYTE_ARRAY_TO_BITS((x"03",x"4b",x"07",x"bd",x"65",x"a6",x"69",x"bf",x"14",x"a7",x"25",x"3e",x"d7",x"d2")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"F1", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")), 
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01", x"01")),
            BYTE_ARRAY_TO_BITS((x"80", x"10", x"00", x"00", x"70", x"00", x"00", x"00", x"10", x"00", x"00", x"20", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"70", x"80", x"60", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"30", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"10", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"50", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"70", x"00", x"00", x"40", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"20", x"60", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"30", x"00", x"30", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"50", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"40", x"50", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"30", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80")),
            BYTE_ARRAY_TO_BITS((x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90")),
            BYTE_ARRAY_TO_BITS((x"80", x"10", x"00", x"00", x"70", x"00", x"00", x"00", x"10", x"00", x"00", x"20", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"70", x"80", x"60", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"30", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"10", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"50", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"70", x"00", x"00", x"40", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"20", x"60", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"30", x"00", x"30", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"50", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"40", x"50", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"30", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80")),
            BYTE_ARRAY_TO_BITS((x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90")),
            BYTE_ARRAY_TO_BITS((x"80", x"10", x"00", x"00", x"70", x"00", x"00", x"00", x"10", x"00", x"00", x"20", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"70", x"80", x"60", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"30", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"10", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"50", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"70", x"00", x"00", x"40", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"20", x"60", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"30", x"00", x"30", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"50", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"40", x"50", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"30", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80")),
            BYTE_ARRAY_TO_BITS((x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"90")),
            others => (others => '0')
        )
    --synthesis translate_on
    ;
    
    attribute ram_style        : string;
    attribute ram_style of RAM : variable is "block";
begin
    WRITE_PORT0_BITS    <= BYTE_ARRAY_TO_BITS(WRITE_PORT0);
    WRITE_PORT1_BITS    <= BYTE_ARRAY_TO_BITS(WRITE_PORT1);
    
    READ_PORT0_REG0_ns  <= BITS_TO_BYTE_ARRAY(READ_PORT0_BITS);
    READ_PORT1_REG0_ns  <= BITS_TO_BYTE_ARRAY(READ_PORT1_BITS);
    READ_PORT0_REG1_ns  <= READ_PORT0_REG0_cs;
    READ_PORT1_REG1_ns  <= READ_PORT1_REG0_cs;
    READ_PORT0          <= READ_PORT0_REG1_cs;
    READ_PORT1          <= READ_PORT1_REG1_cs;

    PORT0:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if EN0 = '1' then
                --synthesis translate_off
                if to_integer(unsigned(ADDRESS0)) < TILE_WIDTH then
                --synthesis translate_on
                    if WRITE_EN0 = '1' then
                        RAM(to_integer(unsigned(ADDRESS0))) := WRITE_PORT0_BITS;
                    end if;
                    READ_PORT0_BITS <= RAM(to_integer(unsigned(ADDRESS0)));
                --synthesis translate_off
                end if;
                --synthesis translate_on
            end if;
        end if;
    end process PORT0;
    
    PORT1:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if EN1 = '1' then
                --synthesis translate_off
                if to_integer(unsigned(ADDRESS1)) < TILE_WIDTH then
                --synthesis translate_on
                    for i in 0 to MATRIX_WIDTH-1 loop
                        if WRITE_EN1(i) = '1' then
                            RAM(to_integer(unsigned(ADDRESS1)))((i + 1) * BYTE_WIDTH - 1 downto i * BYTE_WIDTH) := WRITE_PORT1_BITS((i + 1) * BYTE_WIDTH - 1 downto i * BYTE_WIDTH);
                        end if;
                    end loop;
                    READ_PORT1_BITS <= RAM(to_integer(unsigned(ADDRESS1)));
                --synthesis translate_off
                end if;
                --synthesis translate_on
            end if;
        end if;
    end process PORT1;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                READ_PORT0_REG0_cs <= (others => (others => '0'));
                READ_PORT0_REG1_cs <= (others => (others => '0'));
                READ_PORT1_REG0_cs <= (others => (others => '0'));
                READ_PORT1_REG1_cs <= (others => (others => '0'));
            else
                if ENABLE = '1' then
                    READ_PORT0_REG0_cs <= READ_PORT0_REG0_ns;
                    READ_PORT0_REG1_cs <= READ_PORT0_REG1_ns;
                    READ_PORT1_REG0_cs <= READ_PORT1_REG0_ns;
                    READ_PORT1_REG1_cs <= READ_PORT1_REG1_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;