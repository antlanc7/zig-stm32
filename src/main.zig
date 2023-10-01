const stm32f042 = @import("lib/STM32F042x.zig").devices.STM32F042x.peripherals;
const systick = @import("systick.zig");
const uart = @import("uart.zig");
const gpio = @import("gpio.zig");

const IRC_FREQ = 8000000;

pub fn main() noreturn {
    systick.init(IRC_FREQ / 1000);

    // usb vcom uart configuration: 115200 baudrate
    const uart_vcom = uart.init_vcom_uart(115200, IRC_FREQ);

    gpio.init_output_mode(stm32f042.GPIOB, 3);
    while (true) {
        gpio.toggle(stm32f042.GPIOB, 3);
        uart_vcom.print("ciao da zig, {}\r\n", .{systick.getTicks() / 1000}) catch unreachable;
        systick.delay(1000);
    }
}
