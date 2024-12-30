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

    const test_step = b.step("test", "Test it");
    test_step.makeFn = compare_headers;
    test_step.dependOn(&config_header.step);
    test_step.dependOn(&pwd_sh.step);
    test_step.dependOn(&sigil_header.step);
    test_step.dependOn(&stack_header.step);
    test_step.dependOn(&wrapper_header.step);
}

fn compare_headers(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
    _ = options;
    const allocator = step.owner.allocator;
    const expected_fmt = "expected_{s}";

    for (step.dependencies.items) |config_header_step| {
        const config_header: *ConfigHeader = @fieldParentPtr("step", config_header_step);

        const zig_header_path = config_header.output_file.path orelse @panic("Could not locate header file");

        const cwd = std.fs.cwd();

        const cmake_header_path = try std.fmt.allocPrint(allocator, expected_fmt, .{std.fs.path.basename(zig_header_path)});
        defer allocator.free(cmake_header_path);

        const cmake_header = try cwd.readFileAlloc(allocator, cmake_header_path, config_header.max_bytes);
        defer allocator.free(cmake_header);

        const zig_header = try cwd.readFileAlloc(allocator, zig_header_path, config_header.max_bytes);
        defer allocator.free(zig_header);

        const header_text_index = std.mem.indexOf(u8, zig_header, "\n") orelse @panic("Could not find comment in header filer");

        if (!std.mem.eql(u8, zig_header[header_text_index + 1 ..], cmake_header)) {
            @panic("processed cmakedefine header does not match expected output");
        }
    }
}
