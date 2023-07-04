export fn a() void {
    var x: u0 = 0;
    @compileLog(@log2(x));
}
export fn b() void {
    _ = @log2(0);
}
export fn c() void {
    _ = @log2("hello");
}
export fn d() void {
    var x: i32 = 100;
    _ = @log2(x);
}
export fn e() void {
    _ = @log2(@as(i8, 0));
}
export fn f() void {
    var x: i16 = 0;
    _ = @log2(x);
}
export fn g() void {
    _ = @log2(-1);
}
export fn h() void {
    _ = @log2(@as(i8, -1));
}

// error
// backend=stage2
// target=native
//
// :3:23: error: @log2 integer operand cannot be zero
// :6:15: error: @log2 integer operand cannot be zero
// :9:15: error: expected integer, float, or vector of floats, found '*const [5:0]u8'
// :13:15: error: @log2 integer operand must be unsigned
// :16:15: error: @log2 integer operand cannot be zero
// :20:15: error: @log2 integer operand must be unsigned
// :23:15: error: @log2 integer operand must be positive
// :26:15: error: @log2 integer operand must be positive
