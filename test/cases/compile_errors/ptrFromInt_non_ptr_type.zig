pub export fn entry() void {
    _ = @as(i32, @ptrFromInt(10));
}

pub export fn entry2() void {
    _ = @as([]u8, @ptrFromInt(20));
}

// error
// backend=stage2
// target=native
//
// :2:18: error: expected pointer type, found 'i32'
// :6:19: error: integer cannot be converted to slice type '[]u8'
// :6:19: note: slice length cannot be inferred from address
