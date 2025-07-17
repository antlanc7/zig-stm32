const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const cpu = microzig.cpu;

const StaticRingBuffer = @import("StaticRingBuffer.zig").StaticRingBuffer;

const UART = *volatile chip.types.peripherals.usart_v3.USART;

const UART1 = chip.peripherals.USART1;
const UART2 = chip.peripherals.USART2;

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
        uart.regs.ICR.modify(.{ .TC = 1 });
    }
    if (isr.RXNE == 1) {
        const byte: u8 = @truncate(uart.regs.RDR.raw);
        uart.receive_ring_buf.write(byte) catch {};
    }
    if (isr.ORE == 1) { //clear receive overrun flag
        uart.regs.ICR.modify(.{ .ORE = 1 });
    }
}

pub fn usart1_irq_handler() callconv(.C) void {
    usart_irq_handler(&(uart1 orelse return));
}

pub fn usart2_irq_handler() callconv(.C) void {
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

pub const Uart = struct {
    pub const UartWriter = std.io.GenericWriter(
        *Uart,
        TransmitError,
        uart_write,
    );

    pub const UartReader = std.io.GenericReader(
        *Uart,
        ReceiveError,
        uart_read,
    );

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
    const rcc = chip.peripherals.RCC;
    // enable usart RCC
    if (uart == UART2) {
        rcc.APB1ENR.modify(.{ .USART2EN = 1 });
    } else if (uart == UART1) {
        rcc.APB2ENR.modify(.{ .USART1EN = 1 });
    }
    cpu.interrupt.enable(switch (uart) {
        UART1 => .USART1,
        UART2 => .USART2,
        else => @compileError("Unknown UART"),
    });
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
    const rcc = chip.peripherals.RCC;
    const gpioa = chip.peripherals.GPIOA;
    const usart2 = chip.peripherals.USART2;
    // RCC clock for GPIOA
    rcc.AHBENR.modify(.{ .GPIOAEN = 1 });
    // pin 2 and 15 mode alternate function
    gpioa.MODER.modify(.{
        .@"MODER[2]" = .Alternate,
        .@"MODER[15]" = .Alternate,
    });
    // pin 2 and 15 alternate function 1 = uart
    gpioa.AFR[0].modify(.{ .@"AFR[2]" = 1 });
    gpioa.AFR[1].modify(.{ .@"AFR[7]" = 1 });
    return init(usart2, baudrate, irc_freq);
}
