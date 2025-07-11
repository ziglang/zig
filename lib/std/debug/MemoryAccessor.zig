//! Reads memory from any address of the current location using OS-specific
//! syscalls, bypassing memory page protection. Useful for stack unwinding.

const builtin = @import("builtin");
const native_os = builtin.os.tag;

const std = @import("../std.zig");
const posix = std.posix;
const File = std.fs.File;
const page_size_min = std.heap.page_size_min;

const MemoryAccessor = @This();

pub fn load(comptime Type: type, address: usize) ?Type {
    if (!isValidMemory(address)) return null;
    var result: Type = undefined;
    @memcpy(std.mem.asBytes(&result), @as([*]const u8, @ptrFromInt(address)));
    return result;
}

pub fn isValidMemory(address: usize) bool {
    // We are unable to determine validity of memory for freestanding targets
    if (native_os == .freestanding or native_os == .other or native_os == .uefi) return true;

    const page_size = std.heap.pageSize();
    const aligned_address = address & ~(page_size - 1);
    if (aligned_address == 0) return false;
    const aligned_memory = @as([*]align(page_size_min) u8, @ptrFromInt(aligned_address))[0..page_size];

    if (native_os == .windows) {
        const windows = std.os.windows;

        var memory_info: windows.MEMORY_BASIC_INFORMATION = undefined;

        // The only error this function can throw is ERROR_INVALID_PARAMETER.
        // supply an address that invalid i'll be thrown.
        const rc = windows.VirtualQuery(@ptrCast(aligned_memory), &memory_info, aligned_memory.len) catch {
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
