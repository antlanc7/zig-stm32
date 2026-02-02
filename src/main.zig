const std = @import("std");
const config = @import("config");

const chip = @import("lib/STM32F042x.zig");

const systick = @import("systick.zig");
const Gpio = @import("gpio.zig");
const uart = @import("uart.zig");
const i2c = @import("i2c.zig");
const LCD = @import("lcd_i2c.zig");
const Adc = @import("adc.zig");

const led: Gpio = .{ .gpio = chip.peripherals.GPIOB, .pin = 3 };
const adc_pin: Gpio = .{ .gpio = chip.peripherals.GPIOA, .pin = 0 };

export fn hardFault_Handler() callconv(.c) noreturn {
    while (true) {
        led.toggle();
        for (0..100000) |i| {
            std.mem.doNotOptimizeAway(&i);
        }
    }
}

export const sysTick_Handler = systick.sysTick_Handler;
export const usart1_irq_handler = uart.usart1_irq_handler;
export const usart2_irq_handler = uart.usart2_irq_handler;

const IRC_FREQ = config.IRC_FREQ;

pub fn main() !void {
    systick.init(IRC_FREQ / 1000);
    led.init_mode(.output);
    var uart_vcom = uart.init_vcom_uart(115200, IRC_FREQ);
    uart_vcom.registerUartInterrupt();
    var uart_vcom_reader_buffer: [512]u8 = undefined;
    var uart_vcom_writer_buffer: [512]u8 = undefined;
    var uart_vcom_reader = uart_vcom.reader(&uart_vcom_reader_buffer);
    var uart_vcom_writer = uart_vcom.writer(&uart_vcom_writer_buffer);

    var lcd_handle: LCD = undefined;
    if (config.use_lcd) {
        const i2c_handle = i2c.init_i2c1_pa9_pa10(400000, IRC_FREQ);
        lcd_handle = .{ .i2c = .{ .i2c = i2c_handle, .address = 0x27 } };
        lcd_handle.init();
    }
    const lcd_writer = if (config.use_lcd) lcd_handle.writer() else {};

    var adc1: Adc = .init(Adc.adc1);
    var adc1_ch0 = adc1.channel(adc_pin);

    while (true) {
        led.toggle();
        const adc_val = adc1_ch0.read();
        uart_vcom_writer.interface.print("zig 0.15 ms: {} - {}\n", .{ systick.getTicks() / 1000, adc_val }) catch unreachable;
        if (config.use_lcd) {
            lcd_handle.put_cur(0, 0);
            lcd_writer.print("zig {}-{}", .{ systick.getTicks() / 1000, adc_val }) catch unreachable;
        }
        const receivedBeforeTrim = uart_vcom_reader.interface.takeDelimiterInclusive('\n') catch |err| switch (err) {
            error.ReadFailed => switch (uart_vcom_reader.err.?) {
                error.NoDataAvailable => (&.{}),
            },
            error.StreamTooLong => "StreamTooLong",
            error.EndOfStream => unreachable,
        };
        const received = std.mem.trim(u8, receivedBeforeTrim, &std.ascii.whitespace);
        if (received.len > 0) {
            uart_vcom_writer.interface.print("received: {s} = {any}\r\n", .{ received, received }) catch unreachable;
            if (config.use_lcd) {
                lcd_handle.put_cur(1, 0);
                lcd_writer.print("R: {s}", .{received}) catch unreachable;
            }
        }
        uart_vcom_writer.interface.flush() catch {
            uart_vcom_writer.interface.end = 0; // clear the buffer
            uart_vcom_writer.interface.writeAll("uart write failed\r\n") catch unreachable;
            uart_vcom_writer.interface.flush() catch unreachable;
        };
        systick.delay(1000);
    }
}
