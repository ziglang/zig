const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;
const mem = std.mem;
const builtin = @import("builtin");

// can't really run this test but we can make sure it has no compile error
// and generates code
const vram = @intToPtr([*]volatile u8, 0x20000000)[0..0x8000];
export fn writeToVRam() void {
    vram[0] = 'X';
}

const PackedStruct = packed struct {
    a: u8,
    b: u8,
};
const PackedUnion = packed union {
    a: u8,
    b: u32,
};

test "packed struct, enum, union parameters in extern function" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    testPackedStuff(&(PackedStruct{
        .a = 1,
        .b = 2,
    }), &(PackedUnion{ .a = 1 }));
}

export fn testPackedStuff(a: *const PackedStruct, b: *const PackedUnion) void {
    if (false) {
        a;
        b;
    }
}

test "exporting enum type and value" {
    const S = struct {
        const E = enum(c_int) { one, two };
        const e: E = .two;
        comptime {
            @export(e, .{ .name = "e" });
        }
    };
    try expect(S.e == .two);
}

test "exporting with internal linkage" {
    const S = struct {
        fn foo() callconv(.C) void {}
        comptime {
            @export(foo, .{ .name = "exporting_with_internal_linkage_foo", .linkage = .Internal });
        }
    };
    S.foo();
}

test "exporting using field access" {
    const S = struct {
        const Inner = struct {
            const x: u32 = 5;
        };
        comptime {
            @export(Inner.x, .{ .name = "foo", .linkage = .Internal });
        }
    };

    _ = S.Inner.x;
}

test "exporting comptime-known value" {
    const x: u32 = 10;
    @export(x, .{ .name = "exporting_comptime_known_value_foo" });
    const S = struct {
        extern const exporting_comptime_known_value_foo: u32;
    };
    try expect(S.exporting_comptime_known_value_foo == 10);
}

test "exporting comptime var" {
    comptime var x: u32 = 5;
    @export(x, .{ .name = "exporting_comptime_var_foo" });
    x = 7; // modifying this now shouldn't change anything
    const S = struct {
        extern const exporting_comptime_var_foo: u32;
    };
    try expect(S.exporting_comptime_var_foo == 5);
}
