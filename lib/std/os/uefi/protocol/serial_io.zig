const bits = @import("../bits.zig");

const cc = bits.cc;
const Status = @import("../status.zig").Status;

const Guid = bits.Guid;

/// This protocol is used to communicate with any type of character-based I/O device.
pub const SerialIo = extern struct {
    revision: u32,

    _reset: *const fn (*const SerialIo) callconv(cc) Status,
    _set_attributes: *const fn (*const SerialIo, u64, u32, u32, u32, u32, u32) callconv(cc) Status,
    _set_control: *const fn (*const SerialIo, Control) callconv(cc) Status,
    _get_control: *const fn (*const SerialIo, *Control) callconv(cc) Status,
    _write: *const fn (*const SerialIo, *usize, [*]const u8) callconv(cc) Status,
    _read: *const fn (*const SerialIo, *usize, [*]u8) callconv(cc) Status,

    /// The current mode of the pointer device.
    mode: *Mode,

    /// The type of device, only present when `revision` is `0x00010001` or greater.
    device_type: *const Guid,

    pub const Control = packed struct(u32) {
        /// Can be set with `setControl()`.
        data_terminal_ready: bool,

        /// Can be set with `setControl()`.
        request_to_send: bool,

        _pad1: u2 = 0,

        clear_to_send: bool,
        data_set_ready: bool,
        ring_indicate: bool,
        carrier_detect: bool,
        input_buffer_empty: bool,
        output_buffer_empty: bool,

        _pad2: u2 = 0,

        /// Can be set with `setControl()`.
        hardware_loopback_enable: bool,

        /// Can be set with `setControl()`.
        software_loopback_enable: bool,

        /// Can be set with `setControl()`.
        hardware_flow_control_enable: bool,

        _pad3: u17 = 0,
    };

    pub const Mode = extern struct {
        /// A value of true here means the field is supported.
        control_mask: Control,

        /// If applicable, the number of microseconds to wait before timing out a Read or Write operation.
        timeout: u32,

        /// If applicable, the current baud rate setting of the device; otherwise, baud rate has the value of zero to
        /// indicate that device runs at the device’s designed speed.
        baud_rate: u64,

        /// The number of characters the device will buffer on input.
        receive_fifo_depth: u32,

        /// The number of data bits in each character.
        data_bits: u32,

        /// If applicable, this is the parity that is computed or checked as each character is transmitted or
        /// received. If the device does not support parity the value is the default parity value.
        parity: bits.Parity,

        /// If applicable, the number of stop bits per character. If the device does not support stop bits the value
        /// is the default stop bit value.
        stop_bits: bits.StopBits,
    };

    /// Resets the pointer device hardware.
    pub fn reset(
        self: *const SerialIo,
    ) !void {
        try self._reset(self).err();
    }

    /// Sets the baud rate, receive FIFO depth, transmit/receive time out, parity, data bits, and stop bits on a
    /// serial device.
    pub fn setAttributes(
        self: *const SerialIo,
        /// The baud rate to use on the device.
        baud_rate: u64,
        /// The number of characters the device will buffer on input.
        receive_fifo_depth: u32,
        /// The timeout for a read or write operation in microseconds.
        timeout: u32,
        /// The parity setting to use on this device.
        parity: bits.Parity,
        /// The number of data bits to use on this device.
        data_bits: u32,
        /// The number of stop bits to use on this device.
        stop_bits: bits.StopBits,
    ) !void {
        try self._set_attributes(
            self,
            baud_rate,
            receive_fifo_depth,
            timeout,
            @intFromEnum(parity),
            data_bits,
            @intFromEnum(stop_bits),
        ).err();
    }

    /// Sets the status of the control bits on a serial device.
    pub fn setControl(
        self: *const SerialIo,
        control: Control,
    ) !void {
        try self._set_control(self, control).err();
    }

    /// Retrieves the status of the control bits on a serial device.
    pub fn getControl(
        self: *const SerialIo,
    ) !Control {
        var control: Control = undefined;
        try self._get_control(self, &control).err();
        return control;
    }

    /// Writes data to a serial device.
    pub fn write(
        self: *const SerialIo,
        buffer: []const u8,
    ) !usize {
        var size: usize = buffer.len;
        try self._write(self, &size, buffer.ptr).err();
        return size;
    }

    /// Reads data from a serial device.
    pub fn read(
        self: *const SerialIo,
        buffer: []u8,
    ) !usize {
        var size: usize = buffer.len;
        try self._read(self, &size, buffer.ptr).err();
        return size;
    }

    pub const guid align(8) = Guid{
        .time_low = 0xbb25cf6f,
        .time_mid = 0xf1d4,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x0c,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0xfd },
    };

    pub const terminal_device_guid align(8) = Guid{
        .time_low = 0x6ad9a60f,
        .time_mid = 0x5815,
        .time_high_and_version = 0x4c7c,
        .clock_seq_high_and_reserved = 0x8a,
        .clock_seq_low = 0x10,
        .node = [_]u8{ 0x50, 0x53, 0xd2, 0xbf, 0x7a, 0x1b },
    };
};
