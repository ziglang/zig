const assert = @import("std").debug.assert;

test "params" {
    assert(testParamsAdd(22, 11) == 33);
}
fn testParamsAdd(a: i32, b: i32) i32 {
    return a + b;
}

test "local variables" {
    testLocVars(2);
}
fn testLocVars(b: i32) void {
    const a: i32 = 1;
    if (a + b != 3) unreachable;
}

test "void parameters" {
    voidFun(1, void{}, 2, {});
}
fn voidFun(a: i32, b: void, c: i32, d: void) void {
    const v = b;
    const vv: void = if (a == 1) v else {};
    assert(a + c == 3);
    return vv;
}

test "mutable local variables" {
    var zero: i32 = 0;
    assert(zero == 0);

    var i = i32(0);
    while (i != 3) {
        i += 1;
    }
    assert(i == 3);
}

test "separate block scopes" {
    {
        const no_conflict: i32 = 5;
        assert(no_conflict == 5);
    }

    const c = x: {
        const no_conflict = i32(10);
        break :x no_conflict;
    };
    assert(c == 10);
}

test "call function with empty string" {
    acceptsString("");
}

fn acceptsString(foo: []u8) void {}

fn @"weird function name"() i32 {
    return 1234;
}
test "weird function name" {
    assert(@"weird function name"() == 1234);
}

test "implicit cast function unreachable return" {
    wantsFnWithVoid(fnWithUnreachable);
}

fn wantsFnWithVoid(f: fn () void) void {}

fn fnWithUnreachable() noreturn {
    unreachable;
}

test "function pointers" {
    const fns = []@typeOf(fn1){
        fn1,
        fn2,
        fn3,
        fn4,
    };
    for (fns) |f, i| {
        assert(f() == @intCast(u32, i) + 5);
    }
}
fn fn1() u32 {
    return 5;
}
fn fn2() u32 {
    return 6;
}
fn fn3() u32 {
    return 7;
}
fn fn4() u32 {
    return 8;
}

test "inline function call" {
    assert(@inlineCall(add, 3, 9) == 12);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "number literal as an argument" {
    numberLiteralArg(3);
    comptime numberLiteralArg(3);
}

fn numberLiteralArg(a: var) void {
    assert(a == 3);
}

test "assign inline fn to const variable" {
    const a = inlineFn;
    a();
}

inline fn inlineFn() void {}

test "pass by non-copying value" {
    assert(addPointCoords(Point{ .x = 1, .y = 2 }) == 3);
}

const Point = struct {
    x: i32,
    y: i32,
};

fn addPointCoords(pt: Point) i32 {
    return pt.x + pt.y;
}

test "pass by non-copying value through var arg" {
    assert(addPointCoordsVar(Point{ .x = 1, .y = 2 }) == 3);
}

fn addPointCoordsVar(pt: var) i32 {
    comptime assert(@typeOf(pt) == Point);
    return pt.x + pt.y;
}

test "pass by non-copying value as method" {
    var pt = Point2{ .x = 1, .y = 2 };
    assert(pt.addPointCoords() == 3);
}

const Point2 = struct {
    x: i32,
    y: i32,

    fn addPointCoords(self: Point2) i32 {
        return self.x + self.y;
    }
};

test "pass by non-copying value as method, which is generic" {
    var pt = Point3{ .x = 1, .y = 2 };
    assert(pt.addPointCoords(i32) == 3);
}

const Point3 = struct {
    x: i32,
    y: i32,

    fn addPointCoords(self: Point3, comptime T: type) i32 {
        return self.x + self.y;
    }
};

test "pass by non-copying value as method, at comptime" {
    comptime {
        var pt = Point2{ .x = 1, .y = 2 };
        assert(pt.addPointCoords() == 3);
    }
}
