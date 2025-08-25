export fn f1() void {
    const x: usize = for ("hello") |_| {};
    _ = x;
}
export fn f2() void {
    const x: usize = for ("hello") |_| {
        break;
    };
    _ = x;
}
export fn f3() void {
    var t: bool = true;
    _ = &t;
    const x: usize = while (t) {
        break;
    };
    _ = x;
}
export fn f4() void {
    const x: usize = blk: {
        break :blk;
    };
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:22: error: expected type 'usize', found 'void'
// :7:9: error: expected type 'usize', found 'void'
// :15:9: error: expected type 'usize', found 'void'
// :21:9: error: expected type 'usize', found 'void'
