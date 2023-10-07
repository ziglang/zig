export fn a() void {
    return b + c;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: use of undeclared identifier 'b'
