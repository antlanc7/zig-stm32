const std = @import("std");

const microzig = @import("microzig");
const chip = microzig.chip;
const cpu = microzig.cpu;

const systick = @import("systick.zig");
const gpio = @import("gpio.zig");

fn hardFault_Handler() callconv(.C) void {
    while (true) {
        gpio.toggle(chip.peripherals.GPIOB, 3);
        for (0..100000) |i| {
            std.mem.doNotOptimizeAway(&i);
        }
    }
}

pub const microzig_options = microzig.Options{ .interrupts = .{
    .HardFault = .{ .c = hardFault_Handler },
    .SysTick = .{ .c = systick.sysTick_Handler },
} };

const IRC_FREQ = 8000000;

pub fn main() !void {
    systick.init(IRC_FREQ / 1000);
    gpio.init_output_mode(chip.peripherals.GPIOB, 3);
    while (true) {
        gpio.toggle(chip.peripherals.GPIOB, 3);
        systick.delay(1000);
    }
}
