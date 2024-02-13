pub export fn entry() void {
    var a: *u32 = undefined;
    _ = *a;
    _ = &a;
}

// error
// backend=stage2
// target=native
//
// :3:10: error: expected type 'type', found '*u32'
// :3:10: note: use '.*' to dereference pointer
