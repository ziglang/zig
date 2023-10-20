pub export fn entry() void {
    @as(fn () void, undefined)();
}

// error
// backend=stage2
// target=native
//
// :2:31: error: unable to call 'undefined'
