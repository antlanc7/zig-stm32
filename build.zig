const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .stm32 = true,
});

pub fn build(b: *std.Build) void {
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const firmware = mb.add_firmware(.{
        .name = "main",
        .target = mb.ports.stm32.chips.STM32F042K6,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/main.zig"),
    });

    mb.install_firmware(firmware, .{}); // .format = .elf
    mb.install_firmware(firmware, .{ .format = .bin });

    const use_lcd = b.option(bool, "lcd", "Use LCD display HD44780 with I2C") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "use_lcd", use_lcd);
    firmware.app_mod.addOptions("config", options);
}
