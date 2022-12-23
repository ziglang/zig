const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const LibExeObjectStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const exe = b.addExecutable("main", "main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.linkLibC();

    const check_exe = exe.checkObject(.macho);

    check_exe.checkStart("cmd SEGMENT_64");
    check_exe.checkNext("segname __LINKEDIT");
    check_exe.checkNext("fileoff {fileoff}");
    check_exe.checkNext("filesz {filesz}");

    check_exe.checkStart("cmd DYLD_INFO_ONLY");
    check_exe.checkNext("rebaseoff {rebaseoff}");
    check_exe.checkNext("rebasesize {rebasesize}");
    check_exe.checkNext("bindoff {bindoff}");
    check_exe.checkNext("bindsize {bindsize}");
    check_exe.checkNext("lazybindoff {lazybindoff}");
    check_exe.checkNext("lazybindsize {lazybindsize}");
    check_exe.checkNext("exportoff {exportoff}");
    check_exe.checkNext("exportsize {exportsize}");

    check_exe.checkStart("cmd SYMTAB");
    check_exe.checkNext("symoff {symoff}");
    check_exe.checkNext("stroff {stroff}");
    check_exe.checkNext("strsize {strsize}");

    check_exe.checkStart("cmd DYSYMTAB");
    check_exe.checkNext("indirectsymoff {dysymoff}");

    switch (builtin.cpu.arch) {
        .aarch64 => {
            check_exe.checkStart("cmd CODE_SIGNATURE");
            check_exe.checkNext("dataoff {codesigoff}");
            check_exe.checkNext("datasize {codesigsize}");
        },
        .x86_64 => {},
        else => unreachable,
    }

    // Next check: DYLD_INFO_ONLY subsections are in order: rebase < bind < lazy < export
    check_exe.checkComputeCompare("rebaseoff ", .{ .op = .lt, .value = .{ .variable = "bindoff" } });
    check_exe.checkComputeCompare("bindoff", .{ .op = .lt, .value = .{ .variable = "lazybindoff" } });
    check_exe.checkComputeCompare("lazybindoff", .{ .op = .lt, .value = .{ .variable = "exportoff" } });

    // Next check: DYLD_INFO_ONLY subsections do not overlap
    check_exe.checkComputeCompare("rebaseoff rebasesize +", .{ .op = .lte, .value = .{ .variable = "bindoff" } });
    check_exe.checkComputeCompare("bindoff bindsize +", .{ .op = .lte, .value = .{ .variable = "lazybindoff" } });
    check_exe.checkComputeCompare("lazybindoff lazybindsize +", .{ .op = .lte, .value = .{ .variable = "exportoff" } });

    // Next check: we maintain order: symtab < dysymtab < strtab
    check_exe.checkComputeCompare("symoff", .{ .op = .lt, .value = .{ .variable = "dysymoff" } });
    check_exe.checkComputeCompare("dysymoff", .{ .op = .lt, .value = .{ .variable = "stroff" } });

    // Next check: all LINKEDIT sections apart from CODE_SIGNATURE are 8-bytes aligned
    check_exe.checkComputeCompare("rebaseoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("bindoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("lazybindoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("exportoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("symoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("stroff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_exe.checkComputeCompare("dysymoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });

    switch (builtin.cpu.arch) {
        .aarch64 => {
            // Next check: LINKEDIT segment does not extend beyond, or does not include, CODE_SIGNATURE data
            check_exe.checkComputeCompare("fileoff filesz codesigoff codesigsize + - -", .{
                .op = .eq,
                .value = .{ .literal = 0 },
            });

            // Next check: CODE_SIGNATURE data offset is 16-bytes aligned
            check_exe.checkComputeCompare("codesigoff 16 %", .{ .op = .eq, .value = .{ .literal = 0 } });
        },
        .x86_64 => {
            // Next check: LINKEDIT segment does not extend beyond, or does not include, strtab data
            check_exe.checkComputeCompare("fileoff filesz stroff strsize + - -", .{
                .op = .eq,
                .value = .{ .literal = 0 },
            });
        },
        else => unreachable,
    }

    const run = check_exe.runAndCompare();
    run.expectStdOutEqual("Hello!\n");
    test_step.dependOn(&run.step);
}
