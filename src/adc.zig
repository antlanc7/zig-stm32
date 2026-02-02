const std = @import("std");
const stm32 = @import("lib/STM32F042x.zig");
const GPIO = @import("gpio.zig");

const ADC = *volatile stm32.types.peripherals.ADC;
pub const adc1 = stm32.peripherals.ADC;
const rcc = stm32.peripherals.RCC;

const ADC_Handle = @This();
regs: ADC,

pub fn init(regs: ADC) ADC_Handle {
    rcc.APB2ENR.modify(.{ .ADCEN = 1 });
    regs.CR.modify(.{ .ADCAL = 1 });
    while (regs.CR.read().ADCAL == 1) {} // wait for calibration
    regs.CR.modify(.{ .ADEN = 1 });
    while (regs.ISR.read().ADRDY == 0) {} // wait for ready
    return .{ .regs = regs };
}

pub fn read(self: ADC_Handle, chselr: u32) u16 {
    self.regs.CHSELR.write_raw(chselr);
    self.regs.CR.modify(.{ .ADSTART = 1 });
    while (self.regs.ISR.read().EOC == 0) {}
    return self.regs.DR.read().DATA;
}

pub fn channel(self: *ADC_Handle, comptime adc_pin: GPIO) Channel {
    return .init(self, adc_pin);
}

pub const Channel = struct {
    adc: *ADC_Handle,
    chselr: u32,

    const pin_channel_map = [_]struct {
        gpio_pin: GPIO,
        channel: u4,
    }{
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOA, .pin = 0 }, .channel = 0 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOA, .pin = 1 }, .channel = 1 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOA, .pin = 2 }, .channel = 2 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOA, .pin = 3 }, .channel = 3 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOA, .pin = 4 }, .channel = 4 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOA, .pin = 5 }, .channel = 5 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOA, .pin = 6 }, .channel = 6 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOA, .pin = 7 }, .channel = 7 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOB, .pin = 0 }, .channel = 8 },
        .{ .gpio_pin = .{ .gpio = GPIO.GPIOB, .pin = 1 }, .channel = 9 },
    };

    // comptime function to map gpio pin to adc channel
    fn channelFromGpio(comptime adc_pin: GPIO) u4 {
        inline for (pin_channel_map) |entry| {
            if (entry.gpio_pin.gpio == adc_pin.gpio and entry.gpio_pin.pin == adc_pin.pin) {
                return entry.channel;
            }
        }
        const error_msg = std.fmt.comptimePrint(
            "GPIO{c} pin {d} does not support ADC",
            .{ adc_pin.get_gpio_port_name(), adc_pin.pin },
        );
        @compileError(error_msg);
    }

    pub fn init(adc: *ADC_Handle, comptime adc_pin: GPIO) Channel {
        const chn = comptime channelFromGpio(adc_pin);
        adc_pin.init_mode(.analog);
        return .{
            .adc = adc,
            .chselr = 1 << chn,
        };
    }

    pub fn read(self: Channel) u16 {
        return self.adc.read(self.chselr);
    }
};
