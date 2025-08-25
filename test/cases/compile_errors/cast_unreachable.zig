fn f() i32 {
    return @as(i32, return 1);
}
export fn entry() void {
    _ = f();
}

// error
// backend=stage2
// target=native
//
// :2:12: error: unreachable code
// :2:21: note: control flow is diverted here
// :2:5: error: unreachable code
// :2:12: note: control flow is diverted here
