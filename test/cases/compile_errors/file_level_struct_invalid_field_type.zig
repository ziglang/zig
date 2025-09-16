const Parser = @This();
fn Chunk() type {
    return struct {
        const Self = @This();
    };
}
parser_chunk: Chunk,

comptime {
    _ = @sizeOf(@This()) + 1;
}

// error
//
// :7:15: error: expected type 'type', found 'fn () type'
