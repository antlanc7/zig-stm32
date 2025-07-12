const std = @import("std");
const config = @import("config");

const stm32f042 = @import("lib/STM32F042x.zig").devices.STM32F042x.peripherals;
const systick = @import("systick.zig");
const uart = @import("uart.zig");
const gpio = @import("gpio.zig");
const i2c = @import("i2c.zig");
const lcd_lib = @import("lcd_i2c.zig");

const IRC_FREQ = 8000000;

pub fn main() noreturn {
    systick.init(IRC_FREQ / 1000);

    // usb vcom uart configuration: 115200 baudrate
    const uart_vcom = uart.init_vcom_uart(115200, IRC_FREQ);

    const lcd = lcd_lib.LCD(stm32f042.I2C1, 0x27);
    if (config.use_lcd) {
        i2c.init_i2c1_pa9_pa10(400000, IRC_FREQ);
        lcd.lcd_init();
    }

    gpio.init_output_mode(stm32f042.GPIOB, 3);
    while (true) {
        gpio.toggle(stm32f042.GPIOB, 3);
        uart_vcom.writer.print("ciao da zig, {}\r\n", .{systick.getTicks() / 1000}) catch unreachable;
        if (config.use_lcd) {
            lcd.lcd_send_string_clear_rest_line("abcdefghijklmnopqrstuvwxyz");
        }
        var buf = std.BoundedArray(u8, 1024){};
        uart_vcom.reader.streamUntilDelimiter(buf.writer(), '\n', buf.capacity()) catch unreachable;
        uart_vcom.writer.print("received: {s} = {any}\r\n", .{ buf.constSlice(), buf.constSlice() }) catch unreachable;
        systick.delay(1000);
    }
}
