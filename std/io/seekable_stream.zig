const std = @import("../std.zig");
const InStream = std.io.InStream;
const interface = std.interface;

pub const AnySeekToFn = fn(interface.Any,u64)anyerror!void;
pub const AnySeekForwardFn = fn(interface.Any,i64)anyerror!void;
pub const AnyGetPosFn = fn(interface.Any)anyerror!u64;
pub const AnyGetEndPosFn = fn(interface.Any)anyerror!u64;
pub const AnySeekableStream = SeekableStream(
    interface.Any,
    AnySeekToFn,
    AnySeekForwardFn,
    AnyGetPosFn,
    AnyGetEndPosFn
);
pub fn SeekableStream(
    comptime S: type,
    comptime SeekToFn: type,
    comptime SeekForwardFn: type, 
    comptime GetPosFn: type,
    comptime GetEndPosFn: type,
) type {
    return struct {
        const Self = @This();
        
        impl: S,
        
        seekToFn: SeekToFn,
        seekForwardFn: SeekForwardFn,
        getPosFn: GetPosFn,
        getEndPosFn: GetEndPosFn,

        pub const SeekError = SeekToFn.ReturnType.ErrorSet;
        pub const GetPosError = GetPosFn.ReturnType.ErrorSet;
        
        pub fn seekTo(self: Self, pos: u64) SeekError!void {
            return self.seekToFn(self.impl, pos);
        }

        pub fn seekForward(self: Self, amt: i64) SeekError!void {
            return self.seekForwardFn(self.impl, amt);
        }

        pub fn getEndPos(self: Self) GetPosError!u64 {
            return self.getEndPosFn(self.impl);
        }

        pub fn getPos(self: Self) GetPosError!u64 {
            return self.getPosFn(self.impl);
        }
        
        pub fn toAny(self: *Self) AnySeekableStream {
            return AnySeekableStream {
                .impl = interface.toAny(self.impl),
                .seekToFn = interface.abstractFn(AnySeekToFn, self.seekToFn),
                .seekForwardFn = interface.abstractFn(AnySeekForwardFn, self.seekForwardFn),
                .getPosFn = interface.abstractFn(AnyGetPosFn, self.getPosFn),
                .getEndPosFn = interface.abstractFn(AnyGetEndPosFn, self.getEndPosFn),
            };
        }
    };
}

pub const SliceSeekableInStream = struct {
    const Self = @This();

    pos: usize,
    slice: []const u8,

    pub fn init(slice: []const u8) Self {
        return Self{
            .slice = slice,
            .pos = 0,
        };
    }

    fn readFn(self: *Self, dest: []u8) error{}!usize {
        const size = std.math.min(dest.len, self.slice.len - self.pos);
        const end = self.pos + size;

        std.mem.copy(u8, dest[0..size], self.slice[self.pos..end]);
        self.pos = end;

        return size;
    }
    
    pub const InStreamImpl = InStream(*Self, @typeOf(readFn));
    pub fn inStream(self: *Self) InStreamImpl {
        return InStreamImpl {
            .impl = self,
            .readFn = readFn,
        };
    }

    fn seekToFn(self: *Self, pos: u64) !void {
        const usize_pos = @intCast(usize, pos);
        if (usize_pos >= self.slice.len) return error.EndOfStream;
        self.pos = usize_pos;
    }

    fn seekForwardFn(self: *Self, amt: i64) !void {
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

    fn getEndPosFn(self: *Self) error{}!u64 {
        return @intCast(u64, self.slice.len);
    }

    fn getPosFn(self: *Self) error{}!u64 {
        return @intCast(u64, self.pos);
    }
    
    pub const SeekableStreamImpl = SeekableStream(*Self, 
        @typeOf(seekToFn),
        @typeOf(seekForwardFn),
        @typeOf(getPosFn),
        @typeOf(getEndPosFn),
    );
    pub fn seekableStream(self: *Self) SeekableStreamImpl {
        return SeekableStreamImpl {
            .impl = self,
            .seekToFn = seekToFn,
            .seekForwardFn = seekForwardFn,
            .getPosFn = getPosFn,
            .getEndPosFn = getEndPosFn,
        };
    }
};
