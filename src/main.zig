const stm32f042_lib = @import("lib/STM32F042x.zig");
const stm32f042_types = stm32f042_lib.types.peripherals;
const stm32f042 = stm32f042_lib.devices.STM32F042x.peripherals;
const systick = @import("systick.zig");
const std = @import("std");
const IRC_FREQ = 8000000;

fn uart_write(uart: *volatile stm32f042_types.USART, bytes: []const u8) error{}!usize {
    for (bytes) |byte| {
        uart.TDR.write_raw(byte);
        while (uart.ISR.read().TC != 1) asm volatile ("");
    }
    return bytes.len;
}

const uart2_writer = std.io.Writer(
    *volatile stm32f042_types.USART,
    error{},
    uart_write,
){
    .context = stm32f042.USART2,
};

pub fn main() noreturn {
    systick.init(IRC_FREQ / 1000);

    // enable clock for gpio A and B
    stm32f042.RCC.AHBENR.modify(.{
        .IOPAEN = 1,
        .IOPBEN = 1,
    });
    // enable usart 2 (attached to usb vcom via gpio A2 and A15)
    stm32f042.RCC.APB1ENR.modify(.{ .USART2EN = 1 });
    // pin 2 and 15 mode alternate function
    stm32f042.GPIOA.MODER.modify(.{
        .MODER2 = 2,
        .MODER15 = 2,
    });
    // pin 2 and 15 alternate function 1 = uart
    stm32f042.GPIOA.AFRL.modify(.{ .AFRL2 = 1 });
    stm32f042.GPIOA.AFRH.modify(.{ .AFRH15 = 1 });

    // usart 2 configuration: 115200 baudrate, only transmit and enable
    stm32f042.USART2.BRR.write_raw(IRC_FREQ / 115200);
    stm32f042.USART2.CR1.modify(.{
        // .RE = 1,
        .TE = 1,
        .UE = 1,
    });
    // gpio b3 output (onboard led)
    stm32f042.GPIOB.MODER.modify(.{ .MODER3 = 1 });
    var gpio_state: u1 = 0;
    var counter: u32 = 0;
    while (true) {
        gpio_state = 1 - gpio_state;
        stm32f042.GPIOB.ODR.modify(.{ .ODR3 = gpio_state }); // set gpio out value

        uart2_writer.print("ciao da zig, {}\r\n", .{counter}) catch unreachable;

        //delay 1 sec
        systick.delay(1000);
        counter +%= 1;
    }
}
