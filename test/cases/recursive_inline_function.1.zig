// This additionally tests that the compile error reports the correct source location.
// Without storing source locations relative to the owner decl, the compile error
// here would be off by 2 bytes (from the "7" -> "999").
pub fn main() void {
    const y = fibonacci(999);
    if (y - 21 != 0) unreachable;
}

inline fn fibonacci(n: usize) usize {
    if (n <= 2) return n;
    return fibonacci(n - 2) + fibonacci(n - 1);
}

// error
//
// :11:21: error: evaluation exceeded 1000 backwards branches
// :11:21: note: use @setEvalBranchQuota() to raise the branch limit from 1000
// :11:40: note: called from here (6 times)
// :11:21: note: called from here (495 times)
// :5:24: note: called from here
