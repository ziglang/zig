const std = @import("../../../std.zig");
const mem = std.mem;
const uefi = std.os.uefi;
const Allocator = mem.Allocator;
const Guid = uefi.Guid;
const assert = std.debug.assert;

// All Device Path Nodes are byte-packed and may appear on any byte boundary.
// All code references to device path nodes must assume all fields are unaligned.

pub const DevicePath = extern struct {
    type: uefi.DevicePath.Type,
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

    /// Returns the next DevicePath node in the sequence, if any.
    pub fn next(self: *DevicePath) ?*DevicePath {
        if (self.type == .End and @as(uefi.DevicePath.End.Subtype, @enumFromInt(self.subtype)) == .EndEntire)
            return null;

        return @as(*DevicePath, @ptrCast(@as([*]u8, @ptrCast(self)) + self.length));
    }

    /// Calculates the total length of the device path structure in bytes, including the end of device path node.
    pub fn size(self: *DevicePath) usize {
        var node = self;

        while (node.next()) |next_node| {
            node = next_node;
        }

        return (@intFromPtr(node) + node.length) - @intFromPtr(self);
    }

    /// Creates a file device path from the existing device path and a file path.
    pub fn create_file_device_path(self: *DevicePath, allocator: Allocator, path: [:0]align(1) const u16) !*DevicePath {
        const path_size = self.size();

        // 2 * (path.len + 1) for the path and its null terminator, which are u16s
        // DevicePath for the extra node before the end
        var buf = try allocator.alloc(u8, path_size + 2 * (path.len + 1) + @sizeOf(DevicePath));

        @memcpy(buf[0..path_size], @as([*]const u8, @ptrCast(self))[0..path_size]);

        // Pointer to the copy of the end node of the current chain, which is - 4 from the buffer
        // as the end node itself is 4 bytes (type: u8 + subtype: u8 + length: u16).
        var new = @as(*uefi.DevicePath.Media.FilePathDevicePath, @ptrCast(buf.ptr + path_size - 4));

        new.type = .Media;
        new.subtype = .FilePath;
        new.length = @sizeOf(uefi.DevicePath.Media.FilePathDevicePath) + 2 * (@as(u16, @intCast(path.len)) + 1);

        // The same as new.getPath(), but not const as we're filling it in.
        var ptr = @as([*:0]align(1) u16, @ptrCast(@as([*]u8, @ptrCast(new)) + @sizeOf(uefi.DevicePath.Media.FilePathDevicePath)));

        for (path, 0..) |s, i|
            ptr[i] = s;

        ptr[path.len] = 0;

        var end = @as(*uefi.DevicePath.End.EndEntireDevicePath, @ptrCast(@as(*DevicePath, @ptrCast(new)).next().?));
        end.type = .End;
        end.subtype = .EndEntire;
        end.length = @sizeOf(uefi.DevicePath.End.EndEntireDevicePath);

        return @as(*DevicePath, @ptrCast(buf.ptr));
    }

    pub fn getDevicePath(self: *const DevicePath) ?uefi.DevicePath {
        inline for (@typeInfo(uefi.DevicePath).Union.fields) |ufield| {
            const enum_value = std.meta.stringToEnum(uefi.DevicePath.Type, ufield.name);

            // Got the associated union type for self.type, now
            // we need to initialize it and its subtype
            if (self.type == enum_value) {
                const subtype = self.initSubtype(ufield.type);
                if (subtype) |sb| {
                    // e.g. return .{ .Hardware = .{ .Pci = @ptrCast(...) } }
                    return @unionInit(uefi.DevicePath, ufield.name, sb);
                }
            }
        }

        return null;
    }

    pub fn initSubtype(self: *const DevicePath, comptime TUnion: type) ?TUnion {
        const type_info = @typeInfo(TUnion).Union;
        const TTag = type_info.tag_type.?;

        inline for (type_info.fields) |subtype| {
            // The tag names match the union names, so just grab that off the enum
            const tag_val: u8 = @intFromEnum(@field(TTag, subtype.name));

            if (self.subtype == tag_val) {
                // e.g. expr = .{ .Pci = @ptrCast(...) }
                return @unionInit(TUnion, subtype.name, @as(subtype.type, @ptrCast(self)));
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
