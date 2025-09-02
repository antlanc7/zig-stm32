const std = @import("std");
const config = @import("config");

const microzig = @import("microzig");
const chip = microzig.chip;
const cpu = microzig.cpu;

const systick = @import("systick.zig");
const Gpio = @import("gpio.zig");
const uart = @import("uart.zig");
const i2c = @import("i2c.zig");
const lcd_lib = @import("lcd_i2c.zig");
const adc_lib = @import("adc.zig");

const led: Gpio = .{ .gpio = chip.peripherals.GPIOB, .pin = 3 };

fn hardFault_Handler() callconv(.c) void {
    while (true) {
        led.toggle();
        for (0..100000) |i| {
            std.mem.doNotOptimizeAway(&i);
        }
    }
}

pub const microzig_options = microzig.Options{ .interrupts = .{
    .HardFault = .{ .c = hardFault_Handler },
    .SysTick = .{ .c = systick.sysTick_Handler },
    .USART1 = .{ .c = uart.usart1_irq_handler },
    .USART2 = .{ .c = uart.usart2_irq_handler },
} };

const IRC_FREQ = 8000000;

pub fn main() !void {
    systick.init(IRC_FREQ / 1000);
    led.init_output_mode();
    const uart_vcom = uart.init_vcom_uart(115200, IRC_FREQ);
    const uart_vcom_old_reader = uart_vcom.reader();
    const uart_vcom_old_writer = uart_vcom.writer();

    var uart_vcom_reader_buffer: [1024]u8 = undefined;
    var uart_vcom_writer_buffer: [1024]u8 = undefined;

    var uart_vcom_reader = uart_vcom_old_reader.adaptToNewApi(&uart_vcom_reader_buffer);
    var uart_vcom_writer = uart_vcom_old_writer.adaptToNewApi(&uart_vcom_writer_buffer);

    var lcd: lcd_lib.LCD = undefined;
    if (config.use_lcd) {
        const i2c_handle = i2c.init_i2c1_pa9_pa10(400000, IRC_FREQ);
        lcd = .{ .i2c = .{ .i2c = i2c_handle, .address = 0x27 } };
        lcd.init();
    }
    const lcd_writer = if (config.use_lcd) lcd.writer() else {};

    const adc = adc_lib.init_adc1();

    while (true) {
        led.toggle();
        const adc_val = adc.read();
        uart_vcom_writer.new_interface.print("zig ms: {} - {}\n", .{ systick.getTicks() / 1000, adc_val }) catch unreachable;
        if (config.use_lcd) {
            lcd.put_cur(0, 0);
            lcd_writer.print("zig {}-{}", .{ systick.getTicks() / 1000, adc_val }) catch unreachable;
        }
        const received = uart_vcom_reader.new_interface.takeDelimiterExclusive('\n') catch unreachable;
        if (received.len > 0) {
            uart_vcom_writer.new_interface.print("received: {s} = {any}\r\n", .{ received, received }) catch unreachable;
            if (config.use_lcd) {
                lcd.put_cur(1, 0);
                lcd_writer.print("R: {s}", .{received}) catch unreachable;
            }
        }
        uart_vcom_writer.new_interface.flush() catch hardFault_Handler();
        systick.delay(1000);
    }
}
