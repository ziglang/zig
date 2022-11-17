pub export fn entry() void {
    _ = @intToPtr(i32, 10);
}

// error
// backend=stage2
// target=native
//
// :2:19: error: expected pointer type, found 'i32'
