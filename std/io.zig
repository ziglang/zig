const std = @import("index.zig");
const builtin = @import("builtin");
const Os = builtin.Os;
const c = std.c;

const math = std.math;
const debug = std.debug;
const assert = debug.assert;
const os = std.os;
const mem = std.mem;
const meta = std.meta;
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

pub fn InStreamError(comptime T: type) type {
    const I = if(meta.trait.isSingleItemPtr(T)) comptime meta.Child(T) else T;
    return @typeOf(I.read).ReturnType.ErrorSet;
}

pub fn OutStreamError(comptime T: type) type {
    const I = if(meta.trait.isSingleItemPtr(T)) comptime meta.Child(T) else T;
    return @typeOf(I.write).ReturnType.ErrorSet;
}

pub const SeekableStream = @import("io/seekable_stream.zig").SeekableStream;
pub const AbstractSeekableStream = @import("io/seekable_stream.zig").AbstractSeekableStream;
pub const SeekableStreamInterface = @import("io/seekable_stream.zig").SeekableStreamInterface;

pub const InStream = InStreamInterface(AbstractInStream);

pub fn InStreamInterface(comptime I: type) type {
    return struct {
        const Self = @This();
        
        impl: I,
        
        pub fn init(impl: I) Self {
            return Self {
                .impl = impl,
            };
        }
        
        //@WIP: We need to make this more generally available and make stream-wrappers
        // directly wrap the stream instead of the interface
        //pub const Error = err: {
        //    if(comptime !std.meta.trait.isSingleItemPtr(I)) {
        //        break :err @typeOf(I.read).ReturnType.ErrorSet;
        //    }
        //    break :err @typeOf(comptime meta.Child(I).read).ReturnType.ErrorSet;
        //};
        
        pub const Error = InStreamError(I);

        /// Replaces `buffer` contents by reading from the stream until it is finished.
        /// If `buffer.len()` would exceed `max_size`, `error.StreamTooLong` is returned and
        /// the contents read from the stream are lost.
        pub fn readAllBuffer(self: Self, buffer: *Buffer, max_size: usize) !void {
            try buffer.resize(0);

            var actual_buf_len: usize = 0;
            while (true) {
                const dest_slice = buffer.toSlice()[actual_buf_len..];
                const bytes_read = try self.readFull(dest_slice);
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
        pub fn readAllAlloc(self: Self, allocator: mem.Allocator, max_size: usize) ![]u8 {
            var buf = Buffer.initNull(allocator);
            defer buf.deinit();

            try self.readAllBuffer(&buf, max_size);
            return buf.toOwnedSlice();
        }

        /// Replaces `buffer` contents by reading from the stream until `delimiter` is found.
        /// Does not include the delimiter in the result.
        /// If `buffer.len()` would exceed `max_size`, `error.StreamTooLong` is returned and the contents
        /// read from the stream so far are lost.
        pub fn readUntilDelimiterBuffer(self: Self, buffer: *Buffer, delimiter: u8, max_size: usize) !void {
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
        pub fn readUntilDelimiterAlloc(self: Self, allocator: mem.Allocator, delimiter: u8, max_size: usize) ![]u8 {
            var buf = Buffer.initNull(allocator);
            defer buf.deinit();

            try self.readUntilDelimiterBuffer(&buf, delimiter, max_size);
            return buf.toOwnedSlice();
        }

        /// Returns the number of bytes read. It may be less than buffer.len.
        /// If the number of bytes read is 0, it means end of stream.
        /// End of stream is not an error condition.
        pub fn read(self: Self, buffer: []u8) Error!usize {
            return self.impl.read(buffer);
        }

        /// Returns the number of bytes read. If the number read is smaller than buf.len, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        pub fn readFull(self: Self, buffer: []u8) !usize {
            var index: usize = 0;
            while (index != buffer.len) {
                const amt = try self.read(buffer[index..]);
                if (amt == 0) return index;
                index += amt;
            }
            return index;
        }

        /// Same as `readFull` but end of stream returns `error.EndOfStream`.
        pub fn readNoEof(self: Self, buf: []u8) !void {
            const amt_read = try self.read(buf);
            if (amt_read < buf.len) return error.EndOfStream;
        }

        /// Reads 1 byte from the stream or returns `error.EndOfStream`.
        pub fn readByte(self: Self) !u8 {
            var result: [1]u8 = undefined;
            try self.readNoEof(result[0..]);
            return result[0];
        }

        /// Same as `readByte` except the returned byte is signed.
        pub fn readByteSigned(self: Self) !i8 {
            return @bitCast(i8, try self.readByte());
        }

        /// Reads a native-endian integer
        pub fn readIntNative(self: Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readIntNative(T, &bytes);
        }

        /// Reads a foreign-endian integer
        pub fn readIntForeign(self: Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readIntForeign(T, &bytes);
        }

        pub fn readIntLittle(self: Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readIntLittle(T, &bytes);
        }

        pub fn readIntBig(self: Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readIntBig(T, &bytes);
        }

        pub fn readInt(self: Self, comptime T: type, endian: builtin.Endian) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readInt(T, &bytes, endian);
        }

        pub fn readVarInt(self: Self, comptime ReturnType: type, endian: builtin.Endian, size: usize) !ReturnType {
            assert(size <= @sizeOf(ReturnType));
            var bytes_buf: [@sizeOf(ReturnType)]u8 = undefined;
            const bytes = bytes_buf[0..size];
            try self.readNoEof(bytes);
            return mem.readVarInt(ReturnType, bytes, endian);
        }

        pub fn skipBytes(self: Self, num_bytes: usize) !void {
            var i: usize = 0;
            while (i < num_bytes) : (i += 1) {
                _ = try self.readByte();
            }
        }

        pub fn readStruct(self: Self, comptime T: type) !T {
            // Only extern and packed structs have defined in-memory layout.
            comptime assert(@typeInfo(T).Struct.layout != builtin.TypeInfo.ContainerLayout.Auto);
            var res: [1]T = undefined;
            try self.readNoEof(@sliceToBytes(res[0..]));
            return res[0];
        }
    };
}

pub const AbstractInStream = struct {
    pub const Context = *@OpaqueType();
    
    const VTable = struct {
        /// Return the number of bytes read. If the number read is smaller than buf.len, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        read: fn (self: Context, buffer: []u8) anyerror!usize,
    };

    vtable: *const VTable,
    impl: Context,
    
    pub const Error = anyerror;

    pub fn init(impl: var) AbstractInStream {
        const T = comptime std.meta.Child(@typeOf(impl));
        return AbstractInStream{
            .vtable = comptime std.vtable.populate(VTable, T, T),
            .impl = @ptrCast(Context, impl),
        };
    }
    
    pub fn read(self: AbstractInStream, buffer: []u8) Error!usize {
        return self.vtable.read(self.impl, buffer);
    }

    pub fn inStreamInterface(self: AbstractInStream) InStream {
        return InStreamInterface(AbstractInStream).init(self);
    }
    
    pub fn inStream(self: AbstractInStream) InStream {
        return self.inStreamInterface();
    }
};


pub const OutStream = OutStreamInterface(AbstractOutStream);

pub fn OutStreamInterface(comptime I: type) type {
    return struct {
        const Self = @This();
        
        impl: I,
        
        //pub const Error = err: {
        //    if(comptime !std.meta.trait.isSingleItemPtr(I)) {
        //        break :err @typeOf(I.write).ReturnType.ErrorSet;
        //    }
        //    break :err @typeOf(comptime meta.Child(I).write).ReturnType.ErrorSet;
        //};
        
       pub const Error = OutStreamError(I);
        
        pub fn init(impl: I) Self {
            return Self {
                .impl = impl,
            };
        }

        pub fn print(self: Self, comptime format: []const u8, args: ...) !void {
            return std.fmt.format(self, Error, write, format, args);
        }

        pub fn write(self: Self, bytes: []const u8) Error!void {
            return self.impl.write(bytes);
        }

        pub fn writeByte(self: Self, byte: u8) !void {
            const slice = (*[1]u8)(&byte)[0..];
            return self.impl.write(slice);
        }

        pub fn writeByteNTimes(self: Self, byte: u8, n: usize) Error!void {
            const slice = (*[1]u8)(&byte)[0..];
            var i: usize = 0;
            while (i < n) : (i += 1) {
                try self.impl.write(slice);
            }
        }

        /// Write a native-endian integer.
        pub fn writeIntNative(self: Self, comptime T: type, value: T) !void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeIntNative(T, &bytes, value);
            return self.impl.write(bytes);
        }

        /// Write a foreign-endian integer.
        pub fn writeIntForeign(self: Self, comptime T: type, value: T) !void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeIntForeign(T, &bytes, value);
            return self.impl.write(bytes);
        }

        pub fn writeIntLittle(self: Self, comptime T: type, value: T) !void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeIntLittle(T, &bytes, value);
            return self.impl.write(bytes);
        }

        pub fn writeIntBig(self: Self, comptime T: type, value: T) !void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeIntBig(T, &bytes, value);
            return self.impl.write(bytes);
        }

        pub fn writeInt(self: Self, comptime T: type, value: T, endian: builtin.Endian) !void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeInt(T, &bytes, value, endian);
            return self.impl.write(bytes);
        }
    };
}

