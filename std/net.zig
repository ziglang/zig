const linux = @import("linux.zig");
const errno = @import("errno.zig");
const assert = @import("debug.zig").assert;

pub error SigInterrupt;
pub error Unexpected;
pub error Io;
pub error TimedOut;
pub error ConnectionReset;
pub error ConnectionRefused;
pub error NoMem;
pub error NotSocket;
pub error BadFd;

struct Connection {
    socket_fd: i32,

    pub fn send(c: Connection, buf: []const u8) -> %isize {
        const send_ret = linux.sendto(c.socket_fd, buf.ptr, buf.len, 0, null, 0);
        const send_err = linux.get_errno(send_ret);
        switch (send_err) {
            0 => return send_ret,
            errno.EINVAL => unreachable{},
            errno.EFAULT => unreachable{},
            errno.ECONNRESET => return error.ConnectionReset,
            errno.EINTR => return error.SigInterrupt,
            // TODO there are more possible errors
            else => return error.Unexpected,
        }
    }

    pub fn recv(c: Connection, buf: []u8) -> %[]u8 {
        const recv_ret = linux.recvfrom(c.socket_fd, buf.ptr, buf.len, 0, null, null);
        const recv_err = linux.get_errno(recv_ret);
        switch (recv_err) {
            0 => return buf[0...recv_ret],
            errno.EINVAL => unreachable{},
            errno.EFAULT => unreachable{},
            errno.ENOTSOCK => return error.NotSocket,
            errno.EINTR => return error.SigInterrupt,
            errno.ENOMEM => return error.NoMem,
            errno.ECONNREFUSED => return error.ConnectionRefused,
            errno.EBADF => return error.BadFd,
            // TODO more error values
            else => return error.Unexpected,
        }
    }

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
    family: u16,
    scope_id: u32,
    addr: [16]u8,
    sort_key: i32,
}

pub fn lookup(hostname: []const u8, out_addrs: []Address) -> %[]Address {
    if (hostname.len == 0) {

/*
		if (family != AF_INET6)
			buf[cnt++] = (struct address){ .family = AF_INET, .addr = { 127,0,0,1 } };
		if (family != AF_INET)
			buf[cnt++] = (struct address){ .family = AF_INET6, .addr = { [15] = 1 } };
            */
        unreachable{} // TODO
    }

    switch (parse_ip_literal(hostname)) {
        Ok => |addr| {
            out_addrs[0] = addr;
            return out_addrs[0...1];
        },
        else => {},
    };

    unreachable{} // TODO
}

