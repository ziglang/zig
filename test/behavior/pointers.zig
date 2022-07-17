const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;

test "dereference pointer" {
    comptime try testDerefPtr();
    try testDerefPtr();
}

fn testDerefPtr() !void {
    var x: i32 = 1234;
    var y = &x;
    y.* += 1;
    try expect(x == 1235);
}

test "pointer arithmetic" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var ptr: [*]const u8 = "abcd";

    try expect(ptr[0] == 'a');
    ptr += 1;
    try expect(ptr[0] == 'b');
    ptr += 1;
    try expect(ptr[0] == 'c');
    ptr += 1;
    try expect(ptr[0] == 'd');
    ptr += 1;
    try expect(ptr[0] == 0);
    ptr -= 1;
    try expect(ptr[0] == 'd');
    ptr -= 1;
    try expect(ptr[0] == 'c');
    ptr -= 1;
    try expect(ptr[0] == 'b');
    ptr -= 1;
    try expect(ptr[0] == 'a');
}

test "double pointer parsing" {
    comptime try expect(PtrOf(PtrOf(i32)) == **i32);
}

fn PtrOf(comptime T: type) type {
    return *T;
}

test "implicit cast single item pointer to C pointer and back" {
    var y: u8 = 11;
    var x: [*c]u8 = &y;
    var z: *u8 = x;
    z.* += 1;
    try expect(y == 12);
}

test "initialize const optional C pointer to null" {
    const a: ?[*c]i32 = null;
    try expect(a == null);
    comptime try expect(a == null);
}

test "assigning integer to C pointer" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var x: i32 = 0;
    var y: i32 = 1;
    var ptr: [*c]u8 = 0;
    var ptr2: [*c]u8 = x;
    var ptr3: [*c]u8 = 1;
    var ptr4: [*c]u8 = y;

    try expect(ptr == ptr2);
    try expect(ptr3 == ptr4);
    try expect(ptr3 > ptr and ptr4 > ptr2 and y > x);
    try expect(1 > ptr and y > ptr2 and 0 < ptr3 and x < ptr4);
}

test "C pointer comparison and arithmetic" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var ptr1: [*c]u32 = 0;
            var ptr2 = ptr1 + 10;
            try expect(ptr1 == 0);
            try expect(ptr1 >= 0);
            try expect(ptr1 <= 0);
            // expect(ptr1 < 1);
            // expect(ptr1 < one);
            // expect(1 > ptr1);
            // expect(one > ptr1);
            try expect(ptr1 < ptr2);
            try expect(ptr2 > ptr1);
            try expect(ptr2 >= 40);
            try expect(ptr2 == 40);
            try expect(ptr2 <= 40);
            ptr2 -= 10;
            try expect(ptr1 == ptr2);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "dereference pointer again" {
    try testDerefPtrOneVal();
    comptime try testDerefPtrOneVal();
}

const Foo1 = struct {
    x: void,
};

fn testDerefPtrOneVal() !void {
    // Foo1 satisfies the OnePossibleValueYes criteria
    const x = &Foo1{ .x = {} };
    const y = x.*;
    try expect(@TypeOf(y.x) == void);
}

test "peer type resolution with C pointers" {
    var ptr_one: *u8 = undefined;
    var ptr_many: [*]u8 = undefined;
    var ptr_c: [*c]u8 = undefined;
    var t = true;
    var x1 = if (t) ptr_one else ptr_c;
    var x2 = if (t) ptr_many else ptr_c;
    var x3 = if (t) ptr_c else ptr_one;
    var x4 = if (t) ptr_c else ptr_many;
    try expect(@TypeOf(x1) == [*c]u8);
    try expect(@TypeOf(x2) == [*c]u8);
    try expect(@TypeOf(x3) == [*c]u8);
    try expect(@TypeOf(x4) == [*c]u8);
}

test "peer type resolution with C pointer and const pointer" {
    // stage1 incorrectly resolves to [*]u8
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

    var ptr_c: [*c]u8 = undefined;
    const ptr_const: u8 = undefined;
    try expect(@TypeOf(ptr_c, &ptr_const) == [*c]const u8);
}

test "implicit casting between C pointer and optional non-C pointer" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var slice: []const u8 = "aoeu";
    const opt_many_ptr: ?[*]const u8 = slice.ptr;
    var ptr_opt_many_ptr = &opt_many_ptr;
    var c_ptr: [*c]const [*c]const u8 = ptr_opt_many_ptr;
    try expect(c_ptr.*.* == 'a');
    ptr_opt_many_ptr = c_ptr;
    try expect(ptr_opt_many_ptr.*.?[1] == 'o');
}

