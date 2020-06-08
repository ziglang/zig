const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;

test "dereference pointer" {
    comptime testDerefPtr();
    testDerefPtr();
}

fn testDerefPtr() void {
    var x: i32 = 1234;
    var y = &x;
    y.* += 1;
    expect(x == 1235);
}

const Foo1 = struct {
    x: void,
};

test "dereference pointer again" {
    testDerefPtrOneVal();
    comptime testDerefPtrOneVal();
}

fn testDerefPtrOneVal() void {
    // Foo1 satisfies the OnePossibleValueYes criteria
    const x = &Foo1{ .x = {} };
    const y = x.*;
    expect(@TypeOf(y.x) == void);
}

test "pointer arithmetic" {
    var ptr: [*]const u8 = "abcd";

    expect(ptr[0] == 'a');
    ptr += 1;
    expect(ptr[0] == 'b');
    ptr += 1;
    expect(ptr[0] == 'c');
    ptr += 1;
    expect(ptr[0] == 'd');
    ptr += 1;
    expect(ptr[0] == 0);
    ptr -= 1;
    expect(ptr[0] == 'd');
    ptr -= 1;
    expect(ptr[0] == 'c');
    ptr -= 1;
    expect(ptr[0] == 'b');
    ptr -= 1;
    expect(ptr[0] == 'a');
}

test "double pointer parsing" {
    comptime expect(PtrOf(PtrOf(i32)) == **i32);
}

fn PtrOf(comptime T: type) type {
    return *T;
}

test "assigning integer to C pointer" {
    var x: i32 = 0;
    var ptr: [*c]u8 = 0;
    var ptr2: [*c]u8 = x;
}

test "implicit cast single item pointer to C pointer and back" {
    var y: u8 = 11;
    var x: [*c]u8 = &y;
    var z: *u8 = x;
    z.* += 1;
    expect(y == 12);
}

