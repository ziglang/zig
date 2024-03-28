const Input = struct {
    value: u32 = @as(error{}!u32, 0),
};
export fn foo() void {
    var x: Input = Input{};
    _ = &x;
}

// error
//
//:2:18: error: expected type 'u32', found 'error{}!u32'
//:2:18: note: cannot convert error union to payload type
//:2:18: note: consider using 'try', 'catch', or 'if'
