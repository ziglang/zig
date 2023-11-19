export fn entry() void {
    var x: u32 = 0;
    _ = &x;
    for (0..1, 1..2) |_, _| {
        var y = x + if (x == 0) 1 else 0;
        _ = &y;
    }
}

// error
// backend=stage2
// target=native
//
// :5:21: error: value with comptime-only type 'comptime_int' depends on runtime control flow
// :4:10: note: runtime control flow here
