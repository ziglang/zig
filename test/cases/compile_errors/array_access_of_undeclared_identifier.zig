export fn f() void {
    i[i] = i[i];
}

// error
//
// :2:5: error: use of undeclared identifier 'i'
