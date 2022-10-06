const std = @import("std");
const uefi = std.os.uefi;
const Handle = uefi.Handle;
const Guid = uefi.Guid;
const Status = uefi.Status;

pub const Ip6ServiceBindingProtocol = extern struct {
    _create_child: std.meta.FnPtr(fn (*const Ip6ServiceBindingProtocol, *?Handle) callconv(.C) Status),
    _destroy_child: std.meta.FnPtr(fn (*const Ip6ServiceBindingProtocol, Handle) callconv(.C) Status),

    pub fn createChild(self: *const Ip6ServiceBindingProtocol, handle: *?Handle) Status {
        return self._create_child(self, handle);
    }

    pub fn destroyChild(self: *const Ip6ServiceBindingProtocol, handle: Handle) Status {
        return self._destroy_child(self, handle);
    }

    pub const guid align(8) = Guid{
        .time_low = 0xec835dd3,
        .time_mid = 0xfe0f,
        .time_high_and_version = 0x617b,
        .clock_seq_high_and_reserved = 0xa6,
        .clock_seq_low = 0x21,
        .node = [_]u8{ 0xb3, 0x50, 0xc3, 0xe1, 0x33, 0x88 },
    };
};
