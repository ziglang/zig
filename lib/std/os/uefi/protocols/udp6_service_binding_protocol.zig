const std = @import("std");
const uefi = std.os.uefi;
const Handle = uefi.Handle;
const Guid = uefi.Guid;
const Status = uefi.Status;

pub const Udp6ServiceBindingProtocol = extern struct {
    _create_child: std.meta.FnPtr(fn (*const Udp6ServiceBindingProtocol, *?Handle) callconv(.C) Status),
    _destroy_child: std.meta.FnPtr(fn (*const Udp6ServiceBindingProtocol, Handle) callconv(.C) Status),

    pub fn createChild(self: *const Udp6ServiceBindingProtocol, handle: *?Handle) Status {
        return self._create_child(self, handle);
    }

    pub fn destroyChild(self: *const Udp6ServiceBindingProtocol, handle: Handle) Status {
        return self._destroy_child(self, handle);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x66ed4721,
        .time_mid = 0x3c98,
        .time_high_and_version = 0x4d3e,
        .clock_seq_high_and_reserved = 0x81,
        .clock_seq_low = 0xe3,
        .node = [_]u8{ 0xd0, 0x3d, 0xd3, 0x9a, 0x72, 0x54 },
    };
};
