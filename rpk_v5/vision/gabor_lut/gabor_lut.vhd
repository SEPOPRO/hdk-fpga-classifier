-- gabor_lut.vhd
-- Filtros Gabor 5×5, 8 orientaciones, cuantizados a 1 bit
-- Generado por gabor_lut_gen.py
-- Kernel: 5×5, 8 orientaciones
-- Sigma={SIGMA}, Lambda={LAMBDA}, Gamma={GAMMA}

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gabor_lut is
    Port (
        clk        : in  STD_LOGIC;
        pixel_row  : in  STD_LOGIC_VECTOR(4 downto 0);  -- 0-24
        pixel_col  : in  STD_LOGIC_VECTOR(4 downto 0);  -- 0-24
        orient     : in  STD_LOGIC_VECTOR(2 downto 0);  -- 0-7
        gabor_out  : out STD_LOGIC  -- 1 bit
    );
end gabor_lut;

architecture Behavioral of gabor_lut is
    type lut_array is array (0 to 24, 0 to 7) of STD_LOGIC;
    signal lut : lut_array := (
        "0","0","0","0","0","0","1","0",  -- pixel 0
        "1","0","0","0","0","0","1","1",  -- pixel 1
        "1","1","0","0","0","0","0","1",  -- pixel 2
        "1","1","1","0","0","0","0","0",  -- pixel 3
        "0","0","1","0","0","0","0","0",  -- pixel 4
        "0","0","0","0","0","1","1","0",  -- pixel 5
        "1","0","0","0","1","1","1","1",  -- pixel 6
        "1","1","1","1","1","1","1","1",  -- pixel 7
        "1","1","1","1","1","0","0","0",  -- pixel 8
        "0","0","1","1","1","0","0","0",  -- pixel 9
        "0","0","0","1","1","1","0","0",  -- pixel 10
        "1","1","1","1","1","1","1","1",  -- pixel 11
        "1","1","1","1","1","1","1","1",  -- pixel 12
        "1","1","1","1","1","1","1","1",  -- pixel 13
        "0","0","0","1","1","1","0","0",  -- pixel 14
        "0","0","1","1","1","0","0","0",  -- pixel 15
        "1","1","1","1","1","0","0","0",  -- pixel 16
        "1","1","1","1","1","1","1","1",  -- pixel 17
        "1","0","0","0","1","1","1","1",  -- pixel 18
        "0","0","0","0","0","1","1","0",  -- pixel 19
        "0","0","1","0","0","0","0","0",  -- pixel 20
        "1","1","1","0","0","0","0","0",  -- pixel 21
        "1","1","0","0","0","0","0","1",  -- pixel 22
        "1","0","0","0","0","0","1","1",  -- pixel 23
        "0","0","0","0","0","0","1","0"   -- pixel 24
    );
begin
    process(clk)
        variable row_idx : integer range 0 to 24;
        variable col_idx : integer range 0 to 24;
        variable addr    : integer range 0 to 24;
    begin
        if rising_edge(clk) then
            row_idx := to_integer(unsigned(pixel_row));
            col_idx := to_integer(unsigned(pixel_col));
            addr := row_idx * 5 + col_idx;
            gabor_out <= lut(addr, to_integer(unsigned(orient)));
        end if;
    end process;
end Behavioral;
