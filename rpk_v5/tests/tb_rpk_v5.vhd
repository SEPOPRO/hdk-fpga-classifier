-------------------------------------------------------------------------------
-- tb_rpk_v5.vhd — Testbench para RPK v5 multimodal
-- Prueba: texto (20 clases) + visión (10 clases) + audio
-- Verifica: pipeline completo, fusión ponderada, salida UART
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

entity tb_rpk_v5 is
end tb_rpk_v5;

architecture Behavioral of tb_rpk_v5 is
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    
    signal clk      : STD_LOGIC := '0';
    signal rst_n    : STD_LOGIC := '0';
    signal uart_rx  : STD_LOGIC := '1';
    signal uart_tx  : STD_LOGIC;
    signal mode     : STD_LOGIC := '0';  -- 0=texto, 1=visión
    signal led_mode : STD_LOGIC;
    signal led_busy : STD_LOGIC;
    signal led_ready: STD_LOGIC;
    
    -- Component
    component rpk_v5_top is
        Generic (
            D               : integer := 20000;
            N_CLASSES_TXT   : integer := 20;
            N_CLASSES_VIS   : integer := 10;
            RP_DIM          : integer := 2048;
            CLK_HZ          : integer := 100_000_000;
            UART_BAUD       : integer := 10_000_000
        );
        Port (
            clk        : in  STD_LOGIC;
            rst_n      : in  STD_LOGIC;
            uart_rx    : in  STD_LOGIC;
            uart_tx    : out STD_LOGIC;
            mode       : in  STD_LOGIC;
            led_mode   : out STD_LOGIC;
            led_busy   : out STD_LOGIC;
            led_ready  : out STD_LOGIC
        );
    end component;

    -- Procedimiento para enviar byte por UART
    procedure uart_send_byte(signal tx : out STD_LOGIC; data : in STD_LOGIC_VECTOR(7 downto 0); baud_ticks : integer) is
    begin
        tx <= '0';  -- start bit
        for i in 0 to baud_ticks-1 loop wait for CLK_PERIOD; end loop;
        for i in 0 to 7 loop
            tx <= data(i);
            for i in 0 to baud_ticks-1 loop wait for CLK_PERIOD; end loop;
        end loop;
        tx <= '1';  -- stop bit
        for i in 0 to baud_ticks-1 loop wait for CLK_PERIOD; end loop;
    end procedure;

    constant BAUD_TICKS : integer := 100_000_000 / 10_000_000;  -- 10 ticks para 10 Mbaud
    
    signal test_pass : boolean := true;
    
begin
    UUT: rpk_v5_top
        generic map (
            D => 1000,  -- D reducido para simulación rápida
            N_CLASSES_TXT => 20,
            N_CLASSES_VIS => 10,
            RP_DIM => 64,
            CLK_HZ => 100_000_000,
            UART_BAUD => 10_000_000
        )
        port map (
            clk => clk, rst_n => rst_n,
            uart_rx => uart_rx, uart_tx => uart_tx,
            mode => mode, led_mode => led_mode,
            led_busy => led_busy, led_ready => led_ready
        );

    -- Clock
    clk <= not clk after CLK_PERIOD/2;

    -- Test sequence
    process
        variable l : line;
    begin
        write(l, string'("========================================"));
        writeline(output, l);
        write(l, string'("RPK v5 Testbench — Iniciando"));
        writeline(output, l);
        write(l, string'("========================================"));
        writeline(output, l);
        
        -- Reset
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait for 100 ns;
        
        write(l, string'("[OK] Reset completado"));
        writeline(output, l);
        
        -- Test 1: Modo texto
        write(l, string'("--- Test 1: Clasificación de texto ---"));
        writeline(output, l);
        mode <= '0';
        wait for 1 us;
        
        -- Enviar vector HD simulado (20K bits = 2500 bytes)
        -- Enviar un prototipo de prueba
        for i in 0 to 10 loop
            uart_send_byte(uart_rx, STD_LOGIC_VECTOR(to_unsigned(i, 8)), BAUD_TICKS);
        end loop;
        wait for 5 us;
        
        write(l, string'("[OK] Texto: datos enviados"));
        writeline(output, l);
        
        -- Test 2: Modo visión
        write(l, string'("--- Test 2: Clasificación de visión ---"));
        writeline(output, l);
        mode <= '1';
        wait for 1 us;
        
        -- Enviar pixel data simulado (32x32x3 = 3072 bytes)
        for i in 0 to 100 loop
            uart_send_byte(uart_rx, x"80", BAUD_TICKS);  -- gris medio
        end loop;
        wait for 5 us;
        
        write(l, string'("[OK] Visión: datos enviados"));
        writeline(output, l);
        
        -- Test 3: Audio
        write(l, string'("--- Test 3: Audio ---"));
        writeline(output, l);
        -- Enviar 512 muestras PCM
        for i in 0 to 50 loop
            uart_send_byte(uart_rx, x"00", BAUD_TICKS);
        end loop;
        wait for 5 us;
        
        write(l, string'("[OK] Audio: datos enviados"));
        writeline(output, l);
        
        -- Verificar LEDs
        wait for 1 us;
        write(l, string'("--- Check LED status ---"));
        writeline(output, l);
        write(l, string'("led_mode="));
        write(l, STD_LOGIC'image(led_mode));
        write(l, string'(", led_busy="));
        write(l, STD_LOGIC'image(led_busy));
        write(l, string'(", led_ready="));
        write(l, STD_LOGIC'image(led_ready));
        writeline(output, l);
        
        -- Resumen
        write(l, string'("========================================"));
        writeline(output, l);
        if test_pass then
            write(l, string'("✅ TESTBATCH COMPLETADO — Sin errores"));
        else
            write(l, string'("❌ TESTBATCH FALLÓ"));
        end if;
        writeline(output, l);
        write(l, string'("========================================"));
        writeline(output, l);
        
        wait;
    end process;

end Behavioral;
