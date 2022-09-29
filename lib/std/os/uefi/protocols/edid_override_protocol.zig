const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const Status = uefi.Status;

/// Override EDID information
pub const EdidOverrideProtocol = extern struct {
    _get_edid: std.meta.FnPtr(fn (*const EdidOverrideProtocol, Handle, *u32, *usize, *?[*]u8) callconv(.C) Status),

    /// Returns policy information and potentially a replacement EDID for the specified video output device.
    pub fn getEdid(
        self: *const EdidOverrideProtocol,
        handle: Handle,
        /// The align(4) here should really be part of the EdidOverrideProtocolAttributes type.
        /// TODO remove this workaround when packed(u32) structs are implemented.
        attributes: *align(4) EdidOverrideProtocolAttributes,
        edid_size: *usize,
        edid: *?[*]u8,
    ) Status {
        return self._get_edid(self, handle, @ptrCast(*u32, attributes), edid_size, edid);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x48ecb431,
        .time_mid = 0xfb72,
        .time_high_and_version = 0x45c0,
        .clock_seq_high_and_reserved = 0xa9,
        .clock_seq_low = 0x22,
        .node = [_]u8{ 0xf4, 0x58, 0xfe, 0x04, 0x0b, 0xd5 },
    };
};

pub const EdidOverrideProtocolAttributes = packed struct {
    dont_override: bool,
    enable_hot_plug: bool,
    _pad: u30 = 0,
};
