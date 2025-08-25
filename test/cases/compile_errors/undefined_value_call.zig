pub export fn entry() void {
    @as(fn () void, undefined)();
}

// error
//
// :2:31: error: use of undefined value here causes illegal behavior
