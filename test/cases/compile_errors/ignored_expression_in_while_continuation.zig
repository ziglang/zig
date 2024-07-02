export fn a() void {
    while (true) : (bad()) {}
}
export fn b() void {
    var x: anyerror!i32 = 1234;
    _ = &x;
    while (x) |_| : (bad()) {} else |_| {}
}
export fn c() void {
    var x: ?i32 = 1234;
    _ = &x;
    while (x) |_| : (bad()) {}
}
fn bad() anyerror!void {
    return error.Bad;
}

export fn d() void {
    while (true) : (bad2()) {}
}
fn bad2() anyerror {
    return error.Bad;
}

// error
// backend=stage2
// target=native
//
// :2:24: error: error union is ignored
// :2:24: note: consider using 'try', 'catch', or 'if'
// :7:25: error: error union is ignored
// :7:25: note: consider using 'try', 'catch', or 'if'
// :12:25: error: error union is ignored
// :12:25: note: consider using 'try', 'catch', or 'if'
// :19:25: error: error set is ignored
