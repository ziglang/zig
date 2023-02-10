export fn entry() void {
    if (2 == undefined) {}
}

// error
// backend=stage2
// target=native
//
// :2:11: error: use of undefined value here causes undefined behavior
