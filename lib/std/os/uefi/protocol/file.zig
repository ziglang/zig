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
    _open: *const fn (*const File, **File, [*:0]const u16, OpenMode, Attributes) callconv(cc) Status,
    _close: *const fn (*File) callconv(cc) Status,
    _delete: *const fn (*File) callconv(cc) Status,
    _read: *const fn (*File, *usize, [*]u8) callconv(cc) Status,
    _write: *const fn (*File, *usize, [*]const u8) callconv(cc) Status,
    _get_position: *const fn (*const File, *u64) callconv(cc) Status,
    _set_position: *const fn (*File, u64) callconv(cc) Status,
    _get_info: *const fn (*const File, *const Guid, *usize, ?[*]u8) callconv(cc) Status,
    _set_info: *const fn (*File, *const Guid, usize, [*]const u8) callconv(cc) Status,
    _flush: *const fn (*File) callconv(cc) Status,

    pub const OpenError = uefi.UnexpectedError || error{
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
    };
    pub const CloseError = uefi.UnexpectedError;
    pub const SeekError = uefi.UnexpectedError || error{
        Unsupported,
        DeviceError,
    };
    pub const ReadError = uefi.UnexpectedError || error{
        NoMedia,
        DeviceError,
        VolumeCorrupted,
        BufferTooSmall,
    };
    pub const WriteError = uefi.UnexpectedError || error{
        Unsupported,
        NoMedia,
        DeviceError,
        VolumeCorrupted,
        WriteProtected,
        AccessDenied,
        VolumeFull,
    };
    pub const GetInfoSizeError = uefi.UnexpectedError || error{
        Unsupported,
        NoMedia,
        DeviceError,
        VolumeCorrupted,
    };
    pub const GetInfoError = GetInfoSizeError || error{
        BufferTooSmall,
    };
    pub const SetInfoError = uefi.UnexpectedError || error{
        Unsupported,
        NoMedia,
        DeviceError,
        VolumeCorrupted,
        WriteProtected,
        AccessDenied,
        VolumeFull,
        BadBufferSize,
    };
    pub const FlushError = uefi.UnexpectedError || error{
        DeviceError,
        VolumeCorrupted,
        WriteProtected,
        AccessDenied,
        VolumeFull,
    };

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
        mode: OpenMode,
        create_attributes: Attributes,
    ) OpenError!*File {
        var new: *File = undefined;
        switch (self._open(
            self,
            &new,
            file_name,
            mode,
            create_attributes,
        )) {
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
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn close(self: *File) CloseError!void {
        switch (self._close(self)) {
            .success => {},
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Delete the file.
    ///
    /// Returns true if the file was deleted, false if the file was not deleted, which is a warning
    /// according to the UEFI specification.
    pub fn delete(self: *File) uefi.UnexpectedError!bool {
        switch (self._delete(self)) {
            .success => return true,
            .warn_delete_failure => return false,
            else => |status| return uefi.unexpectedStatus(status),
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
            else => |status| return uefi.unexpectedStatus(status),
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
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn getPosition(self: *const File) SeekError!u64 {
        var position: u64 = undefined;
        switch (self._get_position(self, &position)) {
            .success => return position,
            .unsupported => return Error.Unsupported,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    fn getEndPos(self: *File) SeekError!u64 {
        const start_pos = try self.getPosition();
        // ignore error
        defer self.setPosition(start_pos) catch {};

        try self.setPosition(end_of_file);
        return self.getPosition();
    }

    pub fn setPosition(self: *File, position: u64) SeekError!void {
        switch (self._set_position(self, position)) {
            .success => {},
            .unsupported => return Error.Unsupported,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
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

    pub fn getInfoSize(self: *const File, comptime info: std.meta.Tag(Info)) GetInfoError!usize {
        const InfoType = @FieldType(Info, @tagName(info));

        var len: usize = 0;
        switch (self._get_info(self, &InfoType.guid, &len, null)) {
            .success, .buffer_too_small => return len,
            .unsupported => return Error.Unsupported,
            .no_media => return Error.NoMedia,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// If `buffer` is too small to contain all of the info, this function returns
    /// `Error.BufferTooSmall`. You should call `getInfoSize` first to determine
    /// how big the buffer should be to safely call this function.
    pub fn getInfo(
        self: *const File,
        comptime info: std.meta.Tag(Info),
        buffer: []u8,
    ) GetInfoError!*@FieldType(Info, @tagName(info)) {
        const InfoType = @FieldType(Info, @tagName(info));

        var len = buffer.len;
        switch (self._get_info(
            self,
            &InfoType.guid,
            &len,
            buffer.ptr,
        )) {
            .success => return @as(*InfoType, @ptrCast(buffer.ptr)),
            .buffer_too_small => return Error.BufferTooSmall,
            .unsupported => return Error.Unsupported,
            .no_media => return Error.NoMedia,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn setInfo(
        self: *File,
        comptime info: std.meta.Tag(Info),
        data: *const @FieldType(Info, @tagName(info)),
    ) SetInfoError!void {
        const InfoType = @FieldType(Info, @tagName(info));

        const attached_str: [*:0]const u16 = switch (info) {
            .file => data.getFileName(),
            .file_system, .volume_label => data.getVolumeLabel(),
        };
        const attached_str_len = std.mem.sliceTo(attached_str, 0).len;

        // add the length (not +1 for sentinel) because `@sizeOf(InfoType)`
        // already contains the first utf16 char
        const len = @sizeOf(InfoType) + (attached_str_len * 2);

        switch (self._set_info(self, &InfoType.guid, len, @ptrCast(data))) {
            .success => {},
            .unsupported => return Error.Unsupported,
            .no_media => return Error.NoMedia,
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .write_protected => return Error.WriteProtected,
            .access_denied => return Error.AccessDenied,
            .volume_full => return Error.VolumeFull,
            .bad_buffer_size => return Error.BadBufferSize,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn flush(self: *File) FlushError!void {
        switch (self._flush(self)) {
            .success => {},
            .device_error => return Error.DeviceError,
            .volume_corrupted => return Error.VolumeCorrupted,
            .write_protected => return Error.WriteProtected,
            .access_denied => return Error.AccessDenied,
            .volume_full => return Error.VolumeFull,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const OpenMode = enum(u64) {
        pub const Bits = packed struct(u64) {
            // 0x0000000000000001
            read: bool = false,
            // 0x0000000000000002
            write: bool = false,
            _pad: u61 = 0,
            // 0x8000000000000000
            create: bool = false,
        };

        read = @bitCast(Bits{ .read = true }),
        read_write = @bitCast(Bits{ .read = true, .write = true }),
        read_write_create = @bitCast(Bits{ .read = true, .write = true, .create = true }),
    };

    pub const Attributes = packed struct(u64) {
        // 0x0000000000000001
        read_only: bool = false,
        // 0x0000000000000002
        hidden: bool = false,
        // 0x0000000000000004
        system: bool = false,
        // 0x0000000000000008
        reserved: bool = false,
        // 0x0000000000000010
        directory: bool = false,
        // 0x0000000000000020
        archive: bool = false,
        _pad: u58 = 0,
    };

    pub const Info = union(enum) {
        file: Info.File,
        file_system: FileSystem,
        volume_label: VolumeLabel,

        pub const File = extern struct {
            size: u64,
            file_size: u64,
            physical_size: u64,
            create_time: Time,
            last_access_time: Time,
            modification_time: Time,
            attribute: Attributes,
            _file_name: u16,

            pub fn getFileName(self: *const Info.File) [*:0]const u16 {
                return @as([*:0]const u16, @ptrCast(&self._file_name));
            }

            pub const guid = Guid{
                .time_low = 0x09576e92,
                .time_mid = 0x6d3f,
                .time_high_and_version = 0x11d2,
                .clock_seq_high_and_reserved = 0x8e,
                .clock_seq_low = 0x39,
                .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
            };
        };

        pub const FileSystem = extern struct {
            size: u64,
            read_only: bool,
            volume_size: u64,
            free_space: u64,
            block_size: u32,
            _volume_label: u16,

            pub fn getVolumeLabel(self: *const FileSystem) [*:0]const u16 {
                return @as([*:0]const u16, @ptrCast(&self._volume_label));
            }

            pub const guid = Guid{
                .time_low = 0x09576e93,
                .time_mid = 0x6d3f,
                .time_high_and_version = 0x11d2,
                .clock_seq_high_and_reserved = 0x8e,
                .clock_seq_low = 0x39,
                .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
            };
        };

        pub const VolumeLabel = extern struct {
            _volume_label: u16,

            pub fn getVolumeLabel(self: *const VolumeLabel) [*:0]const u16 {
                return @as([*:0]const u16, @ptrCast(&self._volume_label));
            }

            pub const guid = Guid{
                .time_low = 0xdb47d7d3,
                .time_mid = 0xfe81,
                .time_high_and_version = 0x11d3,
                .clock_seq_high_and_reserved = 0x9a,
                .clock_seq_low = 0x35,
                .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
            };
        };
    };

    const end_of_file: u64 = 0xffffffffffffffff;
};
