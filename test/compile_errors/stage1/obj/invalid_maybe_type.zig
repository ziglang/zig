export fn f() void {
    if (true) |x| { _ = x; }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:9: error: expected optional type, found 'bool'
