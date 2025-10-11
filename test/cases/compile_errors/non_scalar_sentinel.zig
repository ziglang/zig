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

// error
//
// :5:12: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :8:11: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
// :11:12: error: non-scalar sentinel type 'tmp.S'
// :1:11: note: struct declared here
