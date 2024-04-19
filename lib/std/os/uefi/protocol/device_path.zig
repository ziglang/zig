const std = @import("../../../std.zig");
const bits = @import("../bits.zig");

const uefi = std.os.uefi;
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

    /// Return the next node in this device path instance, if any.
    pub fn next(self: *const DevicePath) ?*const DevicePath {
        const next_addr = @intFromPtr(self) + self.length;
        const next_node: *const DevicePath = @ptrFromInt(next_addr);

        if (next_node.type == .end) {
            const subtype: DevicePathNode.End.Subtype = @enumFromInt(next_node.subtype);
            if (subtype == .entire or subtype == .this_instance)
                return null;
        }

        return next_node;
    }

    /// Returns the next instance in this device path, if any, skipping over any remaining nodes if present.
    pub fn nextInstance(self: *const DevicePath) ?*const DevicePath {
        var this_node: *const DevicePath = self;
        while (true) {
            const next_addr = @intFromPtr(this_node) + this_node.length;
            const next_node: *const DevicePath = @ptrFromInt(next_addr);

            if (this_node.type == .end) {
                const subtype: DevicePathNode.End.Subtype = @enumFromInt(this_node.subtype);
                if (subtype == .entire) {
                    return null;
                } else if (subtype == .this_instance) {
                    return next_node;
                }
            }

            this_node = next_node;
        }
    }

    /// Calculates the length of this device path instance in bytes, including the end of device path node.
    pub fn size(self: *const DevicePath) usize {
        var this_node: *const DevicePath = self;
        while (true) {
            const next_addr = @intFromPtr(this_node) + this_node.length;
            const next_node: *const DevicePath = @ptrFromInt(next_addr);

            if (this_node.type == .end) {
                return next_addr - @intFromPtr(self);
            }

            this_node = next_node;
        }
    }

    /// Calculates the total length of the device path structure in bytes, including the end of device path node.
    pub fn sizeEntire(self: *const DevicePath) usize {
        var this_node: *const DevicePath = self;
        while (true) {
            const next_addr = @intFromPtr(this_node) + this_node.length;
            const next_node: *const DevicePath = @ptrFromInt(next_addr);

            if (this_node.type == .end) {
                const subtype: DevicePathNode.End.Subtype = @enumFromInt(this_node.subtype);
                if (subtype == .entire) {
                    return next_addr - @intFromPtr(self);
                }
            }

            this_node = next_node;
        }
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
    pub fn appendNode(self: *DevicePath, allocator: Allocator, node_to_append: *const DevicePathNode) !*DevicePath {
        const original_size = self.sizeEntire();
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

    /// Appends a device path to the end of an existing device path. `allocator` must own the memory of the existing
    /// device path. The existing device path must be the start of the entire device path chain.
    ///
    /// This will reallocate the existing device path. The pointer returned here must be used instead of any dangling
    /// references to the previous device path.
    pub fn appendPath(self: *DevicePath, allocator: Allocator, path: *DevicePath) !*DevicePath {
        const original_size = self.sizeEntire();
        const other_size = path.sizeEntire();

        const new_size = original_size + other_size - 4;

        const original_bytes: [*]u8 = @ptrCast(self);
        const new_bytes = try allocator.realloc(original_bytes[0..original_size], new_size);

        const path_bytes: [*]const u8 = @ptrCast(path);

        // Copy path on top of the previous end entire node.
        @memcpy(new_bytes[original_size - 4 ..], path_bytes[0..other_size]);

        return @ptrCast(new_bytes);
    }

    /// Appends a device path instance to the end of an existing device path. `allocator` must own the memory of the existing
    /// device path. The existing device path must be the start of the entire device path chain.
    ///
    /// The end of entire device path node will be replaced with the end of this instance node.
    /// The end of entire device path node will be copied from the appended device path instance.
    ///
    /// This will reallocate the existing device path. The pointer returned here must be used instead of any dangling
    /// references to the previous device path.
    pub fn appendPathInstance(self: *DevicePath, allocator: Allocator, path: *DevicePath) !*DevicePath {
        const original_size = self.sizeEntire();
        const other_size = path.sizeEntire();

        const new_size = original_size + other_size;

        const original_bytes: [*]u8 = @ptrCast(self);
        const new_bytes = try allocator.realloc(original_bytes[0..original_size], new_size);

        const path_bytes: [*]const u8 = @ptrCast(path);

        // Copy path after of the previous end entire node.
        @memcpy(new_bytes[original_size..], path_bytes[0..other_size]);

        // change end entire node to end this instance node
        const end_of_existing: *DevicePath = @ptrCast(new_bytes.ptr + original_size - 4);
        end_of_existing.subtype = @intFromEnum(DevicePathNode.End.Subtype.this_instance);

        return @ptrCast(new_bytes);
    }

    /// Returns true if this device path is a multi-instance device path.
    pub fn isMultiInstance(self: *const DevicePath) bool {
        return self.nextInstance() != null;
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
