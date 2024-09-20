export fn entry1() void {
    var x: error{Foo}!u32 = 0;
    _ = &x;
    if (x) |_| {} else |err| switch (err + 1) {
        else => {},
    }
}

export fn entry2() void {
    var x: error{Foo}!u32 = 0;
    _ = &x;
    _ = x catch |err| switch (err + 1) {
        else => {},
    };
}

// error
// backend=stage2
// target=native
//
// :4:42: error: invalid operands to binary expression: 'error_set' and 'comptime_int'
// :12:35: error: invalid operands to binary expression: 'error_set' and 'comptime_int'
