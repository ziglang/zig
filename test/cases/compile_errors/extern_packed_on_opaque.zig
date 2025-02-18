const X = extern opaque {};
const Y = packed opaque {};

export fn foo(x: *X, y: *Y) void {
    _ = x;
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :1:11: error: opaque types do not support 'packed' or 'extern'
// :2:11: error: opaque types do not support 'packed' or 'extern'
