export fn a() void {
    for (0.."hello") |i| {
        _ = i;
    }
}
export fn b() void {
    for (-1..-5) |i| {
        _ = i;
    }
}
export fn c() void {
    for ("hello"..0) |i| {
        _ = i;
    }
}
export fn d() void {
    for (0..&.{ 'a', 'b', 'c' }) |i| {
        _ = i;
    }
}
export fn e() void {
    for (@as(u8, 1)..0) |i| {
        _ = i;
    }
}

// error
// backend=stage2
// target=native
//
// :2:13: error: expected type 'usize', found '*const [5:0]u8'
// :7:10: error: type 'usize' cannot represent integer value '-1'
// :12:10: error: expected type 'usize', found '*const [5:0]u8'
// :17:13: error: expected type 'usize', found pointer
// :17:13: note: address-of operator always returns a pointer
// :22:20: error: overflow of integer type 'usize' with value '-1'
