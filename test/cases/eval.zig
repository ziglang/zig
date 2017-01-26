const assert = @import("std").debug.assert;
const str = @import("std").str;

fn compileTimeRecursion() {
    @setFnTest(this);

    assert(some_data.len == 21);
}
var some_data: [usize(fibbonaci(7))]u8 = undefined;
fn fibbonaci(x: i32) -> i32 {
    if (x <= 1) return 1;
    return fibbonaci(x - 1) + fibbonaci(x - 2);
}



fn unwrapAndAddOne(blah: ?i32) -> i32 {
    return ??blah + 1;
}
const should_be_1235 = unwrapAndAddOne(1234);
fn testStaticAddOne() {
    @setFnTest(this);
    assert(should_be_1235 == 1235);
}

fn inlinedLoop() {
    @setFnTest(this);

    comptime var i = 0;
    comptime var sum = 0;
    inline while (i <= 5; i += 1)
        sum += i;
    assert(sum == 15);
}

fn gimme1or2(comptime a: bool) -> i32 {
    const x: i32 = 1;
    const y: i32 = 2;
    comptime var z: i32 = if (a) x else y;
    return z;
}
fn inlineVariableGetsResultOfConstIf() {
    @setFnTest(this);
    assert(gimme1or2(true) == 1);
    assert(gimme1or2(false) == 2);
}


fn staticFunctionEvaluation() {
    @setFnTest(this);

    assert(statically_added_number == 3);
}
const statically_added_number = staticAdd(1, 2);
fn staticAdd(a: i32, b: i32) -> i32 { a + b }


fn constExprEvalOnSingleExprBlocks() {
    @setFnTest(this);

    assert(constExprEvalOnSingleExprBlocksFn(1, true) == 3);
}

fn constExprEvalOnSingleExprBlocksFn(x: i32, b: bool) -> i32 {
    const literal = 3;

    const result = if (b) {
        literal
    } else {
        x
    };

    return result;
}




fn staticallyInitalizedList() {
    @setFnTest(this);

    assert(static_point_list[0].x == 1);
    assert(static_point_list[0].y == 2);
    assert(static_point_list[1].x == 3);
    assert(static_point_list[1].y == 4);
}
const Point = struct {
    x: i32,
    y: i32,
};
const static_point_list = []Point { makePoint(1, 2), makePoint(3, 4) };
fn makePoint(x: i32, y: i32) -> Point {
    return Point {
        .x = x,
        .y = y,
    };
}


fn staticEvalListInit() {
    @setFnTest(this);

    assert(static_vec3.data[2] == 1.0);
    assert(vec3(0.0, 0.0, 3.0).data[2] == 3.0);
}
const static_vec3 = vec3(0.0, 0.0, 1.0);
pub const Vec3 = struct {
    data: [3]f32,
};
pub fn vec3(x: f32, y: f32, z: f32) -> Vec3 {
    Vec3 {
        .data = []f32 { x, y, z, },
    }
}


fn constantExpressions() {
    @setFnTest(this);

    var array : [array_size]u8 = undefined;
    assert(@sizeOf(@typeOf(array)) == 20);
}
const array_size : u8 = 20;


fn constantStructWithNegation() {
    @setFnTest(this);

    assert(vertices[0].x == -0.6);
}
const Vertex = struct {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
};
const vertices = []Vertex {
    Vertex { .x = -0.6, .y = -0.4, .r = 1.0, .g = 0.0, .b = 0.0 },
    Vertex { .x =  0.6, .y = -0.4, .r = 0.0, .g = 1.0, .b = 0.0 },
    Vertex { .x =  0.0, .y =  0.6, .r = 0.0, .g = 0.0, .b = 1.0 },
};


fn staticallyInitalizedStruct() {
    @setFnTest(this);

    st_init_str_foo.x += 1;
    assert(st_init_str_foo.x == 14);
}
const StInitStrFoo = struct {
    x: i32,
    y: bool,
};
var st_init_str_foo = StInitStrFoo { .x = 13, .y = true, };


fn staticallyInitializedArrayLiteral() {
    @setFnTest(this);

    const y : [4]u8 = st_init_arr_lit_x;
    assert(y[3] == 4);
}
const st_init_arr_lit_x = []u8{1,2,3,4};


fn constSlice() {
    @setFnTest(this);

    comptime {
        const a = "1234567890";
        assert(a.len == 10);
        const b = a[1...2];
        assert(b.len == 1);
        assert(b[0] == '2');
    }
}

fn tryToTrickEvalWithRuntimeIf() {
    @setFnTest(this);

    assert(testTryToTrickEvalWithRuntimeIf(true) == 10);
}

fn testTryToTrickEvalWithRuntimeIf(b: bool) -> usize {
    comptime var i: usize = 0;
    inline while (i < 10; i += 1) {
        const result = if (b) false else true;
    }
    comptime {
        return i;
    }
}
