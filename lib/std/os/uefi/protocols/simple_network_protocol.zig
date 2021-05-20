// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;

pub const SimpleNetworkProtocol = extern struct {
    revision: u64,
    _start: fn (*const SimpleNetworkProtocol) callconv(.C) Status,
    _stop: fn (*const SimpleNetworkProtocol) callconv(.C) Status,
    _initialize: fn (*const SimpleNetworkProtocol, usize, usize) callconv(.C) Status,
    _reset: fn (*const SimpleNetworkProtocol, bool) callconv(.C) Status,
    _shutdown: fn (*const SimpleNetworkProtocol) callconv(.C) Status,
    _receive_filters: fn (*const SimpleNetworkProtocol, SimpleNetworkReceiveFilter, SimpleNetworkReceiveFilter, bool, usize, ?[*]const MacAddress) callconv(.C) Status,
    _station_address: fn (*const SimpleNetworkProtocol, bool, ?*const MacAddress) callconv(.C) Status,
    _statistics: fn (*const SimpleNetworkProtocol, bool, ?*usize, ?*NetworkStatistics) callconv(.C) Status,
    _mcast_ip_to_mac: fn (*const SimpleNetworkProtocol, bool, *const c_void, *MacAddress) callconv(.C) Status,
    _nvdata: fn (*const SimpleNetworkProtocol, bool, usize, usize, [*]u8) callconv(.C) Status,
    _get_status: fn (*const SimpleNetworkProtocol, *SimpleNetworkInterruptStatus, ?*?[*]u8) callconv(.C) Status,
    _transmit: fn (*const SimpleNetworkProtocol, usize, usize, [*]const u8, ?*const MacAddress, ?*const MacAddress, ?*const u16) callconv(.C) Status,
    _receive: fn (*const SimpleNetworkProtocol, ?*usize, *usize, [*]u8, ?*MacAddress, ?*MacAddress, ?*u16) callconv(.C) Status,
    wait_for_packet: Event,
    mode: *SimpleNetworkMode,

    /// Changes the state of a network interface from "stopped" to "started".
    pub fn start(self: *const SimpleNetworkProtocol) Status {
        return self._start(self);
    }

    /// Changes the state of a network interface from "started" to "stopped".
    pub fn stop(self: *const SimpleNetworkProtocol) Status {
        return self._stop(self);
    }

    /// Resets a network adapter and allocates the transmit and receive buffers required by the network interface.
    pub fn initialize(self: *const SimpleNetworkProtocol, extra_rx_buffer_size: usize, extra_tx_buffer_size: usize) Status {
        return self._initialize(self, extra_rx_buffer_size, extra_tx_buffer_size);
    }

    /// Resets a network adapter and reinitializes it with the parameters that were provided in the previous call to initialize().
    pub fn reset(self: *const SimpleNetworkProtocol, extended_verification: bool) Status {
        return self._reset(self, extended_verification);
    }

    /// Resets a network adapter and leaves it in a state that is safe for another driver to initialize.
    pub fn shutdown(self: *const SimpleNetworkProtocol) Status {
        return self._shutdown(self);
    }

    /// Manages the multicast receive filters of a network interface.
    pub fn receiveFilters(self: *const SimpleNetworkProtocol, enable: SimpleNetworkReceiveFilter, disable: SimpleNetworkReceiveFilter, reset_mcast_filter: bool, mcast_filter_cnt: usize, mcast_filter: ?[*]const MacAddress) Status {
        return self._receive_filters(self, enable, disable, reset_mcast_filter, mcast_filter_cnt, mcast_filter);
    }

    /// Modifies or resets the current station address, if supported.
    pub fn stationAddress(self: *const SimpleNetworkProtocol, reset: bool, new: ?*const MacAddress) Status {
        return self._station_address(self, reset, new);
    }

    /// Resets or collects the statistics on a network interface.
    pub fn statistics(self: *const SimpleNetworkProtocol, reset_: bool, statistics_size: ?*usize, statistics_table: ?*NetworkStatistics) Status {
        return self._statistics(self, reset_, statistics_size, statistics_table);
    }

    /// Converts a multicast IP address to a multicast HW MAC address.
    pub fn mcastIpToMac(self: *const SimpleNetworkProtocol, ipv6: bool, ip: *const c_void, mac: *MacAddress) Status {
        return self._mcast_ip_to_mac(self, ipv6, ip, mac);
    }

    /// Performs read and write operations on the NVRAM device attached to a network interface.
    pub fn nvdata(self: *const SimpleNetworkProtocol, read_write: bool, offset: usize, buffer_size: usize, buffer: [*]u8) Status {
        return self._nvdata(self, read_write, offset, buffer_size, buffer);
    }

    /// Reads the current interrupt status and recycled transmit buffer status from a network interface.
    pub fn getStatus(self: *const SimpleNetworkProtocol, interrupt_status: *SimpleNetworkInterruptStatus, tx_buf: ?*?[*]u8) Status {
        return self._get_status(self, interrupt_status, tx_buf);
    }

    /// Places a packet in the transmit queue of a network interface.
    pub fn transmit(self: *const SimpleNetworkProtocol, header_size: usize, buffer_size: usize, buffer: [*]const u8, src_addr: ?*const MacAddress, dest_addr: ?*const MacAddress, protocol: ?*const u16) Status {
        return self._transmit(self, header_size, buffer_size, buffer, src_addr, dest_addr, protocol);
    }

    /// Receives a packet from a network interface.
    pub fn receive(self: *const SimpleNetworkProtocol, header_size: ?*usize, buffer_size: *usize, buffer: [*]u8, src_addr: ?*MacAddress, dest_addr: ?*MacAddress, protocol: ?*u16) Status {
        return self._receive(self, header_size, buffer_size, buffer, src_addr, dest_addr, protocol);
    }

    pub const guid align(8) = Guid{
        .time_low = 0xa19832b9,
        .time_mid = 0xac25,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x2d,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };
};

