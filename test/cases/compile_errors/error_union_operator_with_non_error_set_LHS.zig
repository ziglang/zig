comptime {
    const z = i32!i32;
    const x: z = undefined;
    _ = x;
}

// error
//
// :2:15: error: expected error set type, found 'i32'
