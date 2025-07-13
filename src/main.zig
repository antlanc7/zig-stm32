const std = @import("std");
const config = @import("config");

const stm32f042 = @import("lib/STM32F042x.zig").devices.STM32F042x.peripherals;
const systick = @import("systick.zig");
const uart = @import("uart_it.zig");
const gpio = @import("gpio.zig");
const i2c = @import("i2c.zig");
const lcd_lib = @import("lcd_i2c.zig");

const IRC_FREQ = 8000000;

export fn hardFault_Handler() void {
    while (true) {
        gpio.toggle(stm32f042.GPIOB, 3);
        for (0..100000) |i| {
            std.mem.doNotOptimizeAway(&i);
        }
    }
}

pub fn main() noreturn {
    systick.init(IRC_FREQ / 1000);

    // usb vcom uart configuration: 115200 baudrate
    const uart_vcom = uart.init_vcom_uart(115200, IRC_FREQ);
    const uart_vcom_reader = uart_vcom.reader();
    const uart_vcom_writer = uart_vcom.writer();

    const lcd = lcd_lib.LCD(stm32f042.I2C1, 0x27);
    if (config.use_lcd) {
        i2c.init_i2c1_pa9_pa10(400000, IRC_FREQ);
        lcd.lcd_init();
    }

    gpio.init_output_mode(stm32f042.GPIOB, 3);

    while (true) {
        // gpio.toggle(stm32f042.GPIOB, 3);
        uart_vcom_writer.print("ciao da zig, {}\r\n", .{systick.getTicks() / 1000}) catch unreachable;
        var buf = std.BoundedArray(u8, 1024){};
        uart_vcom_reader.streamUntilDelimiter(buf.writer(), '\n', buf.capacity()) catch {};
        const received = buf.constSlice();
        if (received.len > 0) {
            uart_vcom_writer.print("received: {s} = {any}\r\n", .{ received, received }) catch hardFault_Handler();
            if (config.use_lcd) {
                lcd.lcd_send_string_clear_rest_line(received);
            }
        }
        systick.delay(1000);
    }
}