pub fn connect_addr(addr: &Address, port: u16) -> %Connection {
    const socket_ret = linux.socket(addr.family, linux.SOCK_STREAM, linux.PROTO_tcp);
    const socket_err = linux.get_errno(socket_ret);
    if (socket_err > 0) {
        // TODO figure out possible errors from socket()
        return error.Unexpected;
    }
    const socket_fd = i32(socket_ret);

    const connect_ret = if (addr.family == linux.AF_INET) {
        var os_addr: linux.sockaddr_in = undefined;
        os_addr.family = addr.family;
        os_addr.port = swap_if_little_endian(u16, port);
        @memcpy((&u8)(&os_addr.addr), &addr.addr[0], 4);
        @memset(&os_addr.zero, 0, @sizeof(@typeof(os_addr.zero)));
        linux.connect(socket_fd, (&linux.sockaddr)(&os_addr), @sizeof(linux.sockaddr_in))
    } else if (addr.family == linux.AF_INET6) {
        var os_addr: linux.sockaddr_in6 = undefined;
        os_addr.family = addr.family;
        os_addr.port = swap_if_little_endian(u16, port);
        os_addr.flowinfo = 0;
        os_addr.scope_id = addr.scope_id;
        @memcpy(&os_addr.addr[0], &addr.addr[0], 16);
        linux.connect(socket_fd, (&linux.sockaddr)(&os_addr), @sizeof(linux.sockaddr_in6))
    } else {
        unreachable{}
    };
    const connect_err = linux.get_errno(connect_ret);
    if (connect_err > 0) {
        switch (connect_err) {
            errno.ETIMEDOUT => return error.TimedOut,
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

pub fn connect(hostname: []const u8, port: u16) -> %Connection {
    var addrs_buf: [1]Address = undefined;
    const addrs_slice = %return lookup(hostname, addrs_buf);
    const main_addr = &addrs_slice[0];

    return connect_addr(main_addr, port);
}

pub error InvalidIpLiteral;

pub fn parse_ip_literal(buf: []const u8) -> %Address {
    switch (parse_ip4(buf)) {
        Ok => |ip4| {
            var result: Address = undefined;
            @memcpy(&result.addr[0], (&u8)(&ip4), @sizeof(u32));
            result.family = linux.AF_INET;
            result.scope_id = 0;
            return result;
        },
        else => {},
    }
    switch (parse_ip6(buf)) {
        Ok => |addr| {
            return addr;
        },
        else => {},
    }

    return error.InvalidIpLiteral;
}

fn hex_digit(c: u8) -> u8 {
    // TODO use switch with range
    if ('0' <= c && c <= '9') {
        c - '0'
    } else if ('A' <= c && c <= 'Z') {
        c - 'A' + 10
    } else if ('a' <= c && c <= 'z') {
        c - 'a' + 10
    } else {
        @max_value(u8)
    }
}

error InvalidChar;
error Overflow;
error JunkAtEnd;
error Incomplete;

#static_eval_enable(false)
fn parse_ip6(buf: []const u8) -> %Address {
    var result: Address = undefined;
    result.family = linux.AF_INET6;
    result.scope_id = 0;
    const ip_slice = result.addr[0...];

    var x: u16 = 0;
    var saw_any_digits = false;
    var index: u8 = 0;
    var scope_id = false;
    for (buf) |c| {
        if (scope_id) {
            if (c >= '0' && c <= '9') {
                const digit = c - '0';
                if (@mul_with_overflow(u32, result.scope_id, 10, &result.scope_id)) {
                    return error.Overflow;
                }
                if (@add_with_overflow(u32, result.scope_id, digit, &result.scope_id)) {
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
            const digit = hex_digit(c);
            if (digit == @max_value(u8)) {
                return error.InvalidChar;
            }
            if (@mul_with_overflow(u16, x, 16, &x)) {
                return error.Overflow;
            }
            if (@add_with_overflow(u16, x, digit, &x)) {
                return error.Overflow;
            }
            saw_any_digits = true;
        }
    }

    if (!saw_any_digits) {
        return error.Incomplete;
    }

    /*
	if (p) {
		if (isdigit(*++p)) scopeid = strtoull(p, &z, 10);
		else z = p-1;
		if (*z) {
			if (!IN6_IS_ADDR_LINKLOCAL(&a6) &&
			    !IN6_IS_ADDR_MC_LINKLOCAL(&a6))
				return EAI_NONAME;
			scopeid = if_nametoindex(p);
			if (!scopeid) return EAI_NONAME;
		}
		if (scopeid > UINT_MAX) return EAI_NONAME;
	}
    */

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

fn parse_ip4(buf: []const u8) -> %u32 {
    var result: u32 = undefined;
    const out_ptr = ([]u8)((&result)[0...1]);

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
        } else if (c >= '0' && c <= '9') {
            saw_any_digits = true;
            const digit = c - '0';
            if (@mul_with_overflow(u8, x, 10, &x)) {
                return error.Overflow;
            }
            if (@add_with_overflow(u8, x, digit, &x)) {
                return error.Overflow;
            }
        } else {
            return error.InvalidChar;
        } 
    }
    if (index == 3 && saw_any_digits) {
        out_ptr[index] = x;
        return result;
    }

    return error.Incomplete;
}


#attribute("test")
fn test_parse_ip4() {
    assert(%%parse_ip4("127.0.0.1") == swap_if_little_endian(u32, 0x7f000001));
    switch (parse_ip4("256.0.0.1")) { Overflow => {}, else => unreachable {}, }
    switch (parse_ip4("x.0.0.1")) { InvalidChar => {}, else => unreachable {}, }
    switch (parse_ip4("127.0.0.1.1")) { JunkAtEnd => {}, else => unreachable {}, }
    switch (parse_ip4("127.0.0.")) { Incomplete => {}, else => unreachable {}, }
    switch (parse_ip4("100..0.1")) { InvalidChar => {}, else => unreachable {}, }
}

#attribute("test")
fn test_parse_ip6() {
    {
        const addr = %%parse_ip6("FF01:0:0:0:0:0:0:FB");
        assert(addr.addr[0] == 0xff);
        assert(addr.addr[1] == 0x01);
        assert(addr.addr[2] == 0x00);
    }
}

#attribute("test")
fn test_lookup_simple_ip() {
    {
        var addrs_buf: [5]Address = undefined;
        const addrs = %%lookup("192.168.1.1", addrs_buf);
        assert(addrs.len == 1);
        const addr = addrs[0];
        assert(addr.family == linux.AF_INET);
        assert(addr.addr[0] == 192);
        assert(addr.addr[1] == 168);
        assert(addr.addr[2] == 1);
        assert(addr.addr[3] == 1);
    }
}

fn swap_if_little_endian(inline T: type, x: T) -> T {
    if (@compile_var("is_big_endian")) x else endian_swap(T, x)
}

fn endian_swap(inline T: type, x: T) -> T {
    const x_slice = ([]u8)((&const x)[0...1]);
    var result: T = undefined;
    const result_slice = ([]u8)((&result)[0...1]);
    for (result_slice) |*b, i| {
        *b = x_slice[@sizeof(T) - i - 1];
    }
    return result;
}
