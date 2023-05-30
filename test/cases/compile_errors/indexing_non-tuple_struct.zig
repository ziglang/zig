export fn a() void {
    const S = struct { x: i32, y: i32 };
    var s: S = undefined;
    s[0] = 10;
}

// error
// backend=stage2
// target=native
//
// :4:6: error: type 'tmp.a.S' does not support indexing
// :4:6: note: operand must be an array, slice, tuple, or vector
