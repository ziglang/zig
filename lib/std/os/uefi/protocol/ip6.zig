const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Status = uefi.Status;
const MacAddress = uefi.MacAddress;
const ManagedNetworkConfigData = uefi.protocol.ManagedNetwork.Config;
const SimpleNetwork = uefi.protocol.SimpleNetwork;
const cc = uefi.cc;

pub const Ip6 = extern struct {
    _get_mode_data: *const fn (*const Ip6, ?*Mode, ?*ManagedNetworkConfigData, ?*SimpleNetwork) callconv(cc) Status,
    _configure: *const fn (*const Ip6, ?*const Config) callconv(cc) Status,
    _groups: *const fn (*const Ip6, bool, ?*const Address) callconv(cc) Status,
    _routes: *const fn (*const Ip6, bool, ?*const Address, u8, ?*const Address) callconv(cc) Status,
    _neighbors: *const fn (*const Ip6, bool, *const Address, ?*const MacAddress, u32, bool) callconv(cc) Status,
    _transmit: *const fn (*const Ip6, *CompletionToken) callconv(cc) Status,
    _receive: *const fn (*const Ip6, *CompletionToken) callconv(cc) Status,
    _cancel: *const fn (*const Ip6, ?*CompletionToken) callconv(cc) Status,
    _poll: *const fn (*const Ip6) callconv(cc) Status,

    /// Gets the current operational settings for this instance of the EFI IPv6 Protocol driver.
    pub fn getModeData(self: *const Ip6, ip6_mode_data: ?*Mode, mnp_config_data: ?*ManagedNetworkConfigData, snp_mode_data: ?*SimpleNetwork) Status {
        return self._get_mode_data(self, ip6_mode_data, mnp_config_data, snp_mode_data);
    }

    /// Assign IPv6 address and other configuration parameter to this EFI IPv6 Protocol driver instance.
    pub fn configure(self: *const Ip6, ip6_config_data: ?*const Config) Status {
        return self._configure(self, ip6_config_data);
    }

    /// Joins and leaves multicast groups.
    pub fn groups(self: *const Ip6, join_flag: bool, group_address: ?*const Address) Status {
        return self._groups(self, join_flag, group_address);
    }

    /// Adds and deletes routing table entries.
    pub fn routes(self: *const Ip6, delete_route: bool, destination: ?*const Address, prefix_length: u8, gateway_address: ?*const Address) Status {
        return self._routes(self, delete_route, destination, prefix_length, gateway_address);
    }

    /// Add or delete Neighbor cache entries.
    pub fn neighbors(self: *const Ip6, delete_flag: bool, target_ip6_address: *const Address, target_link_address: ?*const MacAddress, timeout: u32, override: bool) Status {
        return self._neighbors(self, delete_flag, target_ip6_address, target_link_address, timeout, override);
    }

    /// Places outgoing data packets into the transmit queue.
    pub fn transmit(self: *const Ip6, token: *CompletionToken) Status {
        return self._transmit(self, token);
    }

    /// Places a receiving request into the receiving queue.
    pub fn receive(self: *const Ip6, token: *CompletionToken) Status {
        return self._receive(self, token);
    }

    /// Abort an asynchronous transmits or receive request.
    pub fn cancel(self: *const Ip6, token: ?*CompletionToken) Status {
        return self._cancel(self, token);
    }

    /// Polls for incoming data packets and processes outgoing data packets.
    pub fn poll(self: *const Ip6) Status {
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
        Incomplete,
        Reachable,
        Stale,
        Delay,
        Probe,
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
