export fn foo() void {
    defer {1;}
}

// error
// backend=stage2
// target=native
//
// :2:12: error: expression value is ignored
