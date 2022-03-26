fn returns() usize {
    return 2;
}
export fn f1() void {
    for ("hello") |_| returns();
}
export fn f2() void {
    var x: anyerror!i32 = error.Bad;
    for ("hello") |_| returns() else unreachable;
    _ = x;
}

// for loop body expression ignored
//
// tmp.zig:5:30: error: expression value is ignored
// tmp.zig:9:30: error: expression value is ignored
