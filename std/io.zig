const std = @import("index.zig");
const builtin = @import("builtin");
const Os = builtin.Os;
const c = std.c;

const math = std.math;
const debug = std.debug;
const assert = debug.assert;
const os = std.os;
const mem = std.mem;
const Buffer = std.Buffer;
const fmt = std.fmt;
const File = std.os.File;

const is_posix = builtin.os != builtin.Os.windows;
const is_windows = builtin.os == builtin.Os.windows;

const GetStdIoErrs = os.WindowsGetStdHandleErrs;

pub fn getStdErr() GetStdIoErrs!File {
    const handle = if (is_windows) try os.windowsGetStdHandle(os.windows.STD_ERROR_HANDLE) else if (is_posix) os.posix.STDERR_FILENO else unreachable;
    return File.openHandle(handle);
}

pub fn getStdOut() GetStdIoErrs!File {
    const handle = if (is_windows) try os.windowsGetStdHandle(os.windows.STD_OUTPUT_HANDLE) else if (is_posix) os.posix.STDOUT_FILENO else unreachable;
    return File.openHandle(handle);
}

pub fn getStdIn() GetStdIoErrs!File {
    const handle = if (is_windows) try os.windowsGetStdHandle(os.windows.STD_INPUT_HANDLE) else if (is_posix) os.posix.STDIN_FILENO else unreachable;
    return File.openHandle(handle);
}

/// Implementation of InStream trait for File
pub const FileInStream = struct {
    file: *File,
    stream: Stream,

    pub const Error = @typeOf(File.read).ReturnType.ErrorSet;
    pub const Stream = InStream(Error);

    pub fn init(file: *File) FileInStream {
        return FileInStream{
            .file = file,
            .stream = Stream{ .readFn = readFn },
        };
    }

    fn readFn(in_stream: *Stream, buffer: []u8) Error!usize {
        const self = @fieldParentPtr(FileInStream, "stream", in_stream);
        return self.file.read(buffer);
    }
};

