export fn a() void {
    return;
    b();
}

fn b() void {}

// error
// backend=stage2
// target=native
//
// :3:6: error: unreachable code
// :2:5: note: control flow is diverted here
