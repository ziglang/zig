const std = @import("std");
const ConfigHeader = std.Build.Step.ConfigHeader;

pub fn build(b: *std.Build) void {
    const config_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = .{ .path = "config.h.cmake" } },
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

    const test_step = b.step("test", "Test it");
    test_step.makeFn = compare_headers;
    test_step.dependOn(&config_header.step);
}

fn compare_headers(step: *std.Build.Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const allocator = step.owner.allocator;
    const cmake_header_path = "expected.h";

    const config_header_step = step.dependencies.getLast();
    const config_header = @fieldParentPtr(ConfigHeader, "step", config_header_step);

    const zig_header_path = config_header.output_file.path orelse @panic("Could not locate header file");

    const cwd = std.fs.cwd();

    const cmake_header = try cwd.readFileAlloc(allocator, cmake_header_path, config_header.max_bytes);
    defer allocator.free(cmake_header);

    const zig_header = try cwd.readFileAlloc(allocator, zig_header_path, config_header.max_bytes);
    defer allocator.free(zig_header);

    const header_text_index = std.mem.indexOf(u8, zig_header, "\n") orelse @panic("Could not find comment in header filer");

    if (!std.mem.eql(u8, zig_header[header_text_index + 1 ..], cmake_header)) {
        @panic("processed cmakedefine header does not match expected output");
    }
}
