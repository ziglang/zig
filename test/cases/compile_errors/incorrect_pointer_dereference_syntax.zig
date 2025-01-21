pub export fn entry() void {
    const a: *u32 = undefined;
    _ = *a;
}

// error
//
// :3:10: error: expected type 'type', found '*u32'
// :3:10: note: use '.*' to dereference pointer
