pub const Stack = @import("stack.zig").Stack;
pub const QueueMpsc = @import("queue_mpsc.zig").QueueMpsc;
pub const QueueMpmc = @import("queue_mpmc.zig").QueueMpmc;
pub const Int = @import("int.zig").Int;

test "std.atomic" {
    _ = @import("stack.zig");
    _ = @import("queue_mpsc.zig");
    _ = @import("queue_mpmc.zig");
    _ = @import("int.zig");
}
