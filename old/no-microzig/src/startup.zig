const main = @import("main.zig").main;

extern const _data_loadaddr: u32;
extern var _data: u32;
extern const _edata: u32;
extern var _bss: u32;
extern const _ebss: u32;

export fn _start() noreturn {
    const data_size = @intFromPtr(&_edata) - @intFromPtr(&_data);
    const data_loadaddr = @as([*]const u8, @ptrCast(&_data_loadaddr))[0..data_size];
    const data = @as([*]u8, @ptrCast(&_data))[0..data_size];
    @memcpy(data, data_loadaddr);
    const bss_size = @intFromPtr(&_ebss) - @intFromPtr(&_bss);
    const bss = @as([*]u8, @ptrCast(&_bss))[0..bss_size];
    @memset(bss, 0);

    main();
    unreachable;
}
