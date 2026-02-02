const std = @import("std");
const stm32 = @import("lib/STM32F042x.zig");

const GPIO = *volatile stm32.types.peripherals.GPIO;

const rcc = stm32.peripherals.RCC;

pub const GPIOA = stm32.peripherals.GPIOA;
pub const GPIOB = stm32.peripherals.GPIOB;
pub const GPIOC = stm32.peripherals.GPIOC;
pub const GPIOF = stm32.peripherals.GPIOF;

const Gpio = @This();

gpio: GPIO,
pin: u4,

pub const Mode = enum(u2) {
    input = 0,
    output = 1,
    alternate = 2,
    analog = 3,
};

pub const DigitalStatus = enum(u1) {
    reset = 0,
    set = 1,
};

pub fn get_gpio_port_name(comptime self: Gpio) u8 {
    return switch (self.gpio) {
        GPIOA => 'A',
        GPIOB => 'B',
        GPIOC => 'C',
        GPIOF => 'F',
        else => unreachable,
    };
}

fn get_rcc_enable_name(comptime self: Gpio) *const [6:0]u8 {
    comptime {
        return std.fmt.comptimePrint("IOP{c}EN", .{self.get_gpio_port_name()});
    }
}

pub fn init_mode(comptime self: Gpio, comptime mode: Mode) void {
    rcc.AHBENR.modify_one(get_rcc_enable_name(self), 1);
    self.gpio.MODER.modify_one(std.fmt.comptimePrint("MODER{}", .{self.pin}), @intFromEnum(mode));
}

pub fn toggle(comptime self: Gpio) void {
    self.gpio.ODR.toggle_one(std.fmt.comptimePrint("ODR{}", .{self.pin}), 1);
}

pub fn write(comptime self: Gpio, value: DigitalStatus) void {
    self.gpio.ODR.modify_one(std.fmt.comptimePrint("ODR{}", .{self.pin}), @intFromEnum(value));
}

pub fn read(comptime self: Gpio) DigitalStatus {
    const bit: u1 = self.gpio.IDR.raw >> self.pin & 1;
    return @enumFromInt(bit);
}
