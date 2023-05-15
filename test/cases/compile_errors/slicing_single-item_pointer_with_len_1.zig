export fn entry(ptr: *i32) void {
    const slice = ptr[0..];
    _ = slice;
}

// error
// backend=stage2
// target=native
//
// :2:22: error: slice of single-item pointer
// :2:22: note: single-item pointer can be coerced to array using '@as(*[1]i32, ptr)'
