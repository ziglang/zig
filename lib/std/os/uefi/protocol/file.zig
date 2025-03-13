const std = @import("std");
const uefi = std.os.uefi;
const io = std.io;
const Guid = uefi.Guid;
const Time = uefi.Time;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

pub const File = extern struct {
    revision: u64,
    _open: *const fn (*const File, **File, [*:0]const u16, u64, u64) callconv(cc) Status,
    _close: *const fn (*File) callconv(cc) Status,
    _delete: *const fn (*File) callconv(cc) Status,
    _read: *const fn (*File, *usize, [*]u8) callconv(cc) Status,
    _write: *const fn (*File, *usize, [*]const u8) callconv(cc) Status,
    _get_position: *const fn (*const File, *u64) callconv(cc) Status,
    _set_position: *const fn (*File, u64) callconv(cc) Status,
    _get_info: *const fn (*const File, *align(8) const Guid, *const usize, [*]u8) callconv(cc) Status,
    _set_info: *const fn (*File, *align(8) const Guid, usize, [*]const u8) callconv(cc) Status,
    _flush: *const fn (*File) callconv(cc) Status,

    pub const OpenError = error{
        NotFound,
        NoMedia,
        MediaChanged,
        DeviceError,
        VolumeCorrupted,
        WriteProtected,
        AccessDenied,
        OutOfResources,
        VolumeFull,
        InvalidParameter,
    } || uefi.UnexpectedError;
    // seek and position have the same errors
    pub const SeekError = error{ Unsupported, DeviceError } || uefi.UnexpectedError;
    pub const ReadError = error{ NoMedia, DeviceError, VolumeCorrupted, BufferTooSmall } || uefi.UnexpectedError;
    pub const WriteError = error{
        Unsupported,
        NoMedia,
        DeviceError,
        VolumeCorrupted,
        WriteProtected,
        AccessDenied,
        VolumeFull,
    } || uefi.UnexpectedError;

    pub const SeekableStream = io.SeekableStream(
        *File,
        SeekError,
        SeekError,
        setPosition,
        seekBy,
        getPosition,
        getEndPos,
    );
    pub const Reader = io.Reader(*File, ReadError, read);
    pub const Writer = io.Writer(*File, WriteError, write);

    pub fn seekableStream(self: *File) SeekableStream {
        return .{ .context = self };
    }

    pub fn reader(self: *File) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *File) Writer {
        return .{ .context = self };
    }

    pub fn open(
        self: *const File,
        file_name: [*:0]const u16,
        open_mode: u64,
        attributes: u64,
    ) !*File {
        var new: *File = undefined;
        switch (self._open(self, &new, file_name, open_mode, attributes)) {
            .success => return new,
            .not_found => return Error.NotFound,
            .no_media => return Error.NoMedia,
            .media_changed => return Error.MediaChanged,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .write_protected => return Error.WriteProtected,
            .access_denied => return Error.AccessDenied,
            .out_of_resources => return Error.OutOfResources,
            .volume_full => return Error.VolumeFull,
            .invalid_parameter => return Error.InvalidParameter,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    pub fn close(self: *File) void {
        switch (self._close(self)) {
            .success => {},
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    /// Delete the file.
    ///
    /// Returns true if the file was deleted, false if the file was not deleted, which is a warning
    /// according to the UEFI specification.
    pub fn delete(self: *File) bool {
        switch (self._delete(self)) {
            .success => return true,
            .warn_delete_failure => return false,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    pub fn read(self: *File, buffer: []u8) ReadError!usize {
        var size: usize = buffer.len;
        switch (self._read(self, &size, buffer.ptr)) {
            .success => return size,
            .no_media => return Error.NoMedia,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .buffer_too_small => return Error.BufferTooSmall,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    pub fn write(self: *File, buffer: []const u8) WriteError!usize {
        var size: usize = buffer.len;
        switch (self._write(self, &size, buffer.ptr)) {
            .success => return size,
            .unsupported => return Error.Unsupported,
            .no_media => return Error.NoMedia,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .write_protected => return Error.WriteProtected,
            .access_denied => return Error.AccessDenied,
            .volume_full => return Error.VolumeFull,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    pub fn getPosition(self: *const File) SeekError!u64 {
        var position: u64 = undefined;
        switch (self._get_position(self, &position)) {
            .success => return position,
            .unsupported => return Error.Unsupported,
            .device_error => return Error.DeviceError,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    fn getEndPos(self: *File) !u64 {
        const start_pos = try self.getPosition();
        // ignore error
        defer _ = self.setPosition(start_pos) catch {};

        try self.setPosition(efi_file_position_end_of_file);
        return try self.getPosition();
    }

    pub fn setPosition(self: *File, position: u64) SeekError!void {
        switch (self._set_position(self, position)) {
            .success => {},
            .unsupported => return Error.Unsupported,
            .device_error => return Error.DeviceError,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    fn seekBy(self: *File, offset: i64) SeekError!void {
        var pos = try self.getPosition();
        const seek_back = offset < 0;
        const amt = @abs(offset);
        if (seek_back) {
            pos += amt;
        } else {
            pos -= amt;
        }
        try self.setPosition(pos);
    }

    pub fn getInfo(
        self: *const File,
        information_type: *align(8) const Guid,
        buffer: []u8,
    ) !usize {
        var len = buffer.len;
        switch (self._get_info(self, information_type, &len, buffer.ptr)) {
            .success => return len,
            .unsupported => return Error.Unsupported,
            .no_media => return Error.NoMedia,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .buffer_too_small => return Error.BufferTooSmall,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    pub fn setInfo(
        self: *const File,
        information_type: *align(8) const Guid,
        buffer: []const u8,
    ) !void {
        switch (self._set_info(self, information_type, buffer.len, buffer.ptr)) {
            .success => {},
            .unsupported => return Error.Unsupported,
            .no_media => return Error.NoMedia,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .write_protected => return Error.WriteProtected,
            .access_denied => return Error.AccessDenied,
            .volume_full => return Error.VolumeFull,
            .bad_buffer_size => return Error.BadBufferSize,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    pub fn flush(self: *File) !void {
        switch (self._flush(self)) {
            .success => {},
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .write_protected => return Error.WriteProtected,
            .access_denied => return Error.AccessDenied,
            .volume_full => return Error.VolumeFull,
            else => |err| return uefi.unexpectedStatus(err),
        }
    }

    pub const efi_file_mode_read: u64 = 0x0000000000000001;
    pub const efi_file_mode_write: u64 = 0x0000000000000002;
    pub const efi_file_mode_create: u64 = 0x8000000000000000;

    pub const efi_file_read_only: u64 = 0x0000000000000001;
    pub const efi_file_hidden: u64 = 0x0000000000000002;
    pub const efi_file_system: u64 = 0x0000000000000004;
    pub const efi_file_reserved: u64 = 0x0000000000000008;
    pub const efi_file_directory: u64 = 0x0000000000000010;
    pub const efi_file_archive: u64 = 0x0000000000000020;
    pub const efi_file_valid_attr: u64 = 0x0000000000000037;

    pub const efi_file_position_end_of_file: u64 = 0xffffffffffffffff;
};
