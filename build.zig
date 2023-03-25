const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0 },
        .os_tag = .freestanding,
        .abi = .none,
    };

    // add a CLI option to enable asm output: -Dasm
    const asm_emit = b.option(bool, "asm", "enable asm output") orelse false;

    const elf = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall }),
    });
    elf.emit_asm = if (asm_emit) .emit else .no_emit;
    elf.setLinkerScriptPath(.{ .path = "linker.ld" });
    elf.install();

    const bin_step = elf.addObjCopy(.{ .format = .bin });
    const install_bin_step = b.addInstallBinFile(bin_step.getOutputSource(), "main.bin");
    install_bin_step.step.dependOn(&bin_step.step);
    b.default_step.dependOn(&install_bin_step.step);

    const flash_cmd = b.addSystemCommand(&.{
        "st-flash",
        "write",
        b.getInstallPath(install_bin_step.dir, install_bin_step.dest_rel_path),
        "0x8000000",
    });
    flash_cmd.step.dependOn(&install_bin_step.step);
    b.step("flash", "Flash and run the app on your STM32F042K6 Nucleo using st-flash utility").dependOn(&flash_cmd.step);
}
