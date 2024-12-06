export fn foo() void {
    _ = @FieldType(u8, "a");
}
export fn bar() void {
    const S = struct { a: u8 };
    _ = @FieldType(S, "b");
}

// error
//
// :2:20: error: expected struct or union; found 'u8'
// :6:23: error: no field named 'b' in struct 'tmp.bar.S'
// :5:15: note: struct declared here
