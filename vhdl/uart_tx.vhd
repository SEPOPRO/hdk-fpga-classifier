-------------------------------------------------------------------------------
-- uart_tx.vhd — UART Transmitter (8N1)
-- Generic baud rate via BAUD_TICK_COUNT
-- Simple shift-register implementation
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    Generic (BAUD_TICK_COUNT : integer := 868);
    Port (
        clk     : in  STD_LOGIC;
        rst_n   : in  STD_LOGIC;
        data    : in  STD_LOGIC_VECTOR(7 downto 0);
        start   : in  STD_LOGIC;
        busy    : out STD_LOGIC;
        tx      : out STD_LOGIC
    );
end uart_tx;

architecture Behavioral of uart_tx is
    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state      : state_type := IDLE;
    signal tick_count : integer range 0 to BAUD_TICK_COUNT-1 := 0;
    signal bit_count  : integer range 0 to 7 := 0;
    signal shift_reg  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal tx_reg     : STD_LOGIC := '1';
begin

    tx <= tx_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                busy <= '0';
                tx_reg <= '1';
                tick_count <= 0;
                bit_count <= 0;
            else
                case state is
                    when IDLE =>
                        busy <= '0';
                        tx_reg <= '1';
                        if start = '1' then
                            shift_reg <= data;
                            state <= START_BIT;
                            busy <= '1';
                            tick_count <= 0;
                        end if;

                    when START_BIT =>
                        tx_reg <= '0';  -- Start bit (low)
                        if tick_count = BAUD_TICK_COUNT - 1 then
                            tick_count <= 0;
                            bit_count <= 0;
                            state <= DATA_BITS;
                        else
                            tick_count <= tick_count + 1;
                        end if;

                    when DATA_BITS =>
                        tx_reg <= shift_reg(0);  -- LSB first
                        if tick_count = BAUD_TICK_COUNT - 1 then
                            tick_count <= 0;
                            shift_reg <= '0' & shift_reg(7 downto 1);
                            if bit_count = 7 then
                                state <= STOP_BIT;
                            else
                                bit_count <= bit_count + 1;
                            end if;
                        else
                            tick_count <= tick_count + 1;
                        end if;

                    when STOP_BIT =>
                        tx_reg <= '1';  -- Stop bit (high)
                        if tick_count = BAUD_TICK_COUNT - 1 then
                            tick_count <= 0;
                            state <= IDLE;
                            busy <= '0';
                        else
                            tick_count <= tick_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
