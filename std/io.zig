const std = @import("std.zig");
const builtin = @import("builtin");
const Os = builtin.Os;
const c = std.c;

const math = std.math;
const debug = std.debug;
const assert = debug.assert;
const os = std.os;
const mem = std.mem;
const meta = std.meta;
const trait = meta.trait;
const Buffer = std.Buffer;
const fmt = std.fmt;
const File = std.os.File;
const testing = std.testing;

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

pub const SeekableStream = @import("io/seekable_stream.zig").SeekableStream;
pub const COutStream = @import("io/c_out_stream.zig").COutStream;

pub fn InStream(comptime ReadError: type) type {
    return struct {
        const Self = @This();
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

        /// Returns the number of bytes read. It may be less than buffer.len.
        /// If the number of bytes read is 0, it means end of stream.
        /// End of stream is not an error condition.
        pub fn read(self: *Self, buffer: []u8) Error!usize {
            return self.readFn(self, buffer);
        }

        /// Returns the number of bytes read. If the number read is smaller than buf.len, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        pub fn readFull(self: *Self, buffer: []u8) Error!usize {
            var index: usize = 0;
            while (index != buffer.len) {
                const amt = try self.read(buffer[index..]);
                if (amt == 0) return index;
                index += amt;
            }
            return index;
        }

        /// Same as `readFull` but end of stream returns `error.EndOfStream`.
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

        /// Reads a native-endian integer
        pub fn readIntNative(self: *Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readIntNative(T, &bytes);
        }

        /// Reads a foreign-endian integer
        pub fn readIntForeign(self: *Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readIntForeign(T, &bytes);
        }

        pub fn readIntLittle(self: *Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readIntLittle(T, &bytes);
        }

        pub fn readIntBig(self: *Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readIntBig(T, &bytes);
        }

        pub fn readInt(self: *Self, comptime T: type, endian: builtin.Endian) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readNoEof(bytes[0..]);
            return mem.readInt(T, &bytes, endian);
        }

        pub fn readVarInt(self: *Self, comptime ReturnType: type, endian: builtin.Endian, size: usize) !ReturnType {
            assert(size <= @sizeOf(ReturnType));
            var bytes_buf: [@sizeOf(ReturnType)]u8 = undefined;
            const bytes = bytes_buf[0..size];
            try self.readNoEof(bytes);
            return mem.readVarInt(ReturnType, bytes, endian);
        }

        pub fn skipBytes(self: *Self, num_bytes: usize) !void {
            var i: usize = 0;
            while (i < num_bytes) : (i += 1) {
                _ = try self.readByte();
            }
        }

        pub fn readStruct(self: *Self, comptime T: type) !T {
            // Only extern and packed structs have defined in-memory layout.
            comptime assert(@typeInfo(T).Struct.layout != builtin.TypeInfo.ContainerLayout.Auto);
            var res: [1]T = undefined;
            try self.readNoEof(@sliceToBytes(res[0..]));
            return res[0];
        }
    };
}

pub fn OutStream(comptime WriteError: type) type {
    return struct {
        const Self = @This();
        pub const Error = WriteError;

        writeFn: fn (self: *Self, bytes: []const u8) Error!void,

        pub fn print(self: *Self, comptime format: []const u8, args: ...) Error!void {
            return std.fmt.format(self, Error, self.writeFn, format, args);
        }

        pub fn write(self: *Self, bytes: []const u8) Error!void {
            return self.writeFn(self, bytes);
        }

        pub fn writeByte(self: *Self, byte: u8) Error!void {
            const slice = (*const [1]u8)(&byte)[0..];
            return self.writeFn(self, slice);
        }

        pub fn writeByteNTimes(self: *Self, byte: u8, n: usize) Error!void {
            const slice = (*const [1]u8)(&byte)[0..];
            var i: usize = 0;
            while (i < n) : (i += 1) {
                try self.writeFn(self, slice);
            }
        }

        /// Write a native-endian integer.
        pub fn writeIntNative(self: *Self, comptime T: type, value: T) Error!void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeIntNative(T, &bytes, value);
            return self.writeFn(self, bytes);
        }

        /// Write a foreign-endian integer.
        pub fn writeIntForeign(self: *Self, comptime T: type, value: T) Error!void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeIntForeign(T, &bytes, value);
            return self.writeFn(self, bytes);
        }

        pub fn writeIntLittle(self: *Self, comptime T: type, value: T) Error!void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeIntLittle(T, &bytes, value);
            return self.writeFn(self, bytes);
        }

        pub fn writeIntBig(self: *Self, comptime T: type, value: T) Error!void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeIntBig(T, &bytes, value);
            return self.writeFn(self, bytes);
        }

        pub fn writeInt(self: *Self, comptime T: type, value: T, endian: builtin.Endian) Error!void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            mem.writeInt(T, &bytes, value, endian);
            return self.writeFn(self, bytes);
        }
    };
}

