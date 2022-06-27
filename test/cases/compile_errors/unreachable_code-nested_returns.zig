export fn a() i32 {
    return return 1;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: unreachable code
// :2:12: note: control flow is diverted here
