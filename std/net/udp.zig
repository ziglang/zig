const std = @import("../index.zig");
const event = std.event;
const assert = std.debug.assert;
const os = std.os;
const mem = std.mem;
const net = std.net;

pub fn UDP() type {
    return struct {
        channel: *event.Channel(Event),
        putter: promise,
        table_lock: event.Lock,
        fd: i32,

        const Self = this;

        pub const Event = union(enum) {
            Packet: []u8,
            Err: Error,

            pub const Error = error{
                UserResourceLimitReached,
                SystemResources,
            };
        };

        pub fn listen(address: net.Address, loop: *event.Loop, event_buf_count: usize) !*Self {
            //socket
            const fd = try os.posixSocket(address.family(), os.posix.SOCK_DGRAM, os.posix.IPPROTO_UDP);
            errdefer os.close(fd);

            //set non blocking?

            //bind
            //@breakpoint();
            try os.posixBind(fd, address);

            const channel = try event.Channel(Self.Event).create(loop, event_buf_count);
            errdefer channel.destroy();

            var result: *Self = undefined;
            _ = try async<loop.allocator> eventPutter(fd, channel, &result);
            return result;
        }

        pub fn destroy(self: *Self) void {
            cancel self.putter;
        }

        pub async fn write(self: *Self, file_path: []const u8, value: V) !?V {
        }

        async fn eventPutter(fd: i32, channel: *event.Channel(Event), out: **Self) void {
            // TODO https://github.com/ziglang/zig/issues/1194
            suspend {
                resume @handle();
            }

            const loop = channel.loop;

            var udp = Self{
                .putter = @handle(),
                .channel = channel,
                .table_lock = event.Lock.init(loop),
                .fd = fd,
            };
            out.* = &udp;

            loop.beginOneEvent();

            defer {
                loop.finishOneEvent();
                os.close(fd);
                channel.destroy();
            }

            var event_buf: [1500]u8 = undefined;

            while (true) {
                const rc = os.darwin.read(fd, &event_buf, event_buf.len);
                const errno = os.darwin.getErrno(rc); //maybe this shouldn't be called so much?
                switch (errno) {
                    0 => {
                        await (async channel.put(Self.Event{ .Packet = &event_buf }) catch unreachable);
                    },
                    else => unreachable,
                }
            }
        }
    };
}

async fn testerCantFail(loop: *event.Loop, result: *(error!void)) void {
    result.* = await async tester(loop) catch unreachable;
}

async fn tester(loop: *event.Loop) !void {
    var ip4 = std.mem.endianSwapIfLe(u32, try net.parseIp4("127.0.0.1"));
    var address = net.Address.initIp4(ip4, 8000);
    var udp = try UDP().listen(address, loop, 0);
    defer udp.destroy();
}

test "read udp packets" {
  var da = std.heap.DirectAllocator.init();
  defer da.deinit();

  const allocator = &da.allocator;

  var loop: event.Loop = undefined;
  try loop.initMultiThreaded(allocator);
  defer loop.deinit();

  var result: error!void = undefined;
  const handle = try async<allocator> testerCantFail(&loop, &result);
  defer cancel handle;

  loop.run();
  return result;
}

