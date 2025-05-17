export fn a() void {
    _ = @as(i32, 1) <<| @as(i32, -1);
}

comptime {
    var x: i32 = 1;
    x <<|= @as(i32, -2);
}

export fn b() void {
    _ = @Vector(1, i32){1} <<| @Vector(1, i32){-3};
}

comptime {
    var x: @Vector(2, i32) = .{ 1, 2 };
    x <<|= @Vector(2, i32){ 0, -4 };
}

export fn c(rhs: i32) void {
    _ = @as(i32, 1) <<| rhs;
}

export fn d(rhs: @Vector(3, i32)) void {
    _ = @Vector(3, i32){ 1, 2, 3 } <<| rhs;
}

// error
// backend=stage2
// target=native
//
// :2:25: error: shift by negative amount '-1'
// :7:12: error: shift by negative amount '-2'
// :11:47: error: shift by negative amount '-3' at index '0'
// :16:27: error: shift by negative amount '-4' at index '1'
// :20:25: error: shift by signed type 'i32'
// :24:40: error: shift by signed type '@Vector(3, i32)'
