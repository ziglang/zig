pub const Stack = @import("stack.zig").Stack;
pub const Queue = @import("queue.zig").Queue;
pub const Int = @import("int.zig").Int;

test "std.atomic" {
    _ = @import("stack.zig");
    _ = @import("queue.zig");
    _ = @import("int.zig");
}
