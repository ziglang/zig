export fn f() void {
    const a = return;
    _ = a;
}

// error
//
// :2:5: error: unreachable code
// :2:15: note: control flow is diverted here
