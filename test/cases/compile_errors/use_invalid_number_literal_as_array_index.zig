var v = 25;
export fn entry() void {
    var arr: [v]u8 = undefined;
    _ = &arr;
}

// error
// backend=stage2
// target=native
//
// :1:5: error: variable of type 'comptime_int' must be const or comptime
// :1:5: note: to modify this variable at runtime, it must be given an explicit fixed-size number type
