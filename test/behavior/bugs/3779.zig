const std = @import("std");
const builtin = @import("builtin");

const TestEnum = enum { TestEnumValue };
const tag_name = @tagName(TestEnum.TestEnumValue);
const ptr_tag_name: [*:0]const u8 = tag_name;

test "@tagName() returns a string literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try std.testing.expect(*const [13:0]u8 == @TypeOf(tag_name));
    try std.testing.expect(std.mem.eql(u8, "TestEnumValue", tag_name));
    try std.testing.expect(std.mem.eql(u8, "TestEnumValue", ptr_tag_name[0..tag_name.len]));
}

const TestError = error{TestErrorCode};
const error_name = @errorName(TestError.TestErrorCode);
const ptr_error_name: [*:0]const u8 = error_name;

test "@errorName() returns a string literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try std.testing.expect(*const [13:0]u8 == @TypeOf(error_name));
    try std.testing.expect(std.mem.eql(u8, "TestErrorCode", error_name));
    try std.testing.expect(std.mem.eql(u8, "TestErrorCode", ptr_error_name[0..error_name.len]));
}

const TestType = struct {};
const type_name = @typeName(TestType);
const ptr_type_name: [*:0]const u8 = type_name;

test "@typeName() returns a string literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try std.testing.expect(*const [type_name.len:0]u8 == @TypeOf(type_name));
    try std.testing.expect(std.mem.eql(u8, "behavior.bugs.3779.TestType", type_name));
    try std.testing.expect(std.mem.eql(u8, "behavior.bugs.3779.TestType", ptr_type_name[0..type_name.len]));
}

const actual_contents = @embedFile("3779_file_to_embed.txt");
const ptr_actual_contents: [*:0]const u8 = actual_contents;
const expected_contents = "hello zig\n";

test "@embedFile() returns a string literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try std.testing.expect(*const [expected_contents.len:0]u8 == @TypeOf(actual_contents));
    try std.testing.expect(std.mem.eql(u8, expected_contents, actual_contents));
    try std.testing.expect(std.mem.eql(u8, expected_contents, actual_contents));
    try std.testing.expect(std.mem.eql(u8, expected_contents, ptr_actual_contents[0..actual_contents.len]));
}

fn testFnForSrc() std.builtin.SourceLocation {
    return @src();
}

test "@src() returns a struct containing 0-terminated string slices" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const src = testFnForSrc();
    try std.testing.expect([:0]const u8 == @TypeOf(src.file));
    try std.testing.expect(std.mem.endsWith(u8, src.file, "3779.zig"));
    try std.testing.expect([:0]const u8 == @TypeOf(src.fn_name));
    try std.testing.expect(std.mem.endsWith(u8, src.fn_name, "testFnForSrc"));

    const ptr_src_file: [*:0]const u8 = src.file;
    _ = ptr_src_file; // unused

    const ptr_src_fn_name: [*:0]const u8 = src.fn_name;
    _ = ptr_src_fn_name; // unused
}
