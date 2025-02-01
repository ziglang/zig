comptime {
    const in: []const comptime_int = &.{0};
    const out: []const type = @ptrCast(in);
    _ = out;
}

const One = u8;
const Two = [2]u8;
const Three = [3]u8;
const Four = [4]u8;
const Five = [5]u8;

// []One -> []Two (small to big, divides neatly)
comptime {
    const in: []const One = &.{ 1, 0, 0 };
    const out: []const Two = @ptrCast(in);
    _ = out;
}
comptime {
    const in: *const [3]One = &.{ 1, 0, 0 };
    const out: []const Two = @ptrCast(in);
    _ = out;
}

// []Four -> []Five (small to big, does not divide)
comptime {
    const in: []const Four = &.{.{ 0, 0, 0, 0 }};
    const out: []const Five = @ptrCast(in);
    _ = out;
}
comptime {
    const in: *const [1]Four = &.{.{ 0, 0, 0, 0 }};
    const out: []const Five = @ptrCast(in);
    _ = out;
}

// []Three -> []Two (big to small, does not divide)
comptime {
    const in: []const Three = &.{.{ 0, 0, 0 }};
    const out: []const Two = @ptrCast(in);
    _ = out;
}
comptime {
    const in: *const [1]Three = &.{.{ 0, 0, 0 }};
    const out: []const Two = @ptrCast(in);
    _ = out;
}

// error
//
// :3:31: error: cannot infer length of slice of 'type' from slice of 'comptime_int'
// :16:30: error: slice length '3' does not divide exactly into destination elements
// :21:30: error: slice length '3' does not divide exactly into destination elements
// :28:31: error: slice length '1' does not divide exactly into destination elements
// :33:31: error: slice length '1' does not divide exactly into destination elements
// :40:30: error: slice length '1' does not divide exactly into destination elements
// :45:30: error: slice length '1' does not divide exactly into destination elements
