export fn a() void {
    const s: [2]usize = .{ 2, 1 };
    var arr: [2]*anyopaque = undefined;
    for (0..2) |i| {
        arr[i] = B(s[i]).c();
    }
}

fn B(comptime N: usize) type {
    return struct {
        x: [N]u8 = undefined,

        pub fn c() *@This() {
            @trap();
        }
    };
}

// error
// backend=stage2
// target=native
//
// :5:21: error: unable to evaluate comptime expression
// :5:22: note: operation is runtime due to this operand
