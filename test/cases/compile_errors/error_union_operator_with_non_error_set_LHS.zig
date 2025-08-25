comptime {
    const z = i32!i32;
    const x: z = undefined;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected error set type, found 'i32'
