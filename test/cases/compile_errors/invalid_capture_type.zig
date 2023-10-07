export fn f1() void {
    if (true) |x| {
        _ = x;
    }
}
export fn f2() void {
    if (@as(usize, 5)) |_| {}
}
export fn f3() void {
    if (@as(usize, 5)) |_| {} else |_| {}
}
export fn f4() void {
    if (null) |_| {}
}
export fn f5() void {
    if (error.Foo) |_| {} else |_| {}
}

// error
// backend=stage2
// target=native
//
// :2:9: error: expected optional type, found 'bool'
// :7:9: error: expected optional type, found 'usize'
// :10:9: error: expected error union type, found 'usize'
// :16:9: error: expected error union type, found 'error{Foo}'
