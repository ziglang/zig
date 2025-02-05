const S = struct { self: *S, x: u32 };
const s: S = .{ .self = &s, .x = 123 };

comptime {
    _ = s;
}

// error
//
// :2:18: error: expected type '*tmp.S', found '*const tmp.S'
// :2:18: note: cast discards const qualifier
