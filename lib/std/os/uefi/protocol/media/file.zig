const std = @import("../../../../std.zig");
const io = std.io;

const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;

pub const File = extern struct {
    revision: u64,
    _open: *const fn (*const File, fd: **const File, name: [*:0]const u16, mode: OpenMode, attrs: bits.FileInfo.Attributes) callconv(cc) Status,
    _close: *const fn (*const File) callconv(cc) Status,
    _delete: *const fn (*const File) callconv(cc) Status,
    _read: *const fn (*const File, buf_size: *usize, buf: [*]u8) callconv(cc) Status,
    _write: *const fn (*const File, buf_size: *usize, buf: [*]const u8) callconv(cc) Status,
    _get_position: *const fn (*const File, pos: *u64) callconv(cc) Status,
    _set_position: *const fn (*const File, pos: u64) callconv(cc) Status,
    _get_info: *const fn (*const File, info: *align(8) const Guid, buf_size: *const usize, buf: ?[*]u8) callconv(cc) Status,
    _set_info: *const fn (*const File, info: *align(8) const Guid, buf_size: usize, buf: [*]const u8) callconv(cc) Status,
    _flush: *const fn (*const File) callconv(cc) Status,

    pub const SeekError = Status.EfiError;
    pub const GetSeekPosError = Status.EfiError;
    pub const ReadError = Status.EfiError;
    pub const WriteError = Status.EfiError;

    pub const SeekableStream = io.SeekableStream(*const File, SeekError, GetSeekPosError, setPosition, movePosition, getPosition, getEndPosition);
    pub const Reader = io.Reader(*const File, ReadError, read);
    pub const Writer = io.Writer(*const File, WriteError, write);

    pub fn seekableStream(self: *File) SeekableStream {
        return .{ .context = self };
    }

    pub fn reader(self: *File) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *File) Writer {
        return .{ .context = self };
    }

    pub const OpenMode = packed struct(u64) {
        read: bool = true,

        /// May only be specified if `read` is true.
        write: bool = false,

        _pad: u61 = 0,

        /// May only be specified if `write` is true.
        create: bool = false,
    };

    /// Opens a new file relative to the source file's location.
    pub fn open(
        self: *const File,
        /// The Null-terminated string of the name of the file to be opened. The file name may contain the following
        /// path modifiers: "\", ".", and "..".
        file_name: [:0]const u16,
        /// The mode to open the file with.
        open_mode: OpenMode,
        /// The attributes for a newly created file.
        attributes: bits.FileInfo.Attributes,
    ) !*const File {
        var new_handle: *const File = undefined;
        try self._open(self, &new_handle, file_name.ptr, open_mode, attributes).err();
        return new_handle;
    }

    /// Closes a specified file handle.
    pub fn close(self: *const File) void {
        _ = self._close(self);
    }

    /// Closes and deletes a file. This can fail, but the descriptor will still be closed.
    ///
    /// Returns `true` if the file was successfully deleted, `false` otherwise.
    pub fn delete(self: *const File) bool {
        return self._delete(self) == .success;
    }

    /// Reads data from a file.
    pub fn read(self: *const File, buffer: []u8) ReadError!usize {
        var size: usize = buffer.len;
        try self._read(self, &size, buffer.ptr).err();
        return size;
    }

    /// Writes data to a file.
    pub fn write(self: *const File, buffer: []const u8) WriteError!usize {
        var size: usize = buffer.len;
        try self._write(self, &size, buffer.ptr).err();
        return size;
    }

    /// Returns a file’s current position.
    pub fn getPosition(self: *const File) GetSeekPosError!u64 {
        var position: u64 = 0;
        try self._get_position(self, &position).err();
        return position;
    }

    /// Returns a file’s end position.
    pub fn getEndPosition(self: *const File) GetSeekPosError!u64 {
        // preserve the old file position
        const position = try self.getPosition();

        // seek to the end of the file
        try self.setPosition(position_end_of_file);
        const end_pos = try self.getPosition();

        // restore the old position
        try self.setPosition(position);

        return end_pos;
    }

    /// Sets a file’s current position. This is allowed to move past the end of the file. A subsequent write will extend
    /// the file.
    pub fn setPosition(self: *const File, position: u64) !void {
        try self._set_position(self, position).err();
    }

    /// Moves the file pointer by the specified offset.
    pub fn movePosition(self: *const File, offset: i64) SeekError!void {
        var position = try self.getPosition();

        const seek_back = offset < 0;
        const amt = @abs(offset);
        if (seek_back) {
            position += amt;
        } else {
            position -= amt;
        }

        try self.setPosition(position);
    }

    /// Returns the buffer size required to hold the information of the specified type.
    ///
    /// `Information` must be one of: `FileInfo` or `FileSystemInfo` or `FileSystemVolumeLabel`.
    pub fn getInfoSize(
        self: *const File,
        comptime Information: type,
    ) !usize {
        var buffer_size: usize = 0;
        self._get_info(self, &Information.guid, &buffer_size, null).err() catch |err| switch (err) {
            error.BufferTooSmall => {},
            else => |e| return e,
        };
        return buffer_size;
    }

    /// Returns information about a file.
    ///
    /// `Information` must be one of: `FileInfo` or `FileSystemInfo` or `FileSystemVolumeLabel`.
    pub fn getInfo(
        self: *const File,
        comptime Information: type,
        buffer: []align(@alignOf(Information)) u8,
    ) !*Information {
        var size: usize = buffer.len;
        try self._get_info(self, &Information.guid, &size, buffer.ptr).err();
        return @ptrCast(buffer.ptr);
    }

    /// Sets information about a file.
    pub fn setInfo(
        self: *const File,
        comptime Information: type,
        buffer: []align(@alignOf(Information)) u8,
    ) !void {
        try self._set_info(self, &Information.guid, buffer.len, buffer.ptr).err();
    }

    /// Flushes all modified data associated with a file to a device.
    pub fn flush(self: *const File) !void {
        try self._flush(self).err();
    }

    /// A special location that will move the file pointer to the end of the file.
    pub const position_end_of_file: u64 = 0xffffffffffffffff;
};
