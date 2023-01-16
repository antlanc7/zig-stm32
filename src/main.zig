const PERIPH_BASE: u32 = 0x40000000;
const AHB_PERIPH_BASE: u32 = PERIPH_BASE + 0x00020000;
const RCC_BASE: u32 = AHB_PERIPH_BASE + 0x00001000;
const RCC_AHBENR_OFFSET: u32 = 0x14;
const RCC_AHBENR = @intToPtr(*volatile u32, RCC_BASE + RCC_AHBENR_OFFSET);
const RCC_GPIOB_EN: u32 = 1 << 18; // Bit mask for GPIOB clock enable inside the AHB peripheral clock enable register
const AHB2_PERIPH_BASE: u32 = PERIPH_BASE + 0x08000000;
const GPIOB_BASE: u32 = AHB2_PERIPH_BASE + 0x00000400;
const GPIO_MODER_OFFSET: u32 = 0x00;
const GPIOB_MODER = @intToPtr(*volatile u32, GPIOB_BASE + GPIO_MODER_OFFSET);
const GPIOB_PIN3_MODE_CLR: u32 = ~@as(u32, 0x3 << (3 * 2)); // Bit mask for clearing the bits relative to PB3
const GPIOB_PIN3_MODE_OUT: u32 = @as(u32, 0x1 << (3 * 2)); // Bit mask for clearing the bits relative to PB3
const GPIO_ODR_OFFSET: u32 = 0x14;
const GPIOB_ODR = @intToPtr(*volatile u32, GPIOB_BASE + GPIO_ODR_OFFSET);
const GPIO_PIN3: u32 = 1 << 3; // Bit mask for GPIOB3 in the GPIO ODR register

fn busy_wait(count: u32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        asm volatile (""); // Prevent the compiler from optimizing the loop away
    }
}

export fn main() void {
    RCC_AHBENR.* |= RCC_GPIOB_EN;
    var mode_reg_value = GPIOB_MODER.*;
    mode_reg_value &= GPIOB_PIN3_MODE_CLR; // Clear the bits corresponding to GPIOB3
    mode_reg_value |= GPIOB_PIN3_MODE_OUT; // Set the bits corresponding to GPIOB3 to output mode
    GPIOB_MODER.* = mode_reg_value;
    while (true) {
        GPIOB_ODR.* ^= GPIO_PIN3; // Toggle the bit corresponding to GPIOB3 state
        busy_wait(1_000_000);
    }
}
