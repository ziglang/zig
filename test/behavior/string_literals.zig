const std = @import("std");
const builtin = @import("builtin");

const TestEnum = enum { TestEnumValue };
const tag_name = @tagName(TestEnum.TestEnumValue);
const ptr_tag_name: [*:0]const u8 = tag_name;

test "@tagName() returns a string literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try std.testing.expect(std.mem.eql(u8, "behavior.string_literals.TestType", type_name));
    try std.testing.expect(std.mem.eql(u8, "behavior.string_literals.TestType", ptr_type_name[0..type_name.len]));
}

const actual_contents = @embedFile("file_to_embed.txt");
const ptr_actual_contents: [*:0]const u8 = actual_contents;
const expected_contents = "hello zig\n";

test "@embedFile() returns a string literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
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

    const src = testFnForSrc();
    try std.testing.expect([:0]const u8 == @TypeOf(src.file));
    try std.testing.expect(std.mem.endsWith(u8, src.file, "string_literals.zig"));
    try std.testing.expect([:0]const u8 == @TypeOf(src.fn_name));
    try std.testing.expect(std.mem.endsWith(u8, src.fn_name, "testFnForSrc"));

    const ptr_src_file: [*:0]const u8 = src.file;
    _ = ptr_src_file; // unused

    const ptr_src_fn_name: [*:0]const u8 = src.fn_name;
    _ = ptr_src_fn_name; // unused
}

test "string literal pointer sentinel" {
    const string_literal = "something";

    try std.testing.expect(@TypeOf(string_literal.ptr) == [*:0]const u8);
}

test "sentinel slice of string literal" {
    const string = "Hello!\x00World!";
    try std.testing.expect(@TypeOf(string) == *const [13:0]u8);

    const slice_without_sentinel: []const u8 = string[0..6];
    try std.testing.expect(@TypeOf(slice_without_sentinel) == []const u8);

    const slice_with_sentinel: [:0]const u8 = string[0..6 :0];
    try std.testing.expect(@TypeOf(slice_with_sentinel) == [:0]const u8);
}

test "Peer type resolution with string literals and unknown length u8 pointers" {
    try std.testing.expect(@TypeOf("", "a", @as([*:0]const u8, "")) == [*:0]const u8);
    try std.testing.expect(@TypeOf(@as([*:0]const u8, "baz"), "foo", "bar") == [*:0]const u8);
}

test "including the sentinel when dereferencing a string literal" {
    var var_str = "abc";
    const var_derefed = var_str[0 .. var_str.len + 1].*;

    const const_str = "abc";
    const const_derefed = const_str[0 .. const_str.len + 1].*;

    try std.testing.expectEqualSlices(u8, &var_derefed, &const_derefed);
    try std.testing.expectEqual(0, const_derefed[3]);
}
