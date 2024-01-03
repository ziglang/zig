const std = @import("std");
const builtin = @import("builtin");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const target = b.resolveTargetQuery(.{ .os_tag = .macos });

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    exe.linkLibC();

    const check_exe = exe.checkObject();

    check_exe.checkInHeaders();
    check_exe.checkExact("cmd SEGMENT_64");
    check_exe.checkExact("segname __LINKEDIT");
    check_exe.checkExtract("fileoff {fileoff}");
    check_exe.checkExtract("filesz {filesz}");

    check_exe.checkInHeaders();
    check_exe.checkExact("cmd DYLD_INFO_ONLY");
    check_exe.checkExtract("rebaseoff {rebaseoff}");
    check_exe.checkExtract("rebasesize {rebasesize}");
    check_exe.checkExtract("bindoff {bindoff}");
    check_exe.checkExtract("bindsize {bindsize}");
    check_exe.checkExtract("lazybindoff {lazybindoff}");
    check_exe.checkExtract("lazybindsize {lazybindsize}");
    check_exe.checkExtract("exportoff {exportoff}");
    check_exe.checkExtract("exportsize {exportsize}");

    check_exe.checkInHeaders();
    check_exe.checkExact("cmd FUNCTION_STARTS");
    check_exe.checkExtract("dataoff {fstartoff}");
    check_exe.checkExtract("datasize {fstartsize}");

    check_exe.checkInHeaders();
    check_exe.checkExact("cmd DATA_IN_CODE");
    check_exe.checkExtract("dataoff {diceoff}");
    check_exe.checkExtract("datasize {dicesize}");

    check_exe.checkInHeaders();
    check_exe.checkExact("cmd SYMTAB");
    check_exe.checkExtract("symoff {symoff}");
    check_exe.checkExtract("nsyms {symnsyms}");
    check_exe.checkExtract("stroff {stroff}");
    check_exe.checkExtract("strsize {strsize}");

    check_exe.checkInHeaders();
    check_exe.checkExact("cmd DYSYMTAB");
    check_exe.checkExtract("indirectsymoff {dysymoff}");
    check_exe.checkExtract("nindirectsyms {dysymnsyms}");

    switch (builtin.cpu.arch) {
        .aarch64 => {
            check_exe.checkInHeaders();
            check_exe.checkExact("cmd CODE_SIGNATURE");
            check_exe.checkExtract("dataoff {codesigoff}");
            check_exe.checkExtract("datasize {codesigsize}");
        },
        .x86_64 => {},
        else => unreachable,
    }

    // DYLD_INFO_ONLY subsections are in order: rebase < bind < lazy < export,
    // and there are no gaps between them
    check_exe.checkComputeCompare("rebaseoff rebasesize +", .{ .op = .eq, .value = .{ .variable = "bindoff" } });
    check_exe.checkComputeCompare("bindoff bindsize +", .{ .op = .eq, .value = .{ .variable = "lazybindoff" } });
    check_exe.checkComputeCompare("lazybindoff lazybindsize +", .{ .op = .eq, .value = .{ .variable = "exportoff" } });

    // FUNCTION_STARTS directly follows DYLD_INFO_ONLY (no gap)
    check_exe.checkComputeCompare("exportoff exportsize +", .{ .op = .eq, .value = .{ .variable = "fstartoff" } });

    // DATA_IN_CODE directly follows FUNCTION_STARTS (no gap)
    check_exe.checkComputeCompare("fstartoff fstartsize +", .{ .op = .eq, .value = .{ .variable = "diceoff" } });

    // SYMTAB directly follows DATA_IN_CODE (no gap)
    check_exe.checkComputeCompare("diceoff dicesize +", .{ .op = .eq, .value = .{ .variable = "symoff" } });

    // DYSYMTAB directly follows SYMTAB (no gap)
    check_exe.checkComputeCompare("symnsyms 16 symoff * +", .{ .op = .eq, .value = .{ .variable = "dysymoff" } });

    // STRTAB follows DYSYMTAB with possible gap
    check_exe.checkComputeCompare("dysymnsyms 4 dysymoff * +", .{ .op = .lte, .value = .{ .variable = "stroff" } });

    // all LINKEDIT sections apart from CODE_SIGNATURE are 8-bytes aligned
    check_exe.checkComputeCompare("rebaseoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("bindoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("lazybindoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("exportoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("fstartoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("diceoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("symoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("stroff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("dysymoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });

    switch (builtin.cpu.arch) {
        .aarch64 => {
            // LINKEDIT segment does not extend beyond, or does not include, CODE_SIGNATURE data
            check_exe.checkComputeCompare("fileoff filesz codesigoff codesigsize + - -", .{
                .op = .eq,
                .value = .{ .literal = 0 },
            });

            // CODE_SIGNATURE data offset is 16-bytes aligned
            check_exe.checkComputeCompare("codesigoff 16 %", .{ .op = .eq, .value = .{ .literal = 0 } });
        },
        .x86_64 => {
            // LINKEDIT segment does not extend beyond, or does not include, strtab data
            check_exe.checkComputeCompare("fileoff filesz stroff strsize + - -", .{
                .op = .eq,
                .value = .{ .literal = 0 },
            });
        },
        else => unreachable,
    }
    test_step.dependOn(&check_exe.step);

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("Hello!\n");
    test_step.dependOn(&run.step);
}
