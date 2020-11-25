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
const Ip6ModeData = uefi.protocols.Ip6ModeData;
const Ip6Address = uefi.protocols.Ip6Address;
const ManagedNetworkConfigData = uefi.protocols.ManagedNetworkConfigData;
const SimpleNetworkMode = uefi.protocols.SimpleNetworkMode;

pub const Udp6Protocol = extern struct {
    _get_mode_data: fn (*const Udp6Protocol, ?*Udp6ConfigData, ?*Ip6ModeData, ?*ManagedNetworkConfigData, ?*SimpleNetworkMode) callconv(.C) Status,
    _configure: fn (*const Udp6Protocol, ?*const Udp6ConfigData) callconv(.C) Status,
    _groups: fn (*const Udp6Protocol, bool, ?*const Ip6Address) callconv(.C) Status,
    _transmit: fn (*const Udp6Protocol, *Udp6CompletionToken) callconv(.C) Status,
    _receive: fn (*const Udp6Protocol, *Udp6CompletionToken) callconv(.C) Status,
    _cancel: fn (*const Udp6Protocol, ?*Udp6CompletionToken) callconv(.C) Status,
    _poll: fn (*const Udp6Protocol) callconv(.C) Status,

    pub fn getModeData(self: *const Udp6Protocol, udp6_config_data: ?*Udp6ConfigData, ip6_mode_data: ?*Ip6ModeData, mnp_config_data: ?*ManagedNetworkConfigData, snp_mode_data: ?*SimpleNetworkMode) Status {
        return self._get_mode_data(self, udp6_config_data, ip6_mode_data, mnp_config_data, snp_mode_data);
    }

    pub fn configure(self: *const Udp6Protocol, udp6_config_data: ?*const Udp6ConfigData) Status {
        return self._configure(self, udp6_config_data);
    }

    pub fn groups(self: *const Udp6Protocol, join_flag: bool, multicast_address: ?*const Ip6Address) Status {
        return self._groups(self, join_flag, multicast_address);
    }

    pub fn transmit(self: *const Udp6Protocol, token: *Udp6CompletionToken) Status {
        return self._transmit(self, token);
    }

    pub fn receive(self: *const Udp6Protocol, token: *Udp6CompletionToken) Status {
        return self._receive(self, token);
    }

    pub fn cancel(self: *const Udp6Protocol, token: ?*Udp6CompletionToken) Status {
        return self._cancel(self, token);
    }

    pub fn poll(self: *const Udp6Protocol) Status {
        return self._poll(self);
    }

    pub const guid align(8) = uefi.Guid{
        .time_low = 0x4f948815,
        .time_mid = 0xb4b9,
        .time_high_and_version = 0x43cb,
        .clock_seq_high_and_reserved = 0x8a,
        .clock_seq_low = 0x33,
        .node = [_]u8{ 0x90, 0xe0, 0x60, 0xb3, 0x49, 0x55 },
    };
};

pub const Udp6ConfigData = extern struct {
    accept_promiscuous: bool,
    accept_any_port: bool,
    allow_duplicate_port: bool,
    traffic_class: u8,
    hop_limit: u8,
    receive_timeout: u32,
    transmit_timeout: u32,
    station_address: Ip6Address,
    station_port: u16,
    remote_address: Ip6Address,
    remote_port: u16,
};

pub const Udp6CompletionToken = extern struct {
    event: Event,
    Status: usize,
    packet: extern union {
        RxData: *Udp6ReceiveData,
        TxData: *Udp6TransmitData,
    },
};

pub const Udp6ReceiveData = extern struct {
    timestamp: Time,
    recycle_signal: Event,
    udp6_session: Udp6SessionData,
    data_length: u32,
    fragment_count: u32,

    pub fn getFragments(self: *Udp6ReceiveData) []Udp6FragmentData {
        return @ptrCast([*]Udp6FragmentData, @ptrCast([*]u8, self) + @sizeOf(Udp6ReceiveData))[0..self.fragment_count];
    }
};

pub const Udp6TransmitData = extern struct {
    udp6_session_data: ?*Udp6SessionData,
    data_length: u32,
    fragment_count: u32,

    pub fn getFragments(self: *Udp6TransmitData) []Udp6FragmentData {
        return @ptrCast([*]Udp6FragmentData, @ptrCast([*]u8, self) + @sizeOf(Udp6TransmitData))[0..self.fragment_count];
    }
};

pub const Udp6SessionData = extern struct {
    source_address: Ip6Address,
    source_port: u16,
    destination_address: Ip6Address,
    destination_port: u16,
};

pub const Udp6FragmentData = extern struct {
    fragment_length: u32,
    fragment_buffer: [*]u8,
};
