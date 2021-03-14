const std = @import("std");
const c = std.c;
const os = std.os;
const testing = std.testing;

test "getaddrinfo" {
    const port = 9999;
    const port_c = try std.fmt.allocPrint(testing.allocator, "{}\x00", .{port});
    defer allocator.free(port_c);

    var res: *os.addrinfo = undefined;
    defer sys.freeaddrinfo(res);
    // Question!
    //
    // Is this the right way to construct a null c pointer?
    // Or is it just `null`?
    const zero = @intToPtr(?[*:0]const u8, 0x0);
    const status = c.getaddrinfo(zero, port_c, zero, &res);

    expect(rc == 0);
}
