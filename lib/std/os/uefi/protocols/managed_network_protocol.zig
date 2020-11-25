// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;
const Event = uefi.Event;
const Status = uefi.Status;
const Time = uefi.Time;
const SimpleNetworkMode = uefi.protocols.SimpleNetworkMode;
const MacAddress = uefi.protocols.MacAddress;

pub const ManagedNetworkProtocol = extern struct {
    _get_mode_data: fn (*const ManagedNetworkProtocol, ?*ManagedNetworkConfigData, ?*SimpleNetworkMode) callconv(.C) Status,
    _configure: fn (*const ManagedNetworkProtocol, ?*const ManagedNetworkConfigData) callconv(.C) Status,
    _mcast_ip_to_mac: fn (*const ManagedNetworkProtocol, bool, *const c_void, *MacAddress) callconv(.C) Status,
    _groups: fn (*const ManagedNetworkProtocol, bool, ?*const MacAddress) callconv(.C) Status,
    _transmit: fn (*const ManagedNetworkProtocol, *const ManagedNetworkCompletionToken) callconv(.C) Status,
    _receive: fn (*const ManagedNetworkProtocol, *const ManagedNetworkCompletionToken) callconv(.C) Status,
    _cancel: fn (*const ManagedNetworkProtocol, ?*const ManagedNetworkCompletionToken) callconv(.C) Status,
    _poll: fn (*const ManagedNetworkProtocol) callconv(.C) usize,

    /// Returns the operational parameters for the current MNP child driver.
    /// May also support returning the underlying SNP driver mode data.
    pub fn getModeData(self: *const ManagedNetworkProtocol, mnp_config_data: ?*ManagedNetworkConfigData, snp_mode_data: ?*SimpleNetworkMode) Status {
        return self._get_mode_data(self, mnp_config_data, snp_mode_data);
    }

    /// Sets or clears the operational parameters for the MNP child driver.
    pub fn configure(self: *const ManagedNetworkProtocol, mnp_config_data: ?*const ManagedNetworkConfigData) Status {
        return self._configure(self, mnp_config_data);
    }

    /// Translates an IP multicast address to a hardware (MAC) multicast address.
    /// This function may be unsupported in some MNP implementations.
    pub fn mcastIpToMac(self: *const ManagedNetworkProtocol, ipv6flag: bool, ipaddress: *const c_void, mac_address: *MacAddress) Status {
        return self._mcast_ip_to_mac(self, ipv6flag, ipaddress);
    }

    /// Enables and disables receive filters for multicast address.
    /// This function may be unsupported in some MNP implementations.
    pub fn groups(self: *const ManagedNetworkProtocol, join_flag: bool, mac_address: ?*const MacAddress) Status {
        return self._groups(self, join_flag, mac_address);
    }

    /// Places asynchronous outgoing data packets into the transmit queue.
    pub fn transmit(self: *const ManagedNetworkProtocol, token: *const ManagedNetworkCompletionToken) Status {
        return self._transmit(self, token);
    }

    /// Places an asynchronous receiving request into the receiving queue.
    pub fn receive(self: *const ManagedNetworkProtocol, token: *const ManagedNetworkCompletionToken) Status {
        return self._receive(self, token);
    }

    /// Aborts an asynchronous transmit or receive request.
    pub fn cancel(self: *const ManagedNetworkProtocol, token: ?*const ManagedNetworkCompletionToken) Status {
        return self._cancel(self, token);
    }

    /// Polls for incoming data packets and processes outgoing data packets.
    pub fn poll(self: *const ManagedNetworkProtocol) Status {
        return self._poll(self);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x7ab33a91,
        .time_mid = 0xace5,
        .time_high_and_version = 0x4326,
        .clock_seq_high_and_reserved = 0xb5,
        .clock_seq_low = 0x72,
        .node = [_]u8{ 0xe7, 0xee, 0x33, 0xd3, 0x9f, 0x16 },
    };
};

pub const ManagedNetworkConfigData = extern struct {
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

pub const ManagedNetworkCompletionToken = extern struct {
    event: Event,
    status: Status,
    packet: extern union {
        RxData: *ManagedNetworkReceiveData,
        TxData: *ManagedNetworkTransmitData,
    },
};

pub const ManagedNetworkReceiveData = extern struct {
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

pub const ManagedNetworkTransmitData = extern struct {
    destination_address: ?*MacAddress,
    source_address: ?*MacAddress,
    protocol_type: u16,
    data_length: u32,
    header_length: u16,
    fragment_count: u16,

    pub fn getFragments(self: *ManagedNetworkTransmitData) []ManagedNetworkFragmentData {
        return @ptrCast([*]ManagedNetworkFragmentData, @ptrCast([*]u8, self) + @sizeOf(ManagedNetworkTransmitData))[0..self.fragment_count];
    }
};

pub const ManagedNetworkFragmentData = extern struct {
    fragment_length: u32,
    fragment_buffer: [*]u8,
};
