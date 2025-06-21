const std = @import("std");
const ConfigHeader = std.Build.Step.ConfigHeader;

pub fn build(b: *std.Build) void {
    const config_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = b.path("config.h.in") },
            .include_path = "config.h",
        },
        .{
            .noval = null,
            .trueval = true,
            .falseval = false,
            .zeroval = 0,
            .oneval = 1,
            .tenval = 10,
            .stringval = "test",

            .boolnoval = void{},
            .booltrueval = true,
            .boolfalseval = false,
            .boolzeroval = 0,
            .booloneval = 1,
            .booltenval = 10,
            .boolstringval = "test",
        },
    );

    const pwd_sh = b.addConfigHeader(
        .{
            .style = .{ .cmake = b.path("pwd.sh.in") },
            .include_path = "pwd.sh",
        },
        .{ .DIR = "${PWD}" },
    );

    const sigil_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = b.path("sigil.h.in") },
            .include_path = "sigil.h",
        },
        .{},
    );

    const stack_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = b.path("stack.h.in") },
            .include_path = "stack.h",
        },
        .{
            .AT = "@",
            .UNDERSCORE = "_",
            .NEST_UNDERSCORE_PROXY = "UNDERSCORE",
            .NEST_PROXY = "NEST_UNDERSCORE_PROXY",
        },
    );

    const wrapper_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = b.path("wrapper.h.in") },
            .include_path = "wrapper.h",
        },
        .{
            .DOLLAR = "$",
            .TEXT = "TRAP",

            .STRING = "TEXT",
            .STRING_AT = "@STRING@",
            .STRING_CURLY = "{STRING}",
            .STRING_VAR = "${STRING}",
        },
    );

    const check_exe = b.addExecutable(.{
        .name = "check",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .root_source_file = b.path("check.zig"),
        }),
    });

    const test_step = b.step("test", "Test it");
    b.default_step = test_step;
    test_step.dependOn(addCheck(b, check_exe, config_header));
    test_step.dependOn(addCheck(b, check_exe, pwd_sh));
    test_step.dependOn(addCheck(b, check_exe, sigil_header));
    test_step.dependOn(addCheck(b, check_exe, stack_header));
    test_step.dependOn(addCheck(b, check_exe, wrapper_header));
}

fn addCheck(
    b: *std.Build,
    check_exe: *std.Build.Step.Compile,
    ch: *ConfigHeader,
) *std.Build.Step {
    // We expect `ch.include_path` to only be a basename to infer where the expected output is.
    std.debug.assert(std.fs.path.dirname(ch.include_path) == null);
    const expected_path = b.fmt("expected_{s}", .{ch.include_path});

    const run_check = b.addRunArtifact(check_exe);
    run_check.addFileArg(ch.getOutputFile());
    run_check.addFileArg(b.path(expected_path));

    return &run_check.step;
}
