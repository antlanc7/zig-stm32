const PERIPH_BASE: u32 = 0x40000000; // Base address of the peripherals
const AHBPERIPH_BASE: u32 = PERIPH_BASE + 0x00020000; // Base address of the AHB peripherals
const RCC_BASE: u32 = AHBPERIPH_BASE + 0x00001000; // Base address of the RCC peripheral (part of AHB)
const RCC_AHBENR_OFFSET: u32 = 0x14; // Offset of the AHB peripheral clock enable register inside the RCC peripheral
const RCC_AHBENR = @intToPtr(*volatile u32, RCC_BASE + RCC_AHBENR_OFFSET); // Pointer to the AHB peripheral clock enable register
const RCC_GPIOB_EN: u32 = 1 << 18; // Bit mask for GPIOB clock enable inside the AHB peripheral clock enable register
const AHB2PERIPH_BASE: u32 = PERIPH_BASE + 0x08000000; // Base address of the AHB2 peripherals
const GPIOB_BASE: u32 = AHB2PERIPH_BASE + 0x00000400; // Base address of the GPIOB peripheral (part of AHB2)
const GPIO_MODER_OFFSET: u32 = 0x00; // Offset of the GPIO mode register inside the GPIO peripheral
const GPIOB_MODER = @intToPtr(*volatile u32, GPIOB_BASE + GPIO_MODER_OFFSET); // Pointer to the GPIOB mode register
const GPIOB_PIN3_MODE_CLR: u32 = ~@as(u32, 0x3 << (3 * 2)); // Bit mask for clearing the bits relative to PB3
const GPIOB_PIN3_MODE_OUT: u32 = @as(u32, 0x1 << (3 * 2)); // Bit mask for clearing the bits relative to PB3
const GPIO_ODR_OFFSET: u32 = 0x14; // Offset of the GPIO output data register inside the GPIO peripheral
const GPIOB_ODR = @intToPtr(*volatile u32, GPIOB_BASE + GPIO_ODR_OFFSET); // Pointer to the GPIOB output data register
const GPIO_PIN3: u32 = 1 << 3; // Bit mask for GPIOB3

fn busy_wait(count: u32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        asm volatile (""); // Prevent the compiler from optimizing the loop away
    }
}

export fn main() void {
    RCC_AHBENR.* |= RCC_GPIOB_EN; // Enable GPIOB clock
    var temp = GPIOB_MODER.*; // Read the current value of the GPIOB mode register
    temp &= GPIOB_PIN3_MODE_CLR; // Clear all the bits relative to PB3
    temp |= GPIOB_PIN3_MODE_OUT; // Set output pin mode
    GPIOB_MODER.* = temp; // Write the new value to the GPIOB mode register
    while (true) {
        GPIOB_ODR.* ^= GPIO_PIN3; // Toggle the bit corresponding to GPIOB3
        busy_wait(1_000_000);
    }
}
