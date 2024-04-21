const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const maxInt = std.math.maxInt;

top_level_field: i32,

test "top level fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var instance = @This(){
        .top_level_field = 1234,
    };
    instance.top_level_field += 1;
    try expect(@as(i32, 1235) == instance.top_level_field);
}

const StructWithFields = struct {
    a: u8,
    b: u32,
    c: u64,
    d: u32,

    fn first(self: *const StructWithFields) u8 {
        return self.a;
    }

    fn second(self: *const StructWithFields) u32 {
        return self.b;
    }

    fn third(self: *const StructWithFields) u64 {
        return self.c;
    }

    fn fourth(self: *const StructWithFields) u32 {
        return self.d;
    }
};

test "non-packed struct has fields padded out to the required alignment" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const foo = StructWithFields{ .a = 5, .b = 1, .c = 10, .d = 2 };
    try expect(foo.first() == 5);
    try expect(foo.second() == 1);
    try expect(foo.third() == 10);
    try expect(foo.fourth() == 2);
}

const SmallStruct = struct {
    a: u8,
    b: u8,

    fn first(self: *SmallStruct) u8 {
        return self.a;
    }

    fn second(self: *SmallStruct) u8 {
        return self.b;
    }
};

test "lower unnamed constants" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var foo = SmallStruct{ .a = 1, .b = 255 };
    try expect(foo.first() == 1);
    try expect(foo.second() == 255);
}

const StructWithNoFields = struct {
    fn add(a: i32, b: i32) i32 {
        return a + b;
    }
};

const StructFoo = struct {
    a: i32,
    b: bool,
    c: u64,
};

test "structs" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var foo: StructFoo = undefined;
    @memset(@as([*]u8, @ptrCast(&foo))[0..@sizeOf(StructFoo)], 0);
    foo.a += 1;
    foo.b = foo.a == 1;
    try testFoo(foo);
    testMutation(&foo);
    try expect(foo.c == 100);
}
fn testFoo(foo: StructFoo) !void {
    try expect(foo.b);
}
fn testMutation(foo: *StructFoo) void {
    foo.c = 100;
}

test "struct byval assign" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var foo1: StructFoo = undefined;
    var foo2: StructFoo = undefined;

    foo1.a = 1234;
    foo2.a = 0;
    try expect(foo2.a == 0);
    foo2 = foo1;
    try expect(foo2.a == 1234);
}

test "call struct static method" {
    const result = StructWithNoFields.add(3, 4);
    try expect(result == 7);
}

const should_be_11 = StructWithNoFields.add(5, 6);

test "invoke static method in global scope" {
    try expect(should_be_11 == 11);
}

const empty_global_instance = StructWithNoFields{};

test "return empty struct instance" {
    _ = returnEmptyStructInstance();
}
fn returnEmptyStructInstance() StructWithNoFields {
    return empty_global_instance;
}

test "fn call of struct field" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Foo = struct {
        ptr: fn () i32,
    };
    const S = struct {
        fn aFunc() i32 {
            return 13;
        }

        fn callStructField(comptime foo: Foo) i32 {
            return foo.ptr();
        }
    };

    try expect(S.callStructField(Foo{ .ptr = S.aFunc }) == 13);
}

test "struct initializer" {
    const val = Val{ .x = 42 };
    try expect(val.x == 42);
}

const MemberFnTestFoo = struct {
    x: i32,
    fn member(foo: MemberFnTestFoo) i32 {
        return foo.x;
    }
};

test "call member function directly" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const instance = MemberFnTestFoo{ .x = 1234 };
    const result = MemberFnTestFoo.member(instance);
    try expect(result == 1234);
}

test "store member function in variable" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const instance = MemberFnTestFoo{ .x = 1234 };
    const memberFn = MemberFnTestFoo.member;
    const result = memberFn(instance);
    try expect(result == 1234);
}

test "member functions" {
    const r = MemberFnRand{ .seed = 1234 };
    try expect(r.getSeed() == 1234);
}
const MemberFnRand = struct {
    seed: u32,
    pub fn getSeed(r: *const MemberFnRand) u32 {
        return r.seed;
    }
};

test "return struct byval from function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Bar = struct {
        x: i32,
        y: i32,
        fn makeBar2(x: i32, y: i32) @This() {
            return .{
                .x = x,
                .y = y,
            };
        }
    };
    const bar = Bar.makeBar2(1234, 5678);
    try expect(bar.y == 5678);
}

test "call method with mutable reference to struct with no fields" {
    const S = struct {
        fn doC(s: *const @This()) bool {
            _ = s;
            return true;
        }
        fn do(s: *@This()) bool {
            _ = s;
            return true;
        }
    };

    var s = S{};
    try expect(S.doC(&s));
    try expect(s.doC());
    try expect(S.do(&s));
    try expect(s.do());
}

test "usingnamespace within struct scope" {
    const S = struct {
        usingnamespace struct {
            pub fn inner() i32 {
                return 42;
            }
        };
    };
    try expect(@as(i32, 42) == S.inner());
}

test "struct field init with catch" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x: anyerror!isize = 1;
            _ = &x;
            const req = Foo{
                .field = x catch undefined,
            };
            try expect(req.field == 1);
        }

        pub const Foo = extern struct {
            field: isize,
        };
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

const blah: packed struct {
    a: u3,
    b: u3,
    c: u2,
} = undefined;

test "bit field alignment" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(@TypeOf(&blah.b) == *align(1:3:1) const u3);
}

const Node = struct {
    val: Val,
    next: *Node,
};

const Val = struct {
    x: i32,
};

test "struct point to self" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var root: Node = undefined;
    root.val.x = 1;

    var node: Node = undefined;
    node.next = &root;
    node.val.x = 2;

    root.next = &node;

    try expect(node.next.next.next.val.x == 1);
}

