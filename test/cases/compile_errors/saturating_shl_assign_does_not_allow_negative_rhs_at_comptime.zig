export fn a() void {
    comptime {
        var x = @as(i32, 1);
        x <<|= @as(i32, -2);
    }
}

// error
// backend=stage2
// target=native
//
// :4:16: error: shift by negative amount '-2'
