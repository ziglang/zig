const bits = @import("../../bits.zig");
const protocol = @import("../../protocol.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;
const Event = bits.Event;

pub const SimpleNetwork = extern struct {
    revision: u64,
    _start: *const fn (*const SimpleNetwork) callconv(cc) Status,
    _stop: *const fn (*const SimpleNetwork) callconv(cc) Status,
    _initialize: *const fn (*const SimpleNetwork, usize, usize) callconv(cc) Status,
    _reset: *const fn (*const SimpleNetwork, bool) callconv(cc) Status,
    _shutdown: *const fn (*const SimpleNetwork) callconv(cc) Status,
    _receive_filters: *const fn (*const SimpleNetwork, ReceiveFilter, ReceiveFilter, bool, usize, ?[*]const bits.MacAddress) callconv(cc) Status,
    _station_address: *const fn (*const SimpleNetwork, bool, ?*const bits.MacAddress) callconv(cc) Status,
    _statistics: *const fn (*const SimpleNetwork, bool, ?*usize, ?*Statistics) callconv(cc) Status,
    _mcast_ip_to_mac: *const fn (*const SimpleNetwork, bool, *const bits.IpAddress, *bits.MacAddress) callconv(cc) Status,
    _nvdata: *const fn (*const SimpleNetwork, bool, usize, usize, [*]u8) callconv(cc) Status,
    _get_status: *const fn (*const SimpleNetwork, *InterruptStatus, ?*?[*]u8) callconv(cc) Status,
    _transmit: *const fn (*const SimpleNetwork, usize, usize, [*]const u8, ?*const bits.MacAddress, ?*const bits.MacAddress, ?*const u16) callconv(cc) Status,
    _receive: *const fn (*const SimpleNetwork, ?*usize, *usize, [*]u8, ?*bits.MacAddress, ?*bits.MacAddress, ?*u16) callconv(cc) Status,
    wait_for_packet: Event,
    mode: *Mode,

    /// Changes the state of a network interface from "stopped" to "started".
    pub fn start(self: *const SimpleNetwork) !void {
        try self._start(self).err();
    }

    /// Changes the state of a network interface from "started" to "stopped".
    pub fn stop(self: *const SimpleNetwork) !void {
        try self._stop(self).err();
    }

    /// Resets a network adapter and allocates the transmit and receive buffers required by the network interface.
    pub fn initialize(
        self: *const SimpleNetwork,
        /// The size, in bytes, of the extra receive buffer space that the driver should allocate for the network
        /// interface. Some network interfaces will not be able to use the extra buffer, and the caller will not know if
        /// it is actually being used.
        extra_rx_buffer_size: usize,
        /// The size, in bytes, of the extra transmit buffer space that the driver should allocate for the network
        /// interface. Some network interfaces will not be able to use the extra buffer, and the caller will not know if
        /// it is actually being used.
        extra_tx_buffer_size: usize,
    ) !void {
        try self._initialize(self, extra_rx_buffer_size, extra_tx_buffer_size).err();
    }

    /// Resets a network adapter and re-initializes it with the parameters that were provided in the previous call to initialize().
    pub fn reset(
        self: *const SimpleNetwork,
        /// Indicates that the driver may perform a more exhaustive verification operation of the device during reset.
        extended_verification: bool,
    ) !void {
        try self._reset(self, extended_verification).err();
    }

    /// Resets a network adapter and leaves it in a state that is safe for another driver to initialize.
    pub fn shutdown(self: *const SimpleNetwork) !void {
        try self._shutdown(self).err();
    }

    /// Manages the multicast receive filters of a network interface.
    pub fn receiveFilters(
        self: *const SimpleNetwork,
        /// A bit mask of receive filters to enable on the network interface.
        enable: ReceiveFilter,
        /// A bit mask of receive filters to disable on the network interface. `.receive_multicast` must be true when
        /// `reset_mcast_filter` is true.
        disable: ReceiveFilter,
        /// When true, resets the multicast receive filter list to the default value.
        reset_mcast_filter: bool,
        /// A pointer to a list of new multicast receive filter HW MAC addresses.
        /// This list will replace any existing multicast HW MAC address list.
        ///
        /// Only optional when `reset_mcast_filter` is true.
        mcast_filter: ?[]const bits.MacAddress,
    ) !void {
        if (mcast_filter) |filter| {
            try self._receive_filters(self, enable, disable, reset_mcast_filter, filter.len, filter.ptr).err();
        } else {
            try self._receive_filters(self, enable, disable, reset_mcast_filter, 0, null).err();
        }
    }

    /// Modifies or resets the current station address, if supported.
    pub fn stationAddress(
        self: *const SimpleNetwork,
        /// New station address to be used for the network interface. or null to reset the station address to the network
        /// interface's permanent station address.
        new: ?bits.MacAddress,
    ) !void {
        if (new) |addr| {
            try self._station_address(self, false, &addr).err();
        } else {
            try self._station_address(self, true, null).err();
        }
    }

    /// Resets the statistics on a network interface.
    pub fn resetStatistics(self: *const SimpleNetwork) !void {
        try self._statistics(self, true, null, null).err();
    }

    /// Collects the statistics on a network interface.
    pub fn collectStatistics(self: *const SimpleNetwork) !Statistics {
        var stats: Statistics = undefined;
        var size: usize = @sizeOf(Statistics);
        self._statistics(self, false, &size, &stats).err() catch |err| switch (err) {
            error.BufferTooSmall => {},
            else => |e| return e,
        };

        return stats;
    }

    /// Converts a multicast IP address to a multicast HW MAC address.
    pub fn mcastIpToMac(
        self: *const SimpleNetwork,
        /// If true, the IP address is an IPv6 address. If false, the IP address is an IPv4 address.
        ipv6: bool,
        /// The multicast IP address that is to be converted to a multicast HW MAC address.
        ip: bits.IpAddress,
    ) !bits.MacAddress {
        var mac: bits.MacAddress = undefined;
        try self._mcast_ip_to_mac(self, ipv6, &ip, &mac).err();
        return mac;
    }

    /// Performs read and write operations on the NVRAM device attached to a network interface.
    pub fn nvdata(
        self: *const SimpleNetwork,
        /// If true, the operation is a read operation. If false, the operation is a write operation.
        is_read: bool,
        /// Byte offset in the NVRAM device at which to start the read or write operation.
        offset: usize,
        buffer: []u8,
    ) !void {
        try self._nvdata(self, is_read, offset, buffer.len, buffer.ptr).err();
    }

    /// Reads the current interrupt status and recycled transmit buffer status from a network interface.
    pub fn getInterruptStatus(self: *const SimpleNetwork) !InterruptStatus {
        var interrupt_status: InterruptStatus = null;
        try self._get_status(self, &interrupt_status).err();
        return interrupt_status;
    }

    /// Reads the current interrupt status and recycled transmit buffer status from a network interface.
    pub fn getTransmitBuffer(self: *const SimpleNetwork) !?[*]u8 {
        var tx_buf: ?[*]u8 = null;
        try self._get_status(self, null, &tx_buf).err();
        return tx_buf;
    }

    /// Places a packet in the transmit queue of a network interface. The caller must have filled in the media header in
    /// the packet buffer.
    ///
    /// The provided buffer must not be modified until the transmit operation is complete.
    pub fn transmitDirect(
        self: *const SimpleNetwork,
        /// A pointer to the packet (media header followed by data) to be transmitted.
        buffer: []const u8,
    ) !void {
        try self._transmit(self, 0, buffer.len, buffer.ptr, null, null, null).err();
    }

    /// Places a packet in the transmit queue of a network interface.
    ///
    /// The provided buffer must not be modified until the transmit operation is complete.
    pub fn transmitWithHeader(
        self: *const SimpleNetwork,
        /// The size, in bytes, of the media header to be filled in by the Transmit() function. Must be non-zero and equal
        /// to mode.media_header_size.
        header_size: usize,
        /// A pointer to the packet (media header followed by data) to be transmitted. The media header will be filled in
        /// the first `header_size` bytes of the buffer.
        buffer: []u8,
        /// The source HW MAC address. If null, will be mode.current_address.
        src_addr: ?bits.MacAddress,
        /// The destination HW MAC address.
        dest_addr: bits.MacAddress,
        /// The type of header to build
        proto: u16,
    ) !void {
        return self._transmit(self, header_size, buffer.len, buffer.ptr, if (src_addr) |addr| &addr else null, &dest_addr, &proto);
    }

    /// Receives a packet from a network interface. The media header is not parsed from the packet.
    pub fn receiveDirect(
        self: *const SimpleNetwork,
        /// A pointer to the data buffer to receive the data.
        buffer: []u8,
    ) !usize {
        var len = buffer.len;
        try self._receive(self, null, &len, buffer.ptr, null, null, null).err();
        return len;
    }

    pub const MediaHeader = struct {
        size: usize,
        src_addr: bits.MacAddress,
        dest_addr: bits.MacAddress,
        proto: u16,
    };

    /// Receives a packet from a network interface.
    pub fn receiveWithHeader(
        self: *const SimpleNetwork,
        /// A pointer to the data buffer to receive both the media header and the data.
        buffer: []u8,
    ) !struct { usize, MediaHeader } {
        var len = buffer.len;
        var header: MediaHeader = undefined;
        try self._receive(self, &header.size, &len, buffer.ptr, &header.src_addr, &header.dest_addr, &header.proto).err();
        return .{ len, header };
    }

    pub const guid align(8) = Guid{
        .time_low = 0xa19832b9,
        .time_mid = 0xac25,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x2d,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };

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
        mcast_filter: [16]bits.MacAddress,
        current_address: bits.MacAddress,
        broadcast_address: bits.MacAddress,
        permanent_address: bits.MacAddress,
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
        Stopped,
        Started,
        Initialized,
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
};
