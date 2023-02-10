export fn f() void {
    break;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: break expression outside loop
