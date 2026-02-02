const stm32 = @import("./lib/STM32F042x.zig");
const mmio = @import("lib/mmio.zig");

const systick = stm32.peripherals.SYSTICK;
const rcc = stm32.peripherals.RCC;

pub fn init(reload: u24) void {
    rcc.APB2ENR.modify(.{ .SYSCFGEN = 1 });
    systick.LOAD.modify(.{ .RELOAD = reload });
    systick.VAL.write_raw(0);
    systick.CTRL.modify(.{
        .ENABLE = 1,
        .TICKINT = 1,
        .CLKSOURCE = 1,
    });
}

var systick_counter: u32 = 0;

pub fn sysTick_Handler() callconv(.c) void {
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
        asm volatile ("" ::: .{ .memory = true });
    }
}