/// Implementation of OutStream trait for File
pub const FileOutStream = struct {
    file: *File,
    stream: Stream,

    pub const Error = File.WriteError;
    pub const Stream = OutStream(Error);

    pub fn init(file: *File) FileOutStream {
        return FileOutStream{
            .file = file,
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    fn writeFn(out_stream: *Stream, bytes: []const u8) !void {
        const self = @fieldParentPtr(FileOutStream, "stream", out_stream);
        return self.file.write(bytes);
    }
};

pub fn InStream(comptime ReadError: type) type {
    return struct {
        const Self = this;
        pub const Error = ReadError;

        /// Return the number of bytes read. If the number read is smaller than buf.len, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        readFn: fn (self: *Self, buffer: []u8) Error!usize,

        /// Replaces `buffer` contents by reading from the stream until it is finished.
        /// If `buffer.len()` would exceed `max_size`, `error.StreamTooLong` is returned and
        /// the contents read from the stream are lost.
        pub fn readAllBuffer(self: *Self, buffer: *Buffer, max_size: usize) !void {
            try buffer.resize(0);

            var actual_buf_len: usize = 0;
            while (true) {
                const dest_slice = buffer.toSlice()[actual_buf_len..];
                const bytes_read = try self.readFn(self, dest_slice);
                actual_buf_len += bytes_read;

                if (bytes_read != dest_slice.len) {
                    buffer.shrink(actual_buf_len);
                    return;
                }

                const new_buf_size = math.min(max_size, actual_buf_len + os.page_size);
                if (new_buf_size == actual_buf_len) return error.StreamTooLong;
                try buffer.resize(new_buf_size);
            }
        }

        /// Allocates enough memory to hold all the contents of the stream. If the allocated
        /// memory would be greater than `max_size`, returns `error.StreamTooLong`.
        /// Caller owns returned memory.
        /// If this function returns an error, the contents from the stream read so far are lost.
        pub fn readAllAlloc(self: *Self, allocator: *mem.Allocator, max_size: usize) ![]u8 {
            var buf = Buffer.initNull(allocator);
            defer buf.deinit();

            try self.readAllBuffer(&buf, max_size);
            return buf.toOwnedSlice();
        }

        /// Replaces `buffer` contents by reading from the stream until `delimiter` is found.
        /// Does not include the delimiter in the result.
        /// If `buffer.len()` would exceed `max_size`, `error.StreamTooLong` is returned and the contents
        /// read from the stream so far are lost.
        pub fn readUntilDelimiterBuffer(self: *Self, buffer: *Buffer, delimiter: u8, max_size: usize) !void {
            try buffer.resize(0);

            while (true) {
                var byte: u8 = try self.readByte();

                if (byte == delimiter) {
                    return;
                }

                if (buffer.len() == max_size) {
                    return error.StreamTooLong;
                }

                try buffer.appendByte(byte);
            }
        }

        /// Allocates enough memory to read until `delimiter`. If the allocated
        /// memory would be greater than `max_size`, returns `error.StreamTooLong`.
        /// Caller owns returned memory.
        /// If this function returns an error, the contents from the stream read so far are lost.
        pub fn readUntilDelimiterAlloc(self: *Self, allocator: *mem.Allocator, delimiter: u8, max_size: usize) ![]u8 {
            var buf = Buffer.initNull(allocator);
            defer buf.deinit();

            try self.readUntilDelimiterBuffer(&buf, delimiter, max_size);
            return buf.toOwnedSlice();
        }

        /// Returns the number of bytes read. If the number read is smaller than buf.len, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        pub fn read(self: *Self, buffer: []u8) !usize {
            return self.readFn(self, buffer);
        }

        /// Same as `read` but end of stream returns `error.EndOfStream`.
        pub fn readNoEof(self: *Self, buf: []u8) !void {
            const amt_read = try self.read(buf);
            if (amt_read < buf.len) return error.EndOfStream;
        }

        /// Reads 1 byte from the stream or returns `error.EndOfStream`.
        pub fn readByte(self: *Self) !u8 {
            var result: [1]u8 = undefined;
            try self.readNoEof(result[0..]);
            return result[0];
        }

        /// Same as `readByte` except the returned byte is signed.
        pub fn readByteSigned(self: *Self) !i8 {
            return @bitCast(i8, try self.readByte());
        }

        pub fn readIntLe(self: *Self, comptime T: type) !T {
            return self.readInt(builtin.Endian.Little, T);
        }

        pub fn readIntBe(self: *Self, comptime T: type) !T {
            return self.readInt(builtin.Endian.Big, T);
        }

        pub fn readInt(self: *Self, endian: builtin.Endian, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readInt(bytes, T, endian);
        }

        pub fn readVarInt(self: *Self, endian: builtin.Endian, comptime T: type, size: usize) !T {
            assert(size <= @sizeOf(T));
            assert(size <= 8);
            var input_buf: [8]u8 = undefined;
            const input_slice = input_buf[0..size];
            try self.readNoEof(input_slice);
            return mem.readInt(input_slice, T, endian);
        }
    };
}

pub fn OutStream(comptime WriteError: type) type {
    return struct {
        const Self = this;
        pub const Error = WriteError;

        writeFn: fn (self: *Self, bytes: []const u8) Error!void,

        pub fn print(self: *Self, comptime format: []const u8, args: ...) !void {
            return std.fmt.format(self, Error, self.writeFn, format, args);
        }

        pub fn write(self: *Self, bytes: []const u8) !void {
            return self.writeFn(self, bytes);
        }

        pub fn writeByte(self: *Self, byte: u8) !void {
            const slice = (*[1]u8)(&byte)[0..];
            return self.writeFn(self, slice);
        }

        pub fn writeByteNTimes(self: *Self, byte: u8, n: usize) !void {
            const slice = (*[1]u8)(&byte)[0..];
            var i: usize = 0;
            while (i < n) : (i += 1) {
                try self.writeFn(self, slice);
            }
        }
    };
}

/// `path` needs to be copied in memory to add a null terminating byte, hence the allocator.
pub fn writeFile(allocator: *mem.Allocator, path: []const u8, data: []const u8) !void {
    var file = try File.openWrite(allocator, path);
    defer file.close();
    try file.write(data);
}

/// On success, caller owns returned buffer.
pub fn readFileAlloc(allocator: *mem.Allocator, path: []const u8) ![]u8 {
    return readFileAllocAligned(allocator, path, @alignOf(u8));
}

/// On success, caller owns returned buffer.
pub fn readFileAllocAligned(allocator: *mem.Allocator, path: []const u8, comptime A: u29) ![]align(A) u8 {
    var file = try File.openRead(allocator, path);
    defer file.close();

    const size = try file.getEndPos();
    const buf = try allocator.alignedAlloc(u8, A, size);
    errdefer allocator.free(buf);

    var adapter = FileInStream.init(&file);
    try adapter.stream.readNoEof(buf[0..size]);
    return buf;
}

pub fn BufferedInStream(comptime Error: type) type {
    return BufferedInStreamCustom(os.page_size, Error);
}

pub fn BufferedInStreamCustom(comptime buffer_size: usize, comptime Error: type) type {
    return struct {
        const Self = this;
        const Stream = InStream(Error);

        pub stream: Stream,

        unbuffered_in_stream: *Stream,

        buffer: [buffer_size]u8,
        start_index: usize,
        end_index: usize,

        pub fn init(unbuffered_in_stream: *Stream) Self {
            return Self{
                .unbuffered_in_stream = unbuffered_in_stream,
                .buffer = undefined,

                // Initialize these two fields to buffer_size so that
                // in `readFn` we treat the state as being able to read
                // more from the unbuffered stream. If we set them to 0
                // and 0, the code would think we already hit EOF.
                .start_index = buffer_size,
                .end_index = buffer_size,

                .stream = Stream{ .readFn = readFn },
            };
        }

        fn readFn(in_stream: *Stream, dest: []u8) !usize {
            const self = @fieldParentPtr(Self, "stream", in_stream);

            var dest_index: usize = 0;
            while (true) {
                const dest_space = dest.len - dest_index;
                if (dest_space == 0) {
                    return dest_index;
                }
                const amt_buffered = self.end_index - self.start_index;
                if (amt_buffered == 0) {
                    assert(self.end_index <= buffer_size);
                    if (self.end_index == buffer_size) {
                        // we can read more data from the unbuffered stream
                        if (dest_space < buffer_size) {
                            self.start_index = 0;
                            self.end_index = try self.unbuffered_in_stream.read(self.buffer[0..]);
                        } else {
                            // asking for so much data that buffering is actually less efficient.
                            // forward the request directly to the unbuffered stream
                            const amt_read = try self.unbuffered_in_stream.read(dest[dest_index..]);
                            return dest_index + amt_read;
                        }
                    } else {
                        // reading from the unbuffered stream returned less than we asked for
                        // so we cannot read any more data.
                        return dest_index;
                    }
                }
                const copy_amount = math.min(dest_space, amt_buffered);
                const copy_end_index = self.start_index + copy_amount;
                mem.copy(u8, dest[dest_index..], self.buffer[self.start_index..copy_end_index]);
                self.start_index = copy_end_index;
                dest_index += copy_amount;
            }
        }
    };
}

pub fn BufferedOutStream(comptime Error: type) type {
    return BufferedOutStreamCustom(os.page_size, Error);
}

pub fn BufferedOutStreamCustom(comptime buffer_size: usize, comptime OutStreamError: type) type {
    return struct {
        const Self = this;
        pub const Stream = OutStream(Error);
        pub const Error = OutStreamError;

        pub stream: Stream,

        unbuffered_out_stream: *Stream,

        buffer: [buffer_size]u8,
        index: usize,

        pub fn init(unbuffered_out_stream: *Stream) Self {
            return Self{
                .unbuffered_out_stream = unbuffered_out_stream,
                .buffer = undefined,
                .index = 0,
                .stream = Stream{ .writeFn = writeFn },
            };
        }

        pub fn flush(self: *Self) !void {
            try self.unbuffered_out_stream.write(self.buffer[0..self.index]);
            self.index = 0;
        }

        fn writeFn(out_stream: *Stream, bytes: []const u8) !void {
            const self = @fieldParentPtr(Self, "stream", out_stream);

            if (bytes.len >= self.buffer.len) {
                try self.flush();
                return self.unbuffered_out_stream.write(bytes);
            }
            var src_index: usize = 0;

            while (src_index < bytes.len) {
                const dest_space_left = self.buffer.len - self.index;
                const copy_amt = math.min(dest_space_left, bytes.len - src_index);
                mem.copy(u8, self.buffer[self.index..], bytes[src_index .. src_index + copy_amt]);
                self.index += copy_amt;
                assert(self.index <= self.buffer.len);
                if (self.index == self.buffer.len) {
                    try self.flush();
                }
                src_index += copy_amt;
            }
        }
    };
}

/// Implementation of OutStream trait for Buffer
pub const BufferOutStream = struct {
    buffer: *Buffer,
    stream: Stream,

    pub const Error = error{OutOfMemory};
    pub const Stream = OutStream(Error);

    pub fn init(buffer: *Buffer) BufferOutStream {
        return BufferOutStream{
            .buffer = buffer,
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    fn writeFn(out_stream: *Stream, bytes: []const u8) !void {
        const self = @fieldParentPtr(BufferOutStream, "stream", out_stream);
        return self.buffer.append(bytes);
    }
};

pub const BufferedAtomicFile = struct {
    atomic_file: os.AtomicFile,
    file_stream: FileOutStream,
    buffered_stream: BufferedOutStream(FileOutStream.Error),

    pub fn create(allocator: *mem.Allocator, dest_path: []const u8) !*BufferedAtomicFile {
        // TODO with well defined copy elision we don't need this allocation
        var self = try allocator.create(BufferedAtomicFile{
            .atomic_file = undefined,
            .file_stream = undefined,
            .buffered_stream = undefined,
        });
        errdefer allocator.destroy(self);

        self.atomic_file = try os.AtomicFile.init(allocator, dest_path, os.default_file_mode);
        errdefer self.atomic_file.deinit();

        self.file_stream = FileOutStream.init(&self.atomic_file.file);
        self.buffered_stream = BufferedOutStream(FileOutStream.Error).init(&self.file_stream.stream);
        return self;
    }

    /// always call destroy, even after successful finish()
    pub fn destroy(self: *BufferedAtomicFile) void {
        const allocator = self.atomic_file.allocator;
        self.atomic_file.deinit();
        allocator.destroy(self);
    }

    pub fn finish(self: *BufferedAtomicFile) !void {
        try self.buffered_stream.flush();
        try self.atomic_file.finish();
    }

    pub fn stream(self: *BufferedAtomicFile) *OutStream(FileOutStream.Error) {
        return &self.buffered_stream.stream;
    }
};

test "import io tests" {
    comptime {
        _ = @import("io_test.zig");
    }
}

pub fn readLine(buf: []u8) !usize {
    var stdin = getStdIn() catch return error.StdInUnavailable;
    var adapter = FileInStream.init(&stdin);
    var stream = &adapter.stream;
    var index: usize = 0;
    while (true) {
        const byte = stream.readByte() catch return error.EndOfFile;
        switch (byte) {
            '\r' => {
                // trash the following \n
                _ = stream.readByte() catch return error.EndOfFile;
                return index;
            },
            '\n' => return index,
            else => {
                if (index == buf.len) return error.InputTooLong;
                buf[index] = byte;
                index += 1;
            },
        }
    }
}
