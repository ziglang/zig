const std = @import("std.zig");
const builtin = @import("builtin");
const root = @import("root");
const c = std.c;

const math = std.math;
const debug = std.debug;
const assert = debug.assert;
const os = std.os;
const fs = std.fs;
const mem = std.mem;
const meta = std.meta;
const trait = meta.trait;
const Buffer = std.Buffer;
const fmt = std.fmt;
const File = std.fs.File;
const testing = std.testing;

pub const Mode = enum {
    /// I/O operates normally, waiting for the operating system syscalls to complete.
    blocking,

    /// I/O functions are generated async and rely on a global event loop. Event-based I/O.
    evented,
};

/// The application's chosen I/O mode. This defaults to `Mode.blocking` but can be overridden
/// by `root.event_loop`.
pub const mode: Mode = if (@hasDecl(root, "io_mode"))
    root.io_mode
else if (@hasDecl(root, "event_loop"))
    Mode.evented
else
    Mode.blocking;
pub const is_async = mode != .blocking;

fn getStdOutHandle() os.fd_t {
    if (builtin.os.tag == .windows) {
        return os.windows.peb().ProcessParameters.hStdOutput;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdOutHandle")) {
        return root.os.io.getStdOutHandle();
    }

    return os.STDOUT_FILENO;
}

pub fn getStdOut() File {
    return File{
        .handle = getStdOutHandle(),
        .io_mode = .blocking,
    };
}

fn getStdErrHandle() os.fd_t {
    if (builtin.os.tag == .windows) {
        return os.windows.peb().ProcessParameters.hStdError;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdErrHandle")) {
        return root.os.io.getStdErrHandle();
    }

    return os.STDERR_FILENO;
}

pub fn getStdErr() File {
    return File{
        .handle = getStdErrHandle(),
        .io_mode = .blocking,
        .async_block_allowed = File.async_block_allowed_yes,
    };
}

fn getStdInHandle() os.fd_t {
    if (builtin.os.tag == .windows) {
        return os.windows.peb().ProcessParameters.hStdInput;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdInHandle")) {
        return root.os.io.getStdInHandle();
    }

    return os.STDIN_FILENO;
}

pub fn getStdIn() File {
    return File{
        .handle = getStdInHandle(),
        .io_mode = .blocking,
    };
}

pub const SeekableStream = @import("io/seekable_stream.zig").SeekableStream;
pub const SliceSeekableInStream = @import("io/seekable_stream.zig").SliceSeekableInStream;
pub const COutStream = @import("io/c_out_stream.zig").COutStream;
pub const InStream = @import("io/in_stream.zig").InStream;
pub const OutStream = @import("io/out_stream.zig").OutStream;

/// Deprecated; use `std.fs.Dir.writeFile`.
pub fn writeFile(path: []const u8, data: []const u8) !void {
    return fs.cwd().writeFile(path, data);
}

/// Deprecated; use `std.fs.Dir.readFileAlloc`.
pub fn readFileAlloc(allocator: *mem.Allocator, path: []const u8) ![]u8 {
    return fs.cwd().readFileAlloc(allocator, path, math.maxInt(usize));
}

pub fn BufferedInStream(comptime Error: type) type {
    return BufferedInStreamCustom(mem.page_size, Error);
}

pub fn BufferedInStreamCustom(comptime buffer_size: usize, comptime Error: type) type {
    return struct {
        const Self = @This();
        const Stream = InStream(Error);

        stream: Stream,

        unbuffered_in_stream: *Stream,

        const FifoType = std.fifo.LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = buffer_size });
        fifo: FifoType,

        pub fn init(unbuffered_in_stream: *Stream) Self {
            return Self{
                .unbuffered_in_stream = unbuffered_in_stream,
                .fifo = FifoType.init(),
                .stream = Stream{ .readFn = readFn },
            };
        }

        fn readFn(in_stream: *Stream, dest: []u8) !usize {
            const self = @fieldParentPtr(Self, "stream", in_stream);
            var dest_index: usize = 0;
            while (dest_index < dest.len) {
                const written = self.fifo.read(dest[dest_index..]);
                if (written == 0) {
                    // fifo empty, fill it
                    const writable = self.fifo.writableSlice(0);
                    assert(writable.len > 0);
                    const n = try self.unbuffered_in_stream.read(writable);
                    if (n == 0) {
                        // reading from the unbuffered stream returned nothing
                        // so we have nothing left to read.
                        return dest_index;
                    }
                    self.fifo.update(n);
                }
                dest_index += written;
            }
            return dest.len;
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

    const str = "This is a test";
    var one_byte_stream = OneByteReadInStream.init(str);
    var buf_in_stream = BufferedInStream(OneByteReadInStream.Error).init(&one_byte_stream.stream);
    const stream = &buf_in_stream.stream;

    const res = try stream.readAllAlloc(testing.allocator, str.len + 1);
    defer testing.allocator.free(res);
    testing.expectEqualSlices(u8, str, res);
}

