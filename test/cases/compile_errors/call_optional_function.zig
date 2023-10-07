pub export fn entry1() void {
    const optional_fn: ?fn () void = null;
    _ = optional_fn();
}
pub export fn entry2() void {
    const optional_fn_ptr: ?*const fn () void = null;
    _ = optional_fn_ptr();
}

// error
// backend=stage2
// target=native
//
// :3:9: error: cannot call optional type '?fn () void'
// :3:9: note: consider using '.?', 'orelse' or 'if'
// :7:9: error: cannot call optional type '?*const fn () void'
// :7:9: note: consider using '.?', 'orelse' or 'if'
