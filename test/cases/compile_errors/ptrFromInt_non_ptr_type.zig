pub export fn entry() void {
    _ = @ptrFromInt(i32, 10);
}

pub export fn entry2() void {
    _ = @ptrFromInt([]u8, 20);
}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected pointer type, found 'i32'
// :6:21: error: integer cannot be converted to slice type '[]u8'
// :6:21: note: slice length cannot be inferred from address