pub const AbstractOutStream = struct {
    pub const Context = *@OpaqueType();
    
    const VTable = struct {
        /// Return the number of bytes read. If the number read is smaller than buf.len, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        write: fn (self: Context, bytes: []const u8) anyerror!void,
    };

    vtable: *const VTable,
    impl: Context,
    
    pub const Error = anyerror;

    pub fn init(impl: var) AbstractOutStream {
        const T = comptime std.meta.Child(@typeOf(impl));
        return AbstractInStream{
            .vtable = comptime std.vtable.populate(VTable, T, T),
            .impl = @ptrCast(Context, impl),
        };
    }
    
    pub fn write(self: AbstractOutStream, bytes: []const u8) Error!void {
        return self.vtable.write(self.impl, bytes);
    }

    pub fn outStreamInterface(self: AbstractOutStream) OutStream {
        return OutStreamInterface(AbstractOutStream).init(self);
    }
    
    pub fn outStream(self: AbstractOutStream) OutStream {
        return self.outStreamInterface();
    }
};

pub fn writeFile(path: []const u8, data: []const u8) !void {
    var file = try File.openWrite(path);
    defer file.close();
    try file.write(data);
}

/// On success, caller owns returned buffer.
pub fn readFileAlloc(allocator: mem.Allocator, path: []const u8) ![]u8 {
    return readFileAllocAligned(allocator, path, @alignOf(u8));
}

