comptime {
    _ = fn name() void;
}
comptime {
    _ = fn () align(128) void;
}
comptime {
    _ = fn () addrspace(.generic) void;
}
comptime {
    _ = fn () linksection("section") void;
}
comptime {
    _ = fn () !void;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: function type cannot have a name
// :5:21: error: function type cannot have an alignment
// :8:26: error: function type cannot have an addrspace
// :11:27: error: function type cannot have a linksection
// :14:15: error: function type cannot have an inferred error set
