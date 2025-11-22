const S = struct {};
const sentinel: S = .{};

comptime {
    _ = [0:sentinel]S;
}
comptime {
    _ = [:sentinel]S;
}
comptime {
    _ = [*:sentinel]S;
}

comptime {
    _ = @Pointer(.slice, .{}, S, sentinel);
}
comptime {
    _ = @Pointer(.many, .{}, S, sentinel);
}

// error
//
// :5:12: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :8:11: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :11:12: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :15:34: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :18:33: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
