fn a() bogus {}
export fn entry() void {
    _ = a();
}

// error
//
// :1:8: error: use of undeclared identifier 'bogus'
