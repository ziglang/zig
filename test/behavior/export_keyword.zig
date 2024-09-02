const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;
const mem = std.mem;
const builtin = @import("builtin");

// can't really run this test but we can make sure it has no compile error
// and generates code
const vram = @as([*]volatile u8, @ptrFromInt(0x20000000))[0..0x8000];
export fn writeToVRam() void {
    vram[0] = 'X';
}

const PackedStruct = packed struct {
    a: u8,
    b: u8,
};
const PackedUnion = packed union(u32) {
    a: i32,
    b: u32,
};
const PackedEnum = enum(u32) {
    a,
    b,
    _,
};

test "packed struct, enum, union parameters in extern function" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    testPackedStuff(
        &(PackedStruct{
            .a = 1,
            .b = 2,
        }),
        &(PackedUnion{ .a = 1 }),
        &(PackedEnum.b),
    );
}

export fn testPackedStuff(
    a: *const PackedStruct,
    b: *const PackedUnion,
    c: *const PackedEnum,
) void {
    if (false) {
        a;
        b;
        c;
    }
}
