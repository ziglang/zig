const std = @import("../../../std.zig");
const bits = @import("../bits.zig");

const mem = std.mem;
const cc = bits.cc;
const DevicePathNode = @import("../device_path.zig").DevicePathNode;

const Handle = bits.Handle;
const Guid = bits.Guid;
const Allocator = mem.Allocator;

const assert = std.debug.assert;

// All Device Path Nodes are byte-packed and may appear on any byte boundary.
// All code references to device path nodes must assume all fields are unaligned.

pub const DevicePath = extern struct {
    type: DevicePathNode.Type,
    subtype: u8,
    length: u16 align(1),

    pub const guid align(8) = Guid{
        .time_low = 0x09576e91,
        .time_mid = 0x6d3f,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };

    pub const loaded_image_guid align(8) = Guid{
        .time_low = 0xbc62157e,
        .time_mid = 0x3e33,
        .time_high_and_version = 0x4fec,
        .clock_seq_high_and_reserved = 0x99,
        .clock_seq_low = 0x20,
        .node = [_]u8{ 0x2d, 0x3b, 0x36, 0xd7, 0x50, 0xdf },
    };

    /// Returns the next DevicePath node in the sequence, if any.
    fn next(self: *const DevicePath) ?*const DevicePath {
        const subtype: DevicePathNode.End.Subtype = @enumFromInt(self.subtype);
        if (self.type != .end or subtype != .entire)
            return null;

        const next_addr = @intFromPtr(self) + self.length;
        return @ptrFromInt(next_addr);
    }

    /// Calculates the total length of the device path structure in bytes, including the end of device path node.
    pub fn size(self: *const DevicePath) usize {
        var cur_node = self;

        while (cur_node.next()) |next_node| {
            cur_node = next_node;
        }

        return (@intFromPtr(cur_node) + cur_node.length) - @intFromPtr(self);
    }

    /// Creates a new device path with only the end entire node. The device path will be owned by the caller.
    pub fn create(allocator: Allocator) !*DevicePath {
        const bytes = try allocator.alloc(u8, 4);

        const device_path: *DevicePath = @ptrCast(bytes.ptr);
        device_path.type = .end;
        device_path.subtype = @intFromEnum(DevicePathNode.End.Subtype.entire);
        device_path.length = 4;

        return device_path;
    }

    /// Appends a device path node to the end of an existing device path. `allocator` must own the memory of the
    /// existing device path. The existing device path must be the start of the entire device path chain.
    /// 
    /// This will reallocate the existing device path. The pointer returned here must be used instead of any dangling
    /// references to the previous device path.
    pub fn append(self: *DevicePath, allocator: Allocator, node_to_append: DevicePathNode) !*DevicePath {
        const original_size = self.size();
        const new_size = original_size + node_to_append.toGeneric().length;

        const original_bytes: [*]u8 = @ptrCast(self);
        const new_bytes = try allocator.realloc(original_bytes[0..original_size], new_size);

        // copy end entire node to the end of the new buffer. It is always 4 bytes.
        @memcpy(new_bytes[new_size - 4 ..], new_bytes[original_size - 4 .. original_size]);

        const node_bytes: [*]const u8 = @ptrCast(node_to_append.toGeneric());

        // Copy new node on top of the previous end entire node.
        @memcpy(new_bytes[original_size - 4 .. new_size - 4], node_bytes[0..node_to_append.toGeneric().length]);

        return @ptrCast(new_bytes);
    }

    /// Returns the DevicePathNode union for this device path protocol
    pub fn node(self: *const DevicePath) ?DevicePathNode {
        inline for (@typeInfo(DevicePathNode).Union.fields) |type_field| {
            if (self.type == @field(DevicePathNode.Type, type_field.name)) {
                const subtype: type_field.type.Subtype = @enumFromInt(self.subtype);

                inline for (@typeInfo(type_field.type).Union.fields) |subtype_field| {
                    if (subtype == @field(type_field.type.Subtype, subtype_field.name)) {
                        return @unionInit(DevicePathNode, type_field.name, @unionInit(type_field.type, subtype_field.name, @ptrCast(self)));
                    }
                }
            }
        }

        return null;
    }
};

comptime {
    assert(4 == @sizeOf(DevicePath));
    assert(1 == @alignOf(DevicePath));

    assert(0 == @offsetOf(DevicePath, "type"));
    assert(1 == @offsetOf(DevicePath, "subtype"));
    assert(2 == @offsetOf(DevicePath, "length"));
}