pub const MacAddress = [32]u8;

pub const SimpleNetworkMode = extern struct {
    state: SimpleNetworkState,
    hw_address_size: u32,
    media_header_size: u32,
    max_packet_size: u32,
    nvram_size: u32,
    nvram_access_size: u32,
    receive_filter_mask: SimpleNetworkReceiveFilter,
    receive_filter_setting: SimpleNetworkReceiveFilter,
    max_mcast_filter_count: u32,
    mcast_filter_count: u32,
    mcast_filter: [16]MacAddress,
    current_address: MacAddress,
    broadcast_address: MacAddress,
    permanent_address: MacAddress,
    if_type: u8,
    mac_address_changeable: bool,
    multiple_tx_supported: bool,
    media_present_supported: bool,
    media_present: bool,
};

pub const SimpleNetworkReceiveFilter = packed struct {
    receive_unicast: bool,
    receive_multicast: bool,
    receive_broadcast: bool,
    receive_promiscuous: bool,
    receive_promiscuous_multicast: bool,
    _pad: u27 = undefined,
};

pub const SimpleNetworkState = enum(u32) {
    Stopped,
    Started,
    Initialized,
};

pub const NetworkStatistics = extern struct {
    rx_total_frames: u64,
    rx_good_frames: u64,
    rx_undersize_frames: u64,
    rx_oversize_frames: u64,
    rx_dropped_frames: u64,
    rx_unicast_frames: u64,
    rx_broadcast_frames: u64,
    rx_multicast_frames: u64,
    rx_crc_error_frames: u64,
    rx_total_bytes: u64,
    tx_total_frames: u64,
    tx_good_frames: u64,
    tx_undersize_frames: u64,
    tx_oversize_frames: u64,
    tx_dropped_frames: u64,
    tx_unicast_frames: u64,
    tx_broadcast_frames: u64,
    tx_multicast_frames: u64,
    tx_crc_error_frames: u64,
    tx_total_bytes: u64,
    collisions: u64,
    unsupported_protocol: u64,
    rx_duplicated_frames: u64,
    rx_decryptError_frames: u64,
    tx_error_frames: u64,
    tx_retry_frames: u64,
};

pub const SimpleNetworkInterruptStatus = packed struct {
    receive_interrupt: bool,
    transmit_interrupt: bool,
    command_interrupt: bool,
    software_interrupt: bool,
    _pad: u28,
};
