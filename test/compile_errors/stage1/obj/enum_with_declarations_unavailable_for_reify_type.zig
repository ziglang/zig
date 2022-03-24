export fn entry() void {
    _ = @Type(@typeInfo(enum { foo, const bar = 1; }));
}

// enum with declarations unavailable for @Type
//
// tmp.zig:2:15: error: Type.Enum.decls must be empty for @Type
