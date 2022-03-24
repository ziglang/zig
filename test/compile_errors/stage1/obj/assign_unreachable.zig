export fn f() void {
    const a = return;
}

// assign unreachable
//
// tmp.zig:2:5: error: unreachable code
// tmp.zig:2:15: note: control flow is diverted here
