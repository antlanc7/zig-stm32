const std = @import("std");
const stm32f042 = @import("lib/STM32F042x.zig");

const StaticRingBuffer = @import("StaticRingBuffer.zig").StaticRingBuffer;

const UART = *volatile stm32f042.types.peripherals.USART;

const UART1 = stm32f042.devices.STM32F042x.peripherals.USART1;
const UART2 = stm32f042.devices.STM32F042x.peripherals.USART2;

const USART1_IRQn = 27;
const USART2_IRQn = 28;

const TransmitError = std.RingBuffer.Error;
const ReceiveError = std.RingBuffer.Error;

var uart1: ?Uart = null;
var uart2: ?Uart = null;

fn usart_irq_handler(uart: *Uart) void {
    const isr = uart.regs.ISR.read();
    if (isr.TXE == 1) {
        if (uart.transmit_ring_buf.read()) |byte| {
            uart.regs.TDR.write_raw(byte);
            if (uart.transmit_ring_buf.isEmpty()) {
                uart.regs.CR1.modify(.{ .TXEIE = 0 });
            }
        }
    }
    if (isr.TC == 1) {
        uart.regs.ICR.modify(.{ .TCCF = 1 });
    }
    if (isr.RXNE == 1) {
        const byte: u8 = @truncate(uart.regs.RDR.raw);
        uart.receive_ring_buf.write(byte) catch {};
    }
    if (isr.ORE == 1) { //clear receive overrun flag
        uart.regs.ICR.modify(.{ .ORECF = 1 });
    }
}

export fn usart1_irq_handler() void {
    usart_irq_handler(&(uart1 orelse return));
}

export fn usart2_irq_handler() void {
    usart_irq_handler(&(uart2 orelse return));
}

fn uart_write(uart: *Uart, bytes: []const u8) TransmitError!usize {
    try uart.transmit_ring_buf.writeSlice(bytes);
    uart.regs.CR1.modify(.{ .TXEIE = 1 });
    return bytes.len;
}

fn uart_read(uart: *Uart, bytes: []u8) ReceiveError!usize {
    const len = @min(bytes.len, uart.receive_ring_buf.len());
    if (len > 0) {
        try uart.receive_ring_buf.readFirst(bytes, len);
    }
    return len;
}

const UartWriter = std.io.GenericWriter(
    *Uart,
    TransmitError,
    uart_write,
);

const UartReader = std.io.GenericReader(
    *Uart,
    ReceiveError,
    uart_read,
);

const Uart = struct {
    regs: UART,
    transmit_ring_buf: StaticRingBuffer(u8, 256) = .{},
    receive_ring_buf: StaticRingBuffer(u8, 256) = .{},

    pub fn init(uart: UART) Uart {
        return .{ .regs = uart };
    }

    pub fn reader(self: *Uart) UartReader {
        return .{ .context = self };
    }

    pub fn writer(self: *Uart) UartWriter {
        return .{ .context = self };
    }
};

pub fn init(comptime uart: UART, baudrate: u32, irc_freq: u32) *Uart {
    const rcc = stm32f042.devices.STM32F042x.peripherals.RCC;
    const nvic = stm32f042.devices.STM32F042x.peripherals.NVIC;
    // enable usart RCC
    if (uart == UART2) {
        rcc.APB1ENR.modify(.{ .USART2EN = 1 });
    } else if (uart == UART1) {
        rcc.APB2ENR.modify(.{ .USART1EN = 1 });
    }
    const USART_IRQn = if (uart == UART2) USART2_IRQn else USART1_IRQn;
    const ISER = &nvic.ISER[USART_IRQn >> 5];
    ISER.write_raw(ISER.raw | (1 << (USART_IRQn & 0x1F))); // enable USART1_IRQ in NVIC
    uart.BRR.write_raw(irc_freq / baudrate);
    uart.CR1.modify(.{ .RE = 1, .TE = 1, .UE = 1, .RXNEIE = 1 });
    if (uart == UART2) {
        uart2 = Uart.init(uart);
        return &(uart2.?);
    } else if (uart == UART1) {
        uart1 = Uart.init(uart);
        return &(uart1.?);
    }
    unreachable;
}

pub fn init_vcom_uart(baudrate: u32, irc_freq: u32) *Uart {
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
    return init(usart2, baudrate, irc_freq);
}
