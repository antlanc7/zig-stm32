const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0 },
        .os_tag = .freestanding,
        .abi = .eabi,
    });

    const elf = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/startup.zig"),
            .target = target,
            .optimize = optimize,
            .strip = true,
        }),
    });
    elf.setLinkerScript(b.path("src/linker.ld"));
    const install_elf_step = b.addInstallArtifact(elf, .{});

    const check = b.addExecutable(.{
        .name = "check",
        .root_module = elf.root_module,
    });
    b.step("check", "check").dependOn(&check.step);

    const bin_step = elf.addObjCopy(.{ .format = .bin });
    bin_step.step.dependOn(&install_elf_step.step);

    const install_bin_step = b.addInstallBinFile(bin_step.getOutput(), "main.bin");
    install_bin_step.step.dependOn(&bin_step.step);
    b.default_step.dependOn(&install_bin_step.step);

    // add a CLI step to enable asm output: asm
    const install_asm_step = b.addInstallFile(elf.getEmittedAsm(), "bin/main.s");
    install_asm_step.step.dependOn(&install_elf_step.step);
    b.step("asm", "emit asm output").dependOn(&install_asm_step.step);

    const use_lcd = b.option(bool, "lcd", "Use LCD display HD44780") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "use_lcd", use_lcd);
    elf.root_module.addOptions("config", options);

    const bin_path = b.getInstallPath(install_bin_step.dir, install_bin_step.dest_rel_path);

    const flash_cmd = b.addSystemCommand(&.{
        "st-flash",
        "--reset",
        "write",
        bin_path,
        "0x8000000",
    });
    flash_cmd.step.dependOn(&install_bin_step.step);
    b.step("flash", "Flash and run the app on your STM32F042K6 Nucleo using st-flash utility").dependOn(&flash_cmd.step);
}
