fn returns() usize {
    return 2;
}

export fn f1() void {
    var a: bool = true;
    while (a) {
        break returns();
    }
    _ = &a;
}

export fn f2() void {
    var x: bool = true;
    outer: while (x) {
        while (x) {
            break :outer returns();
        }
    }
    _ = &x;
}

// error
// backend=stage2
// target=native
//
// :7:5: error: incompatible types: 'usize' and 'void'
// :8:22: note: type 'usize' here
// :15:12: error: incompatible types: 'usize' and 'void'
// :17:33: note: type 'usize' here