test "implicit cast error unions with non-optional to optional pointer" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            try expectError(error.Fail, foo());
        }
        fn foo() anyerror!?*u8 {
            return bar() orelse error.Fail;
        }
        fn bar() ?*u8 {
            return null;
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "compare equality of optional and non-optional pointer" {
    const a = @intToPtr(*const usize, 0x12345678);
    const b = @intToPtr(?*usize, 0x12345678);
    try expect(a == b);
    try expect(b == a);
}

test "allowzero pointer and slice" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var ptr = @intToPtr([*]allowzero i32, 0);
    var opt_ptr: ?[*]allowzero i32 = ptr;
    try expect(opt_ptr != null);
    try expect(@ptrToInt(ptr) == 0);
    var runtime_zero: usize = 0;
    var slice = ptr[runtime_zero..10];
    comptime try expect(@TypeOf(slice) == []allowzero i32);
    try expect(@ptrToInt(&slice[5]) == 20);

    comptime try expect(@typeInfo(@TypeOf(ptr)).Pointer.is_allowzero);
    comptime try expect(@typeInfo(@TypeOf(slice)).Pointer.is_allowzero);
}

test "assign null directly to C pointer and test null equality" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var x: [*c]i32 = null;
    try expect(x == null);
    try expect(null == x);
    try expect(!(x != null));
    try expect(!(null != x));
    if (x) |same_x| {
        _ = same_x;
        @panic("fail");
    }
    var otherx: i32 = undefined;
    try expect((x orelse &otherx) == &otherx);

    const y: [*c]i32 = null;
    comptime try expect(y == null);
    comptime try expect(null == y);
    comptime try expect(!(y != null));
    comptime try expect(!(null != y));
    if (y) |same_y| {
        _ = same_y;
        @panic("fail");
    }
    const othery: i32 = undefined;
    const ptr_othery = &othery;
    comptime try expect((y orelse ptr_othery) == ptr_othery);

    var n: i32 = 1234;
    var x1: [*c]i32 = &n;
    try expect(!(x1 == null));
    try expect(!(null == x1));
    try expect(x1 != null);
    try expect(null != x1);
    try expect(x1.?.* == 1234);
    if (x1) |same_x1| {
        try expect(same_x1.* == 1234);
    } else {
        @panic("fail");
    }
    try expect((x1 orelse &otherx) == x1);

    const nc: i32 = 1234;
    const y1: [*c]const i32 = &nc;
    comptime try expect(!(y1 == null));
    comptime try expect(!(null == y1));
    comptime try expect(y1 != null);
    comptime try expect(null != y1);
    comptime try expect(y1.?.* == 1234);
    if (y1) |same_y1| {
        try expect(same_y1.* == 1234);
    } else {
        @compileError("fail");
    }
    comptime try expect((y1 orelse &othery) == y1);
}

test "array initialization types" {
    const E = enum { A, B, C };
    try expect(@TypeOf([_]u8{}) == [0]u8);
    try expect(@TypeOf([_:0]u8{}) == [0:0]u8);
    try expect(@TypeOf([_:.A]E{}) == [0:.A]E);
    try expect(@TypeOf([_:0]u8{ 1, 2, 3 }) == [3:0]u8);
}

