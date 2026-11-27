`timescale 1ns / 1ps

module spi_master_tb;

    // Параметри симуляції
    localparam CLK_PERIOD = 10; // Період 10 нс (100 МГц)
    localparam CLK_DIV    = 4;  // Частота SCK = 100 / (2*4) = 12.5 МГц

    // Сигнали підключення до DUT (Device Under Test)
    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [7:0] tx_data;
    wire [7:0] rx_data;
    wire       busy;
    wire       done;
    wire       sck;
    wire       mosi;
    reg        miso;
    wire       ss_n;

    // Змінні для імітації роботи зовнішнього SPI Slave
    reg [7:0] slave_tx_data = 8'h3C; // Дані, які Slave відправляє на Master
    reg [7:0] slave_rx_data = 8'h00; // Регістр для перевірки того, що прийняв Slave
    integer   slave_bit_idx;

    // Екземпляр тестованого модуля
    spi_master #(
        .CLK_DIV(CLK_DIV)
    ) uut (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .tx_data (tx_data),
        .rx_data (rx_data),
        .busy    (busy),
        .done    (done),
        .sck     (sck),
        .mosi    (mosi),
        .miso    (miso),
        .ss_n    (ss_n)
    );

    // Генерація системного тактового сигналу
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Імітація поведінки SPI Slave (Mode 0)
    always @(negedge ss_n) begin
        slave_bit_idx = 7;
        miso <= slave_tx_data[7]; // Виставляємо перший біт одразу при активації SS
    end

    // Slave зчитує MOSI по наростаючому фронту SCK
    always @(posedge sck) begin
        if (!ss_n) begin
            slave_rx_data[slave_bit_idx] <= mosi;
        end
    end

    // Slave оновлює MISO по спадаючому фронту SCK
    always @(negedge sck) begin
        if (!ss_n && slave_bit_idx > 0) begin
            slave_bit_idx = slave_bit_idx - 1;
            miso <= slave_tx_data[slave_bit_idx];
        end
    end

    // Основний сценарій тестування
    initial begin
        // Ініціалізація входів
        rst_n   = 1'b0;
        start   = 1'b0;
        tx_data = 8'h00;
        miso    = 1'b0;

        // Зняття сигналу скидання
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 2);

        // Тест 1: Передача байта 0xA5, прийом байта 0x3C
        tx_data = 8'hA5;
        start   = 1'b1;
        #(CLK_PERIOD);
        start   = 1'b0;

        // Очікування завершення транзакції
        wait(done == 1'b1);
        #(CLK_PERIOD * 2);

        // Перевірка результатів у консолі симулятора
        $display("--- Результати симуляції SPI ---");
        $display("Master відправив: 0x%h | Slave отримав:  0x%h", tx_data, slave_rx_data);
        $display("Slave відправив:  0x%h | Master отримав: 0x%h", slave_tx_data, rx_data);

        if (rx_data == 8'h3C && slave_rx_data == 8'hA5)
            $display("ТЕСТ ПРОЙДЕНО УСПІШНО!");
        else
            $display("ПОМИЛКА ОБМІНУ ДАНИМИ!");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule