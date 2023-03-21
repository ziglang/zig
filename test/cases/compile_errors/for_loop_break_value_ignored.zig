fn returns() usize {
    return 2;
}

export fn f1() void {
    for ("hello") |_| {
        break returns();
    }
}

// error
// backend=stage2
// target=native
//
// :6:5: error: incompatible types: 'usize' and 'void'
// :7:22: note: type 'usize' here