test "C pointer comparison and arithmetic" {
    const S = struct {
        fn doTheTest() void {
            var one: usize = 1;
            var ptr1: [*c]u32 = 0;
            var ptr2 = ptr1 + 10;
            expect(ptr1 == 0);
            expect(ptr1 >= 0);
            expect(ptr1 <= 0);
            // expect(ptr1 < 1);
            // expect(ptr1 < one);
            // expect(1 > ptr1);
            // expect(one > ptr1);
            expect(ptr1 < ptr2);
            expect(ptr2 > ptr1);
            expect(ptr2 >= 40);
            expect(ptr2 == 40);
            expect(ptr2 <= 40);
            ptr2 -= 10;
            expect(ptr1 == ptr2);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
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
    expect(@TypeOf(x1) == [*c]u8);
    expect(@TypeOf(x2) == [*c]u8);
    expect(@TypeOf(x3) == [*c]u8);
    expect(@TypeOf(x4) == [*c]u8);
}

test "implicit casting between C pointer and optional non-C pointer" {
    var slice: []const u8 = "aoeu";
    const opt_many_ptr: ?[*]const u8 = slice.ptr;
    var ptr_opt_many_ptr = &opt_many_ptr;
    var c_ptr: [*c]const [*c]const u8 = ptr_opt_many_ptr;
    expect(c_ptr.*.* == 'a');
    ptr_opt_many_ptr = c_ptr;
    expect(ptr_opt_many_ptr.*.?[1] == 'o');
}

test "implicit cast error unions with non-optional to optional pointer" {
    const S = struct {
        fn doTheTest() void {
            expectError(error.Fail, foo());
        }
        fn foo() anyerror!?*u8 {
            return bar() orelse error.Fail;
        }
        fn bar() ?*u8 {
            return null;
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "initialize const optional C pointer to null" {
    const a: ?[*c]i32 = null;
    expect(a == null);
    comptime expect(a == null);
}

test "compare equality of optional and non-optional pointer" {
    const a = @intToPtr(*const usize, 0x12345678);
    const b = @intToPtr(?*usize, 0x12345678);
    expect(a == b);
    expect(b == a);
}

test "allowzero pointer and slice" {
    var ptr = @intToPtr([*]allowzero i32, 0);
    var opt_ptr: ?[*]allowzero i32 = ptr;
    expect(opt_ptr != null);
    expect(@ptrToInt(ptr) == 0);
    var runtime_zero: usize = 0;
    var slice = ptr[runtime_zero..10];
    comptime expect(@TypeOf(slice) == []allowzero i32);
    expect(@ptrToInt(&slice[5]) == 20);

    comptime expect(@typeInfo(@TypeOf(ptr)).Pointer.is_allowzero);
    comptime expect(@typeInfo(@TypeOf(slice)).Pointer.is_allowzero);
}

test "assign null directly to C pointer and test null equality" {
    var x: [*c]i32 = null;
    expect(x == null);
    expect(null == x);
    expect(!(x != null));
    expect(!(null != x));
    if (x) |same_x| {
        @panic("fail");
    }
    var otherx: i32 = undefined;
    expect((x orelse &otherx) == &otherx);

    const y: [*c]i32 = null;
    comptime expect(y == null);
    comptime expect(null == y);
    comptime expect(!(y != null));
    comptime expect(!(null != y));
    if (y) |same_y| @panic("fail");
    const othery: i32 = undefined;
    comptime expect((y orelse &othery) == &othery);

    var n: i32 = 1234;
    var x1: [*c]i32 = &n;
    expect(!(x1 == null));
    expect(!(null == x1));
    expect(x1 != null);
    expect(null != x1);
    expect(x1.?.* == 1234);
    if (x1) |same_x1| {
        expect(same_x1.* == 1234);
    } else {
        @panic("fail");
    }
    expect((x1 orelse &otherx) == x1);

    const nc: i32 = 1234;
    const y1: [*c]const i32 = &nc;
    comptime expect(!(y1 == null));
    comptime expect(!(null == y1));
    comptime expect(y1 != null);
    comptime expect(null != y1);
    comptime expect(y1.?.* == 1234);
    if (y1) |same_y1| {
        expect(same_y1.* == 1234);
    } else {
        @compileError("fail");
    }
    comptime expect((y1 orelse &othery) == y1);
}

test "null terminated pointer" {
    const S = struct {
        fn doTheTest() void {
            var array_with_zero = [_:0]u8{ 'h', 'e', 'l', 'l', 'o' };
            var zero_ptr: [*:0]const u8 = @ptrCast([*:0]const u8, &array_with_zero);
            var no_zero_ptr: [*]const u8 = zero_ptr;
            var zero_ptr_again = @ptrCast([*:0]const u8, no_zero_ptr);
            expect(std.mem.eql(u8, std.mem.spanZ(zero_ptr_again), "hello"));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "allow any sentinel" {
    const S = struct {
        fn doTheTest() void {
            var array = [_:std.math.minInt(i32)]i32{ 1, 2, 3, 4 };
            var ptr: [*:std.math.minInt(i32)]i32 = &array;
            expect(ptr[4] == std.math.minInt(i32));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "pointer sentinel with enums" {
    const S = struct {
        const Number = enum {
            one,
            two,
            sentinel,
        };

        fn doTheTest() void {
            var ptr: [*:.sentinel]const Number = &[_:.sentinel]Number{ .one, .two, .two, .one };
            expect(ptr[4] == .sentinel); // TODO this should be comptime expect, see #3731
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "pointer sentinel with optional element" {
    const S = struct {
        fn doTheTest() void {
            var ptr: [*:null]const ?i32 = &[_:null]?i32{ 1, 2, 3, 4 };
            expect(ptr[4] == null); // TODO this should be comptime expect, see #3731
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "pointer sentinel with +inf" {
    const S = struct {
        fn doTheTest() void {
            const inf = std.math.inf_f32;
            var ptr: [*:inf]const f32 = &[_:inf]f32{ 1.1, 2.2, 3.3, 4.4 };
            expect(ptr[4] == inf); // TODO this should be comptime expect, see #3731
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "pointer to array at fixed address" {
    const array = @intToPtr(*volatile [1]u32, 0x10);
    // Silly check just to reference `array`
    expect(@ptrToInt(&array[0]) == 0x10);
}

test "pointer arithmetic affects the alignment" {
    {
        var ptr: [*]align(8) u32 = undefined;
        var x: usize = 1;

        expect(@typeInfo(@TypeOf(ptr)).Pointer.alignment == 8);
        const ptr1 = ptr + 1; // 1 * 4 = 4 -> lcd(4,8) = 4
        expect(@typeInfo(@TypeOf(ptr1)).Pointer.alignment == 4);
        const ptr2 = ptr + 4; // 4 * 4 = 16 -> lcd(16,8) = 8
        expect(@typeInfo(@TypeOf(ptr2)).Pointer.alignment == 8);
        const ptr3 = ptr + 0; // no-op
        expect(@typeInfo(@TypeOf(ptr3)).Pointer.alignment == 8);
        const ptr4 = ptr + x; // runtime-known addend
        expect(@typeInfo(@TypeOf(ptr4)).Pointer.alignment == 4);
    }
    {
        var ptr: [*]align(8) [3]u8 = undefined;
        var x: usize = 1;

        const ptr1 = ptr + 17; // 3 * 17 = 51
        expect(@typeInfo(@TypeOf(ptr1)).Pointer.alignment == 1);
        const ptr2 = ptr + x; // runtime-known addend
        expect(@typeInfo(@TypeOf(ptr2)).Pointer.alignment == 1);
        const ptr3 = ptr + 8; // 3 * 8 = 24 -> lcd(8,24) = 8
        expect(@typeInfo(@TypeOf(ptr3)).Pointer.alignment == 8);
        const ptr4 = ptr + 4; // 3 * 4 = 12 -> lcd(8,12) = 4
        expect(@typeInfo(@TypeOf(ptr4)).Pointer.alignment == 4);
    }
}

test "@ptrToInt on null optional at comptime" {
    {
        const pointer = @intToPtr(?*u8, 0x000);
        const x = @ptrToInt(pointer);
        comptime expect(0 == @ptrToInt(pointer));
    }
    {
        const pointer = @intToPtr(?*u8, 0xf00);
        comptime expect(0xf00 == @ptrToInt(pointer));
    }
}

test "indexing array with sentinel returns correct type" {
    var s: [:0]const u8 = "abc";
    testing.expectEqualSlices(u8, "*const u8", @typeName(@TypeOf(&s[0])));
}
