fn foo() bool {
    const a = @as([]const u8, "a");
    const b = &a;
    return ptrEql(b, b);
}
fn ptrEql(a: *[]const u8, b: *[]const u8) bool {
    _ = a;
    _ = b;
    return true;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&foo));
}

// error
// backend=stage2
// target=native
//
// :4:19: error: expected type '*[]const u8', found '*const []const u8'
// :4:19: note: cast discards const qualifier
// :6:14: note: parameter type declared here
