const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const expect = testing.expect;
const expectError = testing.expectError;

test "dereference pointer" {
    try comptime testDerefPtr();
    try testDerefPtr();
}

fn testDerefPtr() !void {
    var x: i32 = 1234;
    const y = &x;
    y.* += 1;
    try expect(x == 1235);
}

test "pointer arithmetic" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    comptime assert(PtrOf(PtrOf(i32)) == **i32);
}

fn PtrOf(comptime T: type) type {
    return *T;
}

test "implicit cast single item pointer to C pointer and back" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var y: u8 = 11;
    const x: [*c]u8 = &y;
    const z: *u8 = x;
    z.* += 1;
    try expect(y == 12);
}

test "initialize const optional C pointer to null" {
    const a: ?[*c]i32 = null;
    try expect(a == null);
    comptime assert(a == null);
}

test "assigning integer to C pointer" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: i32 = 0;
    var y: i32 = 1;
    var ptr: [*c]u8 = 0;
    var ptr2: [*c]u8 = x;
    var ptr3: [*c]u8 = 1;
    var ptr4: [*c]u8 = y;
    _ = .{ &x, &y, &ptr, &ptr2, &ptr3, &ptr4 };

    try expect(ptr == ptr2);
    try expect(ptr3 == ptr4);
    try expect(ptr3 > ptr and ptr4 > ptr2 and y > x);
    try expect(1 > ptr and y > ptr2 and 0 < ptr3 and x < ptr4);
}

test "C pointer comparison and arithmetic" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var ptr1: [*c]u32 = 0;
            var ptr2 = ptr1 + 10;
            _ = &ptr1;
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
    try comptime S.doTheTest();
}

test "dereference pointer again" {
    try testDerefPtrOneVal();
    try comptime testDerefPtrOneVal();
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
    const ptr_one: *u8 = undefined;
    const ptr_many: [*]u8 = undefined;
    const ptr_c: [*c]u8 = undefined;
    var t = true;
    _ = &t;
    const x1 = if (t) ptr_one else ptr_c;
    const x2 = if (t) ptr_many else ptr_c;
    const x3 = if (t) ptr_c else ptr_one;
    const x4 = if (t) ptr_c else ptr_many;
    try expect(@TypeOf(x1) == [*c]u8);
    try expect(@TypeOf(x2) == [*c]u8);
    try expect(@TypeOf(x3) == [*c]u8);
    try expect(@TypeOf(x4) == [*c]u8);
}

test "peer type resolution with C pointer and const pointer" {
    var ptr_c: [*c]u8 = undefined;
    var ptr_const: *const u8 = &undefined;
    _ = .{ &ptr_c, &ptr_const };
    try expect(@TypeOf(ptr_c, ptr_const) == [*c]const u8);
}

test "implicit casting between C pointer and optional non-C pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var slice: []const u8 = "aoeu";
    _ = &slice;
    const opt_many_ptr: ?[*]const u8 = slice.ptr;
    var ptr_opt_many_ptr = &opt_many_ptr;
    const c_ptr: [*c]const [*c]const u8 = ptr_opt_many_ptr;
    try expect(c_ptr.*.* == 'a');
    ptr_opt_many_ptr = c_ptr;
    try expect(ptr_opt_many_ptr.*.?[1] == 'o');
}

test "implicit cast error unions with non-optional to optional pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
}

test "compare equality of optional and non-optional pointer" {
    const a = @as(*const usize, @ptrFromInt(0x12345678));
    const b = @as(?*usize, @ptrFromInt(0x12345678));
    try expect(a == b);
    try expect(b == a);
}

test "allowzero pointer and slice" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var ptr: [*]allowzero i32 = @ptrFromInt(0);
    const opt_ptr: ?[*]allowzero i32 = ptr;
    try expect(opt_ptr != null);
    try expect(@intFromPtr(ptr) == 0);
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
    var slice = ptr[runtime_zero..10];
    comptime assert(@TypeOf(slice) == []allowzero i32);
    try expect(@intFromPtr(&slice[5]) == 20);

    comptime assert(@typeInfo(@TypeOf(ptr)).Pointer.is_allowzero);
    comptime assert(@typeInfo(@TypeOf(slice)).Pointer.is_allowzero);
}

