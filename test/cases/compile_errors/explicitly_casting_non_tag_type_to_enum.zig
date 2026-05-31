const Small = enum(u2) {
    One,
    Two,
    Three,
    Four,
};

export fn entry() void {
    var y = @as(f32, 3);
    const x: Small = @enumFromInt((&y).*);
    _ = x;
}

// error
//
// :10:39: error: expected integer type, found 'f32'