test "void struct fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const foo = VoidStructFieldsFoo{
        .a = void{},
        .b = 1,
        .c = void{},
    };
    try expect(foo.b == 1);
    try expect(@sizeOf(VoidStructFieldsFoo) == 4);
}
const VoidStructFieldsFoo = struct {
    a: void,
    b: i32,
    c: void,
};

test "return empty struct from fn" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    _ = testReturnEmptyStructFromFn();
}
const EmptyStruct2 = struct {};
fn testReturnEmptyStructFromFn() EmptyStruct2 {
    return EmptyStruct2{};
}

test "pass slice of empty struct to fn" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(testPassSliceOfEmptyStructToFn(&[_]EmptyStruct2{EmptyStruct2{}}) == 1);
}
fn testPassSliceOfEmptyStructToFn(slice: []const EmptyStruct2) usize {
    return slice.len;
}

test "self-referencing struct via array member" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = struct {
        children: [1]*@This(),
    };
    var x: T = undefined;
    x = T{ .children = .{&x} };
    try expect(x.children[0] == &x);
}

test "empty struct method call" {
    const es = EmptyStruct{};
    try expect(es.method() == 1234);
}
const EmptyStruct = struct {
    fn method(es: *const EmptyStruct) i32 {
        _ = es;
        return 1234;
    }
};

test "align 1 field before self referential align 8 field as slice return type" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const result = alloc(Expr);
    try expect(result.len == 0);
}

const Expr = union(enum) {
    Literal: u8,
    Question: *Expr,
};

fn alloc(comptime T: type) []T {
    return &[_]T{};
}

const APackedStruct = packed struct {
    x: u8,
    y: u8,
};

test "packed struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var foo = APackedStruct{
        .x = 1,
        .y = 2,
    };
    foo.y += 1;
    const four = foo.x + foo.y;
    try expect(four == 4);
}

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest; // TODO
    if (comptime builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    comptime {
        std.debug.assert(@sizeOf(Foo24Bits) == @sizeOf(u24));
        std.debug.assert(@sizeOf(Foo96Bits) == @sizeOf(u96));
    }

    var value = Foo96Bits{
        .a = 0,
        .b = 0,
        .c = 0,
        .d = 0,
    };
    value.a += 1;
    try expect(value.a == 1);
    try expect(value.b == 0);
    try expect(value.c == 0);
    try expect(value.d == 0);

    value.b += 1;
    try expect(value.a == 1);
    try expect(value.b == 1);
    try expect(value.c == 0);
    try expect(value.d == 0);

    value.c += 1;
    try expect(value.a == 1);
    try expect(value.b == 1);
    try expect(value.c == 1);
    try expect(value.d == 0);

    value.d += 1;
    try expect(value.a == 1);
    try expect(value.b == 1);
    try expect(value.c == 1);
    try expect(value.d == 1);
}

test "runtime struct initialization of bitfield" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const s1 = Nibbles{
        .x = x1,
        .y = x1,
    };
    const s2 = Nibbles{
        .x = @as(u4, @intCast(x2)),
        .y = @as(u4, @intCast(x2)),
    };

    try expect(s1.x == x1);
    try expect(s1.y == x1);
    try expect(s2.x == @as(u4, @intCast(x2)));
    try expect(s2.y == @as(u4, @intCast(x2)));
}

var x1 = @as(u4, 1);
var x2 = @as(u8, 2);

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

test "packed struct fields are ordered from LSB to MSB" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var all: u64 = 0x7765443322221111;
    var bytes: [8]u8 align(@alignOf(Bitfields)) = undefined;
    @memcpy(bytes[0..8], @as([*]u8, @ptrCast(&all)));
    const bitfields = @as(*Bitfields, @ptrCast(&bytes)).*;

    try expect(bitfields.f1 == 0x1111);
    try expect(bitfields.f2 == 0x2222);
    try expect(bitfields.f3 == 0x33);
    try expect(bitfields.f4 == 0x44);
    try expect(bitfields.f5 == 0x5);
    try expect(bitfields.f6 == 0x6);
    try expect(bitfields.f7 == 0x77);
}

test "implicit cast packed struct field to const ptr" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const LevelUpMove = packed struct {
        move_id: u9,
        level: u7,

        fn toInt(value: u7) u7 {
            return value;
        }
    };

    var lup: LevelUpMove = undefined;
    lup.level = 12;
    const res = LevelUpMove.toInt(lup.level);
    try expect(res == 12);
}

test "zero-bit field in packed struct" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = packed struct {
        x: u10,
        y: void,
    };
    var x: S = undefined;
    _ = &x;
}

test "packed struct with non-ABI-aligned field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = packed struct {
        x: u9,
        y: u183,
    };
    var s: S = undefined;
    s.x = 1;
    s.y = 42;
    try expect(s.x == 1);
    try expect(s.y == 42);
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var data = bit_field_1;
    try expect(getA(&data) == 1);
    try expect(getB(&data) == 2);
    try expect(getC(&data) == 3);
    comptime assert(@sizeOf(BitField1) == 1);

    data.b += 1;
    try expect(data.b == 3);

    data.a += 1;
    try expect(data.a == 2);
    try expect(data.b == 3);
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

test "default struct initialization fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        a: i32 = 1234,
        b: i32,
    };
    const x = S{
        .b = 5,
    };
    var five: i32 = 5;
    _ = &five;
    const y = S{
        .b = five,
    };
    if (x.a + x.b != 1239) {
        @compileError("it should be comptime-known");
    }
    try expect(y.a == x.a);
    try expect(y.b == x.b);
    try expect(1239 == x.a + x.b);
}

