const stm32 = @import("./lib/STM32F042x.zig");
const mmio = @import("lib/mmio.zig");

const systick_t = extern struct {
    CTRL: mmio.Mmio(packed struct(u32) {
        ENABLE: u1,
        TICKINT: u1,
        CLKSOURCE: u1,
        padding: u13,
        COUNTFLAG: u1,
        padding2: u15,
    }),
    LOAD: mmio.Mmio(packed struct(u32) {
        RELOAD: u24,
        padding: u8,
    }),
    VAL: mmio.Mmio(packed struct(u32) {
        CURRENT: u24,
        padding: u8,
    }),
    STK_CALIB: mmio.Mmio(packed struct(u32) {
        TENMS: u24,
        padding: u8,
    }),
};
const systick: *volatile systick_t = @ptrFromInt(0xe000e010);

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
