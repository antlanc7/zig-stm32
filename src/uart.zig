const std = @import("std");
const stm32f042 = @import("lib/STM32F042x.zig");

const UART = *volatile stm32f042.types.peripherals.USART;

fn uart_write(uart: UART, bytes: []const u8) error{}!usize {
    for (bytes) |byte| {
        uart.TDR.write_raw(byte);
        while (uart.ISR.read().TC != 1) {}
    }
    return bytes.len;
}

fn uart_read(uart: UART, bytes: []u8) error{}!usize {
    for (bytes) |*byte| {
        while (uart.ISR.read().RXNE != 1) {}
        byte.* = @truncate(uart.RDR.read().RDR);
    }
    return bytes.len;
}

const UartWriter = std.io.GenericWriter(
    UART,
    error{},
    uart_write,
);

const UartReader = std.io.GenericReader(
    UART,
    error{},
    uart_read,
);

const Uart = struct {
    reader: UartReader,
    writer: UartWriter,
};

pub fn init(uart: UART, baudrate: u32, irc_freq: u32) Uart {
    uart.BRR.write_raw(irc_freq / baudrate);
    uart.CR1.modify(.{ .RE = 1, .TE = 1, .UE = 1 });
    return .{
        .reader = .{ .context = uart },
        .writer = .{ .context = uart },
    };
}

pub fn init_vcom_uart(baudrate: u32, irc_freq: u32) Uart {
    const rcc = stm32f042.devices.STM32F042x.peripherals.RCC;
    const gpioa = stm32f042.devices.STM32F042x.peripherals.GPIOA;
    const usart2 = stm32f042.devices.STM32F042x.peripherals.USART2;
    // RCC clock for GPIOA
    rcc.AHBENR.modify(.{ .IOPAEN = 1 });
    // pin 2 and 15 mode alternate function
    gpioa.MODER.modify(.{ .MODER2 = 2, .MODER15 = 2 });
    // pin 2 and 15 alternate function 1 = uart
    gpioa.AFRL.modify(.{ .AFRL2 = 1 });
    gpioa.AFRH.modify(.{ .AFRH15 = 1 });
    // enable usart 2 (attached to usb vcom via gpio A2 and A15)
    rcc.APB1ENR.modify(.{ .USART2EN = 1 });
    return init(usart2, baudrate, irc_freq);
}
