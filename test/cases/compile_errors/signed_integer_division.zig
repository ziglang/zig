export fn foo(a: i32, b: i32) i32 {
    return a / b;
}

// error
// backend=stage2
// target=native
//
// :2:14: error: division with 'i32' and 'i32': signed integers must use @divTrunc, @divFloor, or @divExact
