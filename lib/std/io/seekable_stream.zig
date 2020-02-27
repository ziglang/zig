const std = @import("../std.zig");
const InStream = std.io.InStream;

pub fn SeekableStream(comptime SeekErrorType: type, comptime GetSeekPosErrorType: type) type {
    return struct {
        const Self = @This();
        pub const SeekError = SeekErrorType;
        pub const GetSeekPosError = GetSeekPosErrorType;

        seekToFn: fn (self: *Self, pos: u64) SeekError!void,
        seekByFn: fn (self: *Self, pos: i64) SeekError!void,

        getPosFn: fn (self: *Self) GetSeekPosError!u64,
        getEndPosFn: fn (self: *Self) GetSeekPosError!u64,

        pub fn seekTo(self: *Self, pos: u64) SeekError!void {
            return self.seekToFn(self, pos);
        }

        pub fn seekBy(self: *Self, amt: i64) SeekError!void {
            return self.seekByFn(self, amt);
        }

        pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
            return self.getEndPosFn(self);
        }

        pub fn getPos(self: *Self) GetSeekPosError!u64 {
            return self.getPosFn(self);
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

    stream: Stream,
    seekable_stream: SeekableInStream,

    pos: usize,
    slice: []const u8,

    pub fn init(slice: []const u8) Self {
        return Self{
            .slice = slice,
            .pos = 0,
            .stream = Stream{ .readFn = readFn },
            .seekable_stream = SeekableInStream{
                .seekToFn = seekToFn,
                .seekByFn = seekByFn,
                .getEndPosFn = getEndPosFn,
                .getPosFn = getPosFn,
            },
        };
    }

    fn readFn(in_stream: *Stream, dest: []u8) Error!usize {
        const self = @fieldParentPtr(Self, "stream", in_stream);
        const size = std.math.min(dest.len, self.slice.len - self.pos);
        const end = self.pos + size;

        std.mem.copy(u8, dest[0..size], self.slice[self.pos..end]);
        self.pos = end;

        return size;
    }

    fn seekToFn(in_stream: *SeekableInStream, pos: u64) SeekError!void {
        const self = @fieldParentPtr(Self, "seekable_stream", in_stream);
        const usize_pos = @intCast(usize, pos);
        if (usize_pos > self.slice.len) return error.EndOfStream;
        self.pos = usize_pos;
    }

    fn seekByFn(in_stream: *SeekableInStream, amt: i64) SeekError!void {
        const self = @fieldParentPtr(Self, "seekable_stream", in_stream);

        if (amt < 0) {
            const abs_amt = @intCast(usize, -amt);
            if (abs_amt > self.pos) return error.EndOfStream;
            self.pos -= abs_amt;
        } else {
            const usize_amt = @intCast(usize, amt);
            if (self.pos + usize_amt > self.slice.len) return error.EndOfStream;
            self.pos += usize_amt;
        }
    }

    fn getEndPosFn(in_stream: *SeekableInStream) GetSeekPosError!u64 {
        const self = @fieldParentPtr(Self, "seekable_stream", in_stream);
        return @intCast(u64, self.slice.len);
    }

    fn getPosFn(in_stream: *SeekableInStream) GetSeekPosError!u64 {
        const self = @fieldParentPtr(Self, "seekable_stream", in_stream);
        return @intCast(u64, self.pos);
    }
};
