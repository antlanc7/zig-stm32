const microzig = @import("microzig");
const rcc = microzig.chip.peripherals.RCC;
const systick = microzig.cpu.peripherals.systick;

pub fn init(reload: u24) void {
    rcc.APB2ENR.modify(.{ .SYSCFGEN = @intFromBool(true) });
    systick.LOAD.modify(.{ .RELOAD = reload });
    systick.VAL.write_raw(0);
    systick.CTRL.modify(.{
        .ENABLE = @intFromBool(true),
        .TICKINT = @intFromBool(true),
        .CLKSOURCE = @intFromBool(true),
    });
}

var systick_counter: u32 = 0;

pub fn sysTick_Handler() callconv(.C) void {
    systick_counter +%= 1;
}

pub fn delay(ms: u32) void {
    awaitTicks(ms + systick_counter);
}

pub fn getTicks() u32 {
    return systick_counter;
}

pub fn awaitTicks(ms: u32) void {
    while (systick_counter < ms) {
        asm volatile ("" ::: "memory");
    }
}
