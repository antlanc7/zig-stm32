const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0 },
        .os_tag = .freestanding,
        .abi = .none,
    };

    // sets the release mode as small: -Drelease
    b.setPreferredReleaseMode(.ReleaseSmall);

    // add a CLI option to enable asm output: -Dasm
    const asm_emit = b.option(bool, "asm", "enable asm output") orelse false;

    const elf = b.addExecutable("main.elf", "src/main.zig");
    elf.emit_asm = if (asm_emit) .emit else .no_emit;
    elf.setTarget(target);
    elf.setBuildMode(b.standardReleaseOptions());
    elf.setLinkerScriptPath(.{ .path = "linker.ld" });
    elf.install();

    const bin = b.addInstallRaw(elf, "main.bin", .{});
    bin.step.dependOn(&elf.step);
    b.step("bin", "Convert ELF to binary file to be flashed").dependOn(&bin.step);

    const flash_cmd = b.addSystemCommand(&.{
        "st-flash",
        "write",
        b.getInstallPath(bin.dest_dir, bin.dest_filename),
        "0x8000000",
    });
    flash_cmd.step.dependOn(&bin.step);
    flash_cmd.expected_exit_code = null; // st-flash already prints an error message on failure
    b.step("flash", "Flash and run the app on your STM32F042K6 Nucleo using st-flash utility").dependOn(&flash_cmd.step);
}
