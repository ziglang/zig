const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;

pub const SerialIo = extern struct {
    revision: u64,
    _reset: *const fn (*const SerialIo) callconv(cc) Status,
    _set_attribute: *const fn (*const SerialIo, u64, u32, u32, ParityType, u8, StopBitsType) callconv(cc) Status,
    _set_control: *const fn (*const SerialIo, u32) callconv(cc) Status,
    _get_control: *const fn (*const SerialIo, *u32) callconv(cc) Status,
    _write: *const fn (*const SerialIo, *usize, *anyopaque) callconv(cc) Status,
    _read: *const fn (*const SerialIo, *usize, *anyopaque) callconv(cc) Status,
    mode: *Mode,
    device_type_guid: ?*Guid,

    /// Resets the serial device.
    pub fn reset(self: *const SerialIo) Status {
        return self._reset(self);
    }

    /// Sets the baud rate, receive FIFO depth, transmit/receive time out, parity, data bits, and stop bits on a serial device.
    pub fn setAttribute(self: *const SerialIo, baudRate: u64, receiverFifoDepth: u32, timeout: u32, parity: ParityType, dataBits: u8, stopBits: StopBitsType) Status {
        return self._set_attribute(self, baudRate, receiverFifoDepth, timeout, parity, dataBits, stopBits);
    }

    /// Sets the control bits on a serial device.
    pub fn setControl(self: *const SerialIo, control: u32) Status {
        return self._set_control(self, control);
    }

    /// Retrieves the status of the control bits on a serial device.
    pub fn getControl(self: *const SerialIo, control: *u32) Status {
        return self._get_control(self, control);
    }

    /// Writes data to a serial device.
    pub fn write(self: *const SerialIo, bufferSize: *usize, buffer: *anyopaque) Status {
        return self._write(self, bufferSize, buffer);
    }

    /// Reads data from a serial device.
    pub fn read(self: *const SerialIo, bufferSize: *usize, buffer: *anyopaque) Status {
        return self._read(self, bufferSize, buffer);
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
        DefaultParity,
        NoParity,
        EvenParity,
        OddParity,
        MarkParity,
        SpaceParity,
    };

    pub const StopBitsType = enum(u32) {
        DefaultStopBits,
        OneStopBit,
        OneFiveStopBits,
        TwoStopBits,
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
