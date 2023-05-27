const x = @extern(*u3, .{.name="foo"});
pub export fn entry() void {
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :1:19: error: extern symbol cannot have type '*u3'
// :1:19: note: only integers with power of two bits are extern compatible
