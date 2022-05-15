export fn entry9() void {
    var z: noreturn = return;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: unreachable code
// tmp.zig:2:23: note: control flow is diverted here