test "packed array 24bits" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    comptime {
        try expect(@sizeOf([9]Foo32Bits) == 9 * 4);
        try expect(@sizeOf(FooArray24Bits) == @sizeOf(u96));
    }

    var bytes = [_]u8{0} ** (@sizeOf(FooArray24Bits) + 1);
    bytes[bytes.len - 1] = 0xbb;
    const ptr = &std.mem.bytesAsSlice(FooArray24Bits, bytes[0 .. bytes.len - 1])[0];
    try expect(ptr.a == 0);
    try expect(ptr.b0.field == 0);
    try expect(ptr.b1.field == 0);
    try expect(ptr.c == 0);

    ptr.a = maxInt(u16);
    try expect(ptr.a == maxInt(u16));
    try expect(ptr.b0.field == 0);
    try expect(ptr.b1.field == 0);
    try expect(ptr.c == 0);

    ptr.b0.field = maxInt(u24);
    try expect(ptr.a == maxInt(u16));
    try expect(ptr.b0.field == maxInt(u24));
    try expect(ptr.b1.field == 0);
    try expect(ptr.c == 0);

    ptr.b1.field = maxInt(u24);
    try expect(ptr.a == maxInt(u16));
    try expect(ptr.b0.field == maxInt(u24));
    try expect(ptr.b1.field == maxInt(u24));
    try expect(ptr.c == 0);

    ptr.c = maxInt(u16);
    try expect(ptr.a == maxInt(u16));
    try expect(ptr.b0.field == maxInt(u24));
    try expect(ptr.b1.field == maxInt(u24));
    try expect(ptr.c == maxInt(u16));

    try expect(bytes[bytes.len - 1] == 0xbb);
}

const Foo32Bits = packed struct {
    field: u24,
    pad: u8,
};

const FooArray24Bits = packed struct {
    a: u16,
    b0: Foo32Bits,
    b1: Foo32Bits,
    c: u16,
};

const FooStructAligned = packed struct {
    a: u8,
    b: u8,
};

const FooArrayOfAligned = packed struct {
    a: [2]FooStructAligned,
};

test "pointer to packed struct member in a stack variable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = packed struct {
        a: u2,
        b: u2,
    };

    var s = S{ .a = 2, .b = 0 };
    const b_ptr = &s.b;
    try expect(s.b == 0);
    b_ptr.* = 2;
    try expect(s.b == 2);
}

test "packed struct with u0 field access" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = packed struct {
        f0: u0,
    };
    var s = S{ .f0 = 0 };
    _ = &s;
    comptime assert(s.f0 == 0);
}

test "access to global struct fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    g_foo.bar.value = 42;
    try expect(g_foo.bar.value == 42);
}

const S0 = struct {
    bar: S1,

    pub const S1 = struct {
        value: u8,
    };

    fn init() @This() {
        return S0{ .bar = S1{ .value = 123 } };
    }
};

var g_foo: S0 = S0.init();

test "packed struct with fp fields" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = packed struct {
        data0: f32,
        data1: f32,
        data2: f32,

        pub fn frob(self: *@This()) void {
            self.data0 += self.data1 + self.data2;
            self.data1 += self.data0 + self.data2;
            self.data2 += self.data0 + self.data1;
        }
    };

    var s: S = undefined;
    s.data0 = 1.0;
    s.data1 = 2.0;
    s.data2 = 3.0;
    s.frob();
    try expect(@as(f32, 6.0) == s.data0);
    try expect(@as(f32, 11.0) == s.data1);
    try expect(@as(f32, 20.0) == s.data2);
}

test "fn with C calling convention returns struct by value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn entry() !void {
            const x = makeBar(10);
            try expect(@as(i32, 10) == x.handle);
        }

        const ExternBar = extern struct {
            handle: i32,
        };

        fn makeBar(t: i32) callconv(.C) ExternBar {
            return ExternBar{
                .handle = t,
            };
        }
    };
    try S.entry();
    try comptime S.entry();
}

test "non-packed struct with u128 entry in union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c and comptime builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;

    const U = union(enum) {
        Num: u128,
        Void,
    };

    const S = struct {
        f1: U,
        f2: U,
    };

    var sx: S = undefined;
    var s = &sx;
    try expect(@intFromPtr(&s.f2) - @intFromPtr(&s.f1) == @offsetOf(S, "f2"));
    var v2 = U{ .Num = 123 };
    _ = &v2;
    s.f2 = v2;
    try expect(s.f2.Num == 123);
}

test "packed struct field passed to generic function" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const P = packed struct {
            b: u5,
            g: u5,
            r: u5,
            a: u1,
        };

        fn genericReadPackedField(ptr: anytype) u5 {
            return ptr.*;
        }
    };

    var p: S.P = undefined;
    p.b = 29;
    const loaded = S.genericReadPackedField(&p.b);
    try expect(loaded == 29);
}

