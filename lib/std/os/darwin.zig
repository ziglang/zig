const std = @import("std");
const builtin = @import("builtin");
const log = std.log;
const mem = std.mem;

pub usingnamespace std.c;
pub usingnamespace mach_task;

const mach_task = if (builtin.target.isDarwin()) struct {
    pub const MachError = error{
        /// Not enough permissions held to perform the requested kernel
        /// call.
        PermissionDenied,
        /// Kernel returned an unhandled and unexpected error code.
        /// This is a catch-all for any yet unobserved kernel response
        /// to some Mach message.
        Unexpected,
    };

    pub const MachTask = struct {
        port: std.c.mach_port_name_t,

        pub fn isValid(self: MachTask) bool {
            return self.port != 0;
        }

        pub fn getCurrProtection(task: MachTask, address: u64, len: usize) MachError!std.c.vm_prot_t {
            var base_addr = address;
            var base_len: std.c.mach_vm_size_t = if (len == 1) 2 else len;
            var objname: std.c.mach_port_t = undefined;
            var info: std.c.vm_region_submap_info_64 = undefined;
            var count: std.c.mach_msg_type_number_t = std.c.VM_REGION_SUBMAP_SHORT_INFO_COUNT_64;
            switch (std.c.getKernError(std.c.mach_vm_region(
                task.port,
                &base_addr,
                &base_len,
                std.c.VM_REGION_BASIC_INFO_64,
                @ptrCast(std.c.vm_region_info_t, &info),
                &count,
                &objname,
            ))) {
                .SUCCESS => return info.protection,
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("mach_vm_region kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub fn setMaxProtection(task: MachTask, address: u64, len: usize, prot: std.c.vm_prot_t) MachError!void {
            return task.setProtectionImpl(address, len, true, prot);
        }

        pub fn setCurrProtection(task: MachTask, address: u64, len: usize, prot: std.c.vm_prot_t) MachError!void {
            return task.setProtectionImpl(address, len, false, prot);
        }

        fn setProtectionImpl(task: MachTask, address: u64, len: usize, set_max: bool, prot: std.c.vm_prot_t) MachError!void {
            switch (std.c.getKernError(std.c.mach_vm_protect(task.port, address, len, @boolToInt(set_max), prot))) {
                .SUCCESS => return,
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("mach_vm_protect kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        /// Will write to VM even if current protection attributes specifically prohibit
        /// us from doing so, by temporarily setting protection level to a level with VM_PROT_COPY
        /// variant, and resetting after a successful or unsuccessful write.
        pub fn writeMemProtected(task: MachTask, address: u64, buf: []const u8, arch: std.Target.Cpu.Arch) MachError!usize {
            const curr_prot = try task.getCurrProtection(address, buf.len);
            try task.setCurrProtection(
                address,
                buf.len,
                std.c.PROT.READ | std.c.PROT.WRITE | std.c.PROT.COPY,
            );
            defer {
                task.setCurrProtection(address, buf.len, curr_prot) catch {};
            }
            return task.writeMem(address, buf, arch);
        }

        pub fn writeMem(task: MachTask, address: u64, buf: []const u8, arch: std.Target.Cpu.Arch) MachError!usize {
            const count = buf.len;
            var total_written: usize = 0;
            var curr_addr = address;
            const page_size = try getPageSize(task); // TODO we probably can assume value here
            var out_buf = buf[0..];

            while (total_written < count) {
                const curr_size = maxBytesLeftInPage(page_size, curr_addr, count - total_written);
                switch (std.c.getKernError(std.c.mach_vm_write(
                    task.port,
                    curr_addr,
                    @ptrToInt(out_buf.ptr),
                    @intCast(std.c.mach_msg_type_number_t, curr_size),
                ))) {
                    .SUCCESS => {},
                    .FAILURE => return error.PermissionDenied,
                    else => |err| {
                        log.err("mach_vm_write kernel call failed with error code: {s}", .{@tagName(err)});
                        return error.Unexpected;
                    },
                }

                switch (arch) {
                    .aarch64 => {
                        var mattr_value: std.c.vm_machine_attribute_val_t = std.c.MATTR_VAL_CACHE_FLUSH;
                        switch (std.c.getKernError(std.c.vm_machine_attribute(
                            task.port,
                            curr_addr,
                            curr_size,
                            std.c.MATTR_CACHE,
                            &mattr_value,
                        ))) {
                            .SUCCESS => {},
                            .FAILURE => return error.PermissionDenied,
                            else => |err| {
                                log.err("vm_machine_attribute kernel call failed with error code: {s}", .{@tagName(err)});
                                return error.Unexpected;
                            },
                        }
                    },
                    .x86_64 => {},
                    else => unreachable,
                }

                out_buf = out_buf[curr_size..];
                total_written += curr_size;
                curr_addr += curr_size;
            }

            return total_written;
        }

        pub fn readMem(task: MachTask, address: u64, buf: []u8) MachError!usize {
            const count = buf.len;
            var total_read: usize = 0;
            var curr_addr = address;
            const page_size = try getPageSize(task); // TODO we probably can assume value here
            var out_buf = buf[0..];

            while (total_read < count) {
                const curr_size = maxBytesLeftInPage(page_size, curr_addr, count - total_read);
                var curr_bytes_read: std.c.mach_msg_type_number_t = 0;
                var vm_memory: std.c.vm_offset_t = undefined;
                switch (std.c.getKernError(std.c.mach_vm_read(task.port, curr_addr, curr_size, &vm_memory, &curr_bytes_read))) {
                    .SUCCESS => {},
                    .FAILURE => return error.PermissionDenied,
                    else => |err| {
                        log.err("mach_vm_read kernel call failed with error code: {s}", .{@tagName(err)});
                        return error.Unexpected;
                    },
                }

                @memcpy(out_buf[0..].ptr, @intToPtr([*]const u8, vm_memory), curr_bytes_read);
                _ = std.c.vm_deallocate(std.c.mach_task_self(), vm_memory, curr_bytes_read);

                out_buf = out_buf[curr_bytes_read..];
                curr_addr += curr_bytes_read;
                total_read += curr_bytes_read;
            }

            return total_read;
        }

        fn maxBytesLeftInPage(page_size: usize, address: u64, count: usize) usize {
            var left = count;
            if (page_size > 0) {
                const page_offset = address % page_size;
                const bytes_left_in_page = page_size - page_offset;
                if (count > bytes_left_in_page) {
                    left = bytes_left_in_page;
                }
            }
            return left;
        }

        fn getPageSize(task: MachTask) MachError!usize {
            if (task.isValid()) {
                var info_count = std.c.TASK_VM_INFO_COUNT;
                var vm_info: std.c.task_vm_info_data_t = undefined;
                switch (std.c.getKernError(std.c.task_info(
                    task.port,
                    std.c.TASK_VM_INFO,
                    @ptrCast(std.c.task_info_t, &vm_info),
                    &info_count,
                ))) {
                    .SUCCESS => return @intCast(usize, vm_info.page_size),
                    else => {},
                }
            }
            var page_size: std.c.vm_size_t = undefined;
            switch (std.c.getKernError(std.c._host_page_size(std.c.mach_host_self(), &page_size))) {
                .SUCCESS => return page_size,
                else => |err| {
                    log.err("_host_page_size kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }
    };

    pub fn machTaskForPid(pid: std.os.pid_t) MachError!MachTask {
        var port: std.c.mach_port_name_t = undefined;
        switch (std.c.getKernError(std.c.task_for_pid(std.c.mach_task_self(), pid, &port))) {
            .SUCCESS => {},
            .FAILURE => return error.PermissionDenied,
            else => |err| {
                log.err("task_for_pid kernel call failed with error code: {s}", .{@tagName(err)});
                return error.Unexpected;
            },
        }
        return MachTask{ .port = port };
    }
} else struct {};
