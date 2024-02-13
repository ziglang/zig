pub export fn entry() void {
    @as(fn () void, undefined)();
}

// error
// backend=stage2
// target=native
//
// :2:31: error: use of undefined value here causes undefined behavior