test "null terminated pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array_with_zero = [_:0]u8{ 'h', 'e', 'l', 'l', 'o' };
            var zero_ptr: [*:0]const u8 = @ptrCast([*:0]const u8, &array_with_zero);
            var no_zero_ptr: [*]const u8 = zero_ptr;
            var zero_ptr_again = @ptrCast([*:0]const u8, no_zero_ptr);
            try expect(std.mem.eql(u8, std.mem.sliceTo(zero_ptr_again, 0), "hello"));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "allow any sentinel" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array = [_:std.math.minInt(i32)]i32{ 1, 2, 3, 4 };
            var ptr: [*:std.math.minInt(i32)]i32 = &array;
            try expect(ptr[4] == std.math.minInt(i32));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "pointer sentinel with enums" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        const Number = enum {
            one,
            two,
            sentinel,
        };

        fn doTheTest() !void {
            var ptr: [*:.sentinel]const Number = &[_:.sentinel]Number{ .one, .two, .two, .one };
            try expect(ptr[4] == .sentinel); // TODO this should be comptime try expect, see #3731
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "pointer sentinel with optional element" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var ptr: [*:null]const ?i32 = &[_:null]?i32{ 1, 2, 3, 4 };
            try expect(ptr[4] == null); // TODO this should be comptime try expect, see #3731
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "pointer sentinel with +inf" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            const inf = std.math.inf_f32;
            var ptr: [*:inf]const f32 = &[_:inf]f32{ 1.1, 2.2, 3.3, 4.4 };
            try expect(ptr[4] == inf); // TODO this should be comptime try expect, see #3731
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "pointer to array at fixed address" {
    const array = @intToPtr(*volatile [2]u32, 0x10);
    // Silly check just to reference `array`
    try expect(@ptrToInt(&array[0]) == 0x10);
    try expect(@ptrToInt(&array[1]) == 0x14);
}

test "pointer arithmetic affects the alignment" {
    {
        var ptr: [*]align(8) u32 = undefined;
        var x: usize = 1;

        try expect(@typeInfo(@TypeOf(ptr)).Pointer.alignment == 8);
        const ptr1 = ptr + 1; // 1 * 4 = 4 -> lcd(4,8) = 4
        try expect(@typeInfo(@TypeOf(ptr1)).Pointer.alignment == 4);
        const ptr2 = ptr + 4; // 4 * 4 = 16 -> lcd(16,8) = 8
        try expect(@typeInfo(@TypeOf(ptr2)).Pointer.alignment == 8);
        const ptr3 = ptr + 0; // no-op
        try expect(@typeInfo(@TypeOf(ptr3)).Pointer.alignment == 8);
        const ptr4 = ptr + x; // runtime-known addend
        try expect(@typeInfo(@TypeOf(ptr4)).Pointer.alignment == 4);
    }
    {
        var ptr: [*]align(8) [3]u8 = undefined;
        var x: usize = 1;

        const ptr1 = ptr + 17; // 3 * 17 = 51
        try expect(@typeInfo(@TypeOf(ptr1)).Pointer.alignment == 1);
        const ptr2 = ptr + x; // runtime-known addend
        try expect(@typeInfo(@TypeOf(ptr2)).Pointer.alignment == 1);
        const ptr3 = ptr + 8; // 3 * 8 = 24 -> lcd(8,24) = 8
        try expect(@typeInfo(@TypeOf(ptr3)).Pointer.alignment == 8);
        const ptr4 = ptr + 4; // 3 * 4 = 12 -> lcd(8,12) = 4
        try expect(@typeInfo(@TypeOf(ptr4)).Pointer.alignment == 4);
    }
}

test "@ptrToInt on null optional at comptime" {
    {
        const pointer = @intToPtr(?*u8, 0x000);
        const x = @ptrToInt(pointer);
        _ = x;
        comptime try expect(0 == @ptrToInt(pointer));
    }
    {
        const pointer = @intToPtr(?*u8, 0xf00);
        comptime try expect(0xf00 == @ptrToInt(pointer));
    }
}

test "indexing array with sentinel returns correct type" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    var s: [:0]const u8 = "abc";
    try testing.expectEqualSlices(u8, "*const u8", @typeName(@TypeOf(&s[0])));
}

test "element pointer to slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var cases: [2][2]i32 = [_][2]i32{
                [_]i32{ 0, 1 },
                [_]i32{ 2, 3 },
            };

            const items: []i32 = &cases[0]; // *[2]i32
            try testing.expect(items.len == 2);
            try testing.expect(items[1] == 1);
            try testing.expect(items[0] == 0);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "element pointer arithmetic to slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var cases: [2][2]i32 = [_][2]i32{
                [_]i32{ 0, 1 },
                [_]i32{ 2, 3 },
            };

            const elem_ptr = &cases[0]; // *[2]i32
            const many = @ptrCast([*][2]i32, elem_ptr);
            const many_elem = @ptrCast(*[2]i32, &many[1]);
            const items: []i32 = many_elem;
            try testing.expect(items.len == 2);
            try testing.expect(items[1] == 3);
            try testing.expect(items[0] == 2);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "array slicing to slice" {
    const S = struct {
        fn doTheTest() !void {
            var str: [5]i32 = [_]i32{ 1, 2, 3, 4, 5 };
            var sub: *[2]i32 = str[1..3];
            var slice: []i32 = sub; // used to cause failures
            try testing.expect(slice.len == 2);
            try testing.expect(slice[0] == 2);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}
