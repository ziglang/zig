const linux = @import("linux.zig");
const errno = @import("errno.zig");

pub error SigInterrupt;
pub error Unexpected;
pub error Io;

struct Connection {
    socket_fd: i32,

    pub fn close(c: Connection) -> %void {
        switch (linux.get_errno(linux.close(c.socket_fd))) {
            0 => return,
            errno.EBADF => unreachable{},
            errno.EINTR => return error.SigInterrupt,
            errno.EIO => return error.Io,
            else => return error.Unexpected,
        }
    }
}

struct Address {
    addr: linux.sockaddr,
}

pub fn lookup(hostname: []const u8, out_addrs: []Address) -> %[]Address {
    unreachable{} // TODO
}

pub fn connect_addr(addr: &Address, port: u16) -> %Connection {
    addr.addr.port = port;

    const socket_ret = linux.socket(linux.PF_INET, linux.SOCK_STREAM, linux.PROTO_tcp);
    const socket_err = linux.get_errno(socket_ret);
    if (socket_err > 0) {
        // TODO figure out possible errors from socket()
        return error.Unexpected;
    }
    const socket_fd = i32(socket_ret);

    const connect_err = linux.get_errno(linux.connect(socket_fd, &addr.addr, @sizeof(linux.sockaddr)));
    if (connect_err > 0) {
        // TODO figure out possible errors from connect()
        return error.Unexpected;
    }

    return Connection {
        .socket_fd = socket_fd,
    };
}

pub fn connect(hostname: []const u8, port: u16) -> %Connection {
    var addrs_buf: [1]Address = undefined;
    const addrs_slice = %return lookup(hostname, addrs_buf);
    const main_addr = &addrs_slice[0];

    return connect_addr(main_addr, port);
}
