export fn foo(a: i32, b: i32) i32 {
    return a % b;
}

// signed integer remainder division
//
// tmp.zig:2:14: error: remainder division with 'i32' and 'i32': signed integers and floats must use @rem or @mod
