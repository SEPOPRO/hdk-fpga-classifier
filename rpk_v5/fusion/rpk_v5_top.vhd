-------------------------------------------------------------------------------
-- rpk_v5_top.vhd — RPK v5 Top-Level Multimodal
-- Integra: RPK texto (existente) + BNN ternaria visión + control
--
-- Recursos estimados: ~55,000 LUTs, 0 DSPs, 0 BRAMs
-- Frecuencia: ~50 MHz
-- Interfaces: UART (host), modo seleccionable (text/vision)
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rpk_v5_top is
    Generic (
        D               : integer := 20000;  -- HD dimension (texto)
        N_CLASSES_TXT   : integer := 20;     -- Clases texto
        N_CLASSES_VIS   : integer := 10;     -- Clases visión (CIFAR-10)
        RP_DIM          : integer := 2048;   -- Dimensión proyección RPK
        CLK_HZ          : integer := 100_000_000;
        UART_BAUD       : integer := 10_000_000
    );
    Port (
        clk             : in  STD_LOGIC;
        rst_n           : in  STD_LOGIC;
        uart_rx         : in  STD_LOGIC;
        uart_tx         : out STD_LOGIC;
        mode            : in  STD_LOGIC;     -- '0'=texto, '1'=visión
        led_mode        : out STD_LOGIC;
        led_busy        : out STD_LOGIC;
        led_ready       : out STD_LOGIC
    );
end rpk_v5_top;

architecture Structural of rpk_v5_top is

    ---------------------------------------------------------------------------
    -- Señales de interconexión
    ---------------------------------------------------------------------------
    -- UART → Control
    signal rx_byte      : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_valid     : STD_LOGIC;
    signal tx_byte      : STD_LOGIC_VECTOR(7 downto 0);
    signal tx_start     : STD_LOGIC;
    signal tx_busy      : STD_LOGIC;

    -- Control → RPK texto
    signal txt_start    : STD_LOGIC;
    signal txt_done     : STD_LOGIC;
    signal txt_class    : STD_LOGIC_VECTOR(4 downto 0);  -- hasta 20 clases
    signal txt_conf     : STD_LOGIC_VECTOR(15 downto 0);

    -- Control → BNN visión
    signal vis_start    : STD_LOGIC;
    signal vis_class    : STD_LOGIC_VECTOR(3 downto 0);
    signal vis_conf     : STD_LOGIC_VECTOR(15 downto 0);
    signal vis_done     : STD_LOGIC;
    
    -- Audio signals
    signal aud_start    : STD_LOGIC;
    signal aud_class    : STD_LOGIC_VECTOR(3 downto 0);
    signal aud_conf     : STD_LOGIC_VECTOR(15 downto 0);
    signal aud_done     : STD_LOGIC;
    
    -- RPK features bus (compartido texto/visión)
    signal rp_features  : STD_LOGIC_VECTOR(RP_DIM-1 downto 0);

    -- Fusión
    signal result_class : STD_LOGIC_VECTOR(4 downto 0);
    signal result_valid : STD_LOGIC;

    ---------------------------------------------------------------------------
    -- Estados
    ---------------------------------------------------------------------------
    type state_type is (IDLE, RX_DATA, TEXTPROC, VISPROC, FUSION, TX_RESULT);
    signal state : state_type := IDLE;

begin

    ---------------------------------------------------------------------------
    -- UART (existente, reutilizado)
    ---------------------------------------------------------------------------
    UART_RX_INST : entity work.uart_rx
        generic map (BAUD_TICK_COUNT => CLK_HZ / UART_BAUD)
        port map (clk => clk, rst_n => rst_n, rx => uart_rx,
                  data => rx_byte, data_valid => rx_valid);

    UART_TX_INST : entity work.uart_tx
        generic map (BAUD_TICK_COUNT => CLK_HZ / UART_BAUD)
        port map (clk => clk, rst_n => rst_n, data => tx_byte,
                  start => tx_start, tx => uart_tx, busy => tx_busy);

    ---------------------------------------------------------------------------
    -- RPK Texto (núcleo existente)
    ---------------------------------------------------------------------------
    -- Reutiliza el HDK classifier existente con D=20000
    RPK_TEXT : entity work.HDK
        generic map (
            D => D,
            N_CLASSES => N_CLASSES_TXT,
            CLK_HZ => CLK_HZ,
            UART_BAUD => UART_BAUD
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            uart_rx => uart_rx,
            uart_tx => uart_tx,
            led_busy => open,
            led_ready => open,
            led_error => open
        );

    ---------------------------------------------------------------------------
    -- BNN Visión (reactivada con ROM compacta)
    ---------------------------------------------------------------------------
    BNN_VISION : entity work.bnn_vision
        generic map (
            RP_DIM => RP_DIM,
            N_CLASSES => N_CLASSES_VIS
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            start => vis_start,
            rp_features => rp_features,
            class_out => vis_class,
            confidence => vis_conf,
            done => vis_done
        );
    
    ---------------------------------------------------------------------------
    -- Audio Classifier
    ---------------------------------------------------------------------------
    AUDIO : entity work.audio_classifier
        generic map (
            N_CLASSES => 10,
            N_MFCC => 13
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            start => aud_start,
            pcm_data => rx_byte,
            pcm_valid => rx_valid,
            class_out => aud_class,
            confidence => aud_conf,
            done => aud_done
        );

    ---------------------------------------------------------------------------
    -- Controlador principal
    ---------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                tx_start <= '0';
                led_busy <= '0';
                led_mode <= '0';
            else
                led_mode <= mode;
                tx_start <= '0';

                case state is
                    when IDLE =>
                        led_busy <= '0';
                        led_ready <= '1';
                        if rx_valid = '1' then
                            state <= RX_DATA;
                            led_ready <= '0';
                            led_busy <= '1';
                        end if;

                    when RX_DATA =>
                        if rx_valid = '1' then
                            if mode = '0' then
                                state <= TEXTPROC;
                            else
                                state <= VISPROC;
                            end if;
                        end if;

                    when TEXTPROC =>
                        -- El RPK texto procesa autónomamente
                        -- La clase viene por UART directamente del módulo HDK
                        if txt_done = '1' then
                            result_class <= txt_class;
                            state <= TX_RESULT;
                        end if;

                    when VISPROC =>
                        vis_start <= '1';
                        if vis_done = '1' then
                            result_class <= "0" & vis_class;  -- 5 bits
                            state <= TX_RESULT;
                        end if;
                        vis_start <= '0';

                    when TX_RESULT =>
                        tx_byte <= "000" & result_class;
                        tx_start <= '1';
                        state <= FUSION;

                    when FUSION =>
                        if tx_busy = '0' then
                            state <= IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Structural;
