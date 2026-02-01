const std = @import("std");
const Io = std.Io;
const stm32 = @import("lib/STM32F042x.zig");

const UART = *volatile stm32.types.peripherals.USART;
const GPIO = @import("gpio.zig");

const UART1 = stm32.peripherals.USART1;
const UART2 = stm32.peripherals.USART2;

pub fn usart1_irq_handler() callconv(.c) void {}
pub fn usart2_irq_handler() callconv(.c) void {}

fn write(uart: *Uart, bytes: []const u8) usize {
    for (bytes) |byte| {
        uart.regs.TDR.write_raw(byte);
        while (uart.regs.ISR.read().TC != 1) {}
    }
    return bytes.len;
}

fn read(uart: *Uart, bytes: []u8) usize {
    for (bytes) |*byte| {
        while (uart.regs.ISR.read().RXNE != 1) {}
        byte.* = @truncate(uart.regs.RDR.read().RDR);
    }
    return bytes.len;
}

fn stream(r: *Io.Reader, w: *Io.Writer, limit: Io.Limit) Io.Reader.StreamError!usize {
    const uartReader: *Reader = @alignCast(@fieldParentPtr("interface", r));
    const self = uartReader.uart;
    const buf = limit.slice(w.unusedCapacitySlice());
    const len = self.read(buf);
    if (len == 0) {
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
        written += self.write(b[written..]);
    }
    w.end = 0;
    written = 0;
    for (data[0 .. data.len - 1]) |bytes| {
        written += self.write(bytes);
    }
    for (0..splat) |_| {
        written += self.write(data[data.len - 1]);
    }
    return written;
}

pub const Reader = struct {
    uart: *Uart,
    interface: Io.Reader,
};

pub const Writer = struct {
    uart: *Uart,
    interface: Io.Writer,
};

const Uart = @This();
regs: UART,

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

pub fn init(uart: UART, baudrate: u32, irc_freq: u32) Uart {
    const rcc = stm32.peripherals.RCC;
    if (uart == UART2) {
        rcc.APB1ENR.modify(.{ .USART2EN = 1 });
    } else if (uart == UART1) {
        rcc.APB2ENR.modify(.{ .USART1EN = 1 });
    }
    uart.BRR.write_raw(irc_freq / baudrate);
    uart.CR1.modify(.{ .RE = 1, .TE = 1, .UE = 1 });
    return .{ .regs = uart };
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
    return init(usart2, baudrate, irc_freq);
}
