const std = @import("std");
const stm32 = @import("lib/STM32F042x.zig");
const GPIO = @import("gpio.zig");

const I2C = *volatile stm32.types.peripherals.I2C1;

const rcc = stm32.peripherals.RCC;

pub const I2C1 = stm32.peripherals.I2C1;

const I2C_Handle = @This();
regs: I2C,

pub fn init(comptime i2c: I2C, comptime speed: u32, comptime irc_freq: u32) I2C_Handle {
    comptime if (speed != 400000 or irc_freq != 8000000) @compileError("i2c values not supported, please use 8mhz clock and speed 4khz");
    // enable i2c peripheral clock
    rcc.APB1ENR.modify(.{ .I2C1EN = 1 });
    i2c.TIMINGR.modify(.{ .PRESC = 0, .SCLL = 0x9, .SCLH = 0x3, .SDADEL = 0x1, .SCLDEL = 0x3 });
    i2c.CR1.modify(.{ .PE = 1 });
    return .{ .regs = i2c };
}

pub fn write(self: I2C_Handle, address: u7, bytes: []const u8) void {
    const len: u8 = @truncate(bytes.len);
    self.regs.CR2.modify(.{ .SADD1 = address, .AUTOEND = 1, .NBYTES = len, .START = 1 });
    for (bytes) |byte| {
        while (self.regs.ISR.read().TXE != 1) {}
        self.regs.TXDR.write_raw(byte);
    }
    while (self.regs.ISR.read().TXE != 1) {}
    self.regs.CR2.write_raw(0);
}

pub fn attach_pins(self: I2C_Handle, comptime scl: GPIO, comptime sda: GPIO) void {
    const i2c_pins = switch (self.regs) {
        I2C1 => i2c_pinmap.I2C1,
        else => unreachable,
    };
    inline for (i2c_pins.scl.pins) |pin| {
        if (pin.gpio == scl.gpio and pin.pin == scl.pin) break;
    } else @compileError("Invalid SCL pin");
    inline for (i2c_pins.sda.pins) |pin| {
        if (pin.gpio == sda.gpio and pin.pin == sda.pin) break;
    } else @compileError("Invalid SDA pin");

    inline for ([_]GPIO{ scl, sda }) |pin| {
        pin.init_mode(.alternate);
        pin.set_alternate_function(4);
        pin.set_speed(.high);
        pin.set_output_type(.open_drain);
        pin.set_pull_up_down_mode(.pull_up);
    }
}

pub const I2C_Device = struct {
    i2c: I2C_Handle,
    address: u7,

    pub fn write(self: *I2C_Device, bytes: []const u8) void {
        self.i2c.write(self.address, bytes);
    }
};

pub const i2c_pinmap = struct {
    pub const I2C1 = struct {
        pub const scl = struct {
            pub const PA9: GPIO = .{ .gpio = GPIO.GPIOA, .pin = 9 };
            pub const PA11: GPIO = .{ .gpio = GPIO.GPIOA, .pin = 11 };
            pub const PB6: GPIO = .{ .gpio = GPIO.GPIOB, .pin = 6 };
            pub const PF1: GPIO = .{ .gpio = GPIO.GPIOF, .pin = 1 };

            pub const pins = [_]GPIO{ PA9, PA11, PB6, PF1 };
        };

        pub const sda = struct {
            pub const PA10: GPIO = .{ .gpio = GPIO.GPIOA, .pin = 10 };
            pub const PA12: GPIO = .{ .gpio = GPIO.GPIOA, .pin = 12 };
            pub const PB7: GPIO = .{ .gpio = GPIO.GPIOB, .pin = 7 };
            pub const PF0: GPIO = .{ .gpio = GPIO.GPIOF, .pin = 0 };

            pub const pins = [_]GPIO{ PA10, PA12, PB7, PF0 };
        };
    };
};
