const std = @import("std");
const stm32f042 = @import("lib/STM32F042x.zig");

const GPIO = *volatile stm32f042.types.peripherals.GPIO;

const Gpio = @This();

gpio: GPIO,
pin: u4,

pub const Mode = enum(u2) {
    Input,
    Output,
    Alternate,
    Analog,
};

pub fn init_output_mode(comptime self: Gpio) void {
    stm32f042.peripherals.RCC.AHBENR.modify_one(switch (self.gpio) {
        stm32f042.peripherals.GPIOA => "IOPAEN",
        stm32f042.peripherals.GPIOB => "IOPBEN",
        stm32f042.peripherals.GPIOC => "IOPCEN",
        stm32f042.peripherals.GPIOF => "IOPFEN",
        else => unreachable,
    }, 1);
    self.gpio.MODER.modify_one(std.fmt.comptimePrint("MODER{}", .{self.pin}), @intFromEnum(Mode.Output));
}

pub fn toggle(comptime self: Gpio) void {
    self.gpio.ODR.raw ^= 1 << self.pin;
}
