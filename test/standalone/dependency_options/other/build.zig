const std = @import("std");

pub const Enum = enum { alfa, bravo, charlie };

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const expected_bool: bool = true;
    const expected_int: i64 = 123;
    const expected_float: f64 = 0.5;
    const expected_string: []const u8 = "abc";
    const expected_string_list: []const []const u8 = &.{ "a", "b", "c" };
    const expected_lazy_path: std.Build.LazyPath = .{ .cwd_relative = "abc.txt" };
    const expected_lazy_path_list: []const std.Build.LazyPath = &.{
        .{ .cwd_relative = "a.txt" },
        .{ .cwd_relative = "b.txt" },
        .{ .cwd_relative = "c.txt" },
    };
    const expected_enum: Enum = .alfa;
    const expected_enum_list: []const Enum = &.{ .alfa, .bravo, .charlie };
    const expected_build_id: std.zig.BuildId = .uuid;

    const @"bool" = b.option(bool, "bool", "bool") orelse expected_bool;
    const int = b.option(i64, "int", "int") orelse expected_int;
    const float = b.option(f64, "float", "float") orelse expected_float;
    const string = b.option([]const u8, "string", "string") orelse expected_string;
    const string_list = b.option([]const []const u8, "string_list", "string_list") orelse expected_string_list;
    const lazy_path = b.option(std.Build.LazyPath, "lazy_path", "lazy_path") orelse expected_lazy_path;
    const lazy_path_list = b.option([]const std.Build.LazyPath, "lazy_path_list", "lazy_path_list") orelse expected_lazy_path_list;
    const @"enum" = b.option(Enum, "enum", "enum") orelse expected_enum;
    const enum_list = b.option([]const Enum, "enum_list", "enum_list") orelse expected_enum_list;
    const build_id = b.option(std.zig.BuildId, "build_id", "build_id") orelse expected_build_id;

    if (@"bool" != expected_bool) return error.TestFailed;
    if (int != expected_int) return error.TestFailed;
    if (float != expected_float) return error.TestFailed;
    if (!std.mem.eql(u8, string, expected_string)) return error.TestFailed;
    if (string_list.len != expected_string_list.len) return error.TestFailed;
    for (string_list, expected_string_list) |x, y| {
        if (!std.mem.eql(u8, x, y)) return error.TestFailed;
    }
    if (!std.mem.eql(u8, lazy_path.cwd_relative, expected_lazy_path.cwd_relative)) return error.TestFailed;
    for (lazy_path_list, expected_lazy_path_list) |x, y| {
        if (!std.mem.eql(u8, x.cwd_relative, y.cwd_relative)) return error.TestFailed;
    }
    if (@"enum" != expected_enum) return error.TestFailed;
    if (!std.mem.eql(Enum, enum_list, expected_enum_list)) return error.TestFailed;
    if (!std.meta.eql(build_id, expected_build_id)) return error.TestFailed;

    _ = b.addModule("dummy", .{
        .root_source_file = b.path("build.zig"),
        .target = target,
        .optimize = optimize,
    });
}
