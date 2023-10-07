const S = struct {
    x: u32,
};
fn reassign(s: S) void {
    s = S{ .x = 2 };
}
export fn entry() void {
    reassign(S{ .x = 3 });
}

// error
// backend=stage2
// target=native
//
// :5:5: error: cannot assign to constant
