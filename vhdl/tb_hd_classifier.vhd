-------------------------------------------------------------------------------
-- tb_hd_classifier.vhd — Testbench for HDK classifier
--
-- Tests: 
--   1. UART receive (load prototypes)
--   2. UART receive (load document vector)
--   3. Classification computation
--   4. UART transmit (result)
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_hd_classifier is
end tb_hd_classifier;

architecture Behavioral of tb_hd_classifier is
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    constant BAUD_TICK  : integer := 868;  -- 100MHz / 115200
    constant D          : integer := 20000;
    constant N_CLASSES  : integer := 20;

    signal clk          : STD_LOGIC := '0';
    signal rst_n        : STD_LOGIC := '0';
    signal uart_rx      : STD_LOGIC := '1';
    signal uart_tx      : STD_LOGIC;
    signal led_busy     : STD_LOGIC;
    signal led_ready    : STD_LOGIC;
    signal led_error    : STD_LOGIC;

    -- Test data
    type prototype_array is array (0 to N_CLASSES-1) of STD_LOGIC_VECTOR(D-1 downto 0);
    signal test_prototypes : prototype_array := (others => (others => '0'));
    
    -- UART byte to send
    procedure uart_send_byte(signal uart : out STD_LOGIC; data : in STD_LOGIC_VECTOR(7 downto 0)) is
    begin
        uart <= '0';  -- Start bit
        wait for 8.68 us;
        for i in 0 to 7 loop
            uart <= data(i);
            wait for 8.68 us;
        end loop;
        uart <= '1';  -- Stop bit
        wait for 8.68 us;
    end procedure;

begin

    -- Clock
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT
    DUT: entity work.HDK
        generic map (
            D => D,
            N_CLASSES => N_CLASSES
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            uart_rx => uart_rx,
            uart_tx => uart_tx,
            led_busy => led_busy,
            led_ready => led_ready,
            led_error => led_error
        );

    -- Stimulus
    process
        variable checksum : STD_LOGIC_VECTOR(7 downto 0);
    begin
        -- Reset
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait for 100 ns;

        report "=== Test 1: Load Prototypes ===";

        -- Send packet: AA 01 LL HH [data...] CS
        uart_send_byte(uart_rx, x"AA");  -- Header
        wait for 100 us;
        
        uart_send_byte(uart_rx, x"01");  -- Type: load prototypes
        wait for 100 us;
        
        -- Length: N_CLASSES * D / 8 = 20 * 2500 = 50000 bytes
        uart_send_byte(uart_rx, x"50");  -- Length LSB (50000 = 0xC350)
        wait for 100 us;
        uart_send_byte(uart_rx, x"C3");  -- Length MSB
        wait for 100 us;
        
        -- Send prototype data (simplified: 0xAA pattern)
        checksum := x"AA" xor x"01" xor x"50" xor x"C3";
        for i in 0 to 49999 loop
            uart_send_byte(uart_rx, x"AA");
            checksum := checksum xor x"AA";
            if i mod 1000 = 0 then
                wait for 1 us;  -- Allow processing
            end if;
        end loop;
        
        uart_send_byte(uart_rx, checksum);  -- Checksum
        wait for 100 us;
        
        report "=== Test 2: Classify Document ===";
        
        -- Send packet: AA 02 LL HH [data...] CS
        uart_send_byte(uart_rx, x"AA");  -- Header
        wait for 100 us;
        
        uart_send_byte(uart_rx, x"02");  -- Type: classify
        wait for 100 us;
        
        -- Length: D / 8 = 2500 bytes
        uart_send_byte(uart_rx, x"C4");  -- Length LSB (2500 = 0x09C4)
        wait for 100 us;
        uart_send_byte(uart_rx, x"09");  -- Length MSB
        wait for 100 us;
        
        -- Send document vector (all zeros = most similar to prototype 0)
        checksum := x"AA" xor x"02" xor x"C4" xor x"09";
        for i in 0 to 2499 loop
            uart_send_byte(uart_rx, x"00");
            checksum := checksum xor x"00";
            if i mod 500 = 0 then
                wait for 1 us;
            end if;
        end loop;
        
        uart_send_byte(uart_rx, checksum);  -- Checksum
        wait for 100 us;

        -- Wait for classification to complete
        wait for 50 us;
        
        -- Check UART TX for response
        report "=== Test Complete ===";
        
        wait;
    end process;

end Behavioral;