/// Creates a stream which supports 'un-reading' data, so that it can be read again.
/// This makes look-ahead style parsing much easier.
pub fn PeekStream(comptime buffer_type: std.fifo.LinearFifoBufferType, comptime InStreamError: type) type {
    return struct {
        const Self = @This();
        pub const Error = InStreamError;
        pub const Stream = InStream(Error);

        stream: Stream,
        base: *Stream,

        const FifoType = std.fifo.LinearFifo(u8, buffer_type);
        fifo: FifoType,

        pub usingnamespace switch (buffer_type) {
            .Static => struct {
                pub fn init(base: *Stream) Self {
                    return .{
                        .base = base,
                        .fifo = FifoType.init(),
                        .stream = Stream{ .readFn = readFn },
                    };
                }
            },
            .Slice => struct {
                pub fn init(base: *Stream, buf: []u8) Self {
                    return .{
                        .base = base,
                        .fifo = FifoType.init(buf),
                        .stream = Stream{ .readFn = readFn },
                    };
                }
            },
            .Dynamic => struct {
                pub fn init(base: *Stream, allocator: *mem.Allocator) Self {
                    return .{
                        .base = base,
                        .fifo = FifoType.init(allocator),
                        .stream = Stream{ .readFn = readFn },
                    };
                }
            },
        };

        pub fn putBackByte(self: *Self, byte: u8) !void {
            try self.putBack(&[_]u8{byte});
        }

        pub fn putBack(self: *Self, bytes: []const u8) !void {
            try self.fifo.unget(bytes);
        }

        fn readFn(in_stream: *Stream, dest: []u8) Error!usize {
            const self = @fieldParentPtr(Self, "stream", in_stream);

            // copy over anything putBack()'d
            var dest_index = self.fifo.read(dest);
            if (dest_index == dest.len) return dest_index;

            // ask the backing stream for more
            dest_index += try self.base.read(dest[dest_index..]);
            return dest_index;
        }
    };
}

