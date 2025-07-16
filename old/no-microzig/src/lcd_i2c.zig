const systick = @import("systick.zig");
const I2C_Device = @import("i2c.zig").I2C_Device;
const std = @import("std");

const BO: u4 = 0b1000; // BOH??? deve essere sempre 1
const EN: u4 = 0b0100;
const RW: u4 = 0b0010;
const RS: u4 = 0b0001;

pub const LCD = struct {
    i2c: I2C_Device,

    // pub fn read_busy() bool {
    //     const data_u = (cmd & 0xf0);
    //     const data_l = ((cmd << 4) & 0xf0);
    //     const data_t = [_]u8{
    //         data_u | BO | EN | RW,
    //         data_u | BO | RW,
    //         data_l | BO | EN | RW,
    //         data_l | BO | RW,
    //     };
    //     self.i2c.write(&data_t);
    // }

    pub fn send_cmd(self: *LCD, cmd: u8) void {
        const data_u = (cmd & 0xf0);
        const data_l = ((cmd << 4) & 0xf0);
        const data_t = [_]u8{
            data_u | BO | EN,
            data_u | BO,
            data_l | BO | EN,
            data_l | BO,
        };
        self.i2c.write(&data_t);
    }

    pub fn send_data(self: *LCD, data: u8) void {
        const data_u = (data & 0xf0);
        const data_l = ((data << 4) & 0xf0);
        const data_t = [_]u8{
            data_u | BO | EN | RS,
            data_u | BO | RS,
            data_l | BO | EN | RS,
            data_l | BO | RS,
        };
        self.i2c.write(&data_t);
    }

    pub fn init(self: *LCD) void {
        // 4 bit initialisation
        systick.awaitTicks(50); // wait for >40ms
        self.send_cmd(0x30);
        systick.delay(5); // wait for >4.1ms
        self.send_cmd(0x30);
        systick.delay(1); // wait for >100us
        self.send_cmd(0x30);
        systick.delay(10);
        self.send_cmd(0x20); // 4bit mode
        systick.delay(10);

        // display initialisation
        self.send_cmd(0x28); // Function set --> DL=0 (4 bit mode), N = 1 (2 line display) F = 0 (5x8 characters)
        systick.delay(1);
        self.send_cmd(0x08); //Display on/off control --> D=0,C=0, B=0  ---> display off
        systick.delay(1);
        self.send_cmd(0x01); // clear display
        systick.delay(1);
        systick.delay(1);
        self.send_cmd(0x06); //Entry mode set --> I/D = 1 (increment cursor) & S = 0 (no shift)
        systick.delay(1);
        self.send_cmd(0x0C); //Display on/off control --> D = 1, C and B = 0. (Cursor and blink, last two bits)
    }

    pub fn clear(self: *LCD) void {
        self.send_cmd(0x01);
        systick.delay(5);
    }

    pub fn put_cur(self: *LCD, row: u8, col: u8) void {
        self.send_cmd(col | 0x80 | (row << 6));
    }

    pub fn send_string(self: *LCD, str: []const u8) void {
        for (str) |char| {
            self.send_data(char);
        }
    }

    pub fn send_string_clear_rest_line(self: *LCD, str: []const u8) void {
        self.send_string(str);
        for (0..(40 -| str.len)) |_| {
            self.send_data(' ');
        }
    }

    pub fn writeFn(self: *LCD, data: []const u8) error{}!usize {
        self.send_string(data);
        return data.len;
    }

    const LCDWriter = std.io.GenericWriter(*LCD, error{}, writeFn);
    pub fn writer(self: *LCD) LCDWriter {
        return .{ .context = self };
    }
};