test "anonymous struct literal syntax" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const Point = struct {
            x: i32,
            y: i32,
        };

        fn doTheTest() !void {
            var p: Point = .{
                .x = 1,
                .y = 2,
            };
            _ = &p;
            try expect(p.x == 1);
            try expect(p.y == 2);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "fully anonymous struct" {
    const S = struct {
        fn doTheTest() !void {
            try dump(.{
                .int = @as(u32, 1234),
                .float = @as(f64, 12.34),
                .b = true,
                .s = "hi",
            });
        }
        fn dump(args: anytype) !void {
            try expect(args.int == 1234);
            try expect(args.float == 12.34);
            try expect(args.b);
            try expect(args.s[0] == 'h');
            try expect(args.s[1] == 'i');
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "fully anonymous list literal" {
    const S = struct {
        fn doTheTest() !void {
            try dump(.{ @as(u32, 1234), @as(f64, 12.34), true, "hi" });
        }
        fn dump(args: anytype) !void {
            try expect(args.@"0" == 1234);
            try expect(args.@"1" == 12.34);
            try expect(args.@"2");
            try expect(args.@"3"[0] == 'h');
            try expect(args.@"3"[1] == 'i');
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "tuple assigned to variable" {
    var vec = .{ @as(i32, 22), @as(i32, 55), @as(i32, 99) };
    _ = &vec;
    try expect(vec.@"0" == 22);
    try expect(vec.@"1" == 55);
    try expect(vec.@"2" == 99);
    try expect(vec[0] == 22);
    try expect(vec[1] == 55);
    try expect(vec[2] == 99);
}

test "comptime struct field" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (comptime builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest; // TODO

    const T = struct {
        a: i32,
        comptime b: i32 = 1234,
    };

    comptime std.debug.assert(@sizeOf(T) == 4);

    var foo: T = undefined;
    _ = &foo;
    comptime assert(foo.b == 1234);
}

test "tuple element initialized with fn call" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            const x = .{foo()};
            try expectEqualSlices(u8, x[0], "hi");
        }
        fn foo() []const u8 {
            return "hi";
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "struct with union field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Value = struct {
        ref: u32 = 2,
        kind: union(enum) {
            None: usize,
            Bool: bool,
        },
    };

    var True = Value{
        .kind = .{ .Bool = true },
    };
    _ = &True;
    try expect(@as(u32, 2) == True.ref);
    try expect(True.kind.Bool);
}

test "struct with 0-length union array field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const U = union {
        a: u32,
        b: u64,
    };

    const S = struct {
        zero_length: [0]U,
    };

    var s: S = undefined;
    _ = &s;
    try expectEqual(@as(usize, 0), s.zero_length.len);
}

test "type coercion of anon struct literal to struct" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const S2 = struct {
            A: u32,
            B: []const u8,
            C: void,
            D: Foo = .{},
        };

        const Foo = struct {
            field: i32 = 1234,
        };

        fn doTheTest() !void {
            var y: u32 = 42;
            _ = &y;
            const t0 = .{ .A = 123, .B = "foo", .C = {} };
            const t1 = .{ .A = y, .B = "foo", .C = {} };
            const y0: S2 = t0;
            const y1: S2 = t1;
            try expect(y0.A == 123);
            try expect(std.mem.eql(u8, y0.B, "foo"));
            try expect(y0.C == {});
            try expect(y0.D.field == 1234);
            try expect(y1.A == y);
            try expect(std.mem.eql(u8, y1.B, "foo"));
            try expect(y1.C == {});
            try expect(y1.D.field == 1234);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "type coercion of pointer to anon struct literal to pointer to struct" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const S2 = struct {
            A: u32,
            B: []const u8,
            C: void,
            D: Foo = .{},
        };

        const Foo = struct {
            field: i32 = 1234,
        };

        fn doTheTest() !void {
            var y: u32 = 42;
            _ = &y;
            const t0 = &.{ .A = 123, .B = "foo", .C = {} };
            const t1 = &.{ .A = y, .B = "foo", .C = {} };
            const y0: *const S2 = t0;
            const y1: *const S2 = t1;
            try expect(y0.A == 123);
            try expect(std.mem.eql(u8, y0.B, "foo"));
            try expect(y0.C == {});
            try expect(y0.D.field == 1234);
            try expect(y1.A == y);
            try expect(std.mem.eql(u8, y1.B, "foo"));
            try expect(y1.C == {});
            try expect(y1.D.field == 1234);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "packed struct with undefined initializers" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const P = packed struct {
            a: u3,
            _a: u3 = undefined,
            b: u3,
            _b: u3 = undefined,
            c: u3,
            _c: u3 = undefined,
        };

        fn doTheTest() !void {
            var p: P = undefined;
            p = P{ .a = 2, .b = 4, .c = 6 };
            // Make sure the compiler doesn't touch the unprefixed fields.
            // Use expect since x86-linux doesn't like expectEqual
            try expect(p.a == 2);
            try expect(p.b == 4);
            try expect(p.c == 6);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "for loop over pointers to struct, getting field from struct pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const Foo = struct {
            name: []const u8,
        };

        var ok = true;

        fn eql(a: []const u8) bool {
            _ = a;
            return true;
        }

        const ArrayList = struct {
            fn toSlice(self: *ArrayList) []*Foo {
                _ = self;
                return @as([*]*Foo, undefined)[0..0];
            }
        };

        fn doTheTest() !void {
            var objects: ArrayList = undefined;

            for (objects.toSlice()) |obj| {
                if (eql(obj.name)) {
                    ok = false;
                }
            }

            try expect(ok);
        }
    };
    try S.doTheTest();
}

test "anon init through error unions and optionals" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        a: u32,

        fn foo() anyerror!?anyerror!@This() {
            return .{ .a = 1 };
        }
        fn bar() ?anyerror![2]u8 {
            return .{ 1, 2 };
        }

        fn doTheTest() !void {
            const a = try (try foo()).?;
            const b = try bar().?;
            try expect(a.a + b[1] == 3);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "anon init through optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        a: u32,

        fn doTheTest() !void {
            var s: ?@This() = null;
            s = .{ .a = 1 };
            try expect(s.?.a == 1);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "anon init through error union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        a: u32,

        fn doTheTest() !void {
            var s: anyerror!@This() = error.Foo;
            s = .{ .a = 1 };
            try expect((try s).a == 1);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "typed init through error unions and optionals" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        a: u32,

        fn foo() anyerror!?anyerror!@This() {
            return @This(){ .a = 1 };
        }
        fn bar() ?anyerror![2]u8 {
            return [2]u8{ 1, 2 };
        }

        fn doTheTest() !void {
            const a = try (try foo()).?;
            const b = try bar().?;
            try expect(a.a + b[1] == 3);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "initialize struct with empty literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct { x: i32 = 1234 };
    var s: S = .{};
    _ = &s;
    try expect(s.x == 1234);
}

test "loading a struct pointer perfoms a copy" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        a: i32,
        b: i32,
        c: i32,

        fn swap(a: *@This(), b: *@This()) void {
            const tmp = a.*;
            a.* = b.*;
            b.* = tmp;
        }
    };
    var s1: S = .{ .a = 1, .b = 2, .c = 3 };
    var s2: S = .{ .a = 4, .b = 5, .c = 6 };
    S.swap(&s1, &s2);
    try expect(s1.a == 4);
    try expect(s1.b == 5);
    try expect(s1.c == 6);
    try expect(s2.a == 1);
    try expect(s2.b == 2);
    try expect(s2.c == 3);
}

test "packed struct aggregate init" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn foo(a: i2, b: i6) u8 {
            return @as(u8, @bitCast(P{ .a = a, .b = b }));
        }

        const P = packed struct {
            a: i2,
            b: i6,
        };
    };
    const result = @as(u8, @bitCast(S.foo(1, 2)));
    try expect(result == 9);
}

test "packed struct field access via pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            const S = packed struct { a: u30 };
            var s1: S = .{ .a = 1 };
            const s2 = &s1;
            try expect(s2.a == 1);
            var s3: S = undefined;
            const s4 = &s3;
            _ = s4;
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "store to comptime field" {
    {
        const S = struct {
            comptime a: [2]u32 = [2]u32{ 1, 2 },
        };
        var s: S = .{};
        s.a = [2]u32{ 1, 2 };
        s.a[0] = 1;
    }
    {
        const T = struct { a: u32, b: u32 };
        const S = struct {
            comptime a: T = T{ .a = 1, .b = 2 },
        };
        var s: S = .{};
        s.a = T{ .a = 1, .b = 2 };
        s.a.a = 1;
    }
}

test "struct field init value is size of the struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const namespace = struct {
        const S = extern struct {
            size: u8 = @sizeOf(S),
            blah: u16,
        };
    };
    var s: namespace.S = .{ .blah = 1234 };
    _ = &s;
    try expect(s.size == 4);
}

