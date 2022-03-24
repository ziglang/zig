export fn a() void {
    return;
    b();
}

fn b() void {}

// unreachable code
//
// tmp.zig:3:6: error: unreachable code
// tmp.zig:2:5: note: control flow is diverted here
