const std = @import("std");
const config = @import("config");

const microzig = @import("microzig");
const chip = microzig.chip;
const cpu = microzig.cpu;

const systick = @import("systick.zig");
const gpio = @import("gpio.zig");
const uart = @import("uart.zig");
const i2c = @import("i2c.zig");
const lcd_lib = @import("lcd_i2c.zig");

fn hardFault_Handler() callconv(.C) void {
    while (true) {
        gpio.toggle(chip.peripherals.GPIOB, 3);
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
    gpio.init_output_mode(chip.peripherals.GPIOB, 3);
    const uart_vcom = uart.init_vcom_uart(115200, IRC_FREQ);
    const uart_vcom_reader = uart_vcom.reader();
    const uart_vcom_writer = uart_vcom.writer();

    var lcd: lcd_lib.LCD = undefined;
    if (config.use_lcd) {
        const i2c_handle = i2c.init_i2c1_pa9_pa10(400000, IRC_FREQ);
        lcd = .{ .i2c = .{ .i2c = i2c_handle, .address = 0x27 } };
        lcd.init();
    }
    const lcd_writer = if (config.use_lcd) lcd.writer() else {};

    while (true) {
        gpio.toggle(chip.peripherals.GPIOB, 3);
        uart_vcom_writer.print("zig ms: {}\n", .{systick.getTicks() / 1000}) catch unreachable;
        if (config.use_lcd) {
            lcd.put_cur(0, 0);
            lcd_writer.print("zig ms: {}", .{systick.getTicks() / 1000}) catch unreachable;
        }
        var buf = std.BoundedArray(u8, 1024){};
        uart_vcom_reader.streamUntilDelimiter(buf.writer(), '\n', buf.capacity()) catch {};
        const received = buf.constSlice();
        if (received.len > 0) {
            uart_vcom_writer.print("received: {s} = {any}\r\n", .{ received, received }) catch hardFault_Handler();
            if (config.use_lcd) {
                lcd.put_cur(1, 0);
                lcd_writer.print("R: {s}", .{received}) catch unreachable;
            }
        }
        systick.delay(1000);
    }
}
