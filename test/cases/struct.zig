const assert = @import("std").debug.assert;
const builtin = @import("builtin");

const StructWithNoFields = struct {
    fn add(a: i32, b: i32) i32 {
        return a + b;
    }
};
const empty_global_instance = StructWithNoFields{};

test "call struct static method" {
    const result = StructWithNoFields.add(3, 4);
    assert(result == 7);
}

test "return empty struct instance" {
    _ = returnEmptyStructInstance();
}
fn returnEmptyStructInstance() StructWithNoFields {
    return empty_global_instance;
}

const should_be_11 = StructWithNoFields.add(5, 6);

test "invake static method in global scope" {
    assert(should_be_11 == 11);
}

test "void struct fields" {
    const foo = VoidStructFieldsFoo{
        .a = void{},
        .b = 1,
        .c = void{},
    };
    assert(foo.b == 1);
    assert(@sizeOf(VoidStructFieldsFoo) == 4);
}
const VoidStructFieldsFoo = struct {
    a: void,
    b: i32,
    c: void,
};

test "structs" {
    var foo: StructFoo = undefined;
    @memset(@ptrCast([*]u8, &foo), 0, @sizeOf(StructFoo));
    foo.a += 1;
    foo.b = foo.a == 1;
    testFoo(foo);
    testMutation(&foo);
    assert(foo.c == 100);
}
const StructFoo = struct {
    a: i32,
    b: bool,
    c: f32,
};
fn testFoo(foo: *const StructFoo) void {
    assert(foo.b);
}
fn testMutation(foo: *StructFoo) void {
    foo.c = 100;
}

const Node = struct {
    val: Val,
    next: *Node,
};

const Val = struct {
    x: i32,
};

test "struct point to self" {
    var root: Node = undefined;
    root.val.x = 1;

    var node: Node = undefined;
    node.next = &root;
    node.val.x = 2;

    root.next = &node;

    assert(node.next.next.next.val.x == 1);
}

test "struct byval assign" {
    var foo1: StructFoo = undefined;
    var foo2: StructFoo = undefined;

    foo1.a = 1234;
    foo2.a = 0;
    assert(foo2.a == 0);
    foo2 = foo1;
    assert(foo2.a == 1234);
}

fn structInitializer() void {
    const val = Val{ .x = 42 };
    assert(val.x == 42);
}

test "fn call of struct field" {
    assert(callStructField(Foo{ .ptr = aFunc }) == 13);
}

const Foo = struct {
    ptr: fn () i32,
};

fn aFunc() i32 {
    return 13;
}

fn callStructField(foo: *const Foo) i32 {
    return foo.ptr();
}

test "store member function in variable" {
    const instance = MemberFnTestFoo{ .x = 1234 };
    const memberFn = MemberFnTestFoo.member;
    const result = memberFn(instance);
    assert(result == 1234);
}
const MemberFnTestFoo = struct {
    x: i32,
    fn member(foo: *const MemberFnTestFoo) i32 {
        return foo.x;
    }
};

test "call member function directly" {
    const instance = MemberFnTestFoo{ .x = 1234 };
    const result = MemberFnTestFoo.member(instance);
    assert(result == 1234);
}

test "member functions" {
    const r = MemberFnRand{ .seed = 1234 };
    assert(r.getSeed() == 1234);
}
const MemberFnRand = struct {
    seed: u32,
    pub fn getSeed(r: *const MemberFnRand) u32 {
        return r.seed;
    }
};

test "return struct byval from function" {
    const bar = makeBar(1234, 5678);
    assert(bar.y == 5678);
}
const Bar = struct {
    x: i32,
    y: i32,
};
fn makeBar(x: i32, y: i32) Bar {
    return Bar{
        .x = x,
        .y = y,
    };
}

test "empty struct method call" {
    const es = EmptyStruct{};
    assert(es.method() == 1234);
}
const EmptyStruct = struct {
    fn method(es: *const EmptyStruct) i32 {
        return 1234;
    }
};

test "return empty struct from fn" {
    _ = testReturnEmptyStructFromFn();
}
const EmptyStruct2 = struct {};
fn testReturnEmptyStructFromFn() EmptyStruct2 {
    return EmptyStruct2{};
}

test "pass slice of empty struct to fn" {
    assert(testPassSliceOfEmptyStructToFn([]EmptyStruct2{EmptyStruct2{}}) == 1);
}
fn testPassSliceOfEmptyStructToFn(slice: []const EmptyStruct2) usize {
    return slice.len;
}

const APackedStruct = packed struct {
    x: u8,
    y: u8,
};

test "packed struct" {
    var foo = APackedStruct{
        .x = 1,
        .y = 2,
    };
    foo.y += 1;
    const four = foo.x + foo.y;
    assert(four == 4);
}

const BitField1 = packed struct {
    a: u3,
    b: u3,
    c: u2,
};

const bit_field_1 = BitField1{
    .a = 1,
    .b = 2,
    .c = 3,
};

test "bit field access" {
    var data = bit_field_1;
    assert(getA(&data) == 1);
    assert(getB(&data) == 2);
    assert(getC(&data) == 3);
    comptime assert(@sizeOf(BitField1) == 1);

    data.b += 1;
    assert(data.b == 3);

    data.a += 1;
    assert(data.a == 2);
    assert(data.b == 3);
}

fn getA(data: *const BitField1) u3 {
    return data.a;
}

fn getB(data: *const BitField1) u3 {
    return data.b;
}

fn getC(data: *const BitField1) u2 {
    return data.c;
}

