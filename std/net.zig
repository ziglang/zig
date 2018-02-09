const std = @import("index.zig");
const linux = std.os.linux;
const assert = std.debug.assert;
const endian = std.endian;

// TODO don't trust this file, it bit rotted. start over

const Connection = struct {
    socket_fd: i32,

    pub fn send(c: Connection, buf: []const u8) !usize {
        const send_ret = linux.sendto(c.socket_fd, buf.ptr, buf.len, 0, null, 0);
        const send_err = linux.getErrno(send_ret);
        switch (send_err) {
            0 => return send_ret,
            linux.EINVAL => unreachable,
            linux.EFAULT => unreachable,
            linux.ECONNRESET => return error.ConnectionReset,
            linux.EINTR => return error.SigInterrupt,
            // TODO there are more possible errors
            else => return error.Unexpected,
        }
    }

    pub fn recv(c: Connection, buf: []u8) ![]u8 {
        const recv_ret = linux.recvfrom(c.socket_fd, buf.ptr, buf.len, 0, null, null);
        const recv_err = linux.getErrno(recv_ret);
        switch (recv_err) {
            0 => return buf[0..recv_ret],
            linux.EINVAL => unreachable,
            linux.EFAULT => unreachable,
            linux.ENOTSOCK => return error.NotSocket,
            linux.EINTR => return error.SigInterrupt,
            linux.ENOMEM => return error.OutOfMemory,
            linux.ECONNREFUSED => return error.ConnectionRefused,
            linux.EBADF => return error.BadFd,
            // TODO more error values
            else => return error.Unexpected,
        }
    }

    pub fn close(c: Connection) !void {
        switch (linux.getErrno(linux.close(c.socket_fd))) {
            0 => return,
            linux.EBADF => unreachable,
            linux.EINTR => return error.SigInterrupt,
            linux.EIO => return error.Io,
            else => return error.Unexpected,
        }
    }
};

const Address = struct {
    family: u16,
    scope_id: u32,
    addr: [16]u8,
    sort_key: i32,
};

pub fn lookup(hostname: []const u8, out_addrs: []Address) ![]Address {
    if (hostname.len == 0) {

        unreachable; // TODO
    }

    unreachable; // TODO
}

pub fn connectAddr(addr: &Address, port: u16) !Connection {
    const socket_ret = linux.socket(addr.family, linux.SOCK_STREAM, linux.PROTO_tcp);
    const socket_err = linux.getErrno(socket_ret);
    if (socket_err > 0) {
        // TODO figure out possible errors from socket()
        return error.Unexpected;
    }
    const socket_fd = i32(socket_ret);

    const connect_ret = if (addr.family == linux.AF_INET) x: {
        var os_addr: linux.sockaddr_in = undefined;
        os_addr.family = addr.family;
        os_addr.port = endian.swapIfLe(u16, port);
        @memcpy((&u8)(&os_addr.addr), &addr.addr[0], 4);
        @memset(&os_addr.zero[0], 0, @sizeOf(@typeOf(os_addr.zero)));
        break :x linux.connect(socket_fd, (&linux.sockaddr)(&os_addr), @sizeOf(linux.sockaddr_in));
    } else if (addr.family == linux.AF_INET6) x: {
        var os_addr: linux.sockaddr_in6 = undefined;
        os_addr.family = addr.family;
        os_addr.port = endian.swapIfLe(u16, port);
        os_addr.flowinfo = 0;
        os_addr.scope_id = addr.scope_id;
        @memcpy(&os_addr.addr[0], &addr.addr[0], 16);
        break :x linux.connect(socket_fd, (&linux.sockaddr)(&os_addr), @sizeOf(linux.sockaddr_in6));
    } else {
        unreachable;
    };
    const connect_err = linux.getErrno(connect_ret);
    if (connect_err > 0) {
        switch (connect_err) {
            linux.ETIMEDOUT => return error.TimedOut,
            else => {
                // TODO figure out possible errors from connect()
                return error.Unexpected;
            },
        }
    }

    return Connection {
        .socket_fd = socket_fd,
    };
}

