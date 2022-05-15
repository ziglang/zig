fn returns() usize {
    return 2;
}
export fn f1() void {
    while (true) returns();
}
export fn f2() void {
    var x: ?i32 = null;
    while (x) |_| returns();
}
export fn f3() void {
    var x: anyerror!i32 = error.Bad;
    while (x) |_| returns() else |_| unreachable;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:25: error: expression value is ignored
// tmp.zig:9:26: error: expression value is ignored
// tmp.zig:13:26: error: expression value is ignored
