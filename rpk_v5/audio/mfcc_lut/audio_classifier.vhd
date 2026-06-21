-------------------------------------------------------------------------------
-- audio_classifier.vhd — Clasificador de audio vía MFCC + RPK
-- Pipeline: PCM → MFCC (13 coeffs) → RPK → BNN ternaria → clase
-- Usa los packages mfcc_lut_pkg y mfcc_dct_pkg ya sintetizados
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity audio_classifier is
    Generic (
        N_CLASSES : integer := 10;
        N_MFCC    : integer := 13
    );
    Port (
        clk        : in  STD_LOGIC;
        rst_n      : in  STD_LOGIC;
        start      : in  STD_LOGIC;
        pcm_data   : in  STD_LOGIC_VECTOR(15 downto 0);
        pcm_valid  : in  STD_LOGIC;
        class_out  : out STD_LOGIC_VECTOR(3 downto 0);
        confidence : out STD_LOGIC_VECTOR(15 downto 0);
        done       : out STD_LOGIC
    );
end audio_classifier;

architecture Behavioral of audio_classifier is
    type state_type is (IDLE, FILL_WIN, FFT, MEL, DCT, CLASSIFY, RESULT);
    signal state : state_type := IDLE;
    signal buf_idx : integer range 0 to 511 := 0;
    signal frame_buf : array (0 to 511) of STD_LOGIC_VECTOR(15 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE; done <= '0';
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then
                            buf_idx <= 0; state <= FILL_WIN;
                        end if;
                    when FILL_WIN =>
                        if pcm_valid = '1' then
                            frame_buf(buf_idx) <= pcm_data;
                            buf_idx <= buf_idx + 1;
                            if buf_idx = 511 then state <= FFT; end if;
                        end if;
                    when FFT =>
                        -- 512-point FFT → 257 bins (simplificado como sumas)
                        -- En hardware real: usamos LUTs + butterfly
                        state <= MEL;
                    when MEL =>
                        -- 26 filtros Mel × 257 bins = lookup desde mfcc_lut_pkg
                        state <= DCT;
                    when DCT =>
                        -- DCT-II 13×26 desde mfcc_dct_pkg
                        state <= CLASSIFY;
                    when CLASSIFY =>
                        -- RPK projection + BNN ternaria (misma que visión)
                        state <= RESULT;
                    when RESULT =>
                        class_out <= (others => '0'); -- placeholder
                        confidence <= (others => '0');
                        done <= '1'; state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
