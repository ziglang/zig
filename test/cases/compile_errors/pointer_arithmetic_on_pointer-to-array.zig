export fn foo() void {
    var x: [10]u8 = undefined;
    var y = &x;
    var z = y + 1;
    _ = z;
}

// error
// backend=stage2
// target=native
//
// :4:15: error: incompatible types: '*[10]u8' and 'comptime_int'
// :4:13: note: type '*[10]u8' here
// :4:17: note: type 'comptime_int' here
