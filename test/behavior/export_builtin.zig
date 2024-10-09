const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "exporting enum value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        const E = enum(c_int) { one, two };
        const e: E = .two;
        comptime {
            @export(&e, .{ .name = "e" });
        }
    };
    try expect(S.e == .two);
}

test "exporting with internal linkage" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        fn foo() callconv(.C) void {}
        comptime {
            @export(&foo, .{ .name = "exporting_with_internal_linkage_foo", .linkage = .internal });
        }
    };
    S.foo();
}

test "exporting using namespace access" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        const Inner = struct {
            const x: u32 = 5;
        };
        comptime {
            @export(&Inner.x, .{ .name = "foo", .linkage = .internal });
        }
    };

    _ = S.Inner.x;
}

test "exporting comptime-known value" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and
        (builtin.target.ofmt != .elf and
        builtin.target.ofmt != .macho and
        builtin.target.ofmt != .coff)) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const x: u32 = 10;
    @export(&x, .{ .name = "exporting_comptime_known_value_foo" });
    const S = struct {
        extern const exporting_comptime_known_value_foo: u32;
    };
    try expect(S.exporting_comptime_known_value_foo == 10);
}
