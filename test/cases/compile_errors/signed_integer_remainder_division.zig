export fn foo(a: i32, b: i32) i32 {
    return a % b;
}

// error
//
// :2:12: error: remainder division with 'i32' and 'i32': signed integers and floats must use @rem or @mod
