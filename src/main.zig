const PERIPH_BASE = 0x40000000; // Base address of the peripherals
const AHBPERIPH_BASE = PERIPH_BASE + 0x00020000; // Base address of the AHB peripherals
const RCC_BASE = AHBPERIPH_BASE + 0x00001000; // Base address of the RCC peripheral (part of AHB)
const RCC_AHBENR_OFFSET = 0x14; // Offset of the AHB peripheral clock enable register inside the RCC peripheral
const RCC_AHBENR = @intToPtr(*volatile u32, RCC_BASE + RCC_AHBENR_OFFSET); // Pointer to the AHB peripheral clock enable register
const AHB2PERIPH_BASE = PERIPH_BASE + 0x08000000; // Base address of the AHB2 peripherals
const GPIOB_BASE = AHB2PERIPH_BASE + 0x00000400; // Base address of the GPIOB peripheral (part of AHB2)
const GPIO_MODER_OFFSET = 0x00; // Offset of the GPIO mode register inside the GPIO peripheral
const GPIOB_MODER = @intToPtr(*volatile u32, GPIOB_BASE + GPIO_MODER_OFFSET); // Pointer to the GPIOB mode register
const GPIO_ODR_OFFSET = 0x14; // Offset of the GPIO output data register inside the GPIO peripheral
const GPIOB_ODR = @intToPtr(*volatile u32, GPIOB_BASE + GPIO_ODR_OFFSET); // Pointer to the GPIOB output data register
const GPIO_PIN3 = 1 << 3; // Bit mask for GPIOB3

export fn main() void {
    RCC_AHBENR.* |= @as(u32, 1 << 18); // Enable GPIOB clock
    var temp: u32 = GPIOB_MODER.*; // Read the current value of the GPIOB mode register
    temp &= ~@as(u32, 0x3 << (3 * 2)); // Clear all the bits relative to PB3
    temp |= @as(u32, 0x1 << (3 * 2)); // Now set the desired configuration: Out PP, 2MHz
    GPIOB_MODER.* = temp; // Write the new value to the GPIOB mode register
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
