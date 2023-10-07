fn a() bogus {}
export fn entry() void {
    _ = a();
}

// error
// backend=stage2
// target=native
//
// :1:8: error: use of undeclared identifier 'bogus'
