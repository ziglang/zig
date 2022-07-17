export fn foo() void {
    1;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: expression value is ignored
