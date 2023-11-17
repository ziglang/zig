//! Stub implementation only used when bootstrapping stage2
//! Keep in sync with deps/aro/build/GenerateDef.zig

pub fn with(comptime Properties: type) type {
    return struct {
        tag: Tag = @enumFromInt(0),
        properties: Properties = undefined,
        pub const max_param_count = 1;
        pub const longest_name = 0;
        pub const data = [_]@This(){.{}};
        pub inline fn fromName(_: []const u8) ?@This() {
            return .{};
        }
        pub fn nameFromUniqueIndex(_: u16, _: []u8) []u8 {
            return "";
        }
        pub fn uniqueIndex(_: []const u8) ?u16 {
            return null;
        }
        pub const Tag = enum(u16) { _ };
        pub fn nameFromTag(_: Tag) NameBuf {
            return .{};
        }
        pub fn tagFromName(name: []const u8) ?Tag {
            return @enumFromInt(name.len);
        }
        pub const NameBuf = struct {
            pub fn span(_: *const NameBuf) []const u8 {
                return "";
            }
        };
    };
}
