export fn f() void {
    if (true) |x| { _ = x; }
}

// invalid maybe type
//
// tmp.zig:2:9: error: expected optional type, found 'bool'
