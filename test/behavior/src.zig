const src_outside_function = @src(); // do not move

fn doTheTest() !void {
    const src = @src(); // do not move

    try expect(src.line == 4);
    try expect(src.column == 17);
    try expect(std.mem.eql(u8, src.fn_name, "doTheTest"));
    try expect(std.mem.endsWith(u8, src.file, "src.zig"));
    try expect(src.fn_name[src.fn_name.len] == 0);
    try expect(src.file[src.file.len] == 0);
}

const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "@src" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try doTheTest();
}

test "@src outside function" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

    const src = src_outside_function;

    try expect(src.line == 1);
    try expect(src.column == 30);
    try expect(std.mem.eql(u8, src.fn_name, ""));
    try expect(std.mem.endsWith(u8, src.file, "src.zig"));
    try expect(src.fn_name[src.fn_name.len] == 0);
    try expect(src.file[src.file.len] == 0);
}