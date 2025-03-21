const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

pub const SerialIo = extern struct {
    revision: u64,
    _reset: *const fn (*SerialIo) callconv(cc) Status,
    _set_attribute: *const fn (*SerialIo, u64, u32, u32, ParityType, u8, StopBitsType) callconv(cc) Status,
    _set_control: *const fn (*SerialIo, u32) callconv(cc) Status,
    _get_control: *const fn (*const SerialIo, *u32) callconv(cc) Status,
    _write: *const fn (*SerialIo, *usize, *const anyopaque) callconv(cc) Status,
    _read: *const fn (*SerialIo, *usize, *anyopaque) callconv(cc) Status,
    mode: *Mode,
    device_type_guid: ?*Guid,

    pub const ResetError = uefi.UnexpectedError || error{DeviceError};
    pub const SetAttributeError = uefi.UnexpectedError || error{
        InvalidParameter,
        DeviceError,
    };
    pub const SetControlError = uefi.UnexpectedError || error{
        Unsupported,
        DeviceError,
    };
    pub const GetControlError = uefi.UnexpectedError || error{DeviceError};
    pub const WriteError = uefi.UnexpectedError || error{
        DeviceError,
        Timeout,
    };
    pub const ReadError = uefi.UnexpectedError || error{
        DeviceError,
        Timeout,
    };

    /// Resets the serial device.
    pub fn reset(self: *SerialIo) ResetError!void {
        switch (self._reset(self)) {
            .success => {},
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Sets the baud rate, receive FIFO depth, transmit/receive time out, parity, data bits, and stop bits on a serial device.
    pub fn setAttribute(
        self: *SerialIo,
        baud_rate: u64,
        receiver_fifo_depth: u32,
        timeout: u32,
        parity: ParityType,
        data_bits: u8,
        stop_bits: StopBitsType,
    ) SetAttributeError!void {
        switch (self._set_attribute(
            self,
            baud_rate,
            receiver_fifo_depth,
            timeout,
            parity,
            data_bits,
            stop_bits,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Sets the control bits on a serial device.
    pub fn setControl(self: *SerialIo, control: u32) SetControlError!void {
        switch (self._set_control(self, control)) {
            .success => {},
            .unsupported => return Error.Unsupported,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Retrieves the status of the control bits on a serial device.
    pub fn getControl(self: *SerialIo) GetControlError!u32 {
        var control: u32 = undefined;
        switch (self._get_control(self, &control)) {
            .success => return control,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Writes data to a serial device.
    pub fn write(self: *SerialIo, buffer: []const u8) WriteError!usize {
        var len: usize = buffer.len;
        switch (self._write(self, &len, buffer.ptr)) {
            .success => return len,
            .device_error => return Error.DeviceError,
            .timeout => return Error.Timeout,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Reads data from a serial device.
    pub fn read(self: *SerialIo, buffer: []u8) ReadError!usize {
        var len: usize = buffer.len;
        switch (self._read(self, &len, buffer.ptr)) {
            .success => return len,
            .device_error => return Error.DeviceError,
            .timeout => return Error.Timeout,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const guid align(8) = Guid{
        .time_low = 0xBB25CF6F,
        .time_mid = 0xF1D4,
        .time_high_and_version = 0x11D2,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x0c,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0xfd },
    };

    pub const ParityType = enum(u32) {
        default_parity,
        no_parity,
        even_parity,
        odd_parity,
        mark_parity,
        space_parity,
    };

    pub const StopBitsType = enum(u32) {
        default_stop_bits,
        one_stop_bit,
        one_five_stop_bits,
        two_stop_bits,
    };

    pub const Mode = extern struct {
        control_mask: u32,
        timeout: u32,
        baud_rate: u64,
        receive_fifo_depth: u32,
        data_bits: u32,
        parity: u32,
        stop_bits: u32,
    };
};
