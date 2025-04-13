const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Status = uefi.Status;
const MacAddress = uefi.MacAddress;
const ManagedNetworkConfigData = uefi.protocol.ManagedNetwork.Config;
const SimpleNetwork = uefi.protocol.SimpleNetwork;
const cc = uefi.cc;
const Error = Status.Error;

pub const Ip6 = extern struct {
    _get_mode_data: *const fn (*const Ip6, ?*Mode, ?*ManagedNetworkConfigData, ?*SimpleNetwork) callconv(cc) Status,
    _configure: *const fn (*Ip6, ?*const Config) callconv(cc) Status,
    _groups: *const fn (*Ip6, bool, ?*const Address) callconv(cc) Status,
    _routes: *const fn (*Ip6, bool, ?*const Address, u8, ?*const Address) callconv(cc) Status,
    _neighbors: *const fn (*Ip6, bool, *const Address, ?*const MacAddress, u32, bool) callconv(cc) Status,
    _transmit: *const fn (*Ip6, *CompletionToken) callconv(cc) Status,
    _receive: *const fn (*Ip6, *CompletionToken) callconv(cc) Status,
    _cancel: *const fn (*Ip6, ?*CompletionToken) callconv(cc) Status,
    _poll: *const fn (*Ip6) callconv(cc) Status,

    pub const GetModeDataError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
    };
    pub const ConfigureError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
        NoMapping,
        AlreadyStarted,
        DeviceError,
        Unsupported,
    };
    pub const GroupsError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotStarted,
        OutOfResources,
        Unsupported,
        AlreadyStarted,
        NotFound,
        DeviceError,
    };
    pub const RoutesError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        OutOfResources,
        NotFound,
        AccessDenied,
    };
    pub const NeighborsError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        OutOfResources,
        NotFound,
        AccessDenied,
    };
    pub const TransmitError = uefi.UnexpectedError || error{
        NotStarted,
        NoMapping,
        InvalidParameter,
        AccessDenied,
        NotReady,
        NotFound,
        OutOfResources,
        BufferTooSmall,
        BadBufferSize,
        DeviceError,
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
        DeviceError,
    };
    pub const PollError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
        Timeout,
    };

    pub const ModeData = struct {
        ip6_mode: Mode,
        mnp_config: ManagedNetworkConfigData,
        snp_mode: SimpleNetwork,
    };

    /// Gets the current operational settings for this instance of the EFI IPv6 Protocol driver.
    pub fn getModeData(self: *const Ip6) GetModeDataError!ModeData {
        var data: ModeData = undefined;
        switch (self._get_mode_data(self, &data.ip6_mode, &data.mnp_config, &data.snp_mode)) {
            .success => return data,
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Assign IPv6 address and other configuration parameter to this EFI IPv6 Protocol driver instance.
    ///
    /// To reset the configuration, use `disable` instead.
    pub fn configure(self: *Ip6, ip6_config_data: *const Config) ConfigureError!void {
        switch (self._configure(self, ip6_config_data)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            .no_mapping => return Error.NoMapping,
            .already_started => return Error.AlreadyStarted,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn disable(self: *Ip6) ConfigureError!void {
        switch (self._configure(self, null)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            .no_mapping => return Error.NoMapping,
            .already_started => return Error.AlreadyStarted,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn leaveAllGroups(self: *Ip6) GroupsError!void {
        switch (self._groups(self, false, null)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .not_started => return Error.NotStarted,
            .out_of_resources => return Error.OutOfResources,
            .unsupported => return Error.Unsupported,
            .already_started => return Error.AlreadyStarted,
            .not_found => return Error.NotFound,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Joins and leaves multicast groups.
    ///
    /// To leave all groups, use `leaveAllGroups` instead.
    pub fn groups(
        self: *Ip6,
        join_flag: JoinFlag,
        group_address: *const Address,
    ) GroupsError!void {
        switch (self._groups(
            self,
            // set to TRUE to join the multicast group session and FALSE to leave
            join_flag == .join,
            group_address,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .not_started => return Error.NotStarted,
            .out_of_resources => return Error.OutOfResources,
            .unsupported => return Error.Unsupported,
            .already_started => return Error.AlreadyStarted,
            .not_found => return Error.NotFound,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Adds and deletes routing table entries.
    pub fn routes(
        self: *Ip6,
        delete_route: DeleteFlag,
        destination: ?*const Address,
        prefix_length: u8,
        gateway_address: ?*const Address,
    ) RoutesError!void {
        switch (self._routes(
            self,
            delete_route == .delete,
            destination,
            prefix_length,
            gateway_address,
        )) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            .not_found => return Error.NotFound,
            .access_denied => return Error.AccessDenied,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Add or delete Neighbor cache entries.
    pub fn neighbors(
        self: *Ip6,
        delete_flag: DeleteFlag,
        target_ip6_address: *const Address,
        target_link_address: ?*const MacAddress,
        timeout: u32,
        override: bool,
    ) NeighborsError!void {
        switch (self._neighbors(
            self,
            // set to TRUE to delete this route from the routing table.
            // set to FALSE to add this route to the routing table.
            delete_flag == .delete,
            target_ip6_address,
            target_link_address,
            timeout,
            override,
        )) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            .not_found => return Error.NotFound,
            .access_denied => return Error.AccessDenied,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Places outgoing data packets into the transmit queue.
    pub fn transmit(self: *Ip6, token: *CompletionToken) TransmitError!void {
        switch (self._transmit(self, token)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .no_mapping => return Error.NoMapping,
            .invalid_parameter => return Error.InvalidParameter,
            .access_denied => return Error.AccessDenied,
            .not_ready => return Error.NotReady,
            .not_found => return Error.NotFound,
            .out_of_resources => return Error.OutOfResources,
            .buffer_too_small => return Error.BufferTooSmall,
            .bad_buffer_size => return Error.BadBufferSize,
            .device_error => return Error.DeviceError,
            .no_media => return Error.NoMedia,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Places a receiving request into the receiving queue.
    pub fn receive(self: *Ip6, token: *CompletionToken) ReceiveError!void {
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

    /// Abort an asynchronous transmits or receive request.
    pub fn cancel(self: *Ip6, token: ?*CompletionToken) CancelError!void {
        switch (self._cancel(self, token)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .not_started => return Error.NotStarted,
            .not_found => return Error.NotFound,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Polls for incoming data packets and processes outgoing data packets.
    ///
    /// Returns true if a packet was received or processed.
    pub fn poll(self: *Ip6) PollError!bool {
        switch (self._poll(self)) {
            .success => return true,
            .not_ready => return false,
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .timeout => return Error.Timeout,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const guid = Guid{
        .time_low = 0x2c8759d5,
        .time_mid = 0x5c2d,
        .time_high_and_version = 0x66ef,
        .clock_seq_high_and_reserved = 0x92,
        .clock_seq_low = 0x5f,
        .node = [_]u8{ 0xb6, 0x6c, 0x10, 0x19, 0x57, 0xe2 },
    };

    pub const DeleteFlag = enum {
        delete,
        add,
    };

    pub const JoinFlag = enum {
        join,
        leave,
    };

    pub const Mode = extern struct {
        is_started: bool,
        max_packet_size: u32,
        config_data: Config,
        is_configured: bool,
        address_count: u32,
        address_list: [*]AddressInfo,
        group_count: u32,
        group_table: [*]Address,
        route_count: u32,
        route_table: [*]RouteTable,
        neighbor_count: u32,
        neighbor_cache: [*]NeighborCache,
        prefix_count: u32,
        prefix_table: [*]AddressInfo,
        icmp_type_count: u32,
        icmp_type_list: [*]IcmpType,
    };

    pub const Config = extern struct {
        default_protocol: u8,
        accept_any_protocol: bool,
        accept_icmp_errors: bool,
        accept_promiscuous: bool,
        destination_address: Address,
        station_address: Address,
        traffic_class: u8,
        hop_limit: u8,
        flow_label: u32,
        receive_timeout: u32,
        transmit_timeout: u32,
    };

    pub const Address = [16]u8;

    pub const AddressInfo = extern struct {
        address: Address,
        prefix_length: u8,
    };

    pub const RouteTable = extern struct {
        gateway: Address,
        destination: Address,
        prefix_length: u8,
    };

    pub const NeighborState = enum(u32) {
        incomplete,
        reachable,
        stale,
        delay,
        probe,
    };

    pub const NeighborCache = extern struct {
        neighbor: Address,
        link_address: MacAddress,
        state: NeighborState,
    };

    pub const IcmpType = extern struct {
        type: u8,
        code: u8,
    };

    pub const CompletionToken = extern struct {
        event: Event,
        status: Status,
        packet: *anyopaque, // union TODO
    };
};
