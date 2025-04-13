const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Handle = uefi.Handle;
const Status = uefi.Status;
const Time = uefi.Time;
const SimpleNetwork = uefi.protocol.SimpleNetwork;
const MacAddress = uefi.MacAddress;
const cc = uefi.cc;
const Error = Status.Error;

pub const ManagedNetwork = extern struct {
    _get_mode_data: *const fn (*const ManagedNetwork, ?*Config, ?*SimpleNetwork) callconv(cc) Status,
    _configure: *const fn (*ManagedNetwork, ?*const Config) callconv(cc) Status,
    _mcast_ip_to_mac: *const fn (*ManagedNetwork, bool, *const anyopaque, *MacAddress) callconv(cc) Status,
    _groups: *const fn (*ManagedNetwork, bool, ?*const MacAddress) callconv(cc) Status,
    _transmit: *const fn (*ManagedNetwork, *CompletionToken) callconv(cc) Status,
    _receive: *const fn (*ManagedNetwork, *CompletionToken) callconv(cc) Status,
    _cancel: *const fn (*ManagedNetwork, ?*const CompletionToken) callconv(cc) Status,
    _poll: *const fn (*ManagedNetwork) callconv(cc) Status,

    pub const GetModeDataError = uefi.UnexpectedError || error{
        InvalidParameter,
        Unsupported,
        NotStarted,
    } || Error;
    pub const ConfigureError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
        Unsupported,
        DeviceError,
    } || Error;
    pub const McastIpToMacError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotStarted,
        Unsupported,
        DeviceError,
    } || Error;
    pub const GroupsError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotStarted,
        AlreadyStarted,
        NotFound,
        DeviceError,
        Unsupported,
    } || Error;
    pub const TransmitError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        AccessDenied,
        OutOfResources,
        DeviceError,
        NotReady,
        NoMedia,
    };
    pub const ReceiveError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        OutOfResources,
        DeviceError,
        AccessDenied,
        NotReady,
        NoMedia,
    };
    pub const CancelError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        NotFound,
    };
    pub const PollError = uefi.UnexpectedError || error{
        NotStarted,
        DeviceError,
        NotReady,
        Timeout,
    };

    pub const GetModeDataData = struct {
        mnp_config: Config,
        snp_mode: SimpleNetwork,
    };

    /// Returns the operational parameters for the current MNP child driver.
    /// May also support returning the underlying SNP driver mode data.
    pub fn getModeData(self: *const ManagedNetwork) GetModeDataError!GetModeDataData {
        var data: GetModeDataData = undefined;
        switch (self._get_mode_data(self, &data.mnp_config, &data.snp_mode)) {
            .success => return data,
            else => |status| {
                try status.err();
                return uefi.unexpectedStatus(status);
            },
        }
    }

    /// Sets or clears the operational parameters for the MNP child driver.
    pub fn configure(self: *ManagedNetwork, mnp_config_data: ?*const Config) ConfigureError!void {
        switch (self._configure(self, mnp_config_data)) {
            .success => {},
            else => |status| {
                try status.err();
                return uefi.unexpectedStatus(status);
            },
        }
    }

    /// Translates an IP multicast address to a hardware (MAC) multicast address.
    /// This function may be unsupported in some MNP implementations.
    pub fn mcastIpToMac(
        self: *ManagedNetwork,
        ipv6flag: bool,
        ipaddress: *const uefi.IpAddress,
    ) McastIpToMacError!MacAddress {
        var result: MacAddress = undefined;
        switch (self._mcast_ip_to_mac(self, ipv6flag, ipaddress, &result)) {
            .success => return result,
            else => |status| {
                try status.err();
                return uefi.unexpectedStatus(status);
            },
        }
    }

    /// Enables and disables receive filters for multicast address.
    /// This function may be unsupported in some MNP implementations.
    pub fn groups(
        self: *ManagedNetwork,
        join_flag: bool,
        mac_address: ?*const MacAddress,
    ) GroupsError!void {
        switch (self._groups(self, join_flag, mac_address)) {
            .success => {},
            else => |status| {
                try status.err();
                return uefi.unexpectedStatus(status);
            },
        }
    }

    /// Places asynchronous outgoing data packets into the transmit queue.
    pub fn transmit(self: *ManagedNetwork, token: *CompletionToken) TransmitError!void {
        switch (self._transmit(self, token)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .access_denied => return Error.AccessDenied,
            .out_of_resources => return Error.OutOfResources,
            .device_error => return Error.DeviceError,
            .not_ready => return Error.NotReady,
            .no_media => return Error.NoMedia,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Places an asynchronous receiving request into the receiving queue.
    pub fn receive(self: *ManagedNetwork, token: *CompletionToken) TransmitError!void {
        switch (self._receive(self, token)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            .device_error => return Error.DeviceError,
            .access_denied => return Error.AccessDenied,
            .not_ready => return Error.NotReady,
            .no_media => return Error.NoMedia,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Aborts an asynchronous transmit or receive request.
    pub fn cancel(self: *ManagedNetwork, token: ?*const CompletionToken) CancelError!void {
        switch (self._cancel(self, token)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Polls for incoming data packets and processes outgoing data packets.
    pub fn poll(self: *ManagedNetwork) PollError!void {
        switch (self._poll(self)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .device_error => return Error.DeviceError,
            .not_ready => return Error.NotReady,
            .timeout => return Error.Timeout,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const guid = Guid{
        .time_low = 0x7ab33a91,
        .time_mid = 0xace5,
        .time_high_and_version = 0x4326,
        .clock_seq_high_and_reserved = 0xb5,
        .clock_seq_low = 0x72,
        .node = [_]u8{ 0xe7, 0xee, 0x33, 0xd3, 0x9f, 0x16 },
    };

    pub const ServiceBinding = extern struct {
        _create_child: *const fn (*const ServiceBinding, *?Handle) callconv(cc) Status,
        _destroy_child: *const fn (*const ServiceBinding, Handle) callconv(cc) Status,

        pub fn createChild(self: *const ServiceBinding, handle: *?Handle) Status {
            return self._create_child(self, handle);
        }

        pub fn destroyChild(self: *const ServiceBinding, handle: Handle) Status {
            return self._destroy_child(self, handle);
        }

        pub const guid = Guid{
            .time_low = 0xf36ff770,
            .time_mid = 0xa7e1,
            .time_high_and_version = 0x42cf,
            .clock_seq_high_and_reserved = 0x9e,
            .clock_seq_low = 0xd2,
            .node = [_]u8{ 0x56, 0xf0, 0xf2, 0x71, 0xf4, 0x4c },
        };
    };

    pub const Config = extern struct {
        received_queue_timeout_value: u32,
        transmit_queue_timeout_value: u32,
        protocol_type_filter: u16,
        enable_unicast_receive: bool,
        enable_multicast_receive: bool,
        enable_broadcast_receive: bool,
        enable_promiscuous_receive: bool,
        flush_queues_on_reset: bool,
        enable_receive_timestamps: bool,
        disable_background_polling: bool,
    };

    pub const CompletionToken = extern struct {
        event: Event,
        status: Status,
        packet: extern union {
            rx_data: *ReceiveData,
            tx_data: *TransmitData,
        },
    };

    pub const ReceiveData = extern struct {
        timestamp: Time,
        recycle_event: Event,
        packet_length: u32,
        header_length: u32,
        address_length: u32,
        data_length: u32,
        broadcast_flag: bool,
        multicast_flag: bool,
        promiscuous_flag: bool,
        protocol_type: u16,
        destination_address: [*]u8,
        source_address: [*]u8,
        media_header: [*]u8,
        packet_data: [*]u8,
    };

    pub const TransmitData = extern struct {
        destination_address: ?*MacAddress,
        source_address: ?*MacAddress,
        protocol_type: u16,
        data_length: u32,
        header_length: u16,
        fragment_count: u16,

        pub fn getFragments(self: *TransmitData) []Fragment {
            return @as([*]Fragment, @ptrCast(@alignCast(@as([*]u8, @ptrCast(self)) + @sizeOf(TransmitData))))[0..self.fragment_count];
        }
    };

    pub const Fragment = extern struct {
        fragment_length: u32,
        fragment_buffer: [*]u8,
    };
};
