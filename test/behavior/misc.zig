const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;
const mem = std.mem;
const builtin = @import("builtin");

fn emptyFn() void {}

const addr1 = @ptrCast(*const u8, emptyFn);
test "comptime cast fn to ptr" {
    const addr2 = @ptrCast(*const u8, emptyFn);
    comptime try expect(addr1 == addr2);
}

test "equality compare fn ptrs" {
    var a = emptyFn;
    try expect(a == a);
}

test "string escapes" {
    try expectEqualStrings("\"", "\x22");
    try expectEqualStrings("\'", "\x27");
    try expectEqualStrings("\n", "\x0a");
    try expectEqualStrings("\r", "\x0d");
    try expectEqualStrings("\t", "\x09");
    try expectEqualStrings("\\", "\x5c");
    try expectEqualStrings("\u{1234}\u{069}\u{1}", "\xe1\x88\xb4\x69\x01");
}

test "explicit cast optional pointers" {
    const a: ?*i32 = undefined;
    const b: ?*f32 = @ptrCast(?*f32, a);
    _ = b;
}

test "constant enum initialization with differing sizes" {
    try test3_1(test3_foo);
    try test3_2(test3_bar);
}
const Test3Foo = union(enum) {
    One: void,
    Two: f32,
    Three: Test3Point,
};
const Test3Point = struct {
    x: i32,
    y: i32,
};
const test3_foo = Test3Foo{
    .Three = Test3Point{
        .x = 3,
        .y = 4,
    },
};
const test3_bar = Test3Foo{ .Two = 13 };
fn test3_1(f: Test3Foo) !void {
    switch (f) {
        Test3Foo.Three => |pt| {
            try expect(pt.x == 3);
            try expect(pt.y == 4);
        },
        else => unreachable,
    }
}
fn test3_2(f: Test3Foo) !void {
    switch (f) {
        Test3Foo.Two => |x| {
            try expect(x == 13);
        },
        else => unreachable,
    }
}

test "pointer comparison" {
    const a = @as([]const u8, "a");
    const b = &a;
    try expect(ptrEql(b, b));
}
fn ptrEql(a: *const []const u8, b: *const []const u8) bool {
    return a == b;
}

test "string concatenation" {
    const a = "OK" ++ " IT " ++ "WORKED";
    const b = "OK IT WORKED";

    comptime try expect(@TypeOf(a) == *const [12:0]u8);
    comptime try expect(@TypeOf(b) == *const [12:0]u8);

    const len = mem.len(b);
    const len_with_null = len + 1;
    {
        var i: u32 = 0;
        while (i < len_with_null) : (i += 1) {
            try expect(a[i] == b[i]);
        }
    }
    try expect(a[len] == 0);
    try expect(b[len] == 0);
}

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

test "thread local variable" {
    const S = struct {
        threadlocal var t: i32 = 1234;
    };
    S.t += 1;
    try expect(S.t == 1235);
}

fn maybe(x: bool) anyerror!?u32 {
    return switch (x) {
        true => @as(u32, 42),
        else => null,
    };
}

test "result location is optional inside error union" {
    const x = maybe(true) catch unreachable;
    try expect(x.? == 42);
}

threadlocal var buffer: [11]u8 = undefined;

test "pointer to thread local array" {
    const s = "Hello world";
    std.mem.copy(u8, buffer[0..], s);
    try std.testing.expectEqualSlices(u8, buffer[0..], s);
}

test "auto created variables have correct alignment" {
    const S = struct {
        fn foo(str: [*]const u8) u32 {
            for (@ptrCast([*]align(1) const u32, str)[0..1]) |v| {
                return v;
            }
            return 0;
        }
    };
    try expect(S.foo("\x7a\x7a\x7a\x7a") == 0x7a7a7a7a);
    comptime try expect(S.foo("\x7a\x7a\x7a\x7a") == 0x7a7a7a7a);
}

extern var opaque_extern_var: opaque {};
var var_to_export: u32 = 42;
test "extern variable with non-pointer opaque type" {
    @export(var_to_export, .{ .name = "opaque_extern_var" });
    try expect(@ptrCast(*align(1) u32, &opaque_extern_var).* == 42);
}

test "lazy typeInfo value as generic parameter" {
    const S = struct {
        fn foo(args: anytype) void {
            _ = args;
        }
    };
    S.foo(@typeInfo(@TypeOf(.{})));
}
