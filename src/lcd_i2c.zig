const systick = @import("systick.zig");
const i2c_lib = @import("i2c.zig");
const std = @import("std");

pub fn LCD(comptime i2c: i2c_lib.I2C, comptime address: u7) type {
    return struct {
        pub fn lcd_send_cmd(cmd: u8) void {
            const data_u = (cmd & 0xf0);
            const data_l = ((cmd << 4) & 0xf0);
            const data_t = [_]u8{
                data_u | 0x0C, //en=1, rs=1
                data_u | 0x08, //en=0, rs=1
                data_l | 0x0C, //en=1, rs=1
                data_l | 0x08, //en=0, rs=1
            };
            i2c_lib.i2c_write(i2c, address, &data_t);
        }

        pub fn lcd_send_data(data: u8) void {
            const data_u = (data & 0xf0);
            const data_l = ((data << 4) & 0xf0);
            const data_t = [_]u8{
                data_u | 0x0D, //en=1, rs=1
                data_u | 0x09, //en=0, rs=1
                data_l | 0x0D, //en=1, rs=1
                data_l | 0x09, //en=0, rs=1
            };
            i2c_lib.i2c_write(i2c, address, &data_t);
        }

        pub fn lcd_init() void {
            // 4 bit initialisation
            systick.awaitTicks(50); // wait for >40ms
            lcd_send_cmd(0x30);
            systick.delay(5); // wait for >4.1ms
            lcd_send_cmd(0x30);
            systick.delay(1); // wait for >100us
            lcd_send_cmd(0x30);
            systick.delay(10);
            lcd_send_cmd(0x20); // 4bit mode
            systick.delay(10);

            // display initialisation
            lcd_send_cmd(0x28); // Function set --> DL=0 (4 bit mode), N = 1 (2 line display) F = 0 (5x8 characters)
            systick.delay(1);
            lcd_send_cmd(0x08); //Display on/off control --> D=0,C=0, B=0  ---> display off
            systick.delay(1);
            lcd_send_cmd(0x01); // clear display
            systick.delay(1);
            systick.delay(1);
            lcd_send_cmd(0x06); //Entry mode set --> I/D = 1 (increment cursor) & S = 0 (no shift)
            systick.delay(1);
            lcd_send_cmd(0x0C); //Display on/off control --> D = 1, C and B = 0. (Cursor and blink, last two bits)
        }

        pub fn lcd_clear() void {
            lcd_send_cmd(0x80);
            for (0..70) |_| {
                lcd_send_data(' ');
            }
        }

        pub fn lcd_put_cur(row: u2, col: u8) void {
            lcd_send_cmd(col | 0x80 | (row << 6));
        }

        pub fn lcd_send_string(str: []const u8) void {
            for (str) |char| {
                lcd_send_data(char);
            }
        }

        pub fn lcd_send_string_clear_rest_line(str: []const u8) void {
            lcd_send_string(str);
            for (0..(40 -| str.len)) |_| {
                lcd_send_data(' ');
            }
        }
    };
}
