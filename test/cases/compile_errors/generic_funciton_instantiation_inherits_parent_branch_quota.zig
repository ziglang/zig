pub export fn entry1() void {
    @setEvalBranchQuota(1001);
    // Return type evaluation should inherit both the
    // parent's branch quota and count meaning
    // at least 2002 backwards branches are required.
    comptime var i = 0;
    inline while (i < 1000) : (i += 1) {}
    _ = simple(10);
}
pub export fn entry2() void {
    @setEvalBranchQuota(2001);
    comptime var i = 0;
    inline while (i < 1000) : (i += 1) {}
    _ = simple(10);
}
fn simple(comptime n: usize) Type(n) {
    return n;
}
fn Type(comptime n: usize) type {
    if (n <= 1) return usize;
    return Type(n - 1);
}

// error
// backend=stage2
// target=native
//
// :21:16: error: evaluation exceeded 1001 backwards branches
// :21:16: note: use @setEvalBranchQuota() to raise the branch limit from 1001
// :16:34: note: called from here