test "assign null directly to C pointer and test null equality" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: [*c]i32 = null;
    _ = &x;
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
    comptime assert(y == null);
    comptime assert(null == y);
    comptime assert(!(y != null));
    comptime assert(!(null != y));
    if (y) |same_y| {
        _ = same_y;
        @panic("fail");
    }
    const othery: i32 = undefined;
    const ptr_othery = &othery;
    comptime assert((y orelse ptr_othery) == ptr_othery);

    var n: i32 = 1234;
    const x1: [*c]i32 = &n;
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
    comptime assert(!(y1 == null));
    comptime assert(!(null == y1));
    comptime assert(y1 != null);
    comptime assert(null != y1);
    comptime assert(y1.?.* == 1234);
    if (y1) |same_y1| {
        try expect(same_y1.* == 1234);
    } else {
        @compileError("fail");
    }
    comptime assert((y1 orelse &othery) == y1);
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array_with_zero = [_:0]u8{ 'h', 'e', 'l', 'l', 'o' };
            const zero_ptr: [*:0]const u8 = @ptrCast(&array_with_zero);
            const no_zero_ptr: [*]const u8 = zero_ptr;
            const zero_ptr_again: [*:0]const u8 = @ptrCast(no_zero_ptr);
            try expect(std.mem.eql(u8, std.mem.sliceTo(zero_ptr_again, 0), "hello"));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "allow any sentinel" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array = [_:std.math.minInt(i32)]i32{ 1, 2, 3, 4 };
            const ptr: [*:std.math.minInt(i32)]i32 = &array;
            try expect(ptr[4] == std.math.minInt(i32));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "pointer sentinel with enums" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const Number = enum {
            one,
            two,
            sentinel,
        };

        fn doTheTest() !void {
            var ptr: [*:.sentinel]const Number = &[_:.sentinel]Number{ .one, .two, .two, .one };
            _ = &ptr;
            try expect(ptr[4] == .sentinel); // TODO this should be comptime assert, see #3731
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "pointer sentinel with optional element" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var ptr: [*:null]const ?i32 = &[_:null]?i32{ 1, 2, 3, 4 };
            _ = &ptr;
            try expect(ptr[4] == null); // TODO this should be comptime assert, see #3731
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "pointer sentinel with +inf" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            const inf_f32 = comptime std.math.inf(f32);
            var ptr: [*:inf_f32]const f32 = &[_:inf_f32]f32{ 1.1, 2.2, 3.3, 4.4 };
            _ = &ptr;
            try expect(ptr[4] == inf_f32); // TODO this should be comptime assert, see #3731
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "pointer to array at fixed address" {
    const array = @as(*volatile [2]u32, @ptrFromInt(0x10));
    // Silly check just to reference `array`
    try expect(@intFromPtr(&array[0]) == 0x10);
    try expect(@intFromPtr(&array[1]) == 0x14);
}

test "pointer arithmetic affects the alignment" {
    {
        var ptr: [*]align(8) u32 = undefined;
        var x: usize = 1;
        _ = .{ &ptr, &x };

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
        _ = .{ &ptr, &x };

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

test "@intFromPtr on null optional at comptime" {
    {
        const pointer = @as(?*u8, @ptrFromInt(0x000));
        const x = @intFromPtr(pointer);
        _ = x;
        comptime assert(0 == @intFromPtr(pointer));
    }
    {
        const pointer = @as(?*u8, @ptrFromInt(0xf00));
        comptime assert(0xf00 == @intFromPtr(pointer));
    }
}

test "indexing array with sentinel returns correct type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var s: [:0]const u8 = "abc";
    try testing.expectEqualSlices(u8, "*const u8", @typeName(@TypeOf(&s[0])));
}

test "element pointer to slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try comptime S.doTheTest();
}

test "element pointer arithmetic to slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var cases: [2][2]i32 = [_][2]i32{
                [_]i32{ 0, 1 },
                [_]i32{ 2, 3 },
            };

            const elem_ptr = &cases[0]; // *[2]i32
            const many = @as([*][2]i32, @ptrCast(elem_ptr));
            const many_elem = @as(*[2]i32, @ptrCast(&many[1]));
            const items: []i32 = many_elem;
            try testing.expect(items.len == 2);
            try testing.expect(items[1] == 3);
            try testing.expect(items[0] == 2);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "array slicing to slice" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var str: [5]i32 = [_]i32{ 1, 2, 3, 4, 5 };
            const sub: *[2]i32 = str[1..3];
            const slice: []i32 = sub; // used to cause failures
            try testing.expect(slice.len == 2);
            try testing.expect(slice[0] == 2);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "pointer to constant decl preserves alignment" {
    const S = struct {
        a: u8,
        b: u8,
        const aligned align(8) = @This(){ .a = 3, .b = 4 };
    };

    const alignment = @typeInfo(@TypeOf(&S.aligned)).Pointer.alignment;
    try std.testing.expect(alignment == 8);
}

