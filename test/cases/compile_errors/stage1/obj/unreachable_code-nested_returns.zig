export fn a() i32 {
    return return 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: unreachable code
// tmp.zig:2:12: note: control flow is diverted here
