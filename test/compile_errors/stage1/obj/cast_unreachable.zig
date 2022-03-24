fn f() i32 {
    return @as(i32, return 1);
}
export fn entry() void { _ = f(); }

// cast unreachable
//
// tmp.zig:2:12: error: unreachable code
// tmp.zig:2:21: note: control flow is diverted here
