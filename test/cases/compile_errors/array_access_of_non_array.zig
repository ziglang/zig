export fn f() void {
    var bad : bool = undefined;
    bad[0] = bad[0];
}
export fn g() void {
    var bad : bool = undefined;
    _ = bad[0];
}

// error
// backend=stage2
// target=native
//
// :3:8: error: element access of non-indexable type 'bool'
// :7:12: error: element access of non-indexable type 'bool'
