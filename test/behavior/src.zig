fn doTheTest() !void {
    const src = @src(); // do not move

    try expect(src.line == 2);
    try expect(src.column == 17);
    try expect(std.mem.endsWith(u8, src.fn_name, "doTheTest"));
    try expect(std.mem.endsWith(u8, src.file, "src.zig"));
    try expect(src.fn_name[src.fn_name.len] == 0);
    try expect(src.file[src.file.len] == 0);
    if (!std.mem.eql(u8, src.module, "test") and !std.mem.eql(u8, src.module, "root")) return error.TestFailure;
}

const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

test "@src" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try doTheTest();
}

test "@src used as a comptime parameter" {
    const S = struct {
        fn Foo(comptime src: std.builtin.SourceLocation) type {
            return struct {
                comptime {
                    _ = src;
                }
            };
        }
    };
    const T1 = S.Foo(@src());
    const T2 = S.Foo(@src());
    try expect(T1 != T2);
}

test "@src in tuple passed to anytype function" {
    const S = struct {
        fn Foo(a: anytype) u32 {
            return a[0].line;
        }
    };
    const l1 = S.Foo(.{@src()});
    const l2 = S.Foo(.{@src()});
    try expect(l1 != l2);
}
