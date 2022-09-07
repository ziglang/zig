const std = @import("std");

pub const log_level = .info;

pub const Capability = extern struct {
    driver: [16]u8,
    card: [32]u8,
    bus_info: [32]u8,
    version: u32,
    capabilities: u32,
    device_caps: u32,
    reserved: [3]u32,
};

const querycap_ioctl = std.os.linux.ioctlFunc(.read, 'V', 0, Capability);

pub fn main() !u8 {
    var i: u8 = 0;
    while (i <= 4) : (i += 1) {
        var filename_buf: [100]u8 = undefined;
        const filename = std.fmt.bufPrintZ(&filename_buf, "/dev/video{}", .{i}) catch unreachable;
        var fd = std.os.openZ(filename, std.os.O.RDONLY, 0) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        defer std.os.close(fd);

        var cap: Capability = undefined;

        switch (std.os.errno(querycap_ioctl(fd, &cap))) {
            .SUCCESS => {},
            else => |e| {
                // shouldn't be an issue, we're just testing we can call the ioctl
                std.log.debug("querycap ioctl failed, error={}", .{e});
                continue;
            },
        }

        std.log.debug("{s}:", .{filename});
        std.log.debug("  driver '{s}'", .{std.mem.sliceTo(&cap.driver, 0)});
        std.log.debug("  card '{s}'", .{std.mem.sliceTo(&cap.card, 0)});
        std.log.debug("  bus_info '{s}'", .{std.mem.sliceTo(&cap.bus_info, 0)});
        std.log.debug("  version 0x{x}", .{cap.version});
        std.log.debug("  caps 0x{x}", .{cap.capabilities});
        std.log.debug("  device_caps 0x{x}", .{cap.device_caps});
    }
    return 0;
}
