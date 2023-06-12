pub export fn entry() void {
    _ = @intToPtr(i32, 10);
}

pub export fn entry2() void {
    _ = @intToPtr([]u8, 20);
}

// error
// backend=stage2
// target=native
//
// :2:19: error: expected pointer type, found 'i32'
// :6:19: error: integer cannot be converted to slice type '[]u8'
// :6:19: note: slice length cannot be inferred from address
