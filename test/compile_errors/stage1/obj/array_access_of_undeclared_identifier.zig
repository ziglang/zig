export fn f() void {
    i[i] = i[i];
}

// array access of undeclared identifier
//
// tmp.zig:2:5: error: use of undeclared identifier 'i'
