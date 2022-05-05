const S = struct {
    x: u32,
};
fn reassign(s: S) void {
    s = S{.x = 2};
}
export fn entry() void {
    reassign(S{.x = 3});
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:5:10: error: cannot assign to constant
