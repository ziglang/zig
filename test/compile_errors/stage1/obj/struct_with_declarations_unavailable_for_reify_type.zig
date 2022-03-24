export fn entry() void {
    _ = @Type(@typeInfo(struct { const foo = 1; }));
}

// struct with declarations unavailable for @Type
//
// tmp.zig:2:15: error: Type.Struct.decls must be empty for @Type
