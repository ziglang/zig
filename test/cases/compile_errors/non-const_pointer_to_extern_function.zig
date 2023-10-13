const x = @extern(*fn(u8) u8, .{.name="foo"});
pub export fn entry() void {
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :1:19: error: pointer to extern function should be 'const'