pub const SliceInStream = struct {
    const Self = @This();
    pub const Error = error{};
    pub const Stream = InStream(Error);

    stream: Stream,

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
            const Buf = std.meta.IntType(false, buf_bit_count);
            const BufShift = math.Log2Int(Buf);

            out_bits.* = @as(usize, 0);
            if (U == u0 or bits == 0) return 0;
            var out_buffer = @as(Buf, 0);

            if (self.bit_count > 0) {
                const n = if (self.bit_count >= bits) @intCast(u3, bits) else self.bit_count;
                const shift = u7_bit_count - n;
                switch (endian) {
                    .Big => {
                        out_buffer = @as(Buf, self.bit_buffer >> shift);
                        self.bit_buffer <<= n;
                    },
                    .Little => {
                        const value = (self.bit_buffer << shift) >> shift;
                        out_buffer = @as(Buf, value);
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
                    .Big => {
                        if (n >= u8_bit_count) {
                            out_buffer <<= @intCast(u3, u8_bit_count - 1);
                            out_buffer <<= 1;
                            out_buffer |= @as(Buf, next_byte);
                            out_bits.* += u8_bit_count;
                            continue;
                        }

                        const shift = @intCast(u3, u8_bit_count - n);
                        out_buffer <<= @intCast(BufShift, n);
                        out_buffer |= @as(Buf, next_byte >> shift);
                        out_bits.* += n;
                        self.bit_buffer = @truncate(u7, next_byte << @intCast(u3, n - 1));
                        self.bit_count = shift;
                    },
                    .Little => {
                        if (n >= u8_bit_count) {
                            out_buffer |= @as(Buf, next_byte) << @intCast(BufShift, out_bits.*);
                            out_bits.* += u8_bit_count;
                            continue;
                        }

                        const shift = @intCast(u3, u8_bit_count - n);
                        const value = (next_byte << shift) >> shift;
                        out_buffer |= @as(Buf, value) << @intCast(BufShift, out_bits.*);
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
            var out_bits_total = @as(usize, 0);
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

/// This is a simple OutStream that writes to a fixed buffer. If the returned number
/// of bytes written is less than requested, the buffer is full.
/// Returns error.OutOfMemory when no bytes would be written.
pub const SliceOutStream = struct {
    pub const Error = error{OutOfMemory};
    pub const Stream = OutStream(Error);

    stream: Stream,

    pos: usize,
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

    fn writeFn(out_stream: *Stream, bytes: []const u8) Error!usize {
        const self = @fieldParentPtr(SliceOutStream, "stream", out_stream);

        if (bytes.len == 0) return 0;

        assert(self.pos <= self.slice.len);

        const n = if (self.pos + bytes.len <= self.slice.len)
            bytes.len
        else
            self.slice.len - self.pos;

        std.mem.copy(u8, self.slice[self.pos .. self.pos + n], bytes[0..n]);
        self.pos += n;

        if (n == 0) return error.OutOfMemory;

        return n;
    }
};

test "io.SliceOutStream" {
    var buf: [255]u8 = undefined;
    var slice_stream = SliceOutStream.init(buf[0..]);
    const stream = &slice_stream.stream;

    try stream.print("{}{}!", .{ "Hello", "World" });
    testing.expectEqualSlices(u8, "HelloWorld!", slice_stream.getWritten());
}

var null_out_stream_state = NullOutStream.init();
pub const null_out_stream = &null_out_stream_state.stream;

/// An OutStream that doesn't write to anything.
pub const NullOutStream = struct {
    pub const Error = error{};
    pub const Stream = OutStream(Error);

    stream: Stream,

    pub fn init() NullOutStream {
        return NullOutStream{
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    fn writeFn(out_stream: *Stream, bytes: []const u8) Error!usize {
        return bytes.len;
    }
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

        stream: Stream,
        bytes_written: u64,
        child_stream: *Stream,

        pub fn init(child_stream: *Stream) Self {
            return Self{
                .stream = Stream{ .writeFn = writeFn },
                .bytes_written = 0,
                .child_stream = child_stream,
            };
        }

        fn writeFn(out_stream: *Stream, bytes: []const u8) OutStreamError!usize {
            const self = @fieldParentPtr(Self, "stream", out_stream);
            try self.child_stream.write(bytes);
            self.bytes_written += bytes.len;
            return bytes.len;
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
    return BufferedOutStreamCustom(mem.page_size, Error);
}

pub fn BufferedOutStreamCustom(comptime buffer_size: usize, comptime OutStreamError: type) type {
    return struct {
        const Self = @This();
        pub const Stream = OutStream(Error);
        pub const Error = OutStreamError;

        stream: Stream,

        unbuffered_out_stream: *Stream,

        const FifoType = std.fifo.LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = buffer_size });
        fifo: FifoType,

        pub fn init(unbuffered_out_stream: *Stream) Self {
            return Self{
                .unbuffered_out_stream = unbuffered_out_stream,
                .fifo = FifoType.init(),
                .stream = Stream{ .writeFn = writeFn },
            };
        }

        pub fn flush(self: *Self) !void {
            while (true) {
                const slice = self.fifo.readableSlice(0);
                if (slice.len == 0) break;
                try self.unbuffered_out_stream.write(slice);
                self.fifo.discard(slice.len);
            }
        }

        fn writeFn(out_stream: *Stream, bytes: []const u8) Error!usize {
            const self = @fieldParentPtr(Self, "stream", out_stream);
            if (bytes.len >= self.fifo.writableLength()) {
                try self.flush();
                return self.unbuffered_out_stream.writeOnce(bytes);
            }
            self.fifo.writeAssumeCapacity(bytes);
            return bytes.len;
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

    fn writeFn(out_stream: *Stream, bytes: []const u8) !usize {
        const self = @fieldParentPtr(BufferOutStream, "stream", out_stream);
        try self.buffer.append(bytes);
        return bytes.len;
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

            const U = @TypeOf(value);
            comptime assert(trait.isUnsignedInt(U));

            //by extending the buffer to a minimum of u8 we can cover a number of edge cases
            // related to shifting and casting.
            const u_bit_count = comptime meta.bitCount(U);
            const buf_bit_count = bc: {
                assert(u_bit_count >= bits);
                break :bc if (u_bit_count <= u8_bit_count) u8_bit_count else u_bit_count;
            };
            const Buf = std.meta.IntType(false, buf_bit_count);
            const BufShift = math.Log2Int(Buf);

            const buf_value = @intCast(Buf, value);

            const high_byte_shift = @intCast(BufShift, buf_bit_count - u8_bit_count);
            var in_buffer = switch (endian) {
                .Big => buf_value << @intCast(BufShift, buf_bit_count - bits),
                .Little => buf_value,
            };
            var in_bits = bits;

            if (self.bit_count > 0) {
                const bits_remaining = u8_bit_count - self.bit_count;
                const n = @intCast(u3, if (bits_remaining > bits) bits else bits_remaining);
                switch (endian) {
                    .Big => {
                        const shift = @intCast(BufShift, high_byte_shift + self.bit_count);
                        const v = @intCast(u8, in_buffer >> shift);
                        self.bit_buffer |= v;
                        in_buffer <<= n;
                    },
                    .Little => {
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
                    .Big => {
                        const v = @intCast(u8, in_buffer >> high_byte_shift);
                        try self.out_stream.writeByte(v);
                        in_buffer <<= @intCast(u3, u8_bit_count - 1);
                        in_buffer <<= 1;
                    },
                    .Little => {
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
                    .Big => @truncate(u8, in_buffer >> high_byte_shift),
                    .Little => @truncate(u8, in_buffer),
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

        pub fn write(self_stream: *Stream, buffer: []const u8) Error!usize {
            var self = @fieldParentPtr(Self, "stream", self_stream);

            // TODO: I'm not sure this is a good idea, maybe flushBits should be forced
            if (self.bit_count > 0) {
                for (buffer) |b, i|
                    try self.writeBits(b, u8_bit_count);
                return buffer.len;
            }

            return self.out_stream.writeOnce(buffer);
        }
    };
}

pub const BufferedAtomicFile = struct {
    atomic_file: fs.AtomicFile,
    file_stream: File.OutStream,
    buffered_stream: BufferedOutStream(File.WriteError),
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

        self.atomic_file = try fs.AtomicFile.init(dest_path, File.default_mode);
        errdefer self.atomic_file.deinit();

        self.file_stream = self.atomic_file.file.outStream();
        self.buffered_stream = BufferedOutStream(File.WriteError).init(&self.file_stream.stream);
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

    pub fn stream(self: *BufferedAtomicFile) *OutStream(File.WriteError) {
        return &self.buffered_stream.stream;
    }
};

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
            if (packing == .Byte) return;
            self.in_stream.alignToByte();
        }

        //@BUG: inferred error issue. See: #1386
        fn deserializeInt(self: *Self, comptime T: type) (Error || error{EndOfStream})!T {
            comptime assert(trait.is(.Int)(T) or trait.is(.Float)(T));

            const u8_bit_count = 8;
            const t_bit_count = comptime meta.bitCount(T);

            const U = std.meta.IntType(false, t_bit_count);
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
                const PossiblySignedByte = std.meta.IntType(T.is_signed, 8);
                return @truncate(T, @bitCast(PossiblySignedByte, buffer[0]));
            }

            var result = @as(U, 0);
            for (buffer) |byte, i| {
                switch (endian) {
                    .Big => {
                        result = (result << u8_bit_count) | byte;
                    },
                    .Little => {
                        result |= @as(U, byte) << @intCast(Log2U, u8_bit_count * i);
                    },
                }
            }

            return @bitCast(T, result);
        }

        /// Deserializes and returns data of the specified type from the stream
        pub fn deserialize(self: *Self, comptime T: type) !T {
            var value: T = undefined;
            try self.deserializeInto(&value);
            return value;
        }

        /// Deserializes data into the type pointed to by `ptr`
        pub fn deserializeInto(self: *Self, ptr: var) !void {
            const T = @TypeOf(ptr);
            comptime assert(trait.is(.Pointer)(T));

            if (comptime trait.isSlice(T) or comptime trait.isPtrTo(.Array)(T)) {
                for (ptr) |*v|
                    try self.deserializeInto(v);
                return;
            }

            comptime assert(trait.isSingleItemPtr(T));

            const C = comptime meta.Child(T);
            const child_type_id = @typeInfo(C);

            //custom deserializer: fn(self: *Self, deserializer: var) !void
            if (comptime trait.hasFn("deserialize")(C)) return C.deserialize(ptr, self);

            if (comptime trait.isPacked(C) and packing != .Bit) {
                var packed_deserializer = Deserializer(endian, .Bit, Error).init(self.in_stream);
                return packed_deserializer.deserializeInto(ptr);
            }

            switch (child_type_id) {
                .Void => return,
                .Bool => ptr.* = (try self.deserializeInt(u1)) > 0,
                .Float, .Int => ptr.* = try self.deserializeInt(C),
                .Struct => {
                    const info = @typeInfo(C).Struct;

                    inline for (info.fields) |*field_info| {
                        const name = field_info.name;
                        const FieldType = field_info.field_type;

                        if (FieldType == void or FieldType == u0) continue;

                        //it doesn't make any sense to read pointers
                        if (comptime trait.is(.Pointer)(FieldType)) {
                            @compileError("Will not " ++ "read field " ++ name ++ " of struct " ++
                                @typeName(C) ++ " because it " ++ "is of pointer-type " ++
                                @typeName(FieldType) ++ ".");
                        }

                        try self.deserializeInto(&@field(ptr, name));
                    }
                },
                .Union => {
                    const info = @typeInfo(C).Union;
                    if (info.tag_type) |TagType| {
                        //we avoid duplicate iteration over the enum tags
                        // by getting the int directly and casting it without
                        // safety. If it is bad, it will be caught anyway.
                        const TagInt = @TagType(TagType);
                        const tag = try self.deserializeInt(TagInt);

                        inline for (info.fields) |field_info| {
                            if (field_info.enum_field.?.value == tag) {
                                const name = field_info.name;
                                const FieldType = field_info.field_type;
                                ptr.* = @unionInit(C, name, undefined);
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
                .Optional => {
                    const OC = comptime meta.Child(C);
                    const exists = (try self.deserializeInt(u1)) > 0;
                    if (!exists) {
                        ptr.* = null;
                        return;
                    }

                    ptr.* = @as(OC, undefined); //make it non-null so the following .? is guaranteed safe
                    const val_ptr = &ptr.*.?;
                    try self.deserializeInto(val_ptr);
                },
                .Enum => {
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
            const T = @TypeOf(value);
            comptime assert(trait.is(.Int)(T) or trait.is(.Float)(T));

            const t_bit_count = comptime meta.bitCount(T);
            const u8_bit_count = comptime meta.bitCount(u8);

            const U = std.meta.IntType(false, t_bit_count);
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

            try self.out_stream.write(&buffer);
        }

        /// Serializes the passed value into the stream
        pub fn serialize(self: *Self, value: var) Error!void {
            const T = comptime @TypeOf(value);

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

            switch (@typeInfo(T)) {
                .Void => return,
                .Bool => try self.serializeInt(@as(u1, @boolToInt(value))),
                .Float, .Int => try self.serializeInt(value),
                .Struct => {
                    const info = @typeInfo(T);

                    inline for (info.Struct.fields) |*field_info| {
                        const name = field_info.name;
                        const FieldType = field_info.field_type;

                        if (FieldType == void or FieldType == u0) continue;

                        //It doesn't make sense to write pointers
                        if (comptime trait.is(.Pointer)(FieldType)) {
                            @compileError("Will not " ++ "serialize field " ++ name ++
                                " of struct " ++ @typeName(T) ++ " because it " ++
                                "is of pointer-type " ++ @typeName(FieldType) ++ ".");
                        }
                        try self.serialize(@field(value, name));
                    }
                },
                .Union => {
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
                .Optional => {
                    if (value == null) {
                        try self.serializeInt(@as(u1, @boolToInt(false)));
                        return;
                    }
                    try self.serializeInt(@as(u1, @boolToInt(true)));

                    const OC = comptime meta.Child(T);
                    const val_ptr = &value.?;
                    try self.serialize(val_ptr.*);
                },
                .Enum => {
                    try self.serializeInt(@enumToInt(value));
                },
                else => @compileError("Cannot serialize " ++ @tagName(@typeInfo(T)) ++ " types (unimplemented)."),
            }
        }
    };
}

test "import io tests" {
    comptime {
        _ = @import("io/test.zig");
    }
}