test "under-aligned struct field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const U = extern union {
        fd: i32,
        u32: u32,
        u64: u64,
    };
    const S = extern struct {
        events: u32,
        data: U align(4),
    };
    var runtime: usize = 1234;
    _ = &runtime;
    const ptr = &S{ .events = 0, .data = .{ .u64 = runtime } };
    const array = @as(*const [12]u8, @ptrCast(ptr));
    const result = std.mem.readInt(u64, array[4..12], native_endian);
    try expect(result == 1234);
}

test "fieldParentPtr of a zero-bit field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn testStruct(comptime A: type) !void {
            {
                const a = A{ .u = 0 };
                const b_ptr = &a.b;
                const a_ptr: *const A = @fieldParentPtr("b", b_ptr);
                try std.testing.expectEqual(&a, a_ptr);
            }
            {
                var a = A{ .u = 0 };
                const b_ptr = &a.b;
                const a_ptr: *A = @fieldParentPtr("b", b_ptr);
                try std.testing.expectEqual(&a, a_ptr);
            }
        }
        fn testNestedStruct(comptime A: type) !void {
            {
                const a = A{ .u = 0 };
                const c_ptr = &a.b.c;
                const b_ptr: @TypeOf(&a.b) = @fieldParentPtr("c", c_ptr);
                try std.testing.expectEqual(&a.b, b_ptr);
                const a_ptr: *const A = @fieldParentPtr("b", b_ptr);
                try std.testing.expectEqual(&a, a_ptr);
            }
            {
                var a = A{ .u = 0 };
                const c_ptr = &a.b.c;
                const b_ptr: @TypeOf(&a.b) = @fieldParentPtr("c", c_ptr);
                try std.testing.expectEqual(&a.b, b_ptr);
                const a_ptr: *const A = @fieldParentPtr("b", b_ptr);
                try std.testing.expectEqual(&a, a_ptr);
            }
        }
        fn doTheTest() !void {
            try testStruct(struct { b: void = {}, u: u8 });
            try testStruct(struct { u: u8, b: void = {} });
            try testNestedStruct(struct { b: struct { c: void = {} } = .{}, u: u8 });
            try testNestedStruct(struct { u: u8, b: struct { c: void = {} } = .{} });
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "struct field has a pointer to an aligned version of itself" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const E = struct {
        next: *align(1) @This(),
    };
    var e: E = undefined;
    e = .{ .next = &e };

    try expect(&e == e.next);
}

