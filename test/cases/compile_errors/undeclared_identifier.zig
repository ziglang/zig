export fn a() void {
    return
    b +
    c;
}

// error
// backend=stage2
// target=native
//
// :3:5: error: use of undeclared identifier 'b'
