const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const maxInt = std.math.maxInt;

top_level_field: i32,

test "top level fields" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

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
    c: f32,
};

test "structs" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var foo: StructFoo = undefined;
    @memset(@ptrCast([*]u8, &foo), 0, @sizeOf(StructFoo));
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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

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

const Node = struct {
    val: Val,
    next: *Node,
};

const Val = struct {
    x: i32,
};

test "fn call of struct field" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const Foo = struct {
        ptr: fn () i32,
    };
    const S = struct {
        fn aFunc() i32 {
            return 13;
        }

        fn callStructField(foo: Foo) i32 {
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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const instance = MemberFnTestFoo{ .x = 1234 };
    const result = MemberFnTestFoo.member(instance);
    try expect(result == 1234);
}

test "store member function in variable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const bar = makeBar2(1234, 5678);
    try expect(bar.y == 5678);
}
const Bar = struct {
    x: i32,
    y: i32,
};
fn makeBar2(x: i32, y: i32) Bar {
    return Bar{
        .x = x,
        .y = y,
    };
}

test "call method with mutable reference to struct with no fields" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var x: anyerror!isize = 1;
            var req = Foo{
                .field = x catch undefined,
            };
            try expect(req.field == 1);
        }

        pub const Foo = extern struct {
            field: isize,
        };
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "packed struct field alignment" {
    if (builtin.object_format == .c) return error.SkipZigTest;

    const Stage1 = struct {
        var baz: packed struct {
            a: u32,
            b: u32,
        } = undefined;
    };
    const Stage2 = struct {
        var baz: packed struct {
            a: u32,
            b: u32 align(1),
        } = undefined;
    };
    const S = if (builtin.zig_backend != .stage1) Stage2 else Stage1;
    try expect(@TypeOf(&S.baz.b) == *align(1) u32);
}

const blah: packed struct {
    a: u3,
    b: u3,
    c: u2,
} = undefined;

test "bit field alignment" {
    try expect(@TypeOf(&blah.b) == *align(1:3:1) const u3);
}
