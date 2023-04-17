fn returns() usize {
    return 2;
}

export fn f1() void {
    var a: bool = true;
    while (a) {
        break returns();
    }
}

export fn f2() void {
    var x: bool = true;
    outer: while (x) {
        while (x) {
            break :outer returns();
        }
    }
}

// error
// backend=stage2
// target=native
//
// :7:5: error: incompatible types: 'usize' and 'void'
// :8:22: note: type 'usize' here
// :14:12: error: incompatible types: 'usize' and 'void'
// :16:33: note: type 'usize' here
