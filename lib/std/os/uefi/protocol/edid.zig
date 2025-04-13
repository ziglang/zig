const std = @import("../../../std.zig");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

/// EDID information for an active video output device
pub const Active = extern struct {
    size_of_edid: u32,
    edid: ?[*]u8,

    pub const guid = Guid{
        .time_low = 0xbd8c1056,
        .time_mid = 0x9f36,
        .time_high_and_version = 0x44ec,
        .clock_seq_high_and_reserved = 0x92,
        .clock_seq_low = 0xa8,
        .node = [_]u8{ 0xa6, 0x33, 0x7f, 0x81, 0x79, 0x86 },
    };
};

/// EDID information for a video output device
pub const Discovered = extern struct {
    size_of_edid: u32,
    edid: ?[*]u8,

    pub const guid = Guid{
        .time_low = 0x1c0c34f6,
        .time_mid = 0xd380,
        .time_high_and_version = 0x41fa,
        .clock_seq_high_and_reserved = 0xa0,
        .clock_seq_low = 0x49,
        .node = [_]u8{ 0x8a, 0xd0, 0x6c, 0x1a, 0x66, 0xaa },
    };
};

/// Override EDID information
pub const Override = extern struct {
    _get_edid: *const fn (*const Override, *const Handle, *Attributes, *usize, *?[*]u8) callconv(cc) Status,

    pub const GetEdidError = uefi.UnexpectedError || error{
        Unsupported,
    };

    /// Returns policy information and potentially a replacement EDID for the specified video output device.
    pub fn getEdid(self: *const Override, handle: Handle) GetEdidError!Edid {
        var size: usize = undefined;
        var ptr: ?[*]u8 = undefined;
        var attributes: Attributes = undefined;
        switch (self._get_edid(self, &handle, &attributes, &size, &ptr)) {
            .success => {},
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }

        return .{
            .attributes = attributes,
            .edid = if (ptr) |p| p[0..size] else null,
        };
    }

    pub const guid = Guid{
        .time_low = 0x48ecb431,
        .time_mid = 0xfb72,
        .time_high_and_version = 0x45c0,
        .clock_seq_high_and_reserved = 0xa9,
        .clock_seq_low = 0x22,
        .node = [_]u8{ 0xf4, 0x58, 0xfe, 0x04, 0x0b, 0xd5 },
    };

    pub const Edid = struct {
        attributes: Attributes,
        edid: ?[]u8,
    };

    pub const Attributes = packed struct(u32) {
        dont_override: bool,
        enable_hot_plug: bool,
        _pad: u30 = 0,
    };
};
