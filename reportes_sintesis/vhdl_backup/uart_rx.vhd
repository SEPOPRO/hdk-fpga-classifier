-------------------------------------------------------------------------------
-- uart_rx.vhd — UART Receiver (8N1)
-- Generic baud rate via BAUD_TICK_COUNT
-- Oversampling: 16x for midpoint sampling
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    Generic (BAUD_TICK_COUNT : integer := 10);   -- 10 Mbaud (100MHz / 10)
    Port (
        clk         : in  STD_LOGIC;
        rst_n       : in  STD_LOGIC;
        rx          : in  STD_LOGIC;
        data        : out STD_LOGIC_VECTOR(7 downto 0);
        data_valid  : out STD_LOGIC;
        framing_error : out STD_LOGIC
    );
end uart_rx;

architecture Behavioral of uart_rx is
    type state_type is (IDLE, START, DATA, STOP);
    signal state      : state_type := IDLE;
    signal tick_count : integer range 0 to BAUD_TICK_COUNT-1 := 0;
    signal bit_count  : integer range 0 to 7 := 0;
    signal shift_reg  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal rx_sync    : STD_LOGIC_VECTOR(2 downto 0) := (others => '1');
    signal rx_filtered: STD_LOGIC;
    signal sample_tick: STD_LOGIC := '0';
    signal half_tick  : integer range 0 to BAUD_TICK_COUNT-1;
begin

    half_tick <= BAUD_TICK_COUNT / 2;

    -- Synchronizer + glitch filter (3-stage)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                rx_sync <= (others => '1');
            else
                rx_sync <= rx_sync(1 downto 0) & rx;
            end if;
        end if;
    end process;
    
    -- Majority voting for glitch rejection
    rx_filtered <= (rx_sync(0) and rx_sync(1)) or 
                   (rx_sync(0) and rx_sync(2)) or 
                   (rx_sync(1) and rx_sync(2));

    -- Baud rate generator (16x oversampling)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                tick_count <= 0;
                sample_tick <= '0';
            else
                sample_tick <= '0';
                if state = IDLE then
                    tick_count <= 0;
                else
                    if tick_count = BAUD_TICK_COUNT - 1 then
                        tick_count <= 0;
                        sample_tick <= '1';
                    else
                        tick_count <= tick_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- UART FSM
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                data_valid <= '0';
                framing_error <= '0';
                bit_count <= 0;
                shift_reg <= (others => '0');
                data <= (others => '0');
            else
                data_valid <= '0';
                framing_error <= '0';

                case state is
                    when IDLE =>
                        if rx_filtered = '0' then
                            state <= START;
                            tick_count <= 0;
                        end if;

                    when START =>
                        -- Sample at midpoint of start bit
                        if sample_tick = '1' then
                            if rx_filtered = '0' then
                                state <= DATA;
                                bit_count <= 0;
                                tick_count <= 0;
                            else
                                state <= IDLE;  -- False start
                            end if;
                        end if;

                    when DATA =>
                        if sample_tick = '1' then
                            shift_reg <= rx_filtered & shift_reg(7 downto 1);
                            if bit_count = 7 then
                                state <= STOP;
                                tick_count <= 0;
                            else
                                bit_count <= bit_count + 1;
                            end if;
                        end if;

                    when STOP =>
                        if sample_tick = '1' then
                            data <= shift_reg;
                            data_valid <= '1';
                            if rx_filtered = '1' then
                                framing_error <= '0';
                            else
                                framing_error <= '1';  -- Missing stop bit
                            end if;
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