test "struct has only one reference" {
    const S = struct {
        fn optionalStructParam(_: ?struct { x: u8 }) void {}
        fn errorUnionStructParam(_: error{}!struct { x: u8 }) void {}
        fn optionalStructReturn() ?struct { x: u8 } {
            return null;
        }
        fn errorUnionStructReturn() error{Foo}!struct { x: u8 } {
            return error.Foo;
        }

        fn pointerPackedStruct(_: *packed struct { x: u8 }) void {}
        fn nestedPointerPackedStruct(_: struct { x: *packed struct { x: u8 } }) void {}
        fn pointerNestedPackedStruct(_: *struct { x: packed struct { x: u8 } }) void {}
        fn pointerNestedPointerPackedStruct(_: *struct { x: *packed struct { x: u8 } }) void {}

        fn optionalComptimeIntParam(comptime x: ?comptime_int) comptime_int {
            return x.?;
        }
        fn errorUnionComptimeIntParam(comptime x: error{}!comptime_int) comptime_int {
            return x catch unreachable;
        }
    };

    const optional_struct_param: *const anyopaque = &S.optionalStructParam;
    const error_union_struct_param: *const anyopaque = &S.errorUnionStructParam;
    try expect(optional_struct_param != error_union_struct_param);

    const optional_struct_return: *const anyopaque = &S.optionalStructReturn;
    const error_union_struct_return: *const anyopaque = &S.errorUnionStructReturn;
    try expect(optional_struct_return != error_union_struct_return);

    const pointer_packed_struct: *const anyopaque = &S.pointerPackedStruct;
    const nested_pointer_packed_struct: *const anyopaque = &S.nestedPointerPackedStruct;
    try expect(pointer_packed_struct != nested_pointer_packed_struct);

    const pointer_nested_packed_struct: *const anyopaque = &S.pointerNestedPackedStruct;
    const pointer_nested_pointer_packed_struct: *const anyopaque = &S.pointerNestedPointerPackedStruct;
    try expect(pointer_nested_packed_struct != pointer_nested_pointer_packed_struct);

    try expectEqual(@alignOf(struct {}), S.optionalComptimeIntParam(@alignOf(struct {})));
    try expectEqual(@alignOf(struct { x: u8 }), S.errorUnionComptimeIntParam(@alignOf(struct { x: u8 })));
    try expectEqual(@sizeOf(struct { x: u16 }), S.optionalComptimeIntParam(@sizeOf(struct { x: u16 })));
    try expectEqual(@sizeOf(struct { x: u32 }), S.errorUnionComptimeIntParam(@sizeOf(struct { x: u32 })));
}

test "no dependency loop on pointer to optional struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const A = struct { b: B };
        const B = struct { a: *?A };
    };
    var a1: ?S.A = null;
    var a2: ?S.A = .{ .b = .{ .a = &a1 } };
    a1 = .{ .b = .{ .a = &a2 } };

    try expect(a1.?.b.a == &a2);
    try expect(a2.?.b.a == &a1);
}

test "discarded struct initialization works as expected" {
    const S = struct { a: u32 };
    _ = S{ .a = 1 };
}

test "function pointer in struct returns the struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const A = struct {
        const A = @This();
        f: *const fn () A,

        fn f() A {
            return .{ .f = f };
        }
    };
    var a = A.f();
    _ = &a;
    try expect(a.f == A.f);
}

test "no dependency loop on optional field wrapped in generic function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        fn Atomic(comptime T: type) type {
            return T;
        }
        const A = struct { b: Atomic(?*B) };
        const B = struct { a: ?*A };
    };
    var a: S.A = .{ .b = null };
    var b: S.B = .{ .a = &a };
    a.b = &b;

    try expect(a.b == &b);
    try expect(b.a == &a);
}

test "optional field init with tuple" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        a: ?struct { b: u32 },
    };
    var a: u32 = 0;
    _ = &a;
    const b = S{
        .a = .{ .b = a },
    };
    try expect(b.a.?.b == a);
}

test "if inside struct init inside if" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const MyStruct = struct { x: u32 };
    const b: u32 = 5;
    var i: u32 = 1;
    _ = &i;
    const my_var = if (i < 5)
        MyStruct{
            .x = 1 + if (i > 0) b else 0,
        }
    else
        MyStruct{
            .x = 1 + if (i > 0) b else 0,
        };
    try expect(my_var.x == 6);
}

test "optional generic function label struct field" {
    const Options = struct {
        isFoo: ?fn (type) u8 = defaultIsFoo,
        fn defaultIsFoo(comptime _: type) u8 {
            return 123;
        }
    };
    try expect((Options{}).isFoo.?(u8) == 123);
}

test "struct fields get automatically reordered" {
    if (builtin.zig_backend != .stage2_llvm) return error.SkipZigTest; // TODO

    const S1 = struct {
        a: u32,
        b: u32,
        c: bool,
        d: bool,
    };
    const S2 = struct {
        a: u32,
        b: bool,
        c: u32,
        d: bool,
    };
    try expect(@sizeOf(S1) == @sizeOf(S2));
}

test "directly initiating tuple like struct" {
    const a = struct { u8 }{8};
    try expect(a[0] == 8);
}

test "instantiate struct with comptime field" {
    {
        var things = struct {
            comptime foo: i8 = 1,
        }{};
        _ = &things;
        comptime std.debug.assert(things.foo == 1);
    }

    {
        const T = struct {
            comptime foo: i8 = 1,
        };
        var things = T{};
        _ = &things;
        comptime std.debug.assert(things.foo == 1);
    }

    {
        var things: struct {
            comptime foo: i8 = 1,
        } = .{};
        _ = &things;
        comptime std.debug.assert(things.foo == 1);
    }

    {
        var things: struct {
            comptime foo: i8 = 1,
        } = undefined; // Segmentation fault at address 0x0
        _ = &things;
        comptime std.debug.assert(things.foo == 1);
    }
}

