-------------------------------------------------------------------------------
-- HDK.vhd — Hyperdimensional Kernel Classifier
-- Top-level entity for Artix-7 XC7A200T
--
-- Architecture: Inference-only accelerator for HD classification.
-- Training: PC generates class prototypes via L-BFGS.
-- Inference: FPGA computes Hamming distances and returns argmin class.
--
-- Pipeline: UART RX → BRAM → XOR → POPCOUNT → Argmin → UART TX
-- 0 DSPs · 0 MatMul · All LUT logic
--
-- Clock: 100 MHz (internal, from onboard oscillator)
-- Interface: UART 115200 baud (8N1)
-- Frame: [start:0xAA][class:1byte][confidence:2bytes][checksum:1byte][end:0x55]
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity HDK is
    Generic (
        D               : integer := 20000;  -- HD dimension
        N_CLASSES       : integer := 20;     -- Number of classes
        CLK_HZ          : integer := 100_000_000;
        UART_BAUD       : integer := 10_000_000  -- 10 Mbaud (100MHz / 10 = exact)
    );
    Port (
        clk             : in  STD_LOGIC;                     -- 100 MHz onboard
        rst_n           : in  STD_LOGIC;                     -- Active-low reset
        -- UART interface
        uart_rx         : in  STD_LOGIC;
        uart_tx         : out STD_LOGIC;
        -- Status LEDs
        led_busy        : out STD_LOGIC;
        led_ready       : out STD_LOGIC;
        led_error       : out STD_LOGIC
    );
end HDK;

architecture Behavioral of HDK is

    ---------------------------------------------------------------------------
    -- Constants
    ---------------------------------------------------------------------------
    constant BAUD_TICK_COUNT : integer := CLK_HZ / UART_BAUD;
    constant D_WIDTH         : integer := 15;  -- ceil(log2(D)) = 15 for 20000
    constant CLASS_WIDTH     : integer := 5;   -- ceil(log2(20)) = 5
    constant CONFIDENCE_WIDTH: integer := 16;  -- Q4.12 fixed-point

    ---------------------------------------------------------------------------
    -- UART Signals
    ---------------------------------------------------------------------------
    signal rx_byte          : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_valid         : STD_LOGIC;
    signal tx_byte          : STD_LOGIC_VECTOR(7 downto 0);
    signal tx_start         : STD_LOGIC;
    signal tx_busy          : STD_LOGIC;

    ---------------------------------------------------------------------------
    -- Command/Response FSM
    ---------------------------------------------------------------------------
    type state_type is (
        IDLE,
        RX_HEADER,
        RX_LENGTH_L,
        RX_LENGTH_H,
        RX_DATA,
        CHECKSUM,
        PROCESS_CMD,
        TX_HEADER,
        TX_LENGTH_L,
        TX_LENGTH_H,
        TX_DATA,
        TX_CHECKSUM,
        TX_END
    );
    signal state : state_type := IDLE;

    ---------------------------------------------------------------------------
    -- Protocol buffer
    ---------------------------------------------------------------------------
    signal rx_buffer       : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_packet_type  : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_packet_len   : integer range 0 to 65535;
    signal rx_packet_count : integer range 0 to 65535;
    signal rx_checksum     : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_calc_checksum: STD_LOGIC_VECTOR(7 downto 0);

    ---------------------------------------------------------------------------
    -- Prototype memory (BRAM)
    ---------------------------------------------------------------------------
    type prototype_array is array (0 to N_CLASSES-1) of STD_LOGIC_VECTOR(D-1 downto 0);
    signal prototypes      : prototype_array := (others => (others => '0'));
    signal proto_we        : STD_LOGIC;
    signal proto_waddr     : integer range 0 to N_CLASSES-1;
    signal proto_wdata     : STD_LOGIC_VECTOR(D-1 downto 0);

    ---------------------------------------------------------------------------
    -- Input vector (document HD vector)
    ---------------------------------------------------------------------------
    signal doc_vector      : STD_LOGIC_VECTOR(D-1 downto 0) := (others => '0');
    signal doc_ready       : STD_LOGIC := '0';

    ---------------------------------------------------------------------------
    -- Hamming distance computation
    ---------------------------------------------------------------------------
    type dist_array is array (0 to N_CLASSES-1) of STD_LOGIC_VECTOR(D_WIDTH-1 downto 0);
    signal distances       : dist_array;
    signal distances_valid : STD_LOGIC := '0';
    signal compute_busy    : STD_LOGIC := '0';
    signal compute_start   : STD_LOGIC := '0';
    signal current_class   : integer range 0 to N_CLASSES-1 := 0;

    ---------------------------------------------------------------------------
    -- Argmin
    ---------------------------------------------------------------------------
    signal min_dist        : STD_LOGIC_VECTOR(D_WIDTH-1 downto 0);
    signal min_class       : STD_LOGIC_VECTOR(CLASS_WIDTH-1 downto 0);
    signal min_confidence  : STD_LOGIC_VECTOR(CONFIDENCE_WIDTH-1 downto 0);
    signal argmin_valid    : STD_LOGIC := '0';

    ---------------------------------------------------------------------------
    -- LED blink
    ---------------------------------------------------------------------------
    signal led_counter     : integer range 0 to 50_000_000 := 0;
    signal led_ready_int   : STD_LOGIC := '0';

