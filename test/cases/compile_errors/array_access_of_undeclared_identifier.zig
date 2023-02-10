export fn f() void {
    i[i] = i[i];
}

// error
// backend=stage2
// target=native
//
// :2:5: error: use of undeclared identifier 'i'
