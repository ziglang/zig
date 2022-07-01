export fn f() void {
    var bad : bool = undefined;
    bad[0] = bad[0];
}
export fn g() void {
    var bad : bool = undefined;
    _ = bad[0];
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:8: error: array access of non-array type 'bool'
// tmp.zig:7:12: error: array access of non-array type 'bool'
