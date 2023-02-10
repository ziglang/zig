export fn f() void {
    b = 3;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: use of undeclared identifier 'b'