const u24 = @IntType(false, 24);
const Foo24Bits = packed struct {
    field: u24,
};
const Foo96Bits = packed struct {
    a: u24,
    b: u24,
    c: u24,
    d: u24,
};

test "packed struct 24bits" {
    comptime {
        assert(@sizeOf(Foo24Bits) == 3);
        assert(@sizeOf(Foo96Bits) == 12);
    }

    var value = Foo96Bits{
        .a = 0,
        .b = 0,
        .c = 0,
        .d = 0,
    };
    value.a += 1;
    assert(value.a == 1);
    assert(value.b == 0);
    assert(value.c == 0);
    assert(value.d == 0);

    value.b += 1;
    assert(value.a == 1);
    assert(value.b == 1);
    assert(value.c == 0);
    assert(value.d == 0);

    value.c += 1;
    assert(value.a == 1);
    assert(value.b == 1);
    assert(value.c == 1);
    assert(value.d == 0);

    value.d += 1;
    assert(value.a == 1);
    assert(value.b == 1);
    assert(value.c == 1);
    assert(value.d == 1);
}

const FooArray24Bits = packed struct {
    a: u16,
    b: [2]Foo24Bits,
    c: u16,
};

test "packed array 24bits" {
    comptime {
        assert(@sizeOf([9]Foo24Bits) == 9 * 3);
        assert(@sizeOf(FooArray24Bits) == 2 + 2 * 3 + 2);
    }

    var bytes = []u8{0} ** (@sizeOf(FooArray24Bits) + 1);
    bytes[bytes.len - 1] = 0xaa;
    const ptr = &@bytesToSlice(FooArray24Bits, bytes[0 .. bytes.len - 1])[0];
    assert(ptr.a == 0);
    assert(ptr.b[0].field == 0);
    assert(ptr.b[1].field == 0);
    assert(ptr.c == 0);

    ptr.a = @maxValue(u16);
    assert(ptr.a == @maxValue(u16));
    assert(ptr.b[0].field == 0);
    assert(ptr.b[1].field == 0);
    assert(ptr.c == 0);

    ptr.b[0].field = @maxValue(u24);
    assert(ptr.a == @maxValue(u16));
    assert(ptr.b[0].field == @maxValue(u24));
    assert(ptr.b[1].field == 0);
    assert(ptr.c == 0);

    ptr.b[1].field = @maxValue(u24);
    assert(ptr.a == @maxValue(u16));
    assert(ptr.b[0].field == @maxValue(u24));
    assert(ptr.b[1].field == @maxValue(u24));
    assert(ptr.c == 0);

    ptr.c = @maxValue(u16);
    assert(ptr.a == @maxValue(u16));
    assert(ptr.b[0].field == @maxValue(u24));
    assert(ptr.b[1].field == @maxValue(u24));
    assert(ptr.c == @maxValue(u16));

    assert(bytes[bytes.len - 1] == 0xaa);
}

const FooStructAligned = packed struct {
    a: u8,
    b: u8,
};

const FooArrayOfAligned = packed struct {
    a: [2]FooStructAligned,
};

test "aligned array of packed struct" {
    comptime {
        assert(@sizeOf(FooStructAligned) == 2);
        assert(@sizeOf(FooArrayOfAligned) == 2 * 2);
    }

    var bytes = []u8{0xbb} ** @sizeOf(FooArrayOfAligned);
    const ptr = &@bytesToSlice(FooArrayOfAligned, bytes[0..bytes.len])[0];

    assert(ptr.a[0].a == 0xbb);
    assert(ptr.a[0].b == 0xbb);
    assert(ptr.a[1].a == 0xbb);
    assert(ptr.a[1].b == 0xbb);
}

test "runtime struct initialization of bitfield" {
    const s1 = Nibbles{
        .x = x1,
        .y = x1,
    };
    const s2 = Nibbles{
        .x = @intCast(u4, x2),
        .y = @intCast(u4, x2),
    };

    assert(s1.x == x1);
    assert(s1.y == x1);
    assert(s2.x == @intCast(u4, x2));
    assert(s2.y == @intCast(u4, x2));
}

var x1 = u4(1);
var x2 = u8(2);

const Nibbles = packed struct {
    x: u4,
    y: u4,
};

const Bitfields = packed struct {
    f1: u16,
    f2: u16,
    f3: u8,
    f4: u8,
    f5: u4,
    f6: u4,
    f7: u8,
};

test "native bit field understands endianness" {
    var all: u64 = 0x7765443322221111;
    var bytes: [8]u8 = undefined;
    @memcpy(bytes[0..].ptr, @ptrCast([*]u8, &all), 8);
    var bitfields = @ptrCast(*Bitfields, bytes[0..].ptr).*;

    assert(bitfields.f1 == 0x1111);
    assert(bitfields.f2 == 0x2222);
    assert(bitfields.f3 == 0x33);
    assert(bitfields.f4 == 0x44);
    assert(bitfields.f5 == 0x5);
    assert(bitfields.f6 == 0x6);
    assert(bitfields.f7 == 0x77);
}

test "align 1 field before self referential align 8 field as slice return type" {
    const result = alloc(Expr);
    assert(result.len == 0);
}

const Expr = union(enum) {
    Literal: u8,
    Question: *Expr,
};

fn alloc(comptime T: type) []T {
    return []T{};
}

test "call method with mutable reference to struct with no fields" {
    const S = struct {
        fn doC(s: *const this) bool {
            return true;
        }
        fn do(s: *this) bool {
            return true;
        }
    };

    var s = S{};
    assert(S.doC(&s));
    assert(s.doC());
    assert(S.do(&s));
    assert(s.do());
}
