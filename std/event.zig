pub const Locked = @import("event/locked.zig").Locked;
pub const Loop = @import("event/loop.zig").Loop;
pub const Lock = @import("event/lock.zig").Lock;
pub const tcp = @import("event/tcp.zig");
pub const Channel = @import("event/channel.zig").Channel;
pub const Group = @import("event/group.zig").Group;

test "import event tests" {
    _ = @import("event/locked.zig");
    _ = @import("event/loop.zig");
    _ = @import("event/lock.zig");
    _ = @import("event/tcp.zig");
    _ = @import("event/channel.zig");
    _ = @import("event/group.zig");
}
