const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "static eval list init" {
    try expect(static_vec3.data[2] == 1.0);
    try expect(vec3(0.0, 0.0, 3.0).data[2] == 3.0);
}
const static_vec3 = vec3(0.0, 0.0, 1.0);
pub const Vec3 = struct {
    data: [3]f32,
};
pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{
        .data = [_]f32{ x, y, z },
    };
}

test "inlined loop has array literal with elided runtime scope on first iteration but not second iteration" {
    var runtime = [1]i32{3};
    comptime var i: usize = 0;
    inline while (i < 2) : (i += 1) {
        const result = if (i == 0) [1]i32{2} else runtime;
        _ = result;
    }
    comptime {
        try expect(i == 2);
    }
}

test "eval @setFloatMode at compile-time" {
    const result = comptime fnWithFloatMode();
    try expect(result == 1234.0);
}

fn fnWithFloatMode() f32 {
    @setFloatMode(std.builtin.FloatMode.Strict);
    return 1234.0;
}

const SimpleStruct = struct {
    field: i32,

    fn method(self: *const SimpleStruct) i32 {
        return self.field + 3;
    }
};

var simple_struct = SimpleStruct{ .field = 1234 };

const bound_fn = simple_struct.method;

test "call method on bound fn referring to var instance" {
    try expect(bound_fn() == 1237);
}

test "ptr to local array argument at comptime" {
    comptime {
        var bytes: [10]u8 = undefined;
        modifySomeBytes(bytes[0..]);
        try expect(bytes[0] == 'a');
        try expect(bytes[9] == 'b');
    }
}

fn modifySomeBytes(bytes: []u8) void {
    bytes[0] = 'a';
    bytes[9] = 'b';
}

test "comparisons 0 <= uint and 0 > uint should be comptime" {
    testCompTimeUIntComparisons(1234);
}
fn testCompTimeUIntComparisons(x: u32) void {
    if (!(0 <= x)) {
        @compileError("this condition should be comptime known");
    }
    if (0 > x) {
        @compileError("this condition should be comptime known");
    }
    if (!(x >= 0)) {
        @compileError("this condition should be comptime known");
    }
    if (x < 0) {
        @compileError("this condition should be comptime known");
    }
}

test "const ptr to variable data changes at runtime" {
    try expect(foo_ref.name[0] == 'a');
    foo_ref.name = "b";
    try expect(foo_ref.name[0] == 'b');
}

const Foo = struct {
    name: []const u8,
};

var foo_contents = Foo{ .name = "a" };
const foo_ref = &foo_contents;

const hi1 = "hi";
const hi2 = hi1;
test "const global shares pointer with other same one" {
    try assertEqualPtrs(&hi1[0], &hi2[0]);
    comptime try expect(&hi1[0] == &hi2[0]);
}
fn assertEqualPtrs(ptr1: *const u8, ptr2: *const u8) !void {
    try expect(ptr1 == ptr2);
}

test "float literal at compile time not lossy" {
    try expect(16777216.0 + 1.0 == 16777217.0);
    try expect(9007199254740992.0 + 1.0 == 9007199254740993.0);
}

test "f128 at compile time is lossy" {
    try expect(@as(f128, 10384593717069655257060992658440192.0) + 1 == 10384593717069655257060992658440192.0);
}

pub fn TypeWithCompTimeSlice(comptime field_name: []const u8) type {
    _ = field_name;
    return struct {
        pub const Node = struct {};
    };
}

test "string literal used as comptime slice is memoized" {
    const a = "link";
    const b = "link";
    comptime try expect(TypeWithCompTimeSlice(a).Node == TypeWithCompTimeSlice(b).Node);
    comptime try expect(TypeWithCompTimeSlice("link").Node == TypeWithCompTimeSlice("link").Node);
}

test "comptime function with mutable pointer is not memoized" {
    comptime {
        var x: i32 = 1;
        const ptr = &x;
        increment(ptr);
        increment(ptr);
        try expect(x == 3);
    }
}

fn increment(value: *i32) void {
    value.* += 1;
}

