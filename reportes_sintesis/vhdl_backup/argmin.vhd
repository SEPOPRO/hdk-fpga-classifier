-------------------------------------------------------------------------------
-- argmin.vhd — Find minimum value in an array
--
-- Sequential comparator: scans all N values in N clock cycles.
-- Returns the index of the minimum value.
--
-- For N=20 classes, latency = 20 cycles @100 MHz = 200 ns
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity argmin is
    Generic (
        N_VALUES     : integer := 20;
        VALUE_WIDTH  : integer := 15;
        INDEX_WIDTH  : integer := 5
    );
    Port (
        clk         : in  STD_LOGIC;
        rst_n       : in  STD_LOGIC;
        en          : in  STD_LOGIC;
        values      : in  STD_LOGIC_VECTOR(N_VALUES * VALUE_WIDTH - 1 downto 0);
        min_index   : out STD_LOGIC_VECTOR(INDEX_WIDTH-1 downto 0);
        min_value   : out STD_LOGIC_VECTOR(VALUE_WIDTH-1 downto 0);
        done        : out STD_LOGIC
    );
end argmin;

architecture Behavioral of argmin is
    type state_type is (IDLE, SCAN, DONE_ST);
    signal state      : state_type := IDLE;
    signal idx        : integer range 0 to N_VALUES-1 := 0;
    signal best_idx   : integer range 0 to N_VALUES-1 := 0;
    signal best_val   : unsigned(VALUE_WIDTH-1 downto 0) := (others => '1');
    signal current_val: unsigned(VALUE_WIDTH-1 downto 0);
begin

    -- Extract current value from flattened input array
    current_val <= unsigned(values((idx+1) * VALUE_WIDTH - 1 downto idx * VALUE_WIDTH));

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                done <= '0';
                min_index <= (others => '0');
                min_value <= (others => '0');
                idx <= 0;
                best_idx <= 0;
                best_val <= (others => '1');
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if en = '1' then
                            state <= SCAN;
                            idx <= 0;
                            best_idx <= 0;
                            best_val <= unsigned(values(VALUE_WIDTH-1 downto 0));
                        end if;

                    when SCAN =>
                        if idx < N_VALUES - 1 then
                            idx <= idx + 1;
                            if current_val < best_val then
                                best_val <= current_val;
                                best_idx <= idx;
                            end if;
                        else
                            -- Final comparison for last element
                            if current_val < best_val then
                                best_val <= current_val;
                                best_idx <= idx;
                            end if;
                            state <= DONE_ST;
                        end if;

                    when DONE_ST =>
                        min_index <= STD_LOGIC_VECTOR(to_unsigned(best_idx, INDEX_WIDTH));
                        min_value <= STD_LOGIC_VECTOR(best_val);
                        done <= '1';
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