test "ptrCast comptime known slice to C pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const s: [:0]const u8 = "foo";
    var p: [*c]const u8 = @ptrCast(s);
    _ = &p;
    try std.testing.expectEqualStrings(s, std.mem.sliceTo(p, 0));
}

test "pointer alignment and element type include call expression" {
    const S = struct {
        fn T() type {
            return struct { _: i32 };
        }
        const P = *align(@alignOf(T())) [@sizeOf(T())]u8;
    };
    try expect(@alignOf(S.P) > 0);
}

test "pointer to array has explicit alignment" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        const Base = extern struct { a: u8 };
        const Base2 = extern struct { a: u8 };
        fn func(ptr: *[4]Base) *align(1) [4]Base2 {
            return @alignCast(@as(*[4]Base2, @ptrCast(ptr)));
        }
    };
    var bases = [_]S.Base{.{ .a = 2 }} ** 4;
    const casted = S.func(&bases);
    try expect(casted[0].a == 2);
}

test "result type preserved through multiple references" {
    const S = struct { x: u32 };
    var my_u64: u64 = 12345;
    _ = &my_u64;
    const foo: *const *const *const S = &&&.{
        .x = @intCast(my_u64),
    };
    try expect(foo.*.*.*.x == 12345);
}

test "result type found through optional pointer" {
    const ptr1: ?*const u32 = &@intCast(123);
    const ptr2: ?[]const u8 = &.{ @intCast(123), @truncate(0xABCD) };
    try expect(ptr1.?.* == 123);
    try expect(ptr2.?.len == 2);
    try expect(ptr2.?[0] == 123);
    try expect(ptr2.?[1] == 0xCD);
}

const Box0 = struct {
    items: [4]Item,

    const Item = struct {
        num: u32,
    };
};
const Box1 = struct {
    items: [4]Item,

    const Item = struct {};
};
const Box2 = struct {
    items: [4]Item,

    const Item = struct {
        nothing: void,
    };
};

fn mutable() !void {
    var box0: Box0 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box0.items[0..])).Pointer.is_const == false);

    var box1: Box1 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box1.items[0..])).Pointer.is_const == false);

    var box2: Box2 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box2.items[0..])).Pointer.is_const == false);
}

fn constant() !void {
    const box0: Box0 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box0.items[0..])).Pointer.is_const == true);

    const box1: Box1 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box1.items[0..])).Pointer.is_const == true);

    const box2: Box2 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box2.items[0..])).Pointer.is_const == true);
}

test "pointer-to-array constness for zero-size elements, var" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try mutable();
    try comptime mutable();
}

test "pointer-to-array constness for zero-size elements, const" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try constant();
    try comptime constant();
}

test "cast pointers with zero sized elements" {
    const a: *void = undefined;
    const b: *[1]void = a;
    _ = b;
    const c: *[0]u8 = undefined;
    const d: []u8 = c;
    _ = d;
}

test "comptime pointer equality through distinct fields with well-defined layout" {
    const A = extern struct {
        x: u32,
        z: u16,
    };
    const B = extern struct {
        x: u16,
        y: u16,
        z: u16,
    };

    const a: A = .{
        .x = undefined,
        .z = 123,
    };

    const ap: *const A = &a;
    const bp: *const B = @ptrCast(ap);

    comptime assert(&ap.z == &bp.z);
    comptime assert(ap.z == 123);
    comptime assert(bp.z == 123);
}

test "comptime pointer equality through distinct elements with well-defined layout" {
    const buf: [2]u32 = .{ 123, 456 };

    const ptr: *const [2]u32 = &buf;
    const byte_ptr: *align(4) const [8]u8 = @ptrCast(ptr);
    const second_elem: *const u32 = @ptrCast(byte_ptr[4..8]);

    comptime assert(&buf[1] == second_elem);
    comptime assert(buf[1] == 456);
    comptime assert(second_elem.* == 456);
}
