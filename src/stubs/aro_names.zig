//! Stub implementation only used when bootstrapping stage2
//! Keep in sync with deps/aro/build/GenerateDef.zig

pub fn with(comptime _: type) type {
    return struct {
        pub inline fn fromName(_: []const u8) ?@This() {
            return null;
        }
    };
}
