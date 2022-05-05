export fn entry() void {
    if (2 == undefined) {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:11: error: use of undefined value here causes undefined behavior
