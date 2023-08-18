const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Status = uefi.Status;
const MacAddress = uefi.protocols.MacAddress;
const ManagedNetworkConfigData = uefi.protocols.ManagedNetworkConfigData;
const SimpleNetworkMode = uefi.protocols.SimpleNetworkMode;
const cc = uefi.cc;

pub const Ip6Protocol = extern struct {
    _get_mode_data: *const fn (*const Ip6Protocol, ?*Ip6ModeData, ?*ManagedNetworkConfigData, ?*SimpleNetworkMode) callconv(cc) Status,
    _configure: *const fn (*const Ip6Protocol, ?*const Ip6ConfigData) callconv(cc) Status,
    _groups: *const fn (*const Ip6Protocol, bool, ?*const Ip6Address) callconv(cc) Status,
    _routes: *const fn (*const Ip6Protocol, bool, ?*const Ip6Address, u8, ?*const Ip6Address) callconv(cc) Status,
    _neighbors: *const fn (*const Ip6Protocol, bool, *const Ip6Address, ?*const MacAddress, u32, bool) callconv(cc) Status,
    _transmit: *const fn (*const Ip6Protocol, *Ip6CompletionToken) callconv(cc) Status,
    _receive: *const fn (*const Ip6Protocol, *Ip6CompletionToken) callconv(cc) Status,
    _cancel: *const fn (*const Ip6Protocol, ?*Ip6CompletionToken) callconv(cc) Status,
    _poll: *const fn (*const Ip6Protocol) callconv(cc) Status,

    /// Gets the current operational settings for this instance of the EFI IPv6 Protocol driver.
    pub fn getModeData(self: *const Ip6Protocol, ip6_mode_data: ?*Ip6ModeData, mnp_config_data: ?*ManagedNetworkConfigData, snp_mode_data: ?*SimpleNetworkMode) Status {
        return self._get_mode_data(self, ip6_mode_data, mnp_config_data, snp_mode_data);
    }

    /// Assign IPv6 address and other configuration parameter to this EFI IPv6 Protocol driver instance.
    pub fn configure(self: *const Ip6Protocol, ip6_config_data: ?*const Ip6ConfigData) Status {
        return self._configure(self, ip6_config_data);
    }

    /// Joins and leaves multicast groups.
    pub fn groups(self: *const Ip6Protocol, join_flag: bool, group_address: ?*const Ip6Address) Status {
        return self._groups(self, join_flag, group_address);
    }

    /// Adds and deletes routing table entries.
    pub fn routes(self: *const Ip6Protocol, delete_route: bool, destination: ?*const Ip6Address, prefix_length: u8, gateway_address: ?*const Ip6Address) Status {
        return self._routes(self, delete_route, destination, prefix_length, gateway_address);
    }

    /// Add or delete Neighbor cache entries.
    pub fn neighbors(self: *const Ip6Protocol, delete_flag: bool, target_ip6_address: *const Ip6Address, target_link_address: ?*const MacAddress, timeout: u32, override: bool) Status {
        return self._neighbors(self, delete_flag, target_ip6_address, target_link_address, timeout, override);
    }

    /// Places outgoing data packets into the transmit queue.
    pub fn transmit(self: *const Ip6Protocol, token: *Ip6CompletionToken) Status {
        return self._transmit(self, token);
    }

    /// Places a receiving request into the receiving queue.
    pub fn receive(self: *const Ip6Protocol, token: *Ip6CompletionToken) Status {
        return self._receive(self, token);
    }

    /// Abort an asynchronous transmits or receive request.
    pub fn cancel(self: *const Ip6Protocol, token: ?*Ip6CompletionToken) Status {
        return self._cancel(self, token);
    }

    /// Polls for incoming data packets and processes outgoing data packets.
    pub fn poll(self: *const Ip6Protocol) Status {
        return self._poll(self);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x2c8759d5,
        .time_mid = 0x5c2d,
        .time_high_and_version = 0x66ef,
        .clock_seq_high_and_reserved = 0x92,
        .clock_seq_low = 0x5f,
        .node = [_]u8{ 0xb6, 0x6c, 0x10, 0x19, 0x57, 0xe2 },
    };
};

pub const Ip6ModeData = extern struct {
    is_started: bool,
    max_packet_size: u32,
    config_data: Ip6ConfigData,
    is_configured: bool,
    address_count: u32,
    address_list: [*]Ip6AddressInfo,
    group_count: u32,
    group_table: [*]Ip6Address,
    route_count: u32,
    route_table: [*]Ip6RouteTable,
    neighbor_count: u32,
    neighbor_cache: [*]Ip6NeighborCache,
    prefix_count: u32,
    prefix_table: [*]Ip6AddressInfo,
    icmp_type_count: u32,
    icmp_type_list: [*]Ip6IcmpType,
};

pub const Ip6ConfigData = extern struct {
    default_protocol: u8,
    accept_any_protocol: bool,
    accept_icmp_errors: bool,
    accept_promiscuous: bool,
    destination_address: Ip6Address,
    station_address: Ip6Address,
    traffic_class: u8,
    hop_limit: u8,
    flow_label: u32,
    receive_timeout: u32,
    transmit_timeout: u32,
};

pub const Ip6Address = [16]u8;

pub const Ip6AddressInfo = extern struct {
    address: Ip6Address,
    prefix_length: u8,
};

pub const Ip6RouteTable = extern struct {
    gateway: Ip6Address,
    destination: Ip6Address,
    prefix_length: u8,
};

pub const Ip6NeighborState = enum(u32) {
    Incomplete,
    Reachable,
    Stale,
    Delay,
    Probe,
};

pub const Ip6NeighborCache = extern struct {
    neighbor: Ip6Address,
    link_address: MacAddress,
    state: Ip6NeighborState,
};

pub const Ip6IcmpType = extern struct {
    type: u8,
    code: u8,
};

pub const Ip6CompletionToken = extern struct {
    event: Event,
    status: Status,
    packet: *anyopaque, // union TODO
};
