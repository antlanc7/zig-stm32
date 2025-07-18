const std = @import("std");
const stm32f042 = @import("lib/STM32F042x.zig");

const I2C = *volatile stm32f042.types.peripherals.I2C1;

pub const I2C_Handle = struct {
    regs: I2C,

    pub fn init(comptime i2c: I2C, comptime speed: u32, comptime irc_freq: u32) I2C_Handle {
        comptime if (speed != 400000 or irc_freq != 8000000) @compileError("i2c values not supported, please use 8mhz clock and speed 4khz");
        i2c.CR1.modify(.{ .SWRST = 0 }); // assert i2c reset mode
        i2c.TIMINGR.modify(.{ .PRESC = 0, .SCLL = 0x9, .SCLH = 0x3, .SDADEL = 0x1, .SCLDEL = 0x3 });
        i2c.CR1.modify(.{ .PE = 1 });
        return .{ .regs = i2c };
    }

    pub fn write(i2c_handle: *I2C_Handle, address: u7, bytes: []const u8) void {
        const i2c = i2c_handle.regs;
        const len: u8 = @truncate(bytes.len);
        i2c.CR2.modify(.{ .SADD1 = address, .AUTOEND = 1, .NBYTES = len, .START = 1 });
        for (bytes) |byte| {
            while (i2c.ISR.read().TXE != 1) {}
            i2c.TXDR.write_raw(byte);
        }
        // while (i2c.ISR.read().TCR != 1) {}
        while (i2c.ISR.read().TXE != 1) {}
        i2c.CR2.write_raw(0);
    }
};

pub const I2C_Device = struct {
    i2c: I2C_Handle,
    address: u7,

    pub fn write(self: *I2C_Device, bytes: []const u8) void {
        self.i2c.write(self.address, bytes);
    }
};

pub fn init_i2c1_pa9_pa10(comptime speed: u32, comptime irc_freq: u32) I2C_Handle {
    const rcc = stm32f042.devices.STM32F042x.peripherals.RCC;
    const gpioa = stm32f042.devices.STM32F042x.peripherals.GPIOA;
    const i2c1 = stm32f042.devices.STM32F042x.peripherals.I2C1;
    // RCC clock for GPIOA
    rcc.AHBENR.modify(.{ .IOPAEN = 1 });
    // mode alternate function
    gpioa.MODER.modify(.{ .MODER9 = 2, .MODER10 = 2 });
    // open drain
    gpioa.OTYPER.modify(.{ .OT9 = 1, .OT10 = 1 });
    // alternate function 4 = i2c
    gpioa.AFRH.modify(.{ .AFRH9 = 4, .AFRH10 = 4 });
    // high speed mode
    gpioa.OSPEEDR.modify(.{ .OSPEEDR9 = 3, .OSPEEDR10 = 3 });
    // enable internal pull-up (needed for i2c bus)
    gpioa.PUPDR.modify(.{ .PUPDR9 = 1, .PUPDR10 = 1 });
    // enable i2c peripheral clock
    rcc.APB1ENR.modify(.{ .I2C1EN = 1 });
    return I2C_Handle.init(i2c1, speed, irc_freq);
}
