export fn a() void {
    return;
    b();
}

fn b() void {}

// error
//
// :3:6: error: unreachable code
// :2:5: note: control flow is diverted here
