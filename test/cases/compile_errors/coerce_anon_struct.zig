const A = struct { x: u32 };
const T = struct { x: u32 };
export fn foo() void {
    const a = A{ .x = 123 };
    _ = @as(T, a);
}

// error
//
// :5:16: error: expected type 'tmp.T', found 'tmp.A'
// :1:11: note: struct declared here
// :2:11: note: struct declared here
