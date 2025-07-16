const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;

const GPIO = *volatile chip.types.peripherals.gpio_v2.GPIO;

pub fn init_output_mode(comptime gpio: GPIO, comptime pin: u4) void {
    const rcc = chip.peripherals.RCC;
    const gpioa = chip.peripherals.GPIOA;
    const gpiob = chip.peripherals.GPIOB;
    const gpioc = chip.peripherals.GPIOC;
    const gpiof = chip.peripherals.GPIOF;
    rcc.AHBENR.modify_one(switch (gpio) {
        gpioa => "GPIOAEN",
        gpiob => "GPIOBEN",
        gpioc => "GPIOCEN",
        gpiof => "GPIOFEN",
        else => unreachable,
    }, 1);
    gpio.MODER.modify_one(std.fmt.comptimePrint("MODER[{}]", .{pin}), .Output);
}

pub fn toggle(comptime gpio: GPIO, comptime pin: u4) void {
    gpio.ODR.raw ^= 1 << pin;
}
