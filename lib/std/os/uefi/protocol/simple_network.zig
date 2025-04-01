const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

pub const SimpleNetwork = extern struct {
    revision: u64,
    _start: *const fn (*SimpleNetwork) callconv(cc) Status,
    _stop: *const fn (*SimpleNetwork) callconv(cc) Status,
    _initialize: *const fn (*SimpleNetwork, usize, usize) callconv(cc) Status,
    _reset: *const fn (*SimpleNetwork, bool) callconv(cc) Status,
    _shutdown: *const fn (*SimpleNetwork) callconv(cc) Status,
    _receive_filters: *const fn (*SimpleNetwork, ReceiveFilter, ReceiveFilter, bool, usize, ?[*]const MacAddress) callconv(cc) Status,
    _station_address: *const fn (*SimpleNetwork, bool, ?*const MacAddress) callconv(cc) Status,
    _statistics: *const fn (*const SimpleNetwork, bool, ?*usize, ?*Statistics) callconv(cc) Status,
    _mcast_ip_to_mac: *const fn (*SimpleNetwork, bool, *const anyopaque, *MacAddress) callconv(cc) Status,
    _nvdata: *const fn (*SimpleNetwork, bool, usize, usize, [*]u8) callconv(cc) Status,
    _get_status: *const fn (*SimpleNetwork, ?*InterruptStatus, ?*?[*]u8) callconv(cc) Status,
    _transmit: *const fn (*SimpleNetwork, usize, usize, [*]const u8, ?*const MacAddress, ?*const MacAddress, ?*const u16) callconv(cc) Status,
    _receive: *const fn (*SimpleNetwork, ?*usize, *usize, [*]u8, ?*MacAddress, ?*MacAddress, ?*u16) callconv(cc) Status,
    wait_for_packet: Event,
    mode: *Mode,

    pub const StartError = uefi.UnexpectedError || error{
        AlreadyStarted,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const StopError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const InitializeError = uefi.UnexpectedError || error{
        NotStarted,
        OutOfResources,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const ResetError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const ShutdownError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
    };
    pub const ReceiveFiltersError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const StationAddressError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const StatisticsError = uefi.UnexpectedError || error{
        NotStarted,
        BufferTooSmall,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const McastIpToMacError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const NvDataError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const GetStatusError = uefi.UnexpectedError || error{
        NotStarted,
        InvalidParameter,
        DeviceError,
    };
    pub const TransmitError = uefi.UnexpectedError || error{
        NotStarted,
        NotReady,
        BufferTooSmall,
        InvalidParameter,
        DeviceError,
        Unsupported,
    };
    pub const ReceiveError = uefi.UnexpectedError || error{
        NotStarted,
        NotReady,
        BufferTooSmall,
        InvalidParameter,
        DeviceError,
    };

    /// Changes the state of a network interface from "stopped" to "started".
    pub fn start(self: *SimpleNetwork) StartError!void {
        switch (self._start(self)) {
            .success => {},
            .already_started => return Error.AlreadyStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Changes the state of a network interface from "started" to "stopped".
    pub fn stop(self: *SimpleNetwork) StopError!void {
        switch (self._stop(self)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Resets a network adapter and allocates the transmit and receive buffers required by the network interface.
    pub fn initialize(
        self: *SimpleNetwork,
        extra_rx_buffer_size: usize,
        extra_tx_buffer_size: usize,
    ) InitializeError!void {
        switch (self._initialize(self, extra_rx_buffer_size, extra_tx_buffer_size)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .out_of_resources => return Error.OutOfResources,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Resets a network adapter and reinitializes it with the parameters that were provided in the previous call to initialize().
    pub fn reset(self: *SimpleNetwork, extended_verification: bool) ResetError!void {
        switch (self._reset(self, extended_verification)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Resets a network adapter and leaves it in a state that is safe for another driver to initialize.
    pub fn shutdown(self: *SimpleNetwork) ShutdownError!void {
        switch (self._shutdown(self)) {
            .success => {},
            .not_started => return ShutdownError.NotStarted,
            .invalid_parameter => return ShutdownError.InvalidParameter,
            .device_error => return ShutdownError.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Manages the multicast receive filters of a network interface.
    pub fn receiveFilters(
        self: *SimpleNetwork,
        enable: ReceiveFilter,
        disable: ReceiveFilter,
        reset_mcast_filter: bool,
        mcast_filter: ?[]const MacAddress,
    ) ReceiveFiltersError!void {
        const count: usize, const ptr: ?[*]const MacAddress =
            if (mcast_filter) |f|
                .{ f.len, f.ptr }
            else
                .{ 0, null };

        switch (self._receive_filters(self, enable, disable, reset_mcast_filter, count, ptr)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Modifies or resets the current station address, if supported.
    pub fn stationAddress(
        self: *SimpleNetwork,
        reset_flag: bool,
        new: ?*const MacAddress,
    ) StationAddressError!void {
        switch (self._station_address(self, reset_flag, new)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn resetStatistics(self: *SimpleNetwork) StatisticsError!void {
        switch (self._statistics(self, true, null, null)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Resets or collects the statistics on a network interface.
    pub fn statistics(self: *SimpleNetwork, reset_flag: bool) StatisticsError!Statistics {
        var stats: Statistics = undefined;
        var stats_size: usize = @sizeOf(Statistics);
        switch (self._statistics(self, reset_flag, &stats_size, &stats)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }

        if (stats_size != @sizeOf(Statistics))
            return error.Unexpected
        else
            return stats;
    }

    /// Converts a multicast IP address to a multicast HW MAC address.
    pub fn mcastIpToMac(
        self: *SimpleNetwork,
        ipv6: bool,
        ip: *const anyopaque,
    ) McastIpToMacError!MacAddress {
        var mac: MacAddress = undefined;
        switch (self._mcast_ip_to_mac(self, ipv6, ip, &mac)) {
            .success => return mac,
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Performs read and write operations on the NVRAM device attached to a network interface.
    pub fn nvData(
        self: *SimpleNetwork,
        read_write: NvDataOperation,
        offset: usize,
        buffer: []u8,
    ) NvDataError!void {
        switch (self._nvdata(
            self,
            // if ReadWrite is TRUE, a read operation is performed
            read_write == .read,
            offset,
            buffer.len,
            buffer.ptr,
        )) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Reads the current interrupt status and recycled transmit buffer status from a network interface.
    pub fn getStatus(
        self: *SimpleNetwork,
        interrupt_status: ?*InterruptStatus,
        recycled_tx_buf: ?*?[*]u8,
    ) GetStatusError!void {
        switch (self._get_status(self, interrupt_status, recycled_tx_buf)) {
            .success => {},
            .not_started => return Error.NotStarted,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Places a packet in the transmit queue of a network interface.
    pub fn transmit(
        self: *SimpleNetwork,
        header_size: usize,
        buffer: []const u8,
        src_addr: ?*const MacAddress,
        dest_addr: ?*const MacAddress,
        protocol: ?*const u16,
    ) TransmitError!void {
        switch (self._transmit(
            self,
            header_size,
            buffer.len,
            buffer.ptr,
            src_addr,
            dest_addr,
            protocol,
        )) {
            .success => {},
            .not_started => return Error.NotStarted,
            .not_ready => return Error.NotReady,
            .buffer_too_small => return Error.BufferTooSmall,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Receives a packet from a network interface.
    pub fn receive(self: *SimpleNetwork, buffer: []u8) ReceiveError!Packet {
        var packet: Packet = undefined;
        packet.buffer = buffer;

        switch (self._receive(
            self,
            &packet.header_size,
            &packet.buffer.len,
            packet.buffer.ptr,
            &packet.src_addr,
            &packet.dst_addr,
            &packet.protocol,
        )) {
            .success => return packet,
            .not_started => return Error.NotStarted,
            .not_ready => return Error.NotReady,
            .buffer_too_small => return Error.BufferTooSmall,
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const guid align(8) = Guid{
        .time_low = 0xa19832b9,
        .time_mid = 0xac25,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x2d,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };

    pub const NvDataOperation = enum {
        read,
        write,
    };

    pub const MacAddress = [32]u8;

    pub const Mode = extern struct {
        state: State,
        hw_address_size: u32,
        media_header_size: u32,
        max_packet_size: u32,
        nvram_size: u32,
        nvram_access_size: u32,
        receive_filter_mask: ReceiveFilter,
        receive_filter_setting: ReceiveFilter,
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

    pub const ReceiveFilter = packed struct(u32) {
        receive_unicast: bool,
        receive_multicast: bool,
        receive_broadcast: bool,
        receive_promiscuous: bool,
        receive_promiscuous_multicast: bool,
        _pad: u27 = 0,
    };

    pub const State = enum(u32) {
        stopped,
        started,
        initialized,
    };

    pub const Statistics = extern struct {
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

    pub const InterruptStatus = packed struct(u32) {
        receive_interrupt: bool,
        transmit_interrupt: bool,
        command_interrupt: bool,
        software_interrupt: bool,
        _pad: u28 = 0,
    };

    pub const Packet = struct {
        header_size: usize,
        buffer: []u8,
        src_addr: MacAddress,
        dst_addr: MacAddress,
        protocol: u16,
    };
};
