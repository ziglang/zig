//! Reads memory from any address of the current location using OS-specific
//! syscalls, bypassing memory page protection. Useful for stack unwinding.

const builtin = @import("builtin");
const native_os = builtin.os.tag;

const std = @import("../std.zig");
const posix = std.posix;
const File = std.fs.File;
const page_size = std.mem.page_size;

const MemoryAccessor = @This();

var cached_pid: posix.pid_t = -1;

mem: switch (native_os) {
    .linux => File,
    else => void,
},

pub const init: MemoryAccessor = .{
    .mem = switch (native_os) {
        .linux => .{ .handle = -1 },
        else => {},
    },
};

fn read(ma: *MemoryAccessor, address: usize, buf: []u8) bool {
    switch (native_os) {
        .linux => while (true) switch (ma.mem.handle) {
            -2 => break,
            -1 => {
                const linux = std.os.linux;
                const pid = switch (@atomicLoad(posix.pid_t, &cached_pid, .monotonic)) {
                    -1 => pid: {
                        const pid = linux.getpid();
                        @atomicStore(posix.pid_t, &cached_pid, pid, .monotonic);
                        break :pid pid;
                    },
                    else => |pid| pid,
                };
                const bytes_read = linux.process_vm_readv(
                    pid,
                    &.{.{ .base = buf.ptr, .len = buf.len }},
                    &.{.{ .base = @ptrFromInt(address), .len = buf.len }},
                    0,
                );
                switch (linux.E.init(bytes_read)) {
                    .SUCCESS => return bytes_read == buf.len,
                    .FAULT => return false,
                    .INVAL, .PERM, .SRCH => unreachable, // own pid is always valid
                    .NOMEM => {},
                    .NOSYS => {}, // QEMU is known not to implement this syscall.
                    else => unreachable, // unexpected
                }
                var path_buf: [
                    std.fmt.count("/proc/{d}/mem", .{std.math.minInt(posix.pid_t)})
                ]u8 = undefined;
                const path = std.fmt.bufPrint(&path_buf, "/proc/{d}/mem", .{pid}) catch
                    unreachable;
                ma.mem = std.fs.openFileAbsolute(path, .{}) catch {
                    ma.mem.handle = -2;
                    break;
                };
            },
            else => return (ma.mem.pread(buf, address) catch return false) == buf.len,
        },
        else => {},
    }
    if (!isValidMemory(address)) return false;
    @memcpy(buf, @as([*]const u8, @ptrFromInt(address)));
    return true;
}

pub fn load(ma: *MemoryAccessor, comptime Type: type, address: usize) ?Type {
    var result: Type = undefined;
    return if (ma.read(address, std.mem.asBytes(&result))) result else null;
}

pub fn isValidMemory(address: usize) bool {
    // We are unable to determine validity of memory for freestanding targets
    if (native_os == .freestanding or native_os == .uefi) return true;

    const aligned_address = address & ~@as(usize, @intCast((page_size - 1)));
    if (aligned_address == 0) return false;
    const aligned_memory = @as([*]align(page_size) u8, @ptrFromInt(aligned_address))[0..page_size];

    if (native_os == .windows) {
        const windows = std.os.windows;

        var memory_info: windows.MEMORY_BASIC_INFORMATION = undefined;

        // The only error this function can throw is ERROR_INVALID_PARAMETER.
        // supply an address that invalid i'll be thrown.
        const rc = windows.VirtualQuery(aligned_memory, &memory_info, aligned_memory.len) catch {
            return false;
        };

        // Result code has to be bigger than zero (number of bytes written)
        if (rc == 0) {
            return false;
        }

        // Free pages cannot be read, they are unmapped
        if (memory_info.State == windows.MEM_FREE) {
            return false;
        }

        return true;
    } else if (have_msync) {
        posix.msync(aligned_memory, posix.MSF.ASYNC) catch |err| {
            switch (err) {
                error.UnmappedMemory => return false,
                else => unreachable,
            }
        };

        return true;
    } else {
        // We are unable to determine validity of memory on this target.
        return true;
    }
}

const have_msync = switch (native_os) {
    .wasi, .emscripten, .windows => false,
    else => true,
};
