const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;

const GPIO = *volatile chip.types.peripherals.gpio_v2.GPIO;

const Gpio = @This();

gpio: GPIO,
pin: u4,

pub fn init_output_mode(comptime self: Gpio) void {
    chip.peripherals.RCC.AHBENR.modify_one(switch (self.gpio) {
        chip.peripherals.GPIOA => "GPIOAEN",
        chip.peripherals.GPIOB => "GPIOBEN",
        chip.peripherals.GPIOC => "GPIOCEN",
        chip.peripherals.GPIOF => "GPIOFEN",
        else => unreachable,
    }, 1);
    self.gpio.MODER.modify_one(std.fmt.comptimePrint("MODER[{}]", .{self.pin}), .Output);
}

pub fn toggle(comptime self: Gpio) void {
    self.gpio.ODR.raw ^= 1 << self.pin;
}
