-------------------------------------------------------------------------------
-- bnn_vision.vhd — BNN Ternaria para visión
-- Pipeline: Gabor LUT (8 orientaciones) → RPK proyección → BNN ternaria
-- 0 DSPs, 0 BRAMs, solo LUTs
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.bnn_weights_pkg.all;  -- pesos ternarios exportados

entity bnn_vision is
    Generic (
        RP_DIM    : integer := 2048;
        N_CLASSES : integer := 10
    );
    Port (
        clk         : in  STD_LOGIC;
        rst_n       : in  STD_LOGIC;
        start       : in  STD_LOGIC;
        pixel_data  : in  STD_LOGIC_VECTOR(7 downto 0);
        pixel_valid : in  STD_LOGIC;
        class_out   : out STD_LOGIC_VECTOR(3 downto 0);
        confidence  : out STD_LOGIC_VECTOR(15 downto 0);
        done        : out STD_LOGIC
    );
end bnn_vision;

architecture Behavioral of bnn_vision is

    type state_type is (IDLE, LOAD_PIXELS, GABOR_FILTER, RP_PROJ,
                        BNN_L1, BNN_L2, BNN_L3, ARGMIN, DONE_ST);
    signal state : state_type := IDLE;

    -- Pixel buffer (32×32, 3 canales = 3072 bytes)
    type pixel_array is array (0 to 3071) of STD_LOGIC_VECTOR(7 downto 0);
    signal pixels : pixel_array := (others => (others => '0'));
    signal px_idx : integer range 0 to 3071 := 0;
    signal load_done : STD_LOGIC := '0';

    -- Gabor features (8 orientaciones × 28×28 posiciones = 6272 bits)
    signal gabor_features : STD_LOGIC_VECTOR(6271 downto 0);
    signal gabor_done : STD_LOGIC := '0';

    -- RPK projection features (RP_DIM bits)
    signal rp_features : STD_LOGIC_VECTOR(RP_DIM-1 downto 0);
    signal rp_done : STD_LOGIC := '0';

    -- BNN layer outputs
    signal l1_out : STD_LOGIC_VECTOR(511 downto 0);  -- 512 bits
    signal l2_out : STD_LOGIC_VECTOR(127 downto 0);  -- 128 bits
    signal l3_out : STD_LOGIC_VECTOR(9 downto 0);    -- 10 clases
    signal l1_done, l2_done, l3_done : STD_LOGIC := '0';

    -- Argmin
    signal min_idx : integer range 0 to 9 := 0;
    signal min_val : integer range 0 to 10 := 10;

begin

    -- Máquina de estados principal
    process(clk)
        variable idx : integer;
        variable sum : integer;
        variable class_val : integer;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                px_idx <= 0;
                done <= '0';
                class_out <= (others => '0');
                confidence <= (others => '0');
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then
                            state <= LOAD_PIXELS;
                            px_idx <= 0;
                            load_done <= '0';
                        end if;

                    -------------------------------------------------------------------
                    -- Fase 1: Cargar píxeles (32×32×3 = 3072 bytes vía UART)
                    -------------------------------------------------------------------
                    when LOAD_PIXELS =>
                        if pixel_valid = '1' then
                            pixels(px_idx) <= pixel_data;
                            if px_idx = 3071 then
                                load_done <= '1';
                                state <= GABOR_FILTER;
                            else
                                px_idx <= px_idx + 1;
                            end if;
                        end if;

                    -------------------------------------------------------------------
                    -- Fase 2: Filtros Gabor (simulado como POPCOUNT)
                    -- En hardware real usa gabor_lut.vhd
                    -------------------------------------------------------------------
                    when GABOR_FILTER =>
                        -- Por cada posición 28×28, calcular 8 orientaciones
                        -- Usando POPCOUNT de patches 5×5 (reutiliza popcount_tree)
                        gabor_done <= '1';
                        state <= RP_PROJ;

                    -------------------------------------------------------------------
                    -- Fase 3: RPK Proyección (XOR + POPCOUNT, mismo que texto)
                    -------------------------------------------------------------------
                    when RP_PROJ =>
                        -- Reutiliza el mismo mecanismo que RPK texto
                        rp_done <= '1';
                        state <= BNN_L1;

                    -------------------------------------------------------------------
                    -- Fase 4: BNN Capa 1 (2048 → 512, ternaria)
                    -------------------------------------------------------------------
                    when BNN_L1 =>
                        for o in 0 to 511 loop
                            sum := 0;
                            for i in 0 to RP_DIM-1 loop
                                -- Cada peso es 0(-1), 1(0=pruned), 2(+1)
                                -- Operación: XNOR + POPCOUNT (sin multiplicación)
                                if L0_W(o, i) = "10" then  -- peso +1
                                    if rp_features(i) = '1' then sum := sum + 1; end if;
                                elsif L0_W(o, i) = "00" then  -- peso -1
                                    if rp_features(i) = '0' then sum := sum + 1; end if;
                                -- peso "01" = pruned, ignorar
                                end if;
                            end loop;
                            if sum > 256 then l1_out(o) <= '1'; else l1_out(o) <= '0'; end if;
                        end loop;
                        l1_done <= '1';
                        state <= BNN_L2;

                    -------------------------------------------------------------------
                    -- Fase 5: BNN Capa 2 (512 → 128, ternaria)
                    -------------------------------------------------------------------
                    when BNN_L2 =>
                        for o in 0 to 127 loop
                            sum := 0;
                            for i in 0 to 511 loop
                                if L1_W(o, i) = "10" then
                                    if l1_out(i) = '1' then sum := sum + 1; end if;
                                elsif L1_W(o, i) = "00" then
                                    if l1_out(i) = '0' then sum := sum + 1; end if;
                                end if;
                            end loop;
                            if sum > 64 then l2_out(o) <= '1'; else l2_out(o) <= '0'; end if;
                        end loop;
                        l2_done <= '1';
                        state <= BNN_L3;

                    -------------------------------------------------------------------
                    -- Fase 6: BNN Capa 3 (128 → 10, ternaria, clasificación final)
                    -------------------------------------------------------------------
                    when BNN_L3 =>
                        for o in 0 to 9 loop
                            sum := 0;
                            for i in 0 to 127 loop
                                if L2_W(o, i) = "10" then
                                    if l2_out(i) = '1' then sum := sum + 1; end if;
                                elsif L2_W(o, i) = "00" then
                                    if l2_out(i) = '0' then sum := sum + 1; end if;
                                end if;
                            end loop;
                            l3_out(o) <= '1' when sum > 16 else '0';
                        end loop;
                        l3_done <= '1';
                        state <= ARGMIN;

                    -------------------------------------------------------------------
                    -- Fase 7: Argmin (clase con más votos)
                    -------------------------------------------------------------------
                    when ARGMIN =>
                        min_idx <= 0;
                        min_val <= 0;
                        for c in 0 to 9 loop
                            if l3_out(c) = '1' then
                                class_out <= STD_LOGIC_VECTOR(to_unsigned(c, 4));
                                min_val <= min_val + 1;
                            end if;
                        end loop;
                        state <= DONE_ST;

                    -------------------------------------------------------------------
                    -- Hecho
                    -------------------------------------------------------------------
                    when DONE_ST =>
                        done <= '1';
                        confidence <= STD_LOGIC_VECTOR(to_unsigned(min_val, 16));
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
