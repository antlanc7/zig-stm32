const stm32f042 = @import("lib/STM32F042x.zig").devices.STM32F042x.peripherals;

fn busy_wait(count: u32) void {
    const p: *volatile u32 = @constCast(&count); // Prevent the compiler from optimizing the loop away
    while (p.* > 0) : (p.* -= 1) {}
}

export fn main() void {
    stm32f042.RCC.AHBENR.IOPBEN = 1;
    stm32f042.GPIOB.MODER.MODER3 = 1;
    while (true) {
        stm32f042.GPIOB.ODR.ODR3 ^= 1; // Toggle the bit corresponding to GPIOB3 state
        busy_wait(1_000_000);
    }
}
