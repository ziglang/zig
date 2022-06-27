export fn foo() void {
    comptime 1;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: expression value is ignored
