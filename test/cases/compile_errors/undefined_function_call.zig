export fn a() void {
    b();
}

// error
// backend=stage2
// target=native
//
// :2:5: error: use of undeclared identifier 'b'
