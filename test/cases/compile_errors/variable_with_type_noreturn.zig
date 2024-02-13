export fn entry9() void {
    var z: noreturn = return;
    _ = &z;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: unreachable code
// :2:23: note: control flow is diverted here
