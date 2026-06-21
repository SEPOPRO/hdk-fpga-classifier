-------------------------------------------------------------------------------
-- bnn_vision.vhd — BNN Ternaria para visión
-- Pipeline: Gabor LUT → RPK proyección → BNN ternaria (ROM compacta)
-- Usa bnn_weights_compact.vhd (4 pesos por byte, ROM plana)
-- 0 DSPs, 0 BRAMs, solo LUTs
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.bnn_weights_pkg.all;

entity bnn_vision is
    Generic (
        RP_DIM    : integer := 2048;
        N_CLASSES : integer := 10
    );
    Port (
        clk         : in  STD_LOGIC;
        rst_n       : in  STD_LOGIC;
        start       : in  STD_LOGIC;
        rp_features : in  STD_LOGIC_VECTOR(RP_DIM-1 downto 0);
        class_out   : out STD_LOGIC_VECTOR(3 downto 0);
        confidence  : out STD_LOGIC_VECTOR(15 downto 0);
        done        : out STD_LOGIC
    );
end bnn_vision;

architecture Behavioral of bnn_vision is
    type state_type is (IDLE, L1, L2, L3, RESULT);
    signal state : state_type := IDLE;
    
    -- Funcion para decodificar pesos ternarios de la ROM compacta
    function get_weight(layer : integer; row : integer; col : integer) return STD_LOGIC_VECTOR is
        variable idx : integer;
        variable byte_idx : integer;
        variable bit_pos : integer;
        variable byte_val : STD_LOGIC_VECTOR(7 downto 0);
    begin
        if layer = 0 then
            idx := row * 2048 + col;
        elsif layer = 1 then
            idx := row * 512 + col;
        else
            idx := row * 128 + col;
        end if;
        byte_idx := idx / 4;
        bit_pos := (idx mod 4) * 2;
        
        if layer = 0 then byte_val := L0_ROM(byte_idx);
        elsif layer = 1 then byte_val := L1_ROM(byte_idx);
        else byte_val := L2_ROM(byte_idx);
        end if;
        return byte_val(bit_pos+1 downto bit_pos);
    end function;
    
    signal l1_neuron : STD_LOGIC_VECTOR(511 downto 0);
    signal l2_neuron : STD_LOGIC_VECTOR(127 downto 0);
    signal l3_score  : STD_LOGIC_VECTOR(9 downto 0);
    signal compute_done : STD_LOGIC := '0';
begin

    process(clk)
        variable sum : integer range 0 to RP_DIM;
        variable w : STD_LOGIC_VECTOR(1 downto 0);
        variable best_c : integer range 0 to 9 := 0;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE; done <= '0';
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then state <= L1; end if;
                    
                    when L1 =>
                        for o in 0 to 511 loop
                            sum := 0;
                            for i in 0 to RP_DIM-1 loop
                                w := get_weight(0, o, i);
                                if w = "10" and rp_features(i) = '1' then sum := sum + 1; end if;
                                if w = "00" and rp_features(i) = '0' then sum := sum + 1; end if;
                            end loop;
                            if sum > RP_DIM/4 then l1_neuron(o) <= '1'; else l1_neuron(o) <= '0'; end if;
                        end loop;
                        state <= L2;
                    
                    when L2 =>
                        for o in 0 to 127 loop
                            sum := 0;
                            for i in 0 to 511 loop
                                w := get_weight(1, o, i);
                                if w = "10" and l1_neuron(i) = '1' then sum := sum + 1; end if;
                                if w = "00" and l1_neuron(i) = '0' then sum := sum + 1; end if;
                            end loop;
                            if sum > 128 then l2_neuron(o) <= '1'; else l2_neuron(o) <= '0'; end if;
                        end loop;
                        state <= L3;
                    
                    when L3 =>
                        for o in 0 to 9 loop
                            sum := 0;
                            for i in 0 to 127 loop
                                w := get_weight(2, o, i);
                                if w = "10" and l2_neuron(i) = '1' then sum := sum + 1; end if;
                                if w = "00" and l2_neuron(i) = '0' then sum := sum + 1; end if;
                            end loop;
                            if sum > 32 then l3_score(o) <= '1'; else l3_score(o) <= '0'; end if;
                        end loop;
                        state <= RESULT;
                    
                    when RESULT =>
                        best_c := 0;
                        for c in 0 to 9 loop
                            if l3_score(c) = '1' then best_c := c; end if;
                        end loop;
                        class_out <= STD_LOGIC_VECTOR(to_unsigned(best_c, 4));
                        confidence <= (others => '1') when best_c > 0 else (others => '0');
                        done <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
