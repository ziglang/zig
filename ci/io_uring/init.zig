// Source: https://mergeboard.com/blog/2-qemu-microvm-docker/

const std = @import("std");
const io = std.io;
const os = std.os;
const linux = std.os.linux;

pub fn mount_check(source: [*:0]const u8, target: [*:0]const u8, fstype: [*:0]const u8, flags: u32, data: [*:0]const u8) !void {
    var stdout = io.getStdOut().writer();
    var err = os.errno(linux.access(target, linux.F_OK));
    switch (err) {
        .SUCCESS => {},
        .NOENT => {
            try stdout.print("Creating {s}\n", .{target});
            err = os.errno(linux.mkdir(target, 0o755));
            if (err != .SUCCESS) {
                try io.getStdErr().writeAll("Creating directory failed!\n");
                return os.unexpectedErrno(err);
            }
        },
        else => return os.unexpectedErrno(err),
    }

    try stdout.print("Mounting {s}\n", .{target});
    err = os.errno(linux.mount(source, target, fstype, flags, @ptrToInt(data)));
    if (err != .SUCCESS) {
        try io.getStdErr().writeAll("Mount failed!\n");
        return os.unexpectedErrno(err);
    }
}

pub fn main() !void {
    try mount_check("none", "/proc", "proc", 0, "");
    try mount_check("none", "/dev/pts", "devpts", 0, "");
    try mount_check("none", "/dev/mqueue", "mqueue", 0, "");
    try mount_check("none", "/dev/shm", "tmpfs", 0, "");
    try mount_check("none", "/sys", "sysfs", 0, "");
    //try mount_check("none", "/sys/fs/cgroup", "cgroup", 0, "");
    try mount_check("hostfiles", "/hostfiles", "9p", 0, "trans=virtio,version=9p2000.L,msize=52428800");

    const exe = "/bin/sh";
    const args = [_:null] ?[*:0]const u8{exe, "-c", "ifup lo && /hostfiles/io_uring_tests 2>&1 | tee /hostfiles/`uname -r`/output.tests.log"};
    const envp = [_:null] ?[*:0]const u8{"PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"};

    const err = os.errno(linux.execve(exe, &args, &envp));
    if (err != .SUCCESS) {
        try io.getStdErr().writeAll("Exec failed\n");
        return os.unexpectedErrno(err);
    }
}
