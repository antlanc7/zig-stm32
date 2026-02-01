const std = @import("std");
const stm32 = @import("lib/STM32F042x.zig");

const ADC = *volatile stm32.types.peripherals.ADC;

const GPIO = @import("gpio.zig");

const ADC_Handle = @This();
regs: ADC,

pub fn init(comptime adc: ADC) ADC_Handle {
    stm32.peripherals.RCC.APB2ENR.modify(.{ .ADCEN = 1 });
    adc.CR.modify(.{ .ADCAL = 1 });
    while (adc.CR.read().ADCAL == 1) {}
    adc.CR.modify(.{ .ADEN = 1 });
    adc.CHSELR.modify(.{ .CHSEL0 = 1 });
    adc.CFGR1.modify(.{ .CONT = 1 });
    adc.CR.modify(.{ .ADSTART = 1 });
    return .{ .regs = adc };
}

pub fn read(self: ADC_Handle) u16 {
    while (self.regs.ISR.read().EOC == 0) {}
    return self.regs.DR.read().DATA;
}

pub fn init_adc1() ADC_Handle {
    const rcc = stm32.peripherals.RCC;
    const gpioa = stm32.peripherals.GPIOA;
    const adc1 = stm32.peripherals.ADC;
    // RCC clock for GPIOA
    rcc.AHBENR.modify(.{ .IOPAEN = 1 });
    // mode analog for PA0
    gpioa.MODER.modify(.{ .MODER0 = @intFromEnum(GPIO.Mode.Analog) });
    return .init(adc1);
}
