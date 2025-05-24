const T = struct { x: u32 };
export fn foo() void {
    const a = .{ .x = 123 };
    _ = @as(T, a);
}

// error
//
// :4:16: error: expected type 'tmp.T', found 'tmp.foo__struct_468'
// :3:16: note: struct declared here
// :1:11: note: struct declared here
