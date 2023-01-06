pub const PERIPH_BASE = 0x40000000;
pub const AHBPERIPH_BASE = PERIPH_BASE + 0x00020000;
pub const RCC_BASE = AHBPERIPH_BASE + 0x00001000;
pub const RCC_AHBENR_OFFSET = 0x14;
pub const RCC_AHBENR = @intToPtr(*volatile u32, RCC_BASE + RCC_AHBENR_OFFSET);
pub const AHB2PERIPH_BASE = PERIPH_BASE + 0x08000000;
pub const GPIOB_BASE = AHB2PERIPH_BASE + 0x00000400;
pub const GPIO_MODER_OFFSET = 0x00;
pub const GPIOB_MODER = @intToPtr(*volatile u32, GPIOB_BASE + GPIO_MODER_OFFSET);
pub const GPIO_ODR_OFFSET = 0x14;
pub const GPIOB_ODR = @intToPtr(*volatile u32, GPIOB_BASE + GPIO_ODR_OFFSET);
pub const GPIO_PIN3 = 1 << 3;

export fn main() void {
    RCC_AHBENR.* |= @as(u32, 1 << 18); // Enable GPIOB clock
    var temp: u32 = GPIOB_MODER.*;
    temp &= ~@as(u32, 0x3 << (3 * 2)); // Clear all the bits relative to PB3
    temp |= @as(u32, 0x1 << (3 * 2)); // Now set the desired configuration: Out PP, 2MHz
    GPIOB_MODER.* = temp;
    while (true) {
        var i: u32 = 0;
        GPIOB_ODR.* ^= @as(u32, GPIO_PIN3); // Toggle the bit corresponding to GPIOB3
        while (i < 10_00_000) : (i += 1) { // Wait a bit
            comptime {
                asm volatile ("");
            }
        }
    }
}
