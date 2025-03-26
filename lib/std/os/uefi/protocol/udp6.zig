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

pub const Udp6 = extern struct {
    _get_mode_data: *const fn (*const Udp6, ?*Config, ?*Ip6.Mode, ?*ManagedNetworkConfigData, ?*SimpleNetwork) callconv(cc) Status,
    _configure: *const fn (*const Udp6, ?*const Config) callconv(cc) Status,
    _groups: *const fn (*const Udp6, bool, ?*const Ip6.Address) callconv(cc) Status,
    _transmit: *const fn (*const Udp6, *CompletionToken) callconv(cc) Status,
    _receive: *const fn (*const Udp6, *CompletionToken) callconv(cc) Status,
    _cancel: *const fn (*const Udp6, ?*CompletionToken) callconv(cc) Status,
    _poll: *const fn (*const Udp6) callconv(cc) Status,

    pub fn getModeData(self: *const Udp6, udp6_config_data: ?*Config, ip6_mode_data: ?*Ip6.Mode, mnp_config_data: ?*ManagedNetworkConfigData, snp_mode_data: ?*SimpleNetwork) Status {
        return self._get_mode_data(self, udp6_config_data, ip6_mode_data, mnp_config_data, snp_mode_data);
    }

    pub fn configure(self: *const Udp6, udp6_config_data: ?*const Config) Status {
        return self._configure(self, udp6_config_data);
    }

    pub fn groups(self: *const Udp6, join_flag: bool, multicast_address: ?*const Ip6.Address) Status {
        return self._groups(self, join_flag, multicast_address);
    }

    pub fn transmit(self: *const Udp6, token: *CompletionToken) Status {
        return self._transmit(self, token);
    }

    pub fn receive(self: *const Udp6, token: *CompletionToken) Status {
        return self._receive(self, token);
    }

    pub fn cancel(self: *const Udp6, token: ?*CompletionToken) Status {
        return self._cancel(self, token);
    }

    pub fn poll(self: *const Udp6) Status {
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
