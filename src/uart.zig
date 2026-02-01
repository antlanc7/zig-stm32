const std = @import("std");
const stm32 = @import("lib/STM32F042x.zig");

const Io = std.Io;

const GPIO = @import("gpio.zig");
const StaticRingBuffer = @import("StaticRingBuffer.zig").StaticRingBuffer;

const UART = *volatile stm32.types.peripherals.USART;

const UART1 = stm32.peripherals.USART1;
const UART2 = stm32.peripherals.USART2;

const TransmitError = error{Full};
const ReceiveError = error{NoDataAvailable};

var uart1: ?*Uart = null;
var uart2: ?*Uart = null;

pub fn usart1_irq_handler() callconv(.c) void {
    if (uart1) |uart| uart.usart_irq_handler();
}

pub fn usart2_irq_handler() callconv(.c) void {
    if (uart2) |uart| uart.usart_irq_handler();
}

const Uart = @This();

regs: UART,
transmit_ring_buf: StaticRingBuffer(u8, 256) = .{},
receive_ring_buf: StaticRingBuffer(u8, 256) = .{},

pub fn usart_irq_handler(uart: *Uart) void {
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

fn write(uart: *Uart, bytes: []const u8) !usize {
    uart.transmit_ring_buf.writeSlice(bytes) catch return error.Full;
    uart.regs.CR1.modify(.{ .TXEIE = 1 });
    return bytes.len;
}

fn read(uart: *Uart, bytes: []u8) usize {
    const len = @min(bytes.len, uart.receive_ring_buf.len());
    if (len > 0) {
        uart.receive_ring_buf.readFirst(bytes, len) catch unreachable; // since we have checked the length before
    }
    return len;
}

fn stream(r: *Io.Reader, w: *Io.Writer, limit: Io.Limit) Io.Reader.StreamError!usize {
    const uartReader: *Reader = @alignCast(@fieldParentPtr("interface", r));
    const self = uartReader.uart;
    const buf = limit.slice(w.unusedCapacitySlice());
    const len = self.read(buf);
    if (len == 0) {
        uartReader.err = error.NoDataAvailable;
        return error.ReadFailed;
    }
    w.advance(len);
    return len;
}

fn drain(w: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
    const uartWriter: *Writer = @alignCast(@fieldParentPtr("interface", w));
    const self = uartWriter.uart;
    const b = w.buffered();
    var written: usize = 0;
    while (written < b.len) {
        written += self.write(b[written..]) catch return error.WriteFailed;
    }
    w.end = 0;
    written = 0;
    for (data[0 .. data.len - 1]) |bytes| {
        written += self.write(bytes) catch return error.WriteFailed;
    }
    for (0..splat) |_| {
        written += self.write(data[data.len - 1]) catch return error.WriteFailed;
    }
    return written;
}

pub const Reader = struct {
    err: ?ReceiveError = null,
    uart: *Uart,
    interface: Io.Reader,
};

pub const Writer = struct {
    uart: *Uart,
    interface: Io.Writer,
};

pub fn init(uart: UART) Uart {
    return .{
        .regs = uart,
    };
}

pub fn reader(uart: *Uart, buffer: []u8) Reader {
    return .{
        .uart = uart,
        .interface = .{
            .buffer = buffer,
            .end = 0,
            .seek = 0,
            .vtable = &.{
                .stream = stream,
            },
        },
    };
}

pub fn writer(uart: *Uart, buffer: []u8) Writer {
    return .{
        .uart = uart,
        .interface = .{
            .buffer = buffer,
            .end = 0,
            .vtable = &.{
                .drain = drain,
            },
        },
    };
}

pub fn init_static(comptime uart: UART, baudrate: u32, irc_freq: u32) Uart {
    const rcc = stm32.peripherals.RCC;
    // enable usart RCC
    if (uart == UART2) {
        rcc.APB1ENR.modify(.{ .USART2EN = 1 });
    } else if (uart == UART1) {
        rcc.APB2ENR.modify(.{ .USART1EN = 1 });
    }
    const USART1_IRQn = 27;
    const USART2_IRQn = 28;
    const USART_IRQn = if (uart == UART2) USART2_IRQn else USART1_IRQn;
    const ISER = &stm32.peripherals.NVIC.ISER[USART_IRQn >> 5];
    ISER.write_raw(ISER.raw | (1 << (USART_IRQn & 0x1F))); // enable USART_IRQ in NVIC
    uart.BRR.write_raw(irc_freq / baudrate);
    uart.CR1.modify(.{ .RE = 1, .TE = 1, .UE = 1, .RXNEIE = 1 });
    return Uart.init(uart);
}

pub fn init_vcom_uart(baudrate: u32, irc_freq: u32) Uart {
    const rcc = stm32.peripherals.RCC;
    const gpioa = stm32.peripherals.GPIOA;
    const usart2 = stm32.peripherals.USART2;
    // RCC clock for GPIOA
    rcc.AHBENR.modify(.{ .IOPAEN = 1 });
    // pin 2 and 15 mode alternate function
    gpioa.MODER.modify(.{
        .MODER2 = @intFromEnum(GPIO.Mode.Alternate),
        .MODER15 = @intFromEnum(GPIO.Mode.Alternate),
    });
    // pin 2 and 15 alternate function 1 = uart
    gpioa.AFRL.modify(.{ .AFRL2 = 1 });
    gpioa.AFRH.modify(.{ .AFRH15 = 1 });
    return init_static(usart2, baudrate, irc_freq);
}

pub fn registerUartInterrupt(uart: *Uart) void {
    if (uart.regs == UART2) {
        uart2 = uart;
    } else if (uart.regs == UART1) {
        uart1 = uart;
    }
}
