const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

pub const Ip6Config = extern struct {
    _set_data: *const fn (*const Ip6Config, DataType, usize, *const anyopaque) callconv(cc) Status,
    _get_data: *const fn (*const Ip6Config, DataType, *usize, ?*const anyopaque) callconv(cc) Status,
    _register_data_notify: *const fn (*const Ip6Config, DataType, Event) callconv(cc) Status,
    _unregister_data_notify: *const fn (*const Ip6Config, DataType, Event) callconv(cc) Status,

    pub const SetDataError = uefi.UnexpectedError || error{
        InvalidParameter,
        WriteProtected,
        AccessDenied,
        NotReady,
        BadBufferSize,
        Unsupported,
        OutOfResources,
        DeviceError,
    };
    pub const GetDataError = uefi.UnexpectedError || error{
        InvalidParameter,
        BufferTooSmall,
        NotReady,
        NotFound,
    };
    pub const RegisterDataNotifyError = uefi.UnexpectedError || error{
        InvalidParameter,
        Unsupported,
        OutOfResources,
        AccessDenied,
    };
    pub const UnregisterDataNotifyError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotFound,
    };

    pub fn setData(
        self: *const Ip6Config,
        data_type: DataType,
        data_size: usize,
        data: *const anyopaque,
    ) SetDataError!void {
        switch (self._set_data(self, data_type, data_size, data)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .write_protected => return Error.WriteProtected,
            .access_denied => return Error.AccessDenied,
            .not_ready => return Error.NotReady,
            .bad_buffer_size => return Error.BadBufferSize,
            .unsupported => return Error.Unsupported,
            .out_of_resources => return Error.OutOfResources,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn getData(
        self: *const Ip6Config,
        data_type: DataType,
        data_size: *usize,
        data: ?*const anyopaque,
    ) GetDataError!void {
        switch (self._get_data(self, data_type, data_size, data)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .buffer_too_small => return Error.BufferTooSmall,
            .not_ready => return Error.NotReady,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn registerDataNotify(
        self: *const Ip6Config,
        data_type: DataType,
        event: Event,
    ) RegisterDataNotifyError!void {
        switch (self._register_data_notify(self, data_type, event)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .unsupported => return Error.Unsupported,
            .out_of_resources => return Error.OutOfResources,
            .access_denied => return Error.AccessDenied,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn unregisterDataNotify(self: *const Ip6Config, data_type: DataType, event: Event) Status {
        switch (self._unregister_data_notify(self, data_type, event)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const guid align(8) = Guid{
        .time_low = 0x937fe521,
        .time_mid = 0x95ae,
        .time_high_and_version = 0x4d1a,
        .clock_seq_high_and_reserved = 0x89,
        .clock_seq_low = 0x29,
        .node = [_]u8{ 0x48, 0xbc, 0xd9, 0x0a, 0xd3, 0x1a },
    };

    pub const DataType = enum(u32) {
        interface_info,
        alt_interface_id,
        policy,
        dup_addr_detect_transmits,
        manual_address,
        gateway,
        dns_server,
    };
};
