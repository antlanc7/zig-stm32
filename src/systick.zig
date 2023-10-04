const stm32f042 = @import("lib/STM32F042x.zig").devices.STM32F042x.peripherals;
const mmio = @import("lib/mmio.zig");

const systick_t = extern struct {
    STK_CSR: mmio.Mmio(packed struct(u32) {
        ENABLE: u1,
        TICKINT: u1,
        CLKSOURCE: u1,
        padding: u13,
        COUNTFLAG: u1,
        padding2: u15,
    }),
    STK_RVR: mmio.Mmio(packed struct(u32) {
        RELOAD: u24,
        padding: u8,
    }),
    STK_CVR: mmio.Mmio(packed struct(u32) {
        CURRENT: u24,
        padding: u8,
    }),
    STK_CALIB: mmio.Mmio(packed struct(u32) {
        TENMS: u24,
        padding: u8,
    }),
};
const SYSTICK: *volatile systick_t = @ptrFromInt(0xe000e010);

pub fn init(reload: u24) void {
    stm32f042.RCC.APB2ENR.modify(.{ .SYSCFGEN = 1 });
    SYSTICK.STK_RVR.modify(.{ .RELOAD = reload });
    SYSTICK.STK_CVR.write_raw(0);
    SYSTICK.STK_CSR.modify(.{
        .CLKSOURCE = 1,
        .TICKINT = 1,
        .ENABLE = 1,
    });
}

var systick: u32 = 0;
export fn sysTick_Handler() void {
    systick +%= 1;
}

pub fn delay(ms: u32) void {
    awaitTicks(ms + systick);
}

pub fn getTicks() u32 {
    return systick;
}

pub fn awaitTicks(ms: u32) void {
    while (systick < ms) {
        asm volatile ("");
    }
}