begin

    ---------------------------------------------------------------------------
    -- LED outputs
    ---------------------------------------------------------------------------
    led_busy  <= compute_busy;
    led_ready <= led_ready_int;
    led_error <= '0';

    ---------------------------------------------------------------------------
    -- UART Instances
    ---------------------------------------------------------------------------
    UART_RX_INST : entity work.uart_rx
        generic map (BAUD_TICK_COUNT => BAUD_TICK_COUNT)
        port map (
            clk       => clk,
            rst_n     => rst_n,
            rx        => uart_rx,
            data      => rx_byte,
            data_valid=> rx_valid,
            framing_error => open
        );

    UART_TX_INST : entity work.uart_tx
        generic map (BAUD_TICK_COUNT => BAUD_TICK_COUNT)
        port map (
            clk       => clk,
            rst_n     => rst_n,
            data      => tx_byte,
            start     => tx_start,
            busy      => tx_busy,
            tx        => uart_tx
        );

    ---------------------------------------------------------------------------
    -- 20,000-bit POPCOUNT Tree
    ---------------------------------------------------------------------------
    POPCOUNT_INST : entity work.popcount_tree
        generic map (WIDTH => D)
        port map (
            clk    => clk,
            rst_n  => rst_n,
            en     => '1',
            data   => doc_vector xor prototypes(current_class),
            result => distances(current_class),
            done   => open
        );

    ---------------------------------------------------------------------------
    -- Argmin (find minimum distance)
    ---------------------------------------------------------------------------
    ARGMIN_INST : entity work.argmin
        generic map (
            N_VALUES    => N_CLASSES,
            VALUE_WIDTH => D_WIDTH,
            INDEX_WIDTH => CLASS_WIDTH
        )
        port map (
            clk         => clk,
            rst_n       => rst_n,
            en          => distances_valid,
            values      => distances,
            min_index   => min_class,
            min_value   => min_dist,
            done        => argmin_valid
        );

    ---------------------------------------------------------------------------
    -- LED ready blinker (50% duty, ~1Hz)
    ---------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                led_counter <= 0;
                led_ready_int <= '0';
            else
                if led_counter = 50_000_000 then
                    led_counter <= 0;
                    led_ready_int <= not led_ready_int;
                else
                    led_counter <= led_counter + 1;
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Main Control FSM
    ---------------------------------------------------------------------------
    process(clk)
        variable i : integer;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                compute_busy <= '0';
                compute_start <= '0';
                doc_ready <= '0';
                distances_valid <= '0';
                tx_start <= '0';
                rx_calc_checksum <= (others => '0');
                proto_we <= '0';

            else
                case state is

                    -------------------------------------------------------------------
                    -- IDLE: Wait for UART activity
                    -------------------------------------------------------------------
                    when IDLE =>
                        if rx_valid = '1' and rx_byte = x"AA" then
                            state <= RX_HEADER;
                            rx_calc_checksum <= rx_byte;
                        end if;

                    -------------------------------------------------------------------
                    -- RX HEADER: Packet type
                    -------------------------------------------------------------------
                    when RX_HEADER =>
                        if rx_valid = '1' then
                            rx_packet_type <= rx_byte;
                            rx_calc_checksum <= rx_calc_checksum xor rx_byte;
                            state <= RX_LENGTH_L;
                        end if;

                    -------------------------------------------------------------------
                    -- RX LENGTH LSB
                    -------------------------------------------------------------------
                    when RX_LENGTH_L =>
                        if rx_valid = '1' then
                            rx_packet_len(7 downto 0) <= rx_byte;
                            rx_calc_checksum <= rx_calc_checksum xor rx_byte;
                            state <= RX_LENGTH_H;
                        end if;

                    -------------------------------------------------------------------
                    -- RX LENGTH MSB
                    -------------------------------------------------------------------
                    when RX_LENGTH_H =>
                        if rx_valid = '1' then
                            rx_packet_len(15 downto 8) <= rx_byte;
                            rx_calc_checksum <= rx_calc_checksum xor rx_byte;
                            rx_packet_count <= 0;
                            state <= RX_DATA;
                        end if;

                    -------------------------------------------------------------------
                    -- RX DATA: Depends on packet type
                    -------------------------------------------------------------------
                    when RX_DATA =>
                        if rx_valid = '1' then
                            rx_calc_checksum <= rx_calc_checksum xor rx_byte;
                            
                            -- Packet type 0x01: Load prototypes
                            -- Data: [N_CLASSES × D bits]
                            if rx_packet_type = x"01" then
                                -- Each byte fills 8 bits of prototype
                                i := rx_packet_count / 2500;  -- 20000 / 8 = 2500 bytes per prototype
                                proto_waddr <= i;
                                for b in 0 to 7 loop
                                    if rx_packet_count * 8 + b < (i+1) * 20000 then
                                        proto_wdata((rx_packet_count mod 2500) * 8 + b) <= rx_byte(b);
                                    end if;
                                end loop;
                                if rx_packet_count = rx_packet_len - 1 then
                                    proto_we <= '1';
                                end if;
                            end if;
                            
                            -- Packet type 0x02: Classify document
                            -- Data: D bits of document HD vector
                            if rx_packet_type = x"02" then
                                for b in 0 to 7 loop
                                    if rx_packet_count * 8 + b < D then
                                        doc_vector((rx_packet_count mod 2500) * 8 + b) <= rx_byte(b);
                                    end if;
                                end loop;
                                if rx_packet_count = rx_packet_len - 1 then
                                    doc_ready <= '1';
                                end if;
                            end if;

                            if rx_packet_count = rx_packet_len - 1 then
                                state <= CHECKSUM;
                            else
                                rx_packet_count <= rx_packet_count + 1;
                            end if;
                        end if;

                    -------------------------------------------------------------------
                    -- CHECKSUM verification
                    -------------------------------------------------------------------
                    when CHECKSUM =>
                        if rx_valid = '1' then
                            if rx_byte = rx_calc_checksum then
                                state <= PROCESS_CMD;
                            else
                                state <= IDLE;  -- Checksum error, drop packet
                            end if;
                        end if;

                    -------------------------------------------------------------------
                    -- PROCESS: Execute command
                    -------------------------------------------------------------------
                    when PROCESS_CMD =>
                        if rx_packet_type = x"01" then
                            -- Prototypes loaded, acknowledge
                            proto_we <= '0';
                            state <= TX_HEADER;
                            
                        elsif rx_packet_type = x"02" and doc_ready = '1' then
                            -- Start classification
                            compute_busy <= '1';
                            doc_ready <= '0';
                            current_class <= 0;
                            distances_valid <= '0';
                            state <= PROCESS_CMD;  -- Wait for distances
                            
                            -- Compute all Hamming distances (sequential, 1 POPCOUNT reused)
                            if current_class < N_CLASSES then
                                -- POPCOUNT is running (pipelined)
                                -- After 15 cycles, result is ready
                                if current_class = N_CLASSES - 1 then
                                    distances_valid <= '1';
                                    compute_busy <= '0';
                                    state <= TX_HEADER;
                                end if;
                                current_class <= current_class + 1;
                            end if;
                        end if;

                    -------------------------------------------------------------------
                    -- TX: Send classification result
                    -------------------------------------------------------------------
                    when TX_HEADER =>
                        if tx_busy = '0' then
                            tx_byte <= x"AA";
                            tx_start <= '1';
                            rx_calc_checksum <= x"AA";
                            state <= TX_LENGTH_L;
                        end if;

                    when TX_LENGTH_L =>
                        tx_start <= '0';
                        if tx_busy = '0' then
                            tx_byte <= x"04";  -- Payload: class(1) + confidence(2) + status(1)
                            tx_start <= '1';
                            rx_calc_checksum <= rx_calc_checksum xor x"04";
                            state <= TX_LENGTH_H;
                        end if;

                    when TX_LENGTH_H =>
                        tx_start <= '0';
                        if tx_busy = '0' then
                            tx_byte <= x"00";
                            tx_start <= '1';
                            rx_calc_checksum <= rx_calc_checksum xor x"00";
                            state <= TX_DATA;
                        end if;

                    when TX_DATA =>
                        tx_start <= '0';
                        if tx_busy = '0' then
                            -- Byte 0: Class ID
                            if rx_packet_count = 0 then
                                tx_byte <= "000" & min_class;
                                tx_start <= '1';
                                rx_calc_checksum <= rx_calc_checksum xor ("000" & min_class);
                                rx_packet_count <= 1;
                            -- Bytes 1-2: Confidence (min distance as proxy)
                            elsif rx_packet_count = 1 then
                                tx_byte <= min_dist(7 downto 0);
                                tx_start <= '1';
                                rx_calc_checksum <= rx_calc_checksum xor min_dist(7 downto 0);
                                rx_packet_count <= 2;
                            elsif rx_packet_count = 2 then
                                tx_byte <= min_dist(D_WIDTH-1 downto 8);
                                tx_start <= '1';
                                rx_calc_checksum <= rx_calc_checksum xor min_dist(D_WIDTH-1 downto 8);
                                rx_packet_count <= 3;
                            -- Byte 3: Status (0 = OK)
                            else
                                tx_byte <= x"00";
                                tx_start <= '1';
                                rx_calc_checksum <= rx_calc_checksum xor x"00";
                                state <= TX_CHECKSUM;
                            end if;
                        end if;

                    when TX_CHECKSUM =>
                        tx_start <= '0';
                        if tx_busy = '0' then
                            tx_byte <= rx_calc_checksum;
                            tx_start <= '1';
                            state <= TX_END;
                        end if;

                    when TX_END =>
                        tx_start <= '0';
                        if tx_busy = '0' then
                            tx_byte <= x"55";
                            tx_start <= '1';
                            rx_packet_count <= 0;
                            state <= IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
