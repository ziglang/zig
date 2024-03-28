const err = error.Foo;

export fn entry1() void {
    const a: anyerror = @errorCast(1);
    _ = a;
}
export fn entry2() void {
    const a: i32 = @errorCast(err);
    _ = a;
}
export fn entry3() void {
    const e: anyerror!void = err;
    const a: anyerror = @errorCast(e);
    _ = a;
}
pub export fn entry4() void {
    const a: anyerror!u32 = 123;
    const b: anyerror!f32 = @errorCast(a);
    _ = b;
}

// error
// backend=stage2
// target=x86_64-linux
//
// :4:25: error: expected error set or error union type, found 'ComptimeInt'
// :8:20: error: expected error set or error union type, found 'Int'
// :13:25: error: cannot cast an error union type to error set
// :18:29: error: payload types of error unions must match
// :18:29: note: destination payload is 'f32'
// :18:29: note: operand payload is 'u32'
