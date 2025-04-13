const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Status = uefi.Status;
const Time = uefi.Time;
const Ip6 = uefi.protocol.Ip6;
const ManagedNetworkConfigData = uefi.protocol.ManagedNetwork.Config;
const SimpleNetwork = uefi.protocol.SimpleNetwork;
const cc = uefi.cc;
const Error = Status.Error;

pub const Udp6 = extern struct {
    _get_mode_data: *const fn (*const Udp6, ?*Config, ?*Ip6.Mode, ?*ManagedNetworkConfigData, ?*SimpleNetwork) callconv(cc) Status,
    _configure: *const fn (*const Udp6, ?*const Config) callconv(cc) Status,
    _groups: *const fn (*const Udp6, bool, ?*const Ip6.Address) callconv(cc) Status,
    _transmit: *const fn (*const Udp6, *CompletionToken) callconv(cc) Status,
    _receive: *const fn (*const Udp6, *CompletionToken) callconv(cc) Status,
    _cancel: *const fn (*const Udp6, ?*CompletionToken) callconv(cc) Status,
    _poll: *const fn (*const Udp6) callconv(cc) Status,

    pub const GetModeDataError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
    };
    pub const ConfigureError = uefi.UnexpectedError || error{
        NoMapping,
        InvalidParameter,
        AlreadyStarted,
        AccessDenied,
        OutOfResources,
        DeviceError,
    };
    pub const GroupsError = uefi.UnexpectedError || error{
        NotStarted,
        OutOfResources,
        InvalidParameter,
        AlreadyStarted,
        NotFound,
        DeviceError,
    };
    pub const TransmitError = uefi.UnexpectedError || error{
        NotStarted,
        NoMapping,
        InvalidParameter,
        AccessDenied,
        NotReady,
        OutOfResources,
        NotFound,
        BadBufferSize,
        NoMedia,
    };
    pub const ReceiveError = uefi.UnexpectedError || error{
        NotStarted,
        NoMapping,
        InvalidParameter,
        OutOfResources,
        DeviceError,
        AccessDenied,
        NotReady,
        NoMedia,
    };
    pub const CancelError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotStarted,
        NotFound,
    };
    pub const PollError = uefi.UnexpectedError || error{
        InvalidParameter,
        DeviceError,
        Timeout,
    };

    pub fn getModeData(self: *const Udp6) GetModeDataError!ModeData {
        var data: ModeData = undefined;
        switch (self._get_mode_data(
            self,
            &data.udp6_config_data,
            &data.ip6_mode_data,
            &data.mnp_config_data,
            &data.snp_mode_data,
        )) {
            .success => return data,
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn configure(self: *Udp6, udp6_config_data: ?*const Config) ConfigureError!void {
        switch (self._configure(self, udp6_config_data)) {
            .success => {},
            .no_mapping => return Error.NoMapping,
            .invalid_parameter => return Error.InvalidParameter,
            .already_started => return Error.AlreadyStarted,
            .access_denied => return Error.AccessDenied,
            .out_of_resources => return Error.OutOfResources,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn groups(
        self: *Udp6,
        join_flag: JoinFlag,
        multicast_address: ?*const Ip6.Address,
    ) GroupsError!void {
        switch (self._groups(
            self,
            // set to TRUE to join a multicast group
            join_flag == .join,
            multicast_address,
        )) {
            .success => {},
            .not_started => return Error.NotStarted,
            .out_of_resources => return Error.OutOfResources,
            .invalid_parameter => return Error.InvalidParameter,
            .already_started => return Error.AlreadyStarted,
            .not_found => return Error.NotFound,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn transmit(self: *Udp6, token: *CompletionToken) TransmitError!void {
        switch (self._transmit(self, token)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .no_mapping => return Error.NoMapping,
            .invalid_parameter => return Error.InvalidParameter,
            .access_denied => return Error.AccessDenied,
            .not_ready => return Error.NotReady,
            .out_of_resources => return Error.OutOfResources,
            .not_found => return Error.NotFound,
            .bad_buffer_size => return Error.BadBufferSize,
            .no_media => return Error.NoMedia,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn receive(self: *Udp6, token: *CompletionToken) ReceiveError!void {
        switch (self._receive(self, token)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .no_mapping => return Error.NoMapping,
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            .device_error => return Error.DeviceError,
            .access_denied => return Error.AccessDenied,
            .not_ready => return Error.NotReady,
            .no_media => return Error.NoMedia,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn cancel(self: *Udp6, token: ?*CompletionToken) CancelError!void {
        switch (self._cancel(self, token)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .not_started => return Error.NotStarted,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn poll(self: *Udp6) PollError!void {
        switch (self._poll(self)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .timeout => return Error.Timeout,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const guid = Guid{
        .time_low = 0x4f948815,
        .time_mid = 0xb4b9,
        .time_high_and_version = 0x43cb,
        .clock_seq_high_and_reserved = 0x8a,
        .clock_seq_low = 0x33,
        .node = [_]u8{ 0x90, 0xe0, 0x60, 0xb3, 0x49, 0x55 },
    };

    pub const JoinFlag = enum {
        join,
        leave,
    };

    pub const ModeData = struct {
        udp6_config_data: Config,
        ip6_mode_data: Ip6.Mode,
        mnp_config_data: ManagedNetworkConfigData,
        snp_mode_data: SimpleNetwork,
    };

    pub const Config = extern struct {
        accept_promiscuous: bool,
        accept_any_port: bool,
        allow_duplicate_port: bool,
        traffic_class: u8,
        hop_limit: u8,
        receive_timeout: u32,
        transmit_timeout: u32,
        station_address: Ip6.Address,
        station_port: u16,
        remote_address: Ip6.Address,
        remote_port: u16,
    };

    pub const CompletionToken = extern struct {
        event: Event,
        status: usize,
        packet: extern union {
            rx_data: *ReceiveData,
            tx_data: *TransmitData,
        },
    };

    pub const ReceiveData = extern struct {
        timestamp: Time,
        recycle_signal: Event,
        udp6_session: SessionData,
        data_length: u32,
        fragment_count: u32,

        pub fn getFragments(self: *ReceiveData) []Fragment {
            return @as([*]Fragment, @ptrCast(@alignCast(@as([*]u8, @ptrCast(self)) + @sizeOf(ReceiveData))))[0..self.fragment_count];
        }
    };

    pub const TransmitData = extern struct {
        udp6_session_data: ?*SessionData,
        data_length: u32,
        fragment_count: u32,

        pub fn getFragments(self: *TransmitData) []Fragment {
            return @as([*]Fragment, @ptrCast(@alignCast(@as([*]u8, @ptrCast(self)) + @sizeOf(TransmitData))))[0..self.fragment_count];
        }
    };

    pub const SessionData = extern struct {
        source_address: Ip6.Address,
        source_port: u16,
        destination_address: Ip6.Address,
        destination_port: u16,
    };

    pub const Fragment = extern struct {
        fragment_length: u32,
        fragment_buffer: [*]u8,
    };
};
