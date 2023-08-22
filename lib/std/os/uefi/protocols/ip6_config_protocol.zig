const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Status = uefi.Status;
const cc = uefi.cc;

pub const Ip6ConfigProtocol = extern struct {
    _set_data: *const fn (*const Ip6ConfigProtocol, Ip6ConfigDataType, usize, *const anyopaque) callconv(cc) Status,
    _get_data: *const fn (*const Ip6ConfigProtocol, Ip6ConfigDataType, *usize, ?*const anyopaque) callconv(cc) Status,
    _register_data_notify: *const fn (*const Ip6ConfigProtocol, Ip6ConfigDataType, Event) callconv(cc) Status,
    _unregister_data_notify: *const fn (*const Ip6ConfigProtocol, Ip6ConfigDataType, Event) callconv(cc) Status,

    pub fn setData(self: *const Ip6ConfigProtocol, data_type: Ip6ConfigDataType, data_size: usize, data: *const anyopaque) Status {
        return self._set_data(self, data_type, data_size, data);
    }

    pub fn getData(self: *const Ip6ConfigProtocol, data_type: Ip6ConfigDataType, data_size: *usize, data: ?*const anyopaque) Status {
        return self._get_data(self, data_type, data_size, data);
    }

    pub fn registerDataNotify(self: *const Ip6ConfigProtocol, data_type: Ip6ConfigDataType, event: Event) Status {
        return self._register_data_notify(self, data_type, event);
    }

    pub fn unregisterDataNotify(self: *const Ip6ConfigProtocol, data_type: Ip6ConfigDataType, event: Event) Status {
        return self._unregister_data_notify(self, data_type, event);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x937fe521,
        .time_mid = 0x95ae,
        .time_high_and_version = 0x4d1a,
        .clock_seq_high_and_reserved = 0x89,
        .clock_seq_low = 0x29,
        .node = [_]u8{ 0x48, 0xbc, 0xd9, 0x0a, 0xd3, 0x1a },
    };
};

pub const Ip6ConfigDataType = enum(u32) {
    InterfaceInfo,
    AltInterfaceId,
    Policy,
    DupAddrDetectTransmits,
    ManualAddress,
    Gateway,
    DnsServer,
};
