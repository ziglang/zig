const std = @import("../std.zig");
const InStream = std.io.InStream;
const assert = std.debug.assert;

pub fn SeekableStream(comptime SeekErrorType: type, comptime GetSeekPosErrorType: type) type {
    return struct {
        const Self = @This();
        pub const SeekError = SeekErrorType;
        pub const GetSeekPosError = GetSeekPosErrorType;
        pub const SeekableStreamImpl = ?*@OpaqueType();

        impl: SeekableStreamImpl,
        
        seekToFn: fn (self: Self, pos: u64) SeekError!void,
        seekForwardFn: fn (self: Self, pos: i64) SeekError!void,

        getPosFn: fn (self: Self) GetSeekPosError!u64,
        getEndPosFn: fn (self: Self) GetSeekPosError!u64,

        pub fn seekTo(self: Self, pos: u64) SeekError!void {
            return self.seekToFn(self, pos);
        }

        pub fn seekForward(self: Self, amt: i64) SeekError!void {
            return self.seekForwardFn(self, amt);
        }

        pub fn getEndPos(self: Self) GetSeekPosError!u64 {
            return self.getEndPosFn(self);
        }

        pub fn getPos(self: Self) GetSeekPosError!u64 {
            return self.getPosFn(self);
        }
        
        /// Cast the original type to the implementation pointer
        pub fn ifaceCast(ptr: var) SeekableStreamImpl {
            const T = @typeOf(ptr);
            if(@alignOf(T) == 0) @compileError("0-Bit implementations can't be casted (and casting is unnecessary anyway, use null)");
            return @ptrCast(SeekableStreamImpl, ptr);
        }
        
        /// Cast the implementation pointer back to the original type
        pub fn implCast(seek: Self, comptime T: type) *T {
            if(@alignOf(T) == 0) @compileError("0-Bit implementations can't be casted (and casting is unnecessary anyway)");
            assert(seek.impl != null);
            const aligned = @alignCast(@alignOf(T), seek.impl);
            return @ptrCast(*T, aligned);
        }
    };
}

pub const SliceSeekableInStream = struct {
    const Self = @This();
    pub const Error = error{};
    pub const SeekError = error{EndOfStream};
    pub const GetSeekPosError = error{};
    pub const Stream = InStream(Error);
    pub const SeekableInStream = SeekableStream(SeekError, GetSeekPosError);

    pos: usize,
    slice: []const u8,

    pub fn init(slice: []const u8) Self {
        return Self{
            .slice = slice,
            .pos = 0,
        };
    }

    fn readFn(in_stream: Stream, dest: []u8) Error!usize {
        const self = in_stream.implCast(SliceSeekableInStream);
        const size = std.math.min(dest.len, self.slice.len - self.pos);
        const end = self.pos + size;

        std.mem.copy(u8, dest[0..size], self.slice[self.pos..end]);
        self.pos = end;

        return size;
    }

    fn seekToFn(in_stream: SeekableInStream, pos: u64) SeekError!void {
        const self = in_stream.implCast(SliceSeekableInStream);
        const usize_pos = @intCast(usize, pos);
        if (usize_pos >= self.slice.len) return error.EndOfStream;
        self.pos = usize_pos;
    }

    fn seekForwardFn(in_stream: SeekableInStream, amt: i64) SeekError!void {
        const self = in_stream.implCast(SliceSeekableInStream);

        if (amt < 0) {
            const abs_amt = @intCast(usize, -amt);
            if (abs_amt > self.pos) return error.EndOfStream;
            self.pos -= abs_amt;
        } else {
            const usize_amt = @intCast(usize, amt);
            if (self.pos + usize_amt >= self.slice.len) return error.EndOfStream;
            self.pos += usize_amt;
        }
    }

    fn getEndPosFn(in_stream: SeekableInStream) GetSeekPosError!u64 {
        const self = in_stream.implCast(SliceSeekableInStream);
        return @intCast(u64, self.slice.len);
    }

    fn getPosFn(in_stream: SeekableInStream) GetSeekPosError!u64 {
        const self = in_stream.implCast(SliceSeekableInStream);
        return @intCast(u64, self.pos);
    }
    
    pub fn inStream(self: *Self) Stream {
        return Stream {
            .impl = Stream.ifaceCast(self),
            .readFn = readFn,
        };
    }
    
    pub fn seekableStream(self: *Self) SeekableInStream {
        return SeekableInStream {
            .impl = SeekableInStream.ifaceCast(self),
            .seekToFn = seekToFn,
            .seekForwardFn = seekForwardFn,
            .getPosFn = getPosFn,
            .getEndPosFn = getEndPosFn,
        };
    }
};