/// On success, caller owns returned buffer.
pub fn readFileAllocAligned(allocator: mem.Allocator, path: []const u8, comptime A: u29) ![]align(A) u8 {
    var file = try File.openRead(path);
    defer file.close();

    const size = try file.getEndPos();
    const buf = try allocator.alignedAlloc(u8, A, size);
    errdefer allocator.free(buf);

    var adapter = file.inStreamInterface();
    try adapter.readNoEof(buf[0..size]);
    return buf;
}

pub fn BufferedInStream(comptime Stream: type) type {
    return BufferedInStreamCustom(os.page_size, Stream);
}

pub fn BufferedInStreamCustom(comptime buffer_size: usize, comptime Stream: type) type {
    return struct {
        const Self = @This();

        unbuffered_in_stream: Stream,

        buffer: [buffer_size]u8,
        start_index: usize,
        end_index: usize,
        
        pub const Error = InStreamError(Stream);

        pub fn init(unbuffered_in_stream: Stream) Self {
            return Self{
                .unbuffered_in_stream = unbuffered_in_stream,
                .buffer = undefined,

                // Initialize these two fields to buffer_size so that
                // in `readFn` we treat the state as being able to read
                // more from the unbuffered stream. If we set them to 0
                // and 0, the code would think we already hit EOF.
                .start_index = buffer_size,
                .end_index = buffer_size,
            };
        }

        pub fn read(self: *Self, dest: []u8) Error!usize {
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
        
        pub fn inStreamInterface(self: *Self) InStreamInterface(*Self) {
            return InStreamInterface(*Self).init(self);
        }
        
        pub fn inStream(self: *Self) InStream {
            return InStream.init(self);
        }
    };
}

/// Creates a stream which supports 'un-reading' data, so that it can be read again.
/// This makes look-ahead style parsing much easier.
pub fn PeekStream(comptime buffer_size: usize, comptime Stream: type) type {
    return struct {
        const Self = @This();

        base: Stream,

        // Right now the look-ahead space is statically allocated, but a version with dynamic allocation
        // is not too difficult to derive from this.
        buffer: [buffer_size]u8,
        index: usize,
        at_end: bool,

        pub const Error = InStreamError(Stream);
        
        pub fn init(base: Stream) Self {
            return Self{
                .base = base,
                .buffer = undefined,
                .index = 0,
                .at_end = false,
            };
        }

        pub fn putBackByte(self: *Self, byte: u8) void {
            self.buffer[self.index] = byte;
            self.index += 1;
        }

        pub fn putBack(self: *Self, bytes: []const u8) void {
            var pos = bytes.len;
            while (pos != 0) {
                pos -= 1;
                self.putBackByte(bytes[pos]);
            }
        }
        
        pub fn read(self: *Self, dest: []u8) Stream.Error!usize {
            // copy over anything putBack()'d
            var pos: usize = 0;
            while (pos < dest.len and self.index != 0) {
                dest[pos] = self.buffer[self.index - 1];
                self.index -= 1;
                pos += 1;
            }

            if (pos == dest.len or self.at_end) {
                return pos;
            }

            // ask the backing stream for more
            const left = dest.len - pos;
            const bytes_read = try self.base.read(dest[pos..]);
            assert(bytes_read <= left);

            self.at_end = (bytes_read < left);
            return pos + bytes_read;
        }
        
        pub fn inStreamInterface(self: *Self) InStreamInterface(*Self) {
            return InStreamInterface(*Self).init(self);
        }
        
        pub fn inStream(self: *Self) InStream {
            return InStream.init(self);
        }
    };
}

pub const SliceInStream = struct {
    const Self = @This();
    
    pos: usize,
    slice: []const u8,

    pub const Error = error{};
    
    pub fn init(slice: []const u8) Self {
        return Self{
            .slice = slice,
            .pos = 0,
        };
    }

    fn read(self: *Self, dest: []u8) Error!usize {
        const size = math.min(dest.len, self.slice.len - self.pos);
        const end = self.pos + size;

        mem.copy(u8, dest[0..size], self.slice[self.pos..end]);
        self.pos = end;

        return size;
    }
    
    pub fn inStreamInterface(self: *Self) InStreamInterface(*Self) {
        return InStreamInterface(*Self).init(self);
    }
    
    pub fn inStream(self: *Self) InStream {
        return InStream.init(self);
    }
};

/// This is a simple OutStream that writes to a slice, and returns an error
/// when it runs out of space.
pub const SliceOutStream = struct {
    pub pos: usize,
    slice: []u8,
    
    pub const Error = error{OutOfSpace};
    
    pub fn init(slice: []u8) SliceOutStream {
        return SliceOutStream{
            .slice = slice,
            .pos = 0,
        };
    }

    pub fn getWritten(self: *const SliceOutStream) []const u8 {
        return self.slice[0..self.pos];
    }

    pub fn reset(self: *SliceOutStream) void {
        self.pos = 0;
    }

    fn write(self: *SliceOutStream, bytes: []const u8) Error!void {
        assert(self.pos <= self.slice.len);

        const n = if (self.pos + bytes.len <= self.slice.len)
            bytes.len
        else
            self.slice.len - self.pos;

        std.mem.copy(u8, self.slice[self.pos .. self.pos + n], bytes[0..n]);
        self.pos += n;

        if (n < bytes.len) {
            return error.OutOfSpace;
        }
    }
    
    pub fn outStreamInterface(self: *SliceOutStream) OutStreamInterface(*SliceOutStream) {
        return OutStreamInterface(*SliceOutStream).init(self);
    }
    
    pub fn outStream(self: *SliceOutStream) OutStream {
        return OutStream.init(self);
    }
};

test "io.SliceOutStream" {
    var buf: [255]u8 = undefined;
    var slice_stream = SliceOutStream.init(buf[0..]);
    const stream = slice_stream.outStreamInterface();

    try stream.print("{}{}!", "Hello", "World");
    debug.assert(mem.eql(u8, "HelloWorld!", slice_stream.getWritten()));
}

pub const null_out_stream = NullOutStream.init().outStreamInterface();

/// An OutStream that doesn't write to anything.
pub const NullOutStream = struct {
    pub const Error = error{};

    pub fn init() NullOutStream {
        return NullOutStream{
        };
    }

    pub fn write(self: NullOutStream, bytes: []const u8) Error!void {}
    
    pub fn outStreamInterface(self: NullOutStream) OutStreamInterface(NullOutStream) {
        return OutStreamInterface(NullOutStream).init(self);
    }
    
    pub fn outStream(self: NullOutStream) OutStream {
        return OutStream.init(AbstractOutStream.init(self));
    }
};

test "io.NullOutStream" {
    var null_stream = NullOutStream.init();
    const stream = null_stream.outStreamInterface();
    stream.write("yay" ** 10000) catch unreachable;
}

/// An OutStream that counts how many bytes has been written to it.
pub fn CountingOutStream(comptime Stream: type) type {
    return struct {
        const Self = @This();
        
        pub bytes_written: usize,
        child_stream: Stream,

        pub const Error = OutStreamError(Stream);
        
        pub fn init(child_stream: Stream) Self {
            return Self{
                .bytes_written = 0,
                .child_stream = child_stream,
            };
        }
        
        pub fn write(self: *Self, bytes: []const u8) Error!void {
            try self.child_stream.write(bytes);
            self.bytes_written += bytes.len;
        }
        
        pub fn outStreamInterface(self: *Self) OutStreamInterface(*Self) {
            return OutStreamInterface(*Self).init(self);
        }
        
        pub fn outStream(self: *Self) OutStream {
            return OutStream.init(AbstractOutStream.init(self));
        }
    };
}

test "io.CountingOutStream" {
    var null_stream = NullOutStream.init();
    var counting_stream = CountingOutStream(NullOutStream).init(null_stream);
    const stream = counting_stream.outStreamInterface();

    const bytes = "yay" ** 10000;
    stream.write(bytes) catch unreachable;
    debug.assert(counting_stream.bytes_written == bytes.len);
}

pub fn BufferedOutStream(comptime Stream: type) type {
    return BufferedOutStreamCustom(os.page_size, Stream);
}

pub fn BufferedOutStreamCustom(comptime buffer_size: usize, comptime Stream: type) type {
    return struct {
        const Self = @This();

        unbuffered_out_stream: Stream,

        buffer: [buffer_size]u8,
        index: usize,

        pub const Error = OutStreamError(Stream);
        
        pub fn init(unbuffered_out_stream: Stream) Self {
            return Self{
                .unbuffered_out_stream = unbuffered_out_stream,
                .buffer = undefined,
                .index = 0,
            };
        }

        pub fn flush(self: *Self) !void {
            try self.unbuffered_out_stream.write(self.buffer[0..self.index]);
            self.index = 0;
        }

        pub fn write(self: *Self, bytes: []const u8) Error!void {
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
        
        pub fn outStreamInterface(self: *Self) OutStreamInterface(*Self) {
            return OutStreamInterface(*Self).init(self);
        }
        
        pub fn outStream(self: *Self) OutStream {
            return OutStream.init(AbstractOutStream.init(self));
        }
    };
}


/// Implementation of OutStream trait for Buffer
pub const BufferOutStream = struct {
    buffer: *Buffer,
    
    pub fn init(buffer: *Buffer) BufferOutStream {
        return BufferOutStream{
            .buffer = buffer,
        };
    }

    pub fn write(self: *BufferOutStream, bytes: []const u8) !void {
        return self.buffer.append(bytes);
    }
    
    pub fn outStreamInterface(self: *BufferOutStream) OutStreamInterface(*BufferOutStream) {
        return OutStreamInterface(*BufferOutStream).init(self);
    }
    
    pub fn outStream(self: *BufferOutStream) OutStream {
        return OutStream.init(self);
    }
};

pub const BufferedAtomicFile = struct {
    atomic_file: os.AtomicFile,
    buffered_stream: BufferedOutStream(os.File),
    allocator: mem.Allocator,

    pub fn create(allocator: mem.Allocator, dest_path: []const u8) !*BufferedAtomicFile {
        // TODO with well defined copy elision we don't need this allocation
        var self = try allocator.create(BufferedAtomicFile{
            .atomic_file = undefined,
            .buffered_stream = undefined,
            .allocator = allocator,
        });
        errdefer allocator.destroy(self);

        self.atomic_file = try os.AtomicFile.init(dest_path, os.File.default_mode);
        errdefer self.atomic_file.deinit();

        self.buffered_stream = BufferedOutStream(os.File).init(self.atomic_file.file);
        return self;
    }

    /// always call destroy, even after successful finish()
    pub fn destroy(self: *BufferedAtomicFile) void {
        self.atomic_file.deinit();
        self.allocator.destroy(self);
    }

    pub fn finish(self: *BufferedAtomicFile) !void {
        try self.buffered_stream.flush();
        try self.atomic_file.finish();
    }
    
    pub fn stream(self: *BufferedAtomicFile) OutStreamInterface(*BufferedOutStream(os.File)) {
        return self.buffered_stream.outStreamInterface();
    }
};

test "import io tests" {
    comptime {
        _ = @import("io_test.zig");
    }
}

pub fn readLine(buf: *std.Buffer) ![]u8 {
    var stdin = try getStdIn();
    var stdin_stream = stdin.inStreamInterface();
    return readLineFrom(stdin_stream, buf);
}

/// Reads all characters until the next newline into buf, and returns
/// a slice of the characters read (excluding the newline character(s)).
pub fn readLineFrom(stream: var, buf: *std.Buffer) ![]u8 {
    const start = buf.len();
    while (true) {
        const byte = try stream.readByte();
        switch (byte) {
            '\r' => {
                // trash the following \n
                _ = try stream.readByte();
                return buf.toSlice()[start..];
            },
            '\n' => return buf.toSlice()[start..],
            else => try buf.appendByte(byte),
        }
    }
}

test "io.readLineFrom" {
    var bytes: [128]u8 = undefined;
    const allocator = std.heap.FixedBufferAllocator.init(bytes[0..]).allocator();

    var buf = try std.Buffer.initSize(allocator, 0);
    var mem_stream = SliceInStream.init(
        \\Line 1
        \\Line 22
        \\Line 333
    );
    const stream = mem_stream.inStreamInterface();

    debug.assert(mem.eql(u8, "Line 1", try readLineFrom(stream, &buf)));
    debug.assert(mem.eql(u8, "Line 22", try readLineFrom(stream, &buf)));
    debug.assertError(readLineFrom(stream, &buf), error.EndOfStream);
    debug.assert(mem.eql(u8, buf.toSlice(), "Line 1Line 22Line 333"));
}

pub fn readLineSlice(slice: []u8) ![]u8 {
    var stdin = try getStdIn();
    var stdin_stream = stdin.inStreamInterface();
    return readLineSliceFrom(stdin_stream, slice);
}

/// Reads all characters until the next newline into slice, and returns
/// a slice of the characters read (excluding the newline character(s)).
pub fn readLineSliceFrom(stream: var, slice: []u8) ![]u8 {
    // We cannot use Buffer.fromOwnedSlice, as it wants to append a null byte
    // after taking ownership, which would always require an allocation.
    var buf = std.Buffer{ .list = std.ArrayList(u8).fromOwnedSlice(debug.failing_allocator, slice) };
    try buf.resize(0);
    return try readLineFrom(stream, &buf);
}

test "io.readLineSliceFrom" {
    var buf: [7]u8 = undefined;
    var mem_stream = SliceInStream.init(
        \\Line 1
        \\Line 22
        \\Line 333
    );
    const stream = mem_stream.inStreamInterface();

    debug.assert(mem.eql(u8, "Line 1", try readLineSliceFrom(stream, buf[0..])));
    debug.assertError(readLineSliceFrom(stream, buf[0..]), error.OutOfMemory);
}
