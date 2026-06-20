-- tb_gabor_lut.vhd
-- Testbench para el módulo de filtros Gabor LUT
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_gabor_lut is
end tb_gabor_lut;

architecture Behavioral of tb_gabor_lut is
    signal clk       : STD_LOGIC := '0';
    signal pixel_row : STD_LOGIC_VECTOR(4 downto 0) := (others => '0');
    signal pixel_col : STD_LOGIC_VECTOR(4 downto 0) := (others => '0');
    signal orient    : STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
    signal gabor_out : STD_LOGIC;
    
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    
    component gabor_lut is
        Port (
            clk        : in  STD_LOGIC;
            pixel_row  : in  STD_LOGIC_VECTOR(4 downto 0);
            pixel_col  : in  STD_LOGIC_VECTOR(4 downto 0);
            orient     : in  STD_LOGIC_VECTOR(2 downto 0);
            gabor_out  : out STD_LOGIC
        );
    end component;

begin
    UUT: gabor_lut port map (
        clk => clk, pixel_row => pixel_row,
        pixel_col => pixel_col, orient => orient,
        gabor_out => gabor_out
    );

    -- Clock process
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Stimulus
    stim_proc: process
    begin
        -- Test 1: Centro del kernel, orientación 0
        pixel_row <= "01100";  -- 12
        pixel_col <= "01100";  -- 12
        orient <= "000";       -- 0°
        wait for CLK_PERIOD;
        assert gabor_out = '0' or gabor_out = '1'
            report "Test 1 FAILED: gabor_out no es binario"
            severity ERROR;
        
        -- Test 2: Esquina, orientación 45°
        pixel_row <= "00000";  -- 0
        pixel_col <= "00000";  -- 0
        orient <= "010";       -- 45°
        wait for CLK_PERIOD;
        
        -- Test 3: Borde, orientación 90°
        pixel_row <= "00010";  -- 2
        pixel_col <= "01100";  -- 12
        orient <= "100";       -- 90°
        wait for CLK_PERIOD;
        
        -- Test 4: Todas las orientaciones para un píxel
        pixel_row <= "01100";
        pixel_col <= "01100";
        for o in 0 to 7 loop
            orient <= std_logic_vector(to_unsigned(o, 3));
            wait for CLK_PERIOD;
        end loop;
        
        -- Test 5: Todos los píxeles, orientación 0
        orient <= "000";
        for r in 0 to 4 loop
            for c in 0 to 4 loop
                pixel_row <= std_logic_vector(to_unsigned(r, 5));
                pixel_col <= std_logic_vector(to_unsigned(c, 5));
                wait for CLK_PERIOD;
            end loop;
        end loop;
        
        report "Testbench COMPLETED";
        wait;
    end process;
end Behavioral;