pub fn connect(hostname: []const u8, port: u16) !Connection {
    var addrs_buf: [1]Address = undefined;
    const addrs_slice = try lookup(hostname, addrs_buf[0..]);
    const main_addr = &addrs_slice[0];

    return connectAddr(main_addr, port);
}

pub fn parseIpLiteral(buf: []const u8) !Address {

    return error.InvalidIpLiteral;
}

fn hexDigit(c: u8) u8 {
    // TODO use switch with range
    if ('0' <= c and c <= '9') {
        return c - '0';
    } else if ('A' <= c and c <= 'Z') {
        return c - 'A' + 10;
    } else if ('a' <= c and c <= 'z') {
        return c - 'a' + 10;
    } else {
        return @maxValue(u8);
    }
}

fn parseIp6(buf: []const u8) !Address {
    var result: Address = undefined;
    result.family = linux.AF_INET6;
    result.scope_id = 0;
    const ip_slice = result.addr[0..];

    var x: u16 = 0;
    var saw_any_digits = false;
    var index: u8 = 0;
    var scope_id = false;
    for (buf) |c| {
        if (scope_id) {
            if (c >= '0' and c <= '9') {
                const digit = c - '0';
                if (@mulWithOverflow(u32, result.scope_id, 10, &result.scope_id)) {
                    return error.Overflow;
                }
                if (@addWithOverflow(u32, result.scope_id, digit, &result.scope_id)) {
                    return error.Overflow;
                }
            } else {
                return error.InvalidChar;
            }
        } else if (c == ':') {
            if (!saw_any_digits) {
                return error.InvalidChar;
            }
            if (index == 14) {
                return error.JunkAtEnd;
            }
            ip_slice[index] = @truncate(u8, x >> 8);
            index += 1;
            ip_slice[index] = @truncate(u8, x);
            index += 1;

            x = 0;
            saw_any_digits = false;
        } else if (c == '%') {
            if (!saw_any_digits) {
                return error.InvalidChar;
            }
            if (index == 14) {
                ip_slice[index] = @truncate(u8, x >> 8);
                index += 1;
                ip_slice[index] = @truncate(u8, x);
                index += 1;
            }
            scope_id = true;
            saw_any_digits = false;
        } else {
            const digit = hexDigit(c);
            if (digit == @maxValue(u8)) {
                return error.InvalidChar;
            }
            if (@mulWithOverflow(u16, x, 16, &x)) {
                return error.Overflow;
            }
            if (@addWithOverflow(u16, x, digit, &x)) {
                return error.Overflow;
            }
            saw_any_digits = true;
        }
    }

    if (!saw_any_digits) {
        return error.Incomplete;
    }

    if (scope_id) {
        return result;
    }

    if (index == 14) {
        ip_slice[14] = @truncate(u8, x >> 8);
        ip_slice[15] = @truncate(u8, x);
        return result;
    }

    return error.Incomplete;
}

fn parseIp4(buf: []const u8) !u32 {
    var result: u32 = undefined;
    const out_ptr = ([]u8)((&result)[0..1]);

    var x: u8 = 0;
    var index: u8 = 0;
    var saw_any_digits = false;
    for (buf) |c| {
        if (c == '.') {
            if (!saw_any_digits) {
                return error.InvalidChar;
            }
            if (index == 3) {
                return error.JunkAtEnd;
            }
            out_ptr[index] = x;
            index += 1;
            x = 0;
            saw_any_digits = false;
        } else if (c >= '0' and c <= '9') {
            saw_any_digits = true;
            const digit = c - '0';
            if (@mulWithOverflow(u8, x, 10, &x)) {
                return error.Overflow;
            }
            if (@addWithOverflow(u8, x, digit, &x)) {
                return error.Overflow;
            }
        } else {
            return error.InvalidChar;
        } 
    }
    if (index == 3 and saw_any_digits) {
        out_ptr[index] = x;
        return result;
    }

    return error.Incomplete;
}
