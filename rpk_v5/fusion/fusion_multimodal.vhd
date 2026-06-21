-------------------------------------------------------------------------------
-- fusion_multimodal.vhd — Fusión ponderada de modalidades
-- Texto (20 clases) + Visión (10 clases) + Audio → Decisión final
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fusion_multimodal is
    Port (
        clk           : in  STD_LOGIC;
        rst_n         : in  STD_LOGIC;
        txt_class     : in  STD_LOGIC_VECTOR(4 downto 0);
        txt_conf      : in  STD_LOGIC_VECTOR(15 downto 0);
        txt_valid     : in  STD_LOGIC;
        vis_class     : in  STD_LOGIC_VECTOR(3 downto 0);
        vis_conf      : in  STD_LOGIC_VECTOR(15 downto 0);
        vis_valid     : in  STD_LOGIC;
        aud_class     : in  STD_LOGIC_VECTOR(3 downto 0);
        aud_conf      : in  STD_LOGIC_VECTOR(15 downto 0);
        aud_valid     : in  STD_LOGIC;
        final_class   : out STD_LOGIC_VECTOR(4 downto 0);
        final_conf    : out STD_LOGIC_VECTOR(15 downto 0);
        final_valid   : out STD_LOGIC;
        weight_text   : in  STD_LOGIC_VECTOR(7 downto 0);
        weight_vision : in  STD_LOGIC_VECTOR(7 downto 0);
        weight_audio  : in  STD_LOGIC_VECTOR(7 downto 0)
    );
end fusion_multimodal;

architecture Behavioral of fusion_multimodal is
    type state_type is (IDLE, FUSE, RESULT);
    signal state : state_type := IDLE;
    constant MAX_SCORE : integer := 255 * 3;
    
    -- Array de scores como tipo propio (VHDL-2008 compatible con read_vhdl -vhdl2008)
    type score_array is array (0 to 19) of integer range 0 to MAX_SCORE;
    signal scores   : score_array := (others => 0);
    signal best_idx : integer range 0 to 19 := 0;
    signal best_val : integer range 0 to MAX_SCORE := 0;
begin

    process(clk)
        variable idx : integer;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                final_valid <= '0';
                scores <= (others => 0);
                best_idx <= 0;
                best_val <= 0;
            else
                case state is
                    when IDLE =>
                        final_valid <= '0';
                        if txt_valid = '1' and vis_valid = '1' and aud_valid = '1' then
                            scores <= (others => 0);
                            state <= FUSE;
                        end if;

                    when FUSE =>
                        idx := to_integer(unsigned(txt_class));
                        scores(idx) <= scores(idx) + to_integer(unsigned(txt_conf(7 downto 0))) * to_integer(unsigned(weight_text));
                        idx := to_integer(unsigned(vis_class));
                        scores(idx) <= scores(idx) + to_integer(unsigned(vis_conf(7 downto 0))) * to_integer(unsigned(weight_vision));
                        idx := to_integer(unsigned(aud_class));
                        scores(idx) <= scores(idx) + to_integer(unsigned(aud_conf(7 downto 0))) * to_integer(unsigned(weight_audio));
                        state <= RESULT;

                    when RESULT =>
                        best_val <= scores(0);
                        best_idx <= 0;
                        for i in 1 to 19 loop
                            if scores(i) > best_val then
                                best_val <= scores(i);
                                best_idx <= i;
                            end if;
                        end loop;
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

    final_class <= STD_LOGIC_VECTOR(to_unsigned(best_idx, 5));
    final_conf  <= STD_LOGIC_VECTOR(to_unsigned(best_val, 16));
    final_valid <= '1' when state = RESULT else '0';

end Behavioral;
