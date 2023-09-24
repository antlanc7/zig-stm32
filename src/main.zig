const stm32f042 = @import("lib/STM32F042x.zig").devices.STM32F042x.peripherals;
const systick = @import("systick.zig");

const IRC_FREQ = 8000000;

pub fn main() noreturn {
    systick.init(IRC_FREQ / 1000);
    stm32f042.RCC.AHBENR.IOPBEN = 1;
    stm32f042.GPIOB.MODER.MODER3 = 1;
    while (true) {
        stm32f042.GPIOB.ODR.ODR3 ^= 1; // Toggle the bit corresponding to GPIOB3 state
        systick.delay(1000);
    }
}
