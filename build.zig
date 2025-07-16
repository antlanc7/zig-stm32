const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .stm32 = true,
});

pub fn build(b: *std.Build) void {
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const firmware = mb.add_firmware(.{
        .name = "blinky",
        .target = mb.ports.stm32.chips.STM32F042K6,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/main.zig"),
    });

    mb.install_firmware(firmware, .{}); // .format = .elf
    mb.install_firmware(firmware, .{ .format = .bin });
}
