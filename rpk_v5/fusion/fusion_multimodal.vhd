-------------------------------------------------------------------------------
-- fusion_multimodal.vhd — Fusión ponderada de modalidades
-- Texto (20 clases) + Visión (10 clases) + Audio (clases) → Decisión final
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fusion_multimodal is
    Port (
        clk           : in  STD_LOGIC;
        rst_n         : in  STD_LOGIC;
        
        -- Entradas de texto
        txt_class     : in  STD_LOGIC_VECTOR(4 downto 0);
        txt_conf      : in  STD_LOGIC_VECTOR(15 downto 0);
        txt_valid     : in  STD_LOGIC;
        
        -- Entradas de visión
        vis_class     : in  STD_LOGIC_VECTOR(3 downto 0);
        vis_conf      : in  STD_LOGIC_VECTOR(15 downto 0);
        vis_valid     : in  STD_LOGIC;
        
        -- Entradas de audio
        aud_class     : in  STD_LOGIC_VECTOR(3 downto 0);
        aud_conf      : in  STD_LOGIC_VECTOR(15 downto 0);
        aud_valid     : in  STD_LOGIC;
        
        -- Salida fusionada
        final_class   : out STD_LOGIC_VECTOR(4 downto 0);
        final_conf    : out STD_LOGIC_VECTOR(15 downto 0);
        final_valid   : out STD_LOGIC;
        
        -- Pesos programables (desde host vía UART)
        weight_text   : in  STD_LOGIC_VECTOR(7 downto 0);  -- peso texto (0-255)
        weight_vision : in  STD_LOGIC_VECTOR(7 downto 0);  -- peso visión
        weight_audio  : in  STD_LOGIC_VECTOR(7 downto 0)   -- peso audio
    );
end fusion_multimodal;

architecture Behavioral of fusion_multimodal is
    type state_type is (IDLE, FUSE, RESULT);
    signal state : state_type := IDLE;
    
    signal scores   : array (0 to 19) of integer range 0 to 255*3;
    signal best_idx : integer range 0 to 19 := 0;
    signal best_val : integer range 0 to 255*3 := 0;
begin

    process(clk)
        variable idx : integer;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                final_valid <= '0';
            else
                case state is
                    when IDLE =>
                        final_valid <= '0';
                        -- Esperar todas las modalidades
                        if txt_valid = '1' and vis_valid = '1' and aud_valid = '1' then
                            state <= FUSE;
                        end if;
                    
                    when FUSE =>
                        -- Fusión ponderada: score = w_t * conf_t + w_v * conf_v + w_a * conf_a
                        -- Por simplicidad, usamos la clase con mayor confianza ponderada
                        -- En versión completa: mapear clases y sumar scores
                        idx := to_integer(unsigned(txt_class));
                        scores(idx) <= scores(idx) + to_integer(unsigned(txt_conf(7 downto 0))) * to_integer(unsigned(weight_text));
                        idx := to_integer(unsigned(vis_class));
                        scores(idx) <= scores(idx) + to_integer(unsigned(vis_conf(7 downto 0))) * to_integer(unsigned(weight_vision));
                        idx := to_integer(unsigned(aud_class));
                        scores(idx) <= scores(idx) + to_integer(unsigned(aud_conf(7 downto 0))) * to_integer(unsigned(weight_audio));
                        state <= RESULT;
                    
                    when RESULT =>
                        -- Argmax sobre scores
                        best_val <= scores(0);
                        best_idx <= 0;
                        for i in 1 to 19 loop
                            if scores(i) > best_val then
                                best_val <= scores(i);
                                best_idx <= i;
                            end if;
                        end loop;
                        final_class <= STD_LOGIC_VECTOR(to_unsigned(best_idx, 5));
                        final_conf  <= STD_LOGIC_VECTOR(to_unsigned(best_val, 16));
                        final_valid <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
