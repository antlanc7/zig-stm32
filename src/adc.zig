const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;

const ADC = *volatile chip.types.peripherals.adc_v1.ADC;

pub const ADC_Handle = struct {
    regs: ADC,

    pub fn init(comptime adc: ADC) ADC_Handle {
        chip.peripherals.RCC.APB2ENR.modify(.{ .ADCEN = 1 });
        adc.CR.modify(.{ .ADCAL = 1 });
        while (adc.CR.read().ADCAL == 1) {}
        adc.CR.modify(.{ .ADEN = 1 });
        adc.CHSELR.modify(.{ .@"CHSEL x[0]" = 1 });
        adc.CFGR1.modify(.{ .CONT = 1 });
        adc.CR.modify(.{ .ADSTART = 1 });
        return .{ .regs = adc };
    }

    pub fn read(self: ADC_Handle) u16 {
        while (self.regs.ISR.read().EOC == 0) {}
        return self.regs.DR.read().DATA;
    }
};

pub fn init_adc1() ADC_Handle {
    const rcc = chip.peripherals.RCC;
    const gpioa = chip.peripherals.GPIOA;
    const adc1 = chip.peripherals.ADC1;
    // RCC clock for GPIOA
    rcc.AHBENR.modify(.{ .GPIOAEN = 1 });
    // mode analog for PA0
    gpioa.MODER.modify(.{ .@"MODER[0]" = .Analog });
    return ADC_Handle.init(adc1);
}