test "struct field pointer has correct alignment" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: struct { x: u32 } = .{ .x = 123 };
            var b: struct { x: u32 } align(1) = .{ .x = 456 };
            var c: struct { x: u32 } align(64) = .{ .x = 789 };

            const ap = &a.x;
            const bp = &b.x;
            const cp = &c.x;

            comptime assert(@TypeOf(ap) == *u32);
            comptime assert(@TypeOf(bp) == *align(1) u32);
            comptime assert(@TypeOf(cp) == *u32); // undefined layout, cannot inherit larger alignment

            try expectEqual(@as(u32, 123), ap.*);
            try expectEqual(@as(u32, 456), bp.*);
            try expectEqual(@as(u32, 789), cp.*);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "extern struct field pointer has correct alignment" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: extern struct { x: u32, y: u16 } = .{ .x = 1, .y = 2 };
            var b: extern struct { x: u32, y: u16 } align(1) = .{ .x = 3, .y = 4 };
            var c: extern struct { x: u32, y: u16 } align(64) = .{ .x = 5, .y = 6 };

            const axp = &a.x;
            const bxp = &b.x;
            const cxp = &c.x;
            const ayp = &a.y;
            const byp = &b.y;
            const cyp = &c.y;

            comptime assert(@TypeOf(axp) == *u32);
            comptime assert(@TypeOf(bxp) == *align(1) u32);
            comptime assert(@TypeOf(cxp) == *align(64) u32);

            comptime assert(@TypeOf(ayp) == *align(@alignOf(u32)) u16);
            comptime assert(@TypeOf(byp) == *align(1) u16);
            comptime assert(@TypeOf(cyp) == *align(@alignOf(u32)) u16);

            try expectEqual(@as(u32, 1), axp.*);
            try expectEqual(@as(u32, 3), bxp.*);
            try expectEqual(@as(u32, 5), cxp.*);

            try expectEqual(@as(u16, 2), ayp.*);
            try expectEqual(@as(u16, 4), byp.*);
            try expectEqual(@as(u16, 6), cyp.*);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "packed struct field in anonymous struct" {
    const T = packed struct {
        f1: bool = false,
    };

    try std.testing.expect(countFields(.{ .t = T{} }) == 1);
}
fn countFields(v: anytype) usize {
    return @typeInfo(@TypeOf(v)).Struct.fields.len;
}

test "struct init with no result pointer sets field result types" {
    const S = struct {
        // A function parameter has a result type, but no result pointer.
        fn f(s: struct { x: u32 }) u32 {
            return s.x;
        }
    };

    const x: u64 = 123;
    const y = S.f(.{ .x = @intCast(x) });

    try expect(y == x);
}

test "runtime side-effects in comptime-known struct init" {
    var side_effects: u4 = 0;
    const S = struct { a: u4, b: u4, c: u4, d: u4 };
    const init = S{
        .d = blk: {
            side_effects += 8;
            break :blk 8;
        },
        .c = blk: {
            side_effects += 4;
            break :blk 4;
        },
        .b = blk: {
            side_effects += 2;
            break :blk 2;
        },
        .a = blk: {
            side_effects += 1;
            break :blk 1;
        },
    };
    try expectEqual(S{ .a = 1, .b = 2, .c = 4, .d = 8 }, init);
    try expectEqual(@as(u4, std.math.maxInt(u4)), side_effects);
}

test "pointer to struct initialized through reference to anonymous initializer provides result types" {
    const S = struct { a: u8, b: u16, c: *const anyopaque };
    var my_u16: u16 = 0xABCD;
    _ = &my_u16;
    const s: *const S = &.{
        // intentionally out of order
        .c = @ptrCast("hello"),
        .b = my_u16,
        .a = @truncate(my_u16),
    };
    try expect(s.a == 0xCD);
    try expect(s.b == 0xABCD);
    const str: *const [5]u8 = @ptrCast(s.c);
    try std.testing.expectEqualSlices(u8, "hello", str);
}

test "comptimeness of optional and error union payload is analyzed properly" {
    // This is primarily a semantic analysis integrity test.
    // The original failure mode for this was a crash.
    // Both structs and unions work for this, the point is that
    // their comptimeness is lazily evaluated.
    const S = struct {};
    // Original form of bug #17511, regressed in #17471
    const a = @sizeOf(?*S);
    _ = a;
    // Error union case, fails assertion in debug versions of release 0.11.0
    _ = @sizeOf(anyerror!*S);
    _ = @sizeOf(anyerror!?S);
    // Evaluation case, crashes the actual release 0.11.0
    const C = struct { x: comptime_int };
    const c: anyerror!?C = .{ .x = 3 };
    const x = (try c).?.x;
    try std.testing.expectEqual(3, x);
}

test "initializer uses own alignment" {
    const S = struct {
        x: u32 = @alignOf(@This()) + 1,
    };

    var s: S = .{};
    _ = &s;
    try expectEqual(4, @alignOf(S));
    try expectEqual(@as(usize, 5), s.x);
}

test "initializer uses own size" {
    const S = struct {
        x: u32 = @sizeOf(@This()) + 1,
    };

    var s: S = .{};
    _ = &s;
    try expectEqual(4, @sizeOf(S));
    try expectEqual(@as(usize, 5), s.x);
}

test "initializer takes a pointer to a variable inside its struct" {
    const namespace = struct {
        const S = struct {
            s: *S = &S.instance,
            var instance: S = undefined;
        };

        fn doTheTest() !void {
            var foo: S = .{};
            _ = &foo;
            try expectEqual(&S.instance, foo.s);
        }
    };

    try namespace.doTheTest();
    comptime try namespace.doTheTest();
}

test "circular dependency through pointer field of a struct" {
    const S = struct {
        const StructInner = extern struct {
            outer: StructOuter = std.mem.zeroes(StructOuter),
        };

        const StructMiddle = extern struct {
            outer: ?*StructInner,
            inner: ?*StructOuter,
        };

        const StructOuter = extern struct {
            middle: StructMiddle = std.mem.zeroes(StructMiddle),
        };
    };
    var outer: S.StructOuter = .{};
    _ = &outer;
    try expect(outer.middle.outer == null);
    try expect(outer.middle.inner == null);
}

test "field calls do not force struct field init resolution" {
    const S = struct {
        x: u32 = blk: {
            _ = @TypeOf(make().dummyFn()); // runtime field call - S not fully resolved - dummyFn call should not force field init resolution
            break :blk 123;
        },
        dummyFn: *const fn () void = undefined,
        fn make() @This() {
            return .{};
        }
    };
    var s: S = .{};
    _ = &s;
    try expect(s.x == 123);
}

