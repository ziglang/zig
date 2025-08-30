const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;
const MacAddress = uefi.MacAddress;
const Ip6 = uefi.protocol.Ip6;

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
        comptime data_type: std.meta.Tag(DataType),
        payload: *const std.meta.TagPayload(DataType, data_type),
    ) SetDataError!void {
        const data_size = @sizeOf(@TypeOf(payload));
        switch (self._set_data(self, data_type, data_size, @ptrCast(payload))) {
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
        comptime data_type: std.meta.Tag(DataType),
    ) GetDataError!std.meta.TagPayload(DataType, data_type) {
        const DataPayload = std.meta.TagPayload(DataType, data_type);

        var payload: DataPayload = undefined;
        var payload_size: usize = @sizeOf(DataPayload);

        switch (self._get_data(self, data_type, &payload_size, @ptrCast(&payload))) {
            .success => return payload,
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

    pub fn unregisterDataNotify(
        self: *const Ip6Config,
        data_type: DataType,
        event: Event,
    ) UnregisterDataNotifyError!void {
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

    pub const DataType = union(enum(u32)) {
        interface_info: InterfaceInfo,
        alt_interface_id: InterfaceId,
        policy: Policy,
        dup_addr_detect_transmits: DupAddrDetectTransmits,
        manual_address: [*]ManualAddress,
        gateway: [*]Ip6.Address,
        dns_server: [*]Ip6.Address,
    };

    pub const InterfaceInfo = extern struct {
        name: [32]u16,
        if_type: u8,
        hw_address_size: u32,
        hw_address: MacAddress,
        address_info_count: u32,
        address_info: [*]Ip6.AddressInfo,
        route_count: u32,
        route_table: Ip6.RouteTable,
    };

    pub const InterfaceId = extern struct {
        id: [8]u8,
    };

    pub const Policy = enum(u32) {
        manual,
        automatic,
    };

    pub const DupAddrDetectTransmits = extern struct {
        dup_addr_detect_transmits: u32,
    };

    pub const ManualAddress = extern struct {
        address: Ip6.Address,
        is_anycast: bool,
        prefix_length: u8,
    };
};
