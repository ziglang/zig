export fn a() void {
    comptime 1;
}
export fn b() void {
    comptime bar();
}
fn bar() u8 {
    const u32_max = @import("std").math.maxInt(u32);

    @setEvalBranchQuota(u32_max);
    var x: u32 = 0;
    while (x != u32_max) : (x +%= 1) {}

    return 0;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: value of type 'comptime_int' ignored
// :2:5: note: all non-void values must be used
// :2:5: note: this error can be suppressed by assigning the value to '_'
// :5:17: error: value of type 'u8' ignored
// :5:17: note: all non-void values must be used
// :5:17: note: this error can be suppressed by assigning the value to '_'