test "tuple with comptime-only field" {
    const S = struct {
        fn getTuple() struct { comptime_int } {
            return struct { comptime comptime_int = 0 }{0};
        }
    };

    const x = S.getTuple();
    try expect(x.@"0" == 0);
}

test "extern struct fields are aligned to 1" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Foo = extern struct {
        a: u8 align(1),
        b: u16 align(1),
    };

    const foo = Foo{
        .a = 1,
        .b = 2,
    };
    try std.testing.expectEqual(1, foo.a);
    try std.testing.expectEqual(2, foo.b);
}

test "assign to slice.len of global variable" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const allocator = std.testing.allocator;
        var list = std.ArrayList(u32).init(allocator);
    };

    S.list.items.len = 0;
    try expect(S.list.items.len == 0);
}

test "pointers to fields of volatile pointer to struct are also volatile" {
    const B = extern struct {
        a: u32,
        b: i32,
    };
    const A = extern struct {
        value: *volatile B,
    };

    var a: *A = undefined;
    try expect(@TypeOf(&a.value.a) == *volatile u32);
    try expect(@TypeOf(&a.value.b) == *volatile i32);
}

test "pointers to fields of volatile pointer to union are also volatile" {
    const D = extern union {
        a: u32,
        b: i32,
    };
    const C = extern struct {
        value: *volatile D,
    };

    var c: *C = undefined;
    try expect(@TypeOf(&c.value.a) == *volatile u32);
    try expect(@TypeOf(&c.value.b) == *volatile i32);
}

test "array of structs inside struct initialized with undefined" {
    const Item = struct { field: u8 };
    const Thing = struct {
        array: [1]Item,
    };
    _ = Thing{ .array = undefined };
}

test "runtime call in nested initializer" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Holder = struct {
        array: []const u8,
    };
    const Test = struct {
        holders: []const Holder,
    };
    const Letter = enum(u8) {
        A = 0x41,
        B,

        fn letter(e: @This()) u8 {
            return @intFromEnum(e);
        }
    };

    const test_struct = Test{
        .holders = &.{
            Holder{
                .array = &.{
                    Letter.letter(.A),
                },
            },
        },
    };
    try std.testing.expectEqualStrings("A", test_struct.holders[0].array);
}

test "runtime value in nested initializer passed as pointer to function" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Bar = struct {
        b: u32,
    };
    const Foo = struct {
        a: Bar,

        fn takeFoo(foo: *const @This()) !void {
            try std.testing.expectEqual(@as(u32, 24), foo.a.b);
        }
    };

    var baz: u32 = 24;
    _ = &baz;
    try Foo.takeFoo(&.{
        .a = .{
            .b = baz,
        },
    });
}

test "struct field default value is a call" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const Z = packed struct {
        a: u32,
    };
    const Y = struct {
        a: u16,
        b: bool,
        c: Z,
        d: Z,

        fn init() @This() {
            return .{
                .a = 0,
                .b = false,
                .c = @as(Z, @bitCast(@as(u32, 0))),
                .d = @as(Z, @bitCast(@as(u32, 0))),
            };
        }
    };
    const X = struct {
        y: Y = Y.init(),
    };

    const x = X{};
    try std.testing.expectEqual(@as(u16, 0), x.y.a);
    try std.testing.expectEqual(false, x.y.b);
    try std.testing.expectEqual(Z{ .a = 0 }, x.y.c);
    try std.testing.expectEqual(Z{ .a = 0 }, x.y.d);
}

test "aggregate initializers should allow initializing comptime fields, verifying equality" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u32 = 15;
    _ = &x;
    const T = @TypeOf(.{ @as(i32, -1234), @as(u32, 5678), x });
    const a: T = .{ -1234, 5678, x + 1 };

    try expect(a[0] == -1234);
    try expect(a[1] == 5678);
    try expect(a[2] == 16);
}

test "assignment of field with padding" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Mesh = extern struct {
        id: u32,
    };
    const Material = extern struct {
        transparent: bool = true,
        emits_shadows: bool = true,
        render_color: bool = true,
    };
    const Renderable = extern struct {
        material: Material,
        mesh: Mesh,
    };
    var renderable: Renderable = undefined;
    renderable = Renderable{
        .mesh = Mesh{ .id = 0 },
        .material = Material{
            .transparent = false,
            .emits_shadows = false,
        },
    };
    try expect(false == renderable.material.transparent);
    try expect(false == renderable.material.emits_shadows);
    try expect(true == renderable.material.render_color);
}

test "initiate global variable with runtime value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        field: i32,
        fn couldFail() anyerror!i32 {
            return 1;
        }
        var some_struct: @This() = undefined;
    };

    S.some_struct = .{
        .field = S.couldFail() catch 0,
    };
    try expect(S.some_struct.field == 1);
}

test "struct containing optional pointer to array of @This()" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        x: ?*const [1]@This(),
    };

    var s: S = .{ .x = &.{.{ .x = null }} };
    _ = &s;
    try expect(s.x.?[0].x == null);
}

test "matching captures causes struct equivalence" {
    const S = struct {
        fn UnsignedWrapper(comptime I: type) type {
            const bits = @typeInfo(I).Int.bits;
            return struct {
                x: @Type(.{ .Int = .{
                    .signedness = .unsigned,
                    .bits = bits,
                } }),
            };
        }
    };

    comptime assert(S.UnsignedWrapper(u8) == S.UnsignedWrapper(i8));
    comptime assert(S.UnsignedWrapper(u16) == S.UnsignedWrapper(i16));
    comptime assert(S.UnsignedWrapper(u8) != S.UnsignedWrapper(u16));

    const a: S.UnsignedWrapper(u8) = .{ .x = 10 };
    const b: S.UnsignedWrapper(i8) = .{ .x = 10 };
    comptime assert(@TypeOf(a) == @TypeOf(b));
    try expect(a.x == b.x);
}
