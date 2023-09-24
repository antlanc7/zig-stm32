const stm32f042 = @import("lib/STM32F042x.zig").devices.STM32F042x.peripherals;

const systick_t = packed struct {
    STK_CSR: packed struct(u32) {
        ENABLE: u1,
        TICKINT: u1,
        CLKSOURCE: u1,
        padding: u13,
        COUNTFLAG: u1,
        padding2: u15,
    },
    STK_RVR: packed struct(u32) {
        RELOAD: u24,
        padding: u8,
    },
    STK_CVR: packed struct(u32) {
        CURRENT: u24,
        padding: u8,
    },
    STK_CALIB: packed struct(u32) {
        TENMS: u24,
        padding: u8,
    },
};
const SYSTICK: *volatile systick_t = @ptrFromInt(0xe000e010);

pub fn init(reload: u24) void {
    stm32f042.RCC.APB2ENR.SYSCFGEN = 1;

    SYSTICK.STK_RVR.RELOAD = reload;
    SYSTICK.STK_CVR.CURRENT = 0;
    SYSTICK.STK_CSR.CLKSOURCE = 1;
    SYSTICK.STK_CSR.TICKINT = 1;
    SYSTICK.STK_CSR.ENABLE = 1;
}

var systick: u32 = 0;
const systick_ptr: *volatile u32 = &systick;
export fn sysTick_Handler() void {
    systick_ptr.* +%= 1;
}

pub fn delay(ms: u32) void {
    const start = systick_ptr.*;
    while (systick_ptr.* - start < ms) {
        asm volatile ("");
    }
}

pub fn getTicks() u32 {
    return systick_ptr.*;
}
