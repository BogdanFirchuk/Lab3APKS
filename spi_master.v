`timescale 1ns / 1ps

// Модуль SPI Master (Mode 0: CPOL=0, CPHA=0, 8 біт, MSB first)
module spi_master #(
    parameter CLK_DIV = 4 // Дільник частоти (F_sck = F_clk / (2 * CLK_DIV))
)(
    input  wire       clk,      // Системний тактовий сигнал
    input  wire       rst_n,    // Асинхронний скид (активний рівень - 0)
    input  wire       start,    // Сигнал початку транзакції
    input  wire [7:0] tx_data,  // Байт даних для передачі (на MOSI)
    output reg  [7:0] rx_data,  // Прийнятий байт даних (з MISO)
    output reg        busy,     // Прапорець зайнятості модуля
    output reg        done,     // Імпульс завершення обміну
    
    // Фізичні лінії інтерфейсу SPI
    output reg        sck,      // Тактовий сигнал шини SPI
    output wire       mosi,     // Master Out Slave In (передача від Master)
    input  wire       miso,     // Master In Slave Out (прийом від Slave)
    output reg        ss_n      // Slave Select (активний рівень - 0)
);

    // Кодування станів скінченного автомата (FSM)
    localparam [1:0] STATE_IDLE     = 2'b00,
                     STATE_TRANSFER = 2'b01,
                     STATE_DONE     = 2'b10;

    reg [1:0] state;            // Поточний стан FSM
    reg [7:0] shift_reg;        // Зсувний регістр для одночасного прийому/передачі
    reg [2:0] bit_cnt;          // Лічильник переданих бітів (0..7)
    reg [$clog2(CLK_DIV)-1:0] clk_cnt; // Лічильник дільника частоти

    // На лінію MOSI завжди подається старший біт зсувного регістра
    assign mosi = shift_reg[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Скидання всіх регістрів у початковий стан
            state     <= STATE_IDLE;
            sck       <= 1'b0;
            ss_n      <= 1'b1;
            busy      <= 1'b0;
            done      <= 1'b0;
            rx_data   <= 8'h00;
            shift_reg <= 8'h00;
            bit_cnt   <= 3'd0;
            clk_cnt   <= 0;
        end else begin
            done <= 1'b0; // За замовчуванням прапорець завершення скинутий

            case (state)
                // 1. Стан очікування команди запуску
                STATE_IDLE: begin
                    sck     <= 1'b0;
                    ss_n    <= 1'b1;
                    clk_cnt <= 0;
                    bit_cnt <= 3'd0;

                    if (start) begin
                        shift_reg <= tx_data; // Завантаження даних для передачі
                        ss_n      <= 1'b0;    // Активація веденого пристрою
                        busy      <= 1'b1;
                        state     <= STATE_TRANSFER;
                    end else begin
                        busy      <= 1'b0;
                    end
                end

                // 2. Стан побітового обміну даними
                STATE_TRANSFER: begin
                    if (clk_cnt < CLK_DIV - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 0;
                        sck     <= ~sck; // Інверсія тактового сигналу SPI

                        if (sck == 1'b0) begin
                            // Наростаючий фронт SCK (0 -> 1): фіксація вхідного біта з MISO
                            // Зберігаємо прийнятий біт у тимчасовий або молодший розряд після зсуву
                            shift_reg <= {shift_reg[6:0], miso};
                        end else begin
                            // Спадаючий фронт SCK (1 -> 0): перехід до наступного біта
                            if (bit_cnt == 3'd7) begin
                                state <= STATE_DONE; // Усі 8 біт обміняно
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end
                end

                // 3. Стан завершення транзакції
                STATE_DONE: begin
                    ss_n    <= 1'b1;      // Деактивація веденого пристрою
                    sck     <= 1'b0;
                    rx_data <= shift_reg; // Видача прийнятого байта на вихід
                    busy    <= 1'b0;
                    done    <= 1'b1;      // Сигнал про готовність даних
                    state   <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule