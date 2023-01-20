fn doTheTest() !void {
    const src = @src(); // do not move

    try expect(src.line == 2);
    try expect(src.column == 17);
    try expect(std.mem.endsWith(u8, src.fn_name, "doTheTest"));
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try doTheTest();
}

test "@src used as a comptime parameter" {
    const S = struct {
        fn Foo(comptime _: std.builtin.SourceLocation) type {
            return struct {};
        }
    };
    const T1 = S.Foo(@src());
    const T2 = S.Foo(@src());
    try expect(T1 != T2);
}
