const std = @import("std");
const uefi = std.os.uefi;
const io = std.io;
const Guid = uefi.Guid;
const Time = uefi.Time;
const Status = uefi.Status;
const cc = uefi.cc;

pub const File = extern struct {
    revision: u64,
    _open: *const fn (*const File, **const File, [*:0]const u16, u64, u64) callconv(cc) Status,
    _close: *const fn (*const File) callconv(cc) Status,
    _delete: *const fn (*const File) callconv(cc) Status,
    _read: *const fn (*const File, *usize, [*]u8) callconv(cc) Status,
    _write: *const fn (*const File, *usize, [*]const u8) callconv(cc) Status,
    _get_position: *const fn (*const File, *u64) callconv(cc) Status,
    _set_position: *const fn (*const File, u64) callconv(cc) Status,
    _get_info: *const fn (*const File, *align(8) const Guid, *const usize, [*]u8) callconv(cc) Status,
    _set_info: *const fn (*const File, *align(8) const Guid, usize, [*]const u8) callconv(cc) Status,
    _flush: *const fn (*const File) callconv(cc) Status,

    pub const SeekError = error{SeekError};
    pub const GetSeekPosError = error{GetSeekPosError};
    pub const ReadError = error{ReadError};
    pub const WriteError = error{WriteError};

    pub const SeekableStream = io.SeekableStream(*const File, SeekError, GetSeekPosError, seekTo, seekBy, getPos, getEndPos);
    pub const Reader = io.Reader(*const File, ReadError, readFn);
    pub const Writer = io.Writer(*const File, WriteError, writeFn);

    pub fn seekableStream(self: *File) SeekableStream {
        return .{ .context = self };
    }

    pub fn reader(self: *File) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *File) Writer {
        return .{ .context = self };
    }

    pub fn open(self: *const File, new_handle: **const File, file_name: [*:0]const u16, open_mode: u64, attributes: u64) Status {
        return self._open(self, new_handle, file_name, open_mode, attributes);
    }

    pub fn close(self: *const File) Status {
        return self._close(self);
    }

    pub fn delete(self: *const File) Status {
        return self._delete(self);
    }

    pub fn read(self: *const File, buffer_size: *usize, buffer: [*]u8) Status {
        return self._read(self, buffer_size, buffer);
    }

    fn readFn(self: *const File, buffer: []u8) ReadError!usize {
        var size: usize = buffer.len;
        if (.Success != self.read(&size, buffer.ptr)) return ReadError.ReadError;
        return size;
    }

    pub fn write(self: *const File, buffer_size: *usize, buffer: [*]const u8) Status {
        return self._write(self, buffer_size, buffer);
    }

    fn writeFn(self: *const File, bytes: []const u8) WriteError!usize {
        var size: usize = bytes.len;
        if (.Success != self.write(&size, bytes.ptr)) return WriteError.WriteError;
        return size;
    }

    pub fn getPosition(self: *const File, position: *u64) Status {
        return self._get_position(self, position);
    }

    fn getPos(self: *const File) GetSeekPosError!u64 {
        var pos: u64 = undefined;
        if (.Success != self.getPosition(&pos)) return GetSeekPosError.GetSeekPosError;
        return pos;
    }

    fn getEndPos(self: *const File) GetSeekPosError!u64 {
        // preserve the old file position
        var pos: u64 = undefined;
        if (.Success != self.getPosition(&pos)) return GetSeekPosError.GetSeekPosError;
        // seek to end of file to get position = file size
        if (.Success != self.setPosition(efi_file_position_end_of_file)) return GetSeekPosError.GetSeekPosError;
        // restore the old position
        if (.Success != self.setPosition(pos)) return GetSeekPosError.GetSeekPosError;
        // return the file size = position
        return pos;
    }

    pub fn setPosition(self: *const File, position: u64) Status {
        return self._set_position(self, position);
    }

    fn seekTo(self: *const File, pos: u64) SeekError!void {
        if (.Success != self.setPosition(pos)) return SeekError.SeekError;
    }

    fn seekBy(self: *const File, offset: i64) SeekError!void {
        // save the old position and calculate the delta
        var pos: u64 = undefined;
        if (.Success != self.getPosition(&pos)) return SeekError.SeekError;
        const seek_back = offset < 0;
        const amt = @abs(offset);
        if (seek_back) {
            pos += amt;
        } else {
            pos -= amt;
        }
        if (.Success != self.setPosition(pos)) return SeekError.SeekError;
    }

    pub fn getInfo(self: *const File, information_type: *align(8) const Guid, buffer_size: *usize, buffer: [*]u8) Status {
        return self._get_info(self, information_type, buffer_size, buffer);
    }

    pub fn setInfo(self: *const File, information_type: *align(8) const Guid, buffer_size: usize, buffer: [*]const u8) Status {
        return self._set_info(self, information_type, buffer_size, buffer);
    }

    pub fn flush(self: *const File) Status {
        return self._flush(self);
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