pub fn writeFile(path: []const u8, data: []const u8) !void {
    var file = try File.openWrite(path);
    defer file.close();
    try file.write(data);
}

/// On success, caller owns returned buffer.
pub fn readFileAlloc(allocator: *mem.Allocator, path: []const u8) ![]u8 {
    return readFileAllocAligned(allocator, path, @alignOf(u8));
}

/// On success, caller owns returned buffer.
pub fn readFileAllocAligned(allocator: *mem.Allocator, path: []const u8, comptime A: u29) ![]align(A) u8 {
    var file = try File.openRead(path);
    defer file.close();

    const size = try file.getEndPos();
    const buf = try allocator.alignedAlloc(u8, A, size);
    errdefer allocator.free(buf);

    var adapter = file.inStream();
    try adapter.stream.readNoEof(buf[0..size]);
    return buf;
}

pub fn BufferedInStream(comptime Error: type) type {
    return BufferedInStreamCustom(os.page_size, Error);
}

pub fn BufferedInStreamCustom(comptime buffer_size: usize, comptime Error: type) type {
    return struct {
        const Self = @This();
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
                    // Make sure the last read actually gave us some data
                    if (self.end_index == 0) {
                        // reading from the unbuffered stream returned nothing
                        // so we have nothing left to read.
                        return dest_index;
                    }
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

test "io.BufferedInStream" {
    const OneByteReadInStream = struct {
        const Error = error{NoError};
        const Stream = InStream(Error);

        stream: Stream,
        str: []const u8,
        curr: usize,

        fn init(str: []const u8) @This() {
            return @This(){
                .stream = Stream{ .readFn = readFn },
                .str = str,
                .curr = 0,
            };
        }

        fn readFn(in_stream: *Stream, dest: []u8) Error!usize {
            const self = @fieldParentPtr(@This(), "stream", in_stream);
            if (self.str.len <= self.curr or dest.len == 0)
                return 0;

            dest[0] = self.str[self.curr];
            self.curr += 1;
            return 1;
        }
    };

    var buf: [100]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(buf[0..]).allocator;

    const str = "This is a test";
    var one_byte_stream = OneByteReadInStream.init(str);
    var buf_in_stream = BufferedInStream(OneByteReadInStream.Error).init(&one_byte_stream.stream);
    const stream = &buf_in_stream.stream;

    const res = try stream.readAllAlloc(allocator, str.len + 1);
    testing.expectEqualSlices(u8, str, res);
}

/// Creates a stream which supports 'un-reading' data, so that it can be read again.
/// This makes look-ahead style parsing much easier.
pub fn PeekStream(comptime buffer_size: usize, comptime InStreamError: type) type {
    return struct {
        const Self = @This();
        pub const Error = InStreamError;
        pub const Stream = InStream(Error);

        pub stream: Stream,
        base: *Stream,

        // Right now the look-ahead space is statically allocated, but a version with dynamic allocation
        // is not too difficult to derive from this.
        buffer: [buffer_size]u8,
        index: usize,
        at_end: bool,

        pub fn init(base: *Stream) Self {
            return Self{
                .base = base,
                .buffer = undefined,
                .index = 0,
                .at_end = false,
                .stream = Stream{ .readFn = readFn },
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

        fn readFn(in_stream: *Stream, dest: []u8) Error!usize {
            const self = @fieldParentPtr(Self, "stream", in_stream);

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
            const read = try self.base.read(dest[pos..]);
            assert(read <= left);

            self.at_end = (read < left);
            return pos + read;
        }
    };
}

pub const SliceInStream = struct {
    const Self = @This();
    pub const Error = error{};
    pub const Stream = InStream(Error);

    pub stream: Stream,

    pos: usize,
    slice: []const u8,

    pub fn init(slice: []const u8) Self {
        return Self{
            .slice = slice,
            .pos = 0,
            .stream = Stream{ .readFn = readFn },
        };
    }

    fn readFn(in_stream: *Stream, dest: []u8) Error!usize {
        const self = @fieldParentPtr(Self, "stream", in_stream);
        const size = math.min(dest.len, self.slice.len - self.pos);
        const end = self.pos + size;

        mem.copy(u8, dest[0..size], self.slice[self.pos..end]);
        self.pos = end;

        return size;
    }
};

/// Creates a stream which allows for reading bit fields from another stream
pub fn BitInStream(endian: builtin.Endian, comptime Error: type) type {
    return struct {
        const Self = @This();

        in_stream: *Stream,
        bit_buffer: u7,
        bit_count: u3,
        stream: Stream,

        pub const Stream = InStream(Error);
        const u8_bit_count = comptime meta.bitCount(u8);
        const u7_bit_count = comptime meta.bitCount(u7);
        const u4_bit_count = comptime meta.bitCount(u4);

        pub fn init(in_stream: *Stream) Self {
            return Self{
                .in_stream = in_stream,
                .bit_buffer = 0,
                .bit_count = 0,
                .stream = Stream{ .readFn = read },
            };
        }

        /// Reads `bits` bits from the stream and returns a specified unsigned int type
        ///  containing them in the least significant end, returning an error if the
        ///  specified number of bits could not be read.
        pub fn readBitsNoEof(self: *Self, comptime U: type, bits: usize) !U {
            var n: usize = undefined;
            const result = try self.readBits(U, bits, &n);
            if (n < bits) return error.EndOfStream;
            return result;
        }

        /// Reads `bits` bits from the stream and returns a specified unsigned int type
        ///  containing them in the least significant end. The number of bits successfully
        ///  read is placed in `out_bits`, as reaching the end of the stream is not an error.
        pub fn readBits(self: *Self, comptime U: type, bits: usize, out_bits: *usize) Error!U {
            comptime assert(trait.isUnsignedInt(U));

            //by extending the buffer to a minimum of u8 we can cover a number of edge cases
            // related to shifting and casting.
            const u_bit_count = comptime meta.bitCount(U);
            const buf_bit_count = bc: {
                assert(u_bit_count >= bits);
                break :bc if (u_bit_count <= u8_bit_count) u8_bit_count else u_bit_count;
            };
            const Buf = @IntType(false, buf_bit_count);
            const BufShift = math.Log2Int(Buf);

            out_bits.* = usize(0);
            if (U == u0 or bits == 0) return 0;
            var out_buffer = Buf(0);

            if (self.bit_count > 0) {
                const n = if (self.bit_count >= bits) @intCast(u3, bits) else self.bit_count;
                const shift = u7_bit_count - n;
                switch (endian) {
                    builtin.Endian.Big => {
                        out_buffer = Buf(self.bit_buffer >> shift);
                        self.bit_buffer <<= n;
                    },
                    builtin.Endian.Little => {
                        const value = (self.bit_buffer << shift) >> shift;
                        out_buffer = Buf(value);
                        self.bit_buffer >>= n;
                    },
                }
                self.bit_count -= n;
                out_bits.* = n;
            }
            //at this point we know bit_buffer is empty

            //copy bytes until we have enough bits, then leave the rest in bit_buffer
            while (out_bits.* < bits) {
                const n = bits - out_bits.*;
                const next_byte = self.in_stream.readByte() catch |err| {
                    if (err == error.EndOfStream) {
                        return @intCast(U, out_buffer);
                    }
                    //@BUG: See #1810. Not sure if the bug is that I have to do this for some
                    // streams, or that I don't for streams with emtpy errorsets.
                    return @errSetCast(Error, err);
                };

                switch (endian) {
                    builtin.Endian.Big => {
                        if (n >= u8_bit_count) {
                            out_buffer <<= @intCast(u3, u8_bit_count - 1);
                            out_buffer <<= 1;
                            out_buffer |= Buf(next_byte);
                            out_bits.* += u8_bit_count;
                            continue;
                        }

                        const shift = @intCast(u3, u8_bit_count - n);
                        out_buffer <<= @intCast(BufShift, n);
                        out_buffer |= Buf(next_byte >> shift);
                        out_bits.* += n;
                        self.bit_buffer = @truncate(u7, next_byte << @intCast(u3, n - 1));
                        self.bit_count = shift;
                    },
                    builtin.Endian.Little => {
                        if (n >= u8_bit_count) {
                            out_buffer |= Buf(next_byte) << @intCast(BufShift, out_bits.*);
                            out_bits.* += u8_bit_count;
                            continue;
                        }

                        const shift = @intCast(u3, u8_bit_count - n);
                        const value = (next_byte << shift) >> shift;
                        out_buffer |= Buf(value) << @intCast(BufShift, out_bits.*);
                        out_bits.* += n;
                        self.bit_buffer = @truncate(u7, next_byte >> @intCast(u3, n));
                        self.bit_count = shift;
                    },
                }
            }

            return @intCast(U, out_buffer);
        }

        pub fn alignToByte(self: *Self) void {
            self.bit_buffer = 0;
            self.bit_count = 0;
        }

        pub fn read(self_stream: *Stream, buffer: []u8) Error!usize {
            var self = @fieldParentPtr(Self, "stream", self_stream);

            var out_bits: usize = undefined;
            var out_bits_total = usize(0);
            //@NOTE: I'm not sure this is a good idea, maybe alignToByte should be forced
            if (self.bit_count > 0) {
                for (buffer) |*b, i| {
                    b.* = try self.readBits(u8, u8_bit_count, &out_bits);
                    out_bits_total += out_bits;
                }
                const incomplete_byte = @boolToInt(out_bits_total % u8_bit_count > 0);
                return (out_bits_total / u8_bit_count) + incomplete_byte;
            }

            return self.in_stream.read(buffer);
        }
    };
}

/// This is a simple OutStream that writes to a slice, and returns an error
/// when it runs out of space.
pub const SliceOutStream = struct {
    pub const Error = error{OutOfSpace};
    pub const Stream = OutStream(Error);

    pub stream: Stream,

    pub pos: usize,
    slice: []u8,

    pub fn init(slice: []u8) SliceOutStream {
        return SliceOutStream{
            .slice = slice,
            .pos = 0,
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    pub fn getWritten(self: *const SliceOutStream) []const u8 {
        return self.slice[0..self.pos];
    }

    pub fn reset(self: *SliceOutStream) void {
        self.pos = 0;
    }

    fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {
        const self = @fieldParentPtr(SliceOutStream, "stream", out_stream);

        assert(self.pos <= self.slice.len);

        const n = if (self.pos + bytes.len <= self.slice.len)
            bytes.len
        else
            self.slice.len - self.pos;

        std.mem.copy(u8, self.slice[self.pos .. self.pos + n], bytes[0..n]);
        self.pos += n;

        if (n < bytes.len) {
            return Error.OutOfSpace;
        }
    }
};

test "io.SliceOutStream" {
    var buf: [255]u8 = undefined;
    var slice_stream = SliceOutStream.init(buf[0..]);
    const stream = &slice_stream.stream;

    try stream.print("{}{}!", "Hello", "World");
    testing.expectEqualSlices(u8, "HelloWorld!", slice_stream.getWritten());
}

var null_out_stream_state = NullOutStream.init();
pub const null_out_stream = &null_out_stream_state.stream;

/// An OutStream that doesn't write to anything.
pub const NullOutStream = struct {
    pub const Error = error{};
    pub const Stream = OutStream(Error);

    pub stream: Stream,

    pub fn init() NullOutStream {
        return NullOutStream{
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {}
};

test "io.NullOutStream" {
    var null_stream = NullOutStream.init();
    const stream = &null_stream.stream;
    stream.write("yay" ** 10000) catch unreachable;
}

/// An OutStream that counts how many bytes has been written to it.
pub fn CountingOutStream(comptime OutStreamError: type) type {
    return struct {
        const Self = @This();
        pub const Stream = OutStream(Error);
        pub const Error = OutStreamError;

        pub stream: Stream,
        pub bytes_written: usize,
        child_stream: *Stream,

        pub fn init(child_stream: *Stream) Self {
            return Self{
                .stream = Stream{ .writeFn = writeFn },
                .bytes_written = 0,
                .child_stream = child_stream,
            };
        }

        fn writeFn(out_stream: *Stream, bytes: []const u8) OutStreamError!void {
            const self = @fieldParentPtr(Self, "stream", out_stream);
            try self.child_stream.write(bytes);
            self.bytes_written += bytes.len;
        }
    };
}

test "io.CountingOutStream" {
    var null_stream = NullOutStream.init();
    var counting_stream = CountingOutStream(NullOutStream.Error).init(&null_stream.stream);
    const stream = &counting_stream.stream;

    const bytes = "yay" ** 10000;
    stream.write(bytes) catch unreachable;
    testing.expect(counting_stream.bytes_written == bytes.len);
}

pub fn BufferedOutStream(comptime Error: type) type {
    return BufferedOutStreamCustom(os.page_size, Error);
}

pub fn BufferedOutStreamCustom(comptime buffer_size: usize, comptime OutStreamError: type) type {
    return struct {
        const Self = @This();
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

/// Creates a stream which allows for writing bit fields to another stream
pub fn BitOutStream(endian: builtin.Endian, comptime Error: type) type {
    return struct {
        const Self = @This();

        out_stream: *Stream,
        bit_buffer: u8,
        bit_count: u4,
        stream: Stream,

        pub const Stream = OutStream(Error);
        const u8_bit_count = comptime meta.bitCount(u8);
        const u4_bit_count = comptime meta.bitCount(u4);

        pub fn init(out_stream: *Stream) Self {
            return Self{
                .out_stream = out_stream,
                .bit_buffer = 0,
                .bit_count = 0,
                .stream = Stream{ .writeFn = write },
            };
        }

        /// Write the specified number of bits to the stream from the least significant bits of
        ///  the specified unsigned int value. Bits will only be written to the stream when there
        ///  are enough to fill a byte.
        pub fn writeBits(self: *Self, value: var, bits: usize) Error!void {
            if (bits == 0) return;

            const U = @typeOf(value);
            comptime assert(trait.isUnsignedInt(U));

            //by extending the buffer to a minimum of u8 we can cover a number of edge cases
            // related to shifting and casting.
            const u_bit_count = comptime meta.bitCount(U);
            const buf_bit_count = bc: {
                assert(u_bit_count >= bits);
                break :bc if (u_bit_count <= u8_bit_count) u8_bit_count else u_bit_count;
            };
            const Buf = @IntType(false, buf_bit_count);
            const BufShift = math.Log2Int(Buf);

            const buf_value = @intCast(Buf, value);

            const high_byte_shift = @intCast(BufShift, buf_bit_count - u8_bit_count);
            var in_buffer = switch (endian) {
                builtin.Endian.Big => buf_value << @intCast(BufShift, buf_bit_count - bits),
                builtin.Endian.Little => buf_value,
            };
            var in_bits = bits;

            if (self.bit_count > 0) {
                const bits_remaining = u8_bit_count - self.bit_count;
                const n = @intCast(u3, if (bits_remaining > bits) bits else bits_remaining);
                switch (endian) {
                    builtin.Endian.Big => {
                        const shift = @intCast(BufShift, high_byte_shift + self.bit_count);
                        const v = @intCast(u8, in_buffer >> shift);
                        self.bit_buffer |= v;
                        in_buffer <<= n;
                    },
                    builtin.Endian.Little => {
                        const v = @truncate(u8, in_buffer) << @intCast(u3, self.bit_count);
                        self.bit_buffer |= v;
                        in_buffer >>= n;
                    },
                }
                self.bit_count += n;
                in_bits -= n;

                //if we didn't fill the buffer, it's because bits < bits_remaining;
                if (self.bit_count != u8_bit_count) return;
                try self.out_stream.writeByte(self.bit_buffer);
                self.bit_buffer = 0;
                self.bit_count = 0;
            }
            //at this point we know bit_buffer is empty

            //copy bytes until we can't fill one anymore, then leave the rest in bit_buffer
            while (in_bits >= u8_bit_count) {
                switch (endian) {
                    builtin.Endian.Big => {
                        const v = @intCast(u8, in_buffer >> high_byte_shift);
                        try self.out_stream.writeByte(v);
                        in_buffer <<= @intCast(u3, u8_bit_count - 1);
                        in_buffer <<= 1;
                    },
                    builtin.Endian.Little => {
                        const v = @truncate(u8, in_buffer);
                        try self.out_stream.writeByte(v);
                        in_buffer >>= @intCast(u3, u8_bit_count - 1);
                        in_buffer >>= 1;
                    },
                }
                in_bits -= u8_bit_count;
            }

            if (in_bits > 0) {
                self.bit_count = @intCast(u4, in_bits);
                self.bit_buffer = switch (endian) {
                    builtin.Endian.Big => @truncate(u8, in_buffer >> high_byte_shift),
                    builtin.Endian.Little => @truncate(u8, in_buffer),
                };
            }
        }

        /// Flush any remaining bits to the stream.
        pub fn flushBits(self: *Self) Error!void {
            if (self.bit_count == 0) return;
            try self.out_stream.writeByte(self.bit_buffer);
            self.bit_buffer = 0;
            self.bit_count = 0;
        }

        pub fn write(self_stream: *Stream, buffer: []const u8) Error!void {
            var self = @fieldParentPtr(Self, "stream", self_stream);

            //@NOTE: I'm not sure this is a good idea, maybe flushBits should be forced
            if (self.bit_count > 0) {
                for (buffer) |b, i|
                    try self.writeBits(b, u8_bit_count);
                return;
            }

            return self.out_stream.write(buffer);
        }
    };
}

pub const BufferedAtomicFile = struct {
    atomic_file: os.AtomicFile,
    file_stream: os.File.OutStream,
    buffered_stream: BufferedOutStream(os.File.WriteError),
    allocator: *mem.Allocator,

    pub fn create(allocator: *mem.Allocator, dest_path: []const u8) !*BufferedAtomicFile {
        // TODO with well defined copy elision we don't need this allocation
        var self = try allocator.create(BufferedAtomicFile);
        self.* = BufferedAtomicFile{
            .atomic_file = undefined,
            .file_stream = undefined,
            .buffered_stream = undefined,
            .allocator = allocator,
        };
        errdefer allocator.destroy(self);

        self.atomic_file = try os.AtomicFile.init(dest_path, os.File.default_mode);
        errdefer self.atomic_file.deinit();

        self.file_stream = self.atomic_file.file.outStream();
        self.buffered_stream = BufferedOutStream(os.File.WriteError).init(&self.file_stream.stream);
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

    pub fn stream(self: *BufferedAtomicFile) *OutStream(os.File.WriteError) {
        return &self.buffered_stream.stream;
    }
};

pub fn readLine(buf: *std.Buffer) ![]u8 {
    var stdin = try getStdIn();
    var stdin_stream = stdin.inStream();
    return readLineFrom(&stdin_stream.stream, buf);
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
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;

    var buf = try std.Buffer.initSize(allocator, 0);
    var mem_stream = SliceInStream.init(
        \\Line 1
        \\Line 22
        \\Line 333
    );
    const stream = &mem_stream.stream;

    testing.expectEqualSlices(u8, "Line 1", try readLineFrom(stream, &buf));
    testing.expectEqualSlices(u8, "Line 22", try readLineFrom(stream, &buf));
    testing.expectError(error.EndOfStream, readLineFrom(stream, &buf));
    testing.expectEqualSlices(u8, "Line 1Line 22Line 333", buf.toSlice());
}

pub fn readLineSlice(slice: []u8) ![]u8 {
    var stdin = try getStdIn();
    var stdin_stream = stdin.inStream();
    return readLineSliceFrom(&stdin_stream.stream, slice);
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
    const stream = &mem_stream.stream;

    testing.expectEqualSlices(u8, "Line 1", try readLineSliceFrom(stream, buf[0..]));
    testing.expectError(error.OutOfMemory, readLineSliceFrom(stream, buf[0..]));
}

pub const Packing = enum {
    /// Pack data to byte alignment
    Byte,
    /// Pack data to bit alignment
    Bit,
};

/// Creates a deserializer that deserializes types from any stream.
///  If `is_packed` is true, the data stream is treated as bit-packed,
///  otherwise data is expected to be packed to the smallest byte.
///  Types may implement a custom deserialization routine with a
///  function named `deserialize` in the form of:
///    pub fn deserialize(self: *Self, deserializer: var) !void
///  which will be called when the deserializer is used to deserialize
///  that type. It will pass a pointer to the type instance to deserialize
///  into and a pointer to the deserializer struct.
pub fn Deserializer(comptime endian: builtin.Endian, comptime packing: Packing, comptime Error: type) type {
    return struct {
        const Self = @This();

        in_stream: if (packing == .Bit) BitInStream(endian, Stream.Error) else *Stream,

        pub const Stream = InStream(Error);

        pub fn init(in_stream: *Stream) Self {
            return Self{
                .in_stream = switch (packing) {
                    .Bit => BitInStream(endian, Stream.Error).init(in_stream),
                    .Byte => in_stream,
                },
            };
        }

        pub fn alignToByte(self: *Self) void {
            if (!is_packed) return;
            self.in_stream.alignToByte();
        }

        //@BUG: inferred error issue. See: #1386
        fn deserializeInt(self: *Self, comptime T: type) (Error || error{EndOfStream})!T {
            comptime assert(trait.is(builtin.TypeId.Int)(T) or trait.is(builtin.TypeId.Float)(T));

            const u8_bit_count = 8;
            const t_bit_count = comptime meta.bitCount(T);

            const U = @IntType(false, t_bit_count);
            const Log2U = math.Log2Int(U);
            const int_size = (U.bit_count + 7) / 8;

            if (packing == .Bit) {
                const result = try self.in_stream.readBitsNoEof(U, t_bit_count);
                return @bitCast(T, result);
            }

            var buffer: [int_size]u8 = undefined;
            const read_size = try self.in_stream.read(buffer[0..]);
            if (read_size < int_size) return error.EndOfStream;

            if (int_size == 1) {
                if (t_bit_count == 8) return @bitCast(T, buffer[0]);
                const PossiblySignedByte = @IntType(T.is_signed, 8);
                return @truncate(T, @bitCast(PossiblySignedByte, buffer[0]));
            }

            var result = U(0);
            for (buffer) |byte, i| {
                switch (endian) {
                    builtin.Endian.Big => {
                        result = (result << u8_bit_count) | byte;
                    },
                    builtin.Endian.Little => {
                        result |= U(byte) << @intCast(Log2U, u8_bit_count * i);
                    },
                }
            }

            return @bitCast(T, result);
        }

        //@TODO: Replace this with @unionInit or whatever when it is added
        // see: #1315
        fn setTag(ptr: var, tag: var) void {
            const T = @typeOf(ptr);
            comptime assert(trait.isPtrTo(builtin.TypeId.Union)(T));
            const U = meta.Child(T);

            const info = @typeInfo(U).Union;
            if (info.tag_type) |TagType| {
                comptime assert(TagType == @typeOf(tag));

                var ptr_tag = ptr: {
                    if (@alignOf(TagType) >= @alignOf(U)) break :ptr @ptrCast(*TagType, ptr);
                    const offset = comptime max: {
                        var max_field_size: comptime_int = 0;
                        for (info.fields) |field_info| {
                            const field_size = @sizeOf(field_info.field_type);
                            max_field_size = math.max(max_field_size, field_size);
                        }
                        break :max math.max(max_field_size, @alignOf(U));
                    };
                    break :ptr @intToPtr(*TagType, @ptrToInt(ptr) + offset);
                };
                ptr_tag.* = tag;
            }
        }

        /// Deserializes and returns data of the specified type from the stream
        pub fn deserialize(self: *Self, comptime T: type) !T {
            var value: T = undefined;
            try self.deserializeInto(&value);
            return value;
        }

        /// Deserializes data into the type pointed to by `ptr`
        pub fn deserializeInto(self: *Self, ptr: var) !void {
            const T = @typeOf(ptr);
            comptime assert(trait.is(builtin.TypeId.Pointer)(T));

            if (comptime trait.isSlice(T) or comptime trait.isPtrTo(builtin.TypeId.Array)(T)) {
                for (ptr) |*v|
                    try self.deserializeInto(v);
                return;
            }

            comptime assert(trait.isSingleItemPtr(T));

            const C = comptime meta.Child(T);
            const child_type_id = @typeId(C);

            //custom deserializer: fn(self: *Self, deserializer: var) !void
            if (comptime trait.hasFn("deserialize")(C)) return C.deserialize(ptr, self);

            if (comptime trait.isPacked(C) and packing != .Bit) {
                var packed_deserializer = Deserializer(endian, .Bit, Error).init(self.in_stream);
                return packed_deserializer.deserializeInto(ptr);
            }

            switch (child_type_id) {
                builtin.TypeId.Void => return,
                builtin.TypeId.Bool => ptr.* = (try self.deserializeInt(u1)) > 0,
                builtin.TypeId.Float, builtin.TypeId.Int => ptr.* = try self.deserializeInt(C),
                builtin.TypeId.Struct => {
                    const info = @typeInfo(C).Struct;

                    inline for (info.fields) |*field_info| {
                        const name = field_info.name;
                        const FieldType = field_info.field_type;

                        if (FieldType == void or FieldType == u0) continue;

                        //it doesn't make any sense to read pointers
                        if (comptime trait.is(builtin.TypeId.Pointer)(FieldType)) {
                            @compileError("Will not " ++ "read field " ++ name ++ " of struct " ++
                                @typeName(C) ++ " because it " ++ "is of pointer-type " ++
                                @typeName(FieldType) ++ ".");
                        }

                        try self.deserializeInto(&@field(ptr, name));
                    }
                },
                builtin.TypeId.Union => {
                    const info = @typeInfo(C).Union;
                    if (info.tag_type) |TagType| {
                        //we avoid duplicate iteration over the enum tags
                        // by getting the int directly and casting it without
                        // safety. If it is bad, it will be caught anyway.
                        const TagInt = @TagType(TagType);
                        const tag = try self.deserializeInt(TagInt);

                        {
                            @setRuntimeSafety(false);
                            //See: #1315
                            setTag(ptr, @intToEnum(TagType, tag));
                        }

                        inline for (info.fields) |field_info| {
                            if (field_info.enum_field.?.value == tag) {
                                const name = field_info.name;
                                const FieldType = field_info.field_type;
                                @field(ptr, name) = FieldType(undefined);
                                try self.deserializeInto(&@field(ptr, name));
                                return;
                            }
                        }
                        //This is reachable if the enum data is bad
                        return error.InvalidEnumTag;
                    }
                    @compileError("Cannot meaningfully deserialize " ++ @typeName(C) ++
                        " because it is an untagged union. Use a custom deserialize().");
                },
                builtin.TypeId.Optional => {
                    const OC = comptime meta.Child(C);
                    const exists = (try self.deserializeInt(u1)) > 0;
                    if (!exists) {
                        ptr.* = null;
                        return;
                    }

                    ptr.* = OC(undefined); //make it non-null so the following .? is guaranteed safe
                    const val_ptr = &ptr.*.?;
                    try self.deserializeInto(val_ptr);
                },
                builtin.TypeId.Enum => {
                    var value = try self.deserializeInt(@TagType(C));
                    ptr.* = try meta.intToEnum(C, value);
                },
                else => {
                    @compileError("Cannot deserialize " ++ @tagName(child_type_id) ++ " types (unimplemented).");
                },
            }
        }
    };
}

/// Creates a serializer that serializes types to any stream.
///  If `is_packed` is true, the data will be bit-packed into the stream.
///  Note that the you must call `serializer.flush()` when you are done
///  writing bit-packed data in order ensure any unwritten bits are committed.
///  If `is_packed` is false, data is packed to the smallest byte. In the case
///  of packed structs, the struct will written bit-packed and with the specified
///  endianess, after which data will resume being written at the next byte boundary.
///  Types may implement a custom serialization routine with a
///  function named `serialize` in the form of:
///    pub fn serialize(self: Self, serializer: var) !void
///  which will be called when the serializer is used to serialize that type. It will
///  pass a const pointer to the type instance to be serialized and a pointer
///  to the serializer struct.
pub fn Serializer(comptime endian: builtin.Endian, comptime packing: Packing, comptime Error: type) type {
    return struct {
        const Self = @This();

        out_stream: if (packing == .Bit) BitOutStream(endian, Stream.Error) else *Stream,

        pub const Stream = OutStream(Error);

        pub fn init(out_stream: *Stream) Self {
            return Self{
                .out_stream = switch (packing) {
                    .Bit => BitOutStream(endian, Stream.Error).init(out_stream),
                    .Byte => out_stream,
                },
            };
        }

        /// Flushes any unwritten bits to the stream
        pub fn flush(self: *Self) Error!void {
            if (packing == .Bit) return self.out_stream.flushBits();
        }

        fn serializeInt(self: *Self, value: var) Error!void {
            const T = @typeOf(value);
            comptime assert(trait.is(builtin.TypeId.Int)(T) or trait.is(builtin.TypeId.Float)(T));

            const t_bit_count = comptime meta.bitCount(T);
            const u8_bit_count = comptime meta.bitCount(u8);

            const U = @IntType(false, t_bit_count);
            const Log2U = math.Log2Int(U);
            const int_size = (U.bit_count + 7) / 8;

            const u_value = @bitCast(U, value);

            if (packing == .Bit) return self.out_stream.writeBits(u_value, t_bit_count);

            var buffer: [int_size]u8 = undefined;
            if (int_size == 1) buffer[0] = u_value;

            for (buffer) |*byte, i| {
                const idx = switch (endian) {
                    .Big => int_size - i - 1,
                    .Little => i,
                };
                const shift = @intCast(Log2U, idx * u8_bit_count);
                const v = u_value >> shift;
                byte.* = if (t_bit_count < u8_bit_count) v else @truncate(u8, v);
            }

            try self.out_stream.write(buffer);
        }

        /// Serializes the passed value into the stream
        pub fn serialize(self: *Self, value: var) Error!void {
            const T = comptime @typeOf(value);

            if (comptime trait.isIndexable(T)) {
                for (value) |v|
                    try self.serialize(v);
                return;
            }

            //custom serializer: fn(self: Self, serializer: var) !void
            if (comptime trait.hasFn("serialize")(T)) return T.serialize(value, self);

            if (comptime trait.isPacked(T) and packing != .Bit) {
                var packed_serializer = Serializer(endian, .Bit, Error).init(self.out_stream);
                try packed_serializer.serialize(value);
                try packed_serializer.flush();
                return;
            }

            switch (@typeId(T)) {
                builtin.TypeId.Void => return,
                builtin.TypeId.Bool => try self.serializeInt(u1(@boolToInt(value))),
                builtin.TypeId.Float, builtin.TypeId.Int => try self.serializeInt(value),
                builtin.TypeId.Struct => {
                    const info = @typeInfo(T);

                    inline for (info.Struct.fields) |*field_info| {
                        const name = field_info.name;
                        const FieldType = field_info.field_type;

                        if (FieldType == void or FieldType == u0) continue;

                        //It doesn't make sense to write pointers
                        if (comptime trait.is(builtin.TypeId.Pointer)(FieldType)) {
                            @compileError("Will not " ++ "serialize field " ++ name ++
                                " of struct " ++ @typeName(T) ++ " because it " ++
                                "is of pointer-type " ++ @typeName(FieldType) ++ ".");
                        }
                        try self.serialize(@field(value, name));
                    }
                },
                builtin.TypeId.Union => {
                    const info = @typeInfo(T).Union;
                    if (info.tag_type) |TagType| {
                        const active_tag = meta.activeTag(value);
                        try self.serialize(active_tag);
                        //This inline loop is necessary because active_tag is a runtime
                        // value, but @field requires a comptime value. Our alternative
                        // is to check each field for a match
                        inline for (info.fields) |field_info| {
                            if (field_info.enum_field.?.value == @enumToInt(active_tag)) {
                                const name = field_info.name;
                                const FieldType = field_info.field_type;
                                try self.serialize(@field(value, name));
                                return;
                            }
                        }
                        unreachable;
                    }
                    @compileError("Cannot meaningfully serialize " ++ @typeName(T) ++
                        " because it is an untagged union. Use a custom serialize().");
                },
                builtin.TypeId.Optional => {
                    if (value == null) {
                        try self.serializeInt(u1(@boolToInt(false)));
                        return;
                    }
                    try self.serializeInt(u1(@boolToInt(true)));

                    const OC = comptime meta.Child(T);
                    const val_ptr = &value.?;
                    try self.serialize(val_ptr.*);
                },
                builtin.TypeId.Enum => {
                    try self.serializeInt(@enumToInt(value));
                },
                else => @compileError("Cannot serialize " ++ @tagName(@typeId(T)) ++ " types (unimplemented)."),
            }
        }
    };
}

test "import io tests" {
    comptime {
        _ = @import("io_test.zig");
    }
}
