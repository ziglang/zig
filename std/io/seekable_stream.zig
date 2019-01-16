const std = @import("../index.zig");
const InStream = std.io.InStream;

pub const SeekableStream = SeekableStreamInterface(AbstractSeekableStream);

pub fn SeekableStreamInterface(comptime Stream: type) type {
    return struct {
        const Self = @This();

        impl: Stream,
        
        pub fn init(impl: Stream) Self {
            return Self {
                .impl = impl,
            };
        }

        pub fn seekTo(self: Self, pos: usize) !void {
            return self.impl.seekTo(pos);
        }

        pub fn seekForward(self: Self, amt: isize) !void {
            return self.impl.seekForward(amt);
        }

        pub fn getEndPos(self: Self) !usize {
            return self.impl.getEndPos();
        }

        pub fn getPos(self: Self) !usize {
            return self.impl.getPos();
        }
    };
}
 
pub const AbstractSeekableStream = struct {
    pub const Context = *@OpaqueType();
    
    const VTable = struct {
        seekTo: fn (self: Context, pos: usize) anyerror!void,
        seekForward: fn (self: Context, pos: isize) anyerror!void,

        getPos: fn (self: Context) anyerror!usize,
        getEndPos: fn (self: Context) anyerror!usize,
    };

    vtable: *const VTable,
    impl: Context,

    pub fn init(impl: var) AbstractSeekableStream {
        const T = comptime std.meta.Child(@typeOf(impl));
        return AbstractSeekableStream{
            .vtable = comptime std.vtable.populate(VTable, T, T),
            .impl = @ptrCast(Context, impl),
        };
    }

    pub fn seekTo(self: AbstractSeekableStream, pos: usize) !void {
        return self.vtable.seekTo(self.impl, pos);
    }

    pub fn seekForward(self: AbstractSeekableStream, amt: isize) !void {
        return self.vtable.seekForward(self.impl, amt);
    }

    pub fn getEndPos(self: AbstractSeekableStream) !usize {
        return self.vtable.getEndPos(self.impl);
    }

    pub fn getPos(self: AbstractSeekableStream) !usize {
        return self.vtable.getPos(self.impl);
    }
    
    pub fn seekableStreamInterface(self: AbstractSeekableStream) SeekableStream {
        return SeekableStream.init(self);
    }
    
    pub fn seekableStream(self: AbstractSeekableStream) SeekableStream {
        return self.seekableStreamInterface();
    }
};