const SingleFieldStruct = struct {
    x: i32,

    fn read_x(self: *const SingleFieldStruct) i32 {
        return self.x;
    }
};
test "const ptr to comptime mutable data is not memoized" {
    comptime {
        var foo = SingleFieldStruct{ .x = 1 };
        try expect(foo.read_x() == 1);
        foo.x = 2;
        try expect(foo.read_x() == 2);
    }
}

test "comptime shlWithOverflow" {
    const ct_shifted: u64 = comptime amt: {
        var amt = @as(u64, 0);
        _ = @shlWithOverflow(u64, ~@as(u64, 0), 16, &amt);
        break :amt amt;
    };

    const rt_shifted: u64 = amt: {
        var amt = @as(u64, 0);
        _ = @shlWithOverflow(u64, ~@as(u64, 0), 16, &amt);
        break :amt amt;
    };

    try expect(ct_shifted == rt_shifted);
}

test "runtime 128 bit integer division" {
    var a: u128 = 152313999999999991610955792383;
    var b: u128 = 10000000000000000000;
    var c = a / b;
    try expect(c == 15231399999);
}

const Wrapper = struct {
    T: type,
};

fn wrap(comptime T: type) Wrapper {
    return Wrapper{ .T = T };
}

test "function which returns struct with type field causes implicit comptime" {
    const ty = wrap(i32).T;
    try expect(ty == i32);
}

test "call method with comptime pass-by-non-copying-value self parameter" {
    const S = struct {
        a: u8,

        fn b(comptime s: @This()) u8 {
            return s.a;
        }
    };

    const s = S{ .a = 2 };
    var b = s.b();
    try expect(b == 2);
}

test "@tagName of @typeInfo" {
    const str = @tagName(@typeInfo(u8));
    try expect(std.mem.eql(u8, str, "Int"));
}

test "setting backward branch quota just before a generic fn call" {
    @setEvalBranchQuota(1001);
    loopNTimes(1001);
}

fn loopNTimes(comptime n: usize) void {
    comptime var i = 0;
    inline while (i < n) : (i += 1) {}
}

test "variable inside inline loop that has different types on different iterations" {
    try testVarInsideInlineLoop(.{ true, @as(u32, 42) });
}

fn testVarInsideInlineLoop(args: anytype) !void {
    comptime var i = 0;
    inline while (i < args.len) : (i += 1) {
        const x = args[i];
        if (i == 0) try expect(x);
        if (i == 1) try expect(x == 42);
    }
}

test "bit shift a u1" {
    var x: u1 = 1;
    var y = x << 0;
    try expect(y == 1);
}

test "*align(1) u16 is the same as *align(1:0:2) u16" {
    comptime {
        try expect(*align(1:0:2) u16 == *align(1) u16);
        try expect(*align(2:0:2) u16 == *u16);
    }
}

test "array concatenation forces comptime" {
    var a = oneItem(3) ++ oneItem(4);
    try expect(std.mem.eql(i32, &a, &[_]i32{ 3, 4 }));
}

test "array multiplication forces comptime" {
    var a = oneItem(3) ** scalar(2);
    try expect(std.mem.eql(i32, &a, &[_]i32{ 3, 3 }));
}

fn oneItem(x: i32) [1]i32 {
    return [_]i32{x};
}

fn scalar(x: u32) u32 {
    return x;
}

test "comptime assign int to optional int" {
    comptime {
        var x: ?i32 = null;
        x = 2;
        x.? *= 10;
        try expectEqual(20, x.?);
    }
}

test "two comptime calls with array default initialized to undefined" {
    const S = struct {
        const CrossTarget = struct {
            dynamic_linker: DynamicLinker = DynamicLinker{},

            pub fn parse() void {
                var result: CrossTarget = .{};
                result.getCpuArch();
            }

            pub fn getCpuArch(self: CrossTarget) void {
                _ = self;
            }
        };

        const DynamicLinker = struct {
            buffer: [255]u8 = undefined,
        };
    };

    comptime {
        S.CrossTarget.parse();
        S.CrossTarget.parse();
    }
}
