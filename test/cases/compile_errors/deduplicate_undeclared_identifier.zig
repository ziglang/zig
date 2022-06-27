export fn a() void {
    x += 1;
}
export fn b() void {
    x += 1;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: use of undeclared identifier 'x'
// :5:5: error: use of undeclared identifier 'x'
