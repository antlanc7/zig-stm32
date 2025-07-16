const std = @import("std");
const stm32f042 = @import("lib/STM32F042x.zig");

const GPIO = *volatile stm32f042.types.peripherals.GPIO;

pub fn init_output_mode(comptime gpio: GPIO, comptime pin: u4) void {
    const rcc = stm32f042.devices.STM32F042x.peripherals.RCC;
    const gpioa = stm32f042.devices.STM32F042x.peripherals.GPIOA;
    const gpiob = stm32f042.devices.STM32F042x.peripherals.GPIOB;
    const gpioc = stm32f042.devices.STM32F042x.peripherals.GPIOC;
    const gpiof = stm32f042.devices.STM32F042x.peripherals.GPIOF;
    var rccahbenr = rcc.AHBENR.read();
    @field(rccahbenr, "IOP" ++ switch (gpio) {
        gpioa => "A",
        gpiob => "B",
        gpioc => "C",
        gpiof => "F",
        else => unreachable,
    } ++ "EN") = 1;
    rcc.AHBENR.write(rccahbenr);
    var moder = gpio.MODER.read();
    @field(moder, std.fmt.comptimePrint("MODER{}", .{pin})) = 1;
    gpio.MODER.write(moder);
}

pub fn toggle(comptime gpio: GPIO, comptime pin: u4) void {
    var odr = gpio.ODR.read();
    @field(odr, std.fmt.comptimePrint("ODR{}", .{pin})) ^= 1;
    gpio.ODR.write(odr);
}
