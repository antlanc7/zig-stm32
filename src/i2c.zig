const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;

const I2C = *volatile chip.types.peripherals.i2c_v2.I2C;

pub const I2C_Handle = struct {
    regs: I2C,

    pub fn init(comptime i2c: I2C, comptime speed: u32, comptime irc_freq: u32) I2C_Handle {
        comptime if (speed != 400000 or irc_freq != 8000000) @compileError("i2c values not supported, please use 8mhz clock and speed 4khz");
        i2c.TIMINGR.modify(.{ .PRESC = 0, .SCLL = 0x9, .SCLH = 0x3, .SDADEL = 0x1, .SCLDEL = 0x3 });
        i2c.CR1.modify(.{ .PE = 1 });
        return .{ .regs = i2c };
    }

    pub fn write(i2c_handle: *I2C_Handle, address: u7, bytes: []const u8) void {
        const i2c = i2c_handle.regs;
        const len: u8 = @truncate(bytes.len);
        i2c.CR2.modify(.{ .SADD = @as(u8, @intCast(address)) << 1, .AUTOEND = .Automatic, .NBYTES = len, .START = 1 });
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
    const rcc = chip.peripherals.RCC;
    const gpioa = chip.peripherals.GPIOA;
    const i2c1 = chip.peripherals.I2C1;
    // RCC clock for GPIOA
    rcc.AHBENR.modify(.{ .GPIOAEN = 1 });
    // mode alternate function
    gpioa.MODER.modify(.{ .@"MODER[9]" = .Alternate, .@"MODER[10]" = .Alternate });
    // open drain
    gpioa.OTYPER.modify(.{ .@"OT[9]" = .OpenDrain, .@"OT[10]" = .OpenDrain });
    // alternate function 4 = i2c
    gpioa.AFR[1].modify(.{ .@"AFR[1]" = 4, .@"AFR[2]" = 4 }); // AFRH = AFR[1] we need to subtract 8 from the gpio pin number -> 9 - 8 = 1
    // very high speed mode
    gpioa.OSPEEDR.modify(.{ .@"OSPEEDR[9]" = .VeryHighSpeed, .@"OSPEEDR[10]" = .VeryHighSpeed });
    // enable internal pull-up (needed for i2c bus)
    gpioa.PUPDR.modify(.{ .@"PUPDR[9]" = .PullUp, .@"PUPDR[10]" = .PullUp });
    // enable i2c peripheral clock
    rcc.APB1ENR.modify(.{ .I2C1EN = 1 });
    return I2C_Handle.init(i2c1, speed, irc_freq);
}
