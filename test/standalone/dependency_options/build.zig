const std = @import("std");

pub const Enum = enum { alfa, bravo, charlie };

pub fn build(b: *std.Build) !void {
    const test_step = b.step("test", "Test passing options to a dependency");
    b.default_step = test_step;

    const none_specified = b.dependency("other", .{});

    const none_specified_mod = none_specified.module("dummy");
    if (!none_specified_mod.resolved_target.?.query.eql(b.graph.host.query)) return error.TestFailed;
    const expected_optimize: std.builtin.OptimizeMode = switch (b.release_mode) {
        .off => .Debug,
        .any => unreachable,
        .fast => .ReleaseFast,
        .safe => .ReleaseSafe,
        .small => .ReleaseSmall,
    };
    if (none_specified_mod.optimize.? != expected_optimize) return error.TestFailed;

    // Passing null is the same as not specifying the option,
    // so this should resolve to the same cached dependency instance.
    const null_specified = b.dependency("other", .{
        // Null literals
        .target = null,
        .optimize = null,
        .bool = null,

        // Optionals
        .int = @as(?i64, null),
        .float = @as(?f64, null),

        // Optionals of the wrong type
        .string = @as(?usize, null),
        .@"enum" = @as(?bool, null),

        // Non-defined option names
        .this_option_does_not_exist = null,
        .neither_does_this_one = @as(?[]const u8, null),
    });

    if (null_specified != none_specified) return error.TestFailed;

    const all_specified = b.dependency("other", .{
        .target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu }),
        .optimize = @as(std.builtin.OptimizeMode, .ReleaseSafe),
        .bool = @as(bool, true),
        .int = @as(i64, 123),
        .float = @as(f64, 0.5),
        .string = @as([]const u8, "abc"),
        .string_list = @as([]const []const u8, &.{ "a", "b", "c" }),
        .lazy_path = @as(std.Build.LazyPath, .{ .cwd_relative = "abc.txt" }),
        .lazy_path_list = @as([]const std.Build.LazyPath, &.{
            .{ .cwd_relative = "a.txt" },
            .{ .cwd_relative = "b.txt" },
            .{ .cwd_relative = "c.txt" },
        }),
        .@"enum" = @as(Enum, .alfa),
        .enum_list = @as([]const Enum, &.{ .alfa, .bravo, .charlie }),
        .build_id = @as(std.zig.BuildId, .uuid),
        .hex_build_id = std.zig.BuildId.initHexString("\x12\x34\xcd\xef"),
    });

    const all_specified_mod = all_specified.module("dummy");
    if (all_specified_mod.resolved_target.?.result.cpu.arch != .x86_64) return error.TestFailed;
    if (all_specified_mod.resolved_target.?.result.os.tag != .windows) return error.TestFailed;
    if (all_specified_mod.resolved_target.?.result.abi != .gnu) return error.TestFailed;
    if (all_specified_mod.optimize.? != .ReleaseSafe) return error.TestFailed;

    const all_specified_optional = b.dependency("other", .{
        .target = @as(?std.Build.ResolvedTarget, b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu })),
        .optimize = @as(?std.builtin.OptimizeMode, .ReleaseSafe),
        .bool = @as(?bool, true),
        .int = @as(?i64, 123),
        .float = @as(?f64, 0.5),
        .string = @as(?[]const u8, "abc"),
        .string_list = @as(?[]const []const u8, &.{ "a", "b", "c" }),
        .lazy_path = @as(?std.Build.LazyPath, .{ .cwd_relative = "abc.txt" }),
        .lazy_path_list = @as(?[]const std.Build.LazyPath, &.{
            .{ .cwd_relative = "a.txt" },
            .{ .cwd_relative = "b.txt" },
            .{ .cwd_relative = "c.txt" },
        }),
        .@"enum" = @as(?Enum, .alfa),
        .enum_list = @as(?[]const Enum, &.{ .alfa, .bravo, .charlie }),
        .build_id = @as(?std.zig.BuildId, .uuid),
        .hex_build_id = @as(?std.zig.BuildId, .initHexString("\x12\x34\xcd\xef")),
    });

    if (all_specified_optional != all_specified) return error.TestFailed;

    const all_specified_literal = b.dependency("other", .{
        .target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu }),
        .optimize = .ReleaseSafe,
        .bool = true,
        .int = 123,
        .float = 0.5,
        .string = "abc",
        .string_list = &[_][]const u8{ "a", "b", "c" },
        .lazy_path = @as(std.Build.LazyPath, .{ .cwd_relative = "abc.txt" }),
        .lazy_path_list = &[_]std.Build.LazyPath{
            .{ .cwd_relative = "a.txt" },
            .{ .cwd_relative = "b.txt" },
            .{ .cwd_relative = "c.txt" },
        },
        .@"enum" = .alfa,
        .enum_list = &[_]Enum{ .alfa, .bravo, .charlie },
        .build_id = .uuid,
        .hex_build_id = std.zig.BuildId.initHexString("\x12\x34\xcd\xef"),
    });

    if (all_specified_literal != all_specified) return error.TestFailed;

    var mut_string_buf = "abc".*;
    const mut_string: []u8 = &mut_string_buf;
    var mut_string_list_buf = [_][]const u8{ "a", "b", "c" };
    const mut_string_list: [][]const u8 = &mut_string_list_buf;
    var mut_lazy_path_list_buf = [_]std.Build.LazyPath{
        .{ .cwd_relative = "a.txt" },
        .{ .cwd_relative = "b.txt" },
        .{ .cwd_relative = "c.txt" },
    };
    const mut_lazy_path_list: []std.Build.LazyPath = &mut_lazy_path_list_buf;
    var mut_enum_list_buf = [_]Enum{ .alfa, .bravo, .charlie };
    const mut_enum_list: []Enum = &mut_enum_list_buf;

    // Most supported option types are serialized to a string representation,
    // so alternative representations of the same option value should resolve
    // to the same cached dependency instance.
    const all_specified_alt = b.dependency("other", .{
        .target = @as(std.Target.Query, .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu }),
        .optimize = "ReleaseSafe",
        .bool = .true,
        .int = "123",
        .float = @as(f16, 0.5),
        .string = mut_string,
        .string_list = mut_string_list,
        .lazy_path = @as(std.Build.LazyPath, .{ .cwd_relative = "abc.txt" }),
        .lazy_path_list = mut_lazy_path_list,
        .@"enum" = "alfa",
        .enum_list = mut_enum_list,
        .build_id = "uuid",
        .hex_build_id = "0x1234cdef",
    });

    if (all_specified_alt != all_specified) return error.TestFailed;
}
