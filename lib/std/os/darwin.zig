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

    pub const MachTask = extern struct {
        port: std.c.mach_port_name_t,

        pub fn isValid(self: MachTask) bool {
            return self.port != std.c.TASK_NULL;
        }

        pub fn pidForTask(self: MachTask) MachError!std.os.pid_t {
            var pid: std.os.pid_t = undefined;
            switch (std.c.getKernError(std.c.pid_for_task(self.port, &pid))) {
                .SUCCESS => return pid,
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("pid_for_task kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub fn allocatePort(self: MachTask, right: std.c.MACH_PORT_RIGHT) MachError!MachTask {
            var out_port: std.c.mach_port_name_t = undefined;
            switch (std.c.getKernError(std.c.mach_port_allocate(
                self.port,
                @enumToInt(right),
                &out_port,
            ))) {
                .SUCCESS => return .{ .port = out_port },
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("mach_task_allocate kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub fn deallocatePort(self: MachTask, port: MachTask) void {
            _ = std.c.getKernError(std.c.mach_port_deallocate(self.port, port.port));
        }

        pub fn insertRight(self: MachTask, port: MachTask, msg: std.c.MACH_MSG_TYPE) !void {
            switch (std.c.getKernError(std.c.mach_port_insert_right(
                self.port,
                port.port,
                port.port,
                @enumToInt(msg),
            ))) {
                .SUCCESS => return,
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("mach_port_insert_right kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub const PortInfo = struct {
            mask: std.c.exception_mask_t,
            masks: [std.c.EXC_TYPES_COUNT]std.c.exception_mask_t,
            ports: [std.c.EXC_TYPES_COUNT]std.c.mach_port_t,
            behaviors: [std.c.EXC_TYPES_COUNT]std.c.exception_behavior_t,
            flavors: [std.c.EXC_TYPES_COUNT]std.c.thread_state_flavor_t,
            count: std.c.mach_msg_type_number_t,
        };

        pub fn getExceptionPorts(self: MachTask, mask: std.c.exception_mask_t) !PortInfo {
            var info = PortInfo{
                .mask = mask,
                .masks = undefined,
                .ports = undefined,
                .behaviors = undefined,
                .flavors = undefined,
                .count = 0,
            };
            info.count = info.ports.len / @sizeOf(std.c.mach_port_t);

            switch (std.c.getKernError(std.c.task_get_exception_ports(
                self.port,
                info.mask,
                &info.masks,
                &info.count,
                &info.ports,
                &info.behaviors,
                &info.flavors,
            ))) {
                .SUCCESS => return info,
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("task_get_exception_ports kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub fn setExceptionPorts(
            self: MachTask,
            mask: std.c.exception_mask_t,
            new_port: MachTask,
            behavior: std.c.exception_behavior_t,
            new_flavor: std.c.thread_state_flavor_t,
        ) !void {
            switch (std.c.getKernError(std.c.task_set_exception_ports(
                self.port,
                mask,
                new_port.port,
                behavior,
                new_flavor,
            ))) {
                .SUCCESS => return,
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("task_set_exception_ports kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub const RegionInfo = struct {
            pub const Tag = enum {
                basic,
                extended,
                top,
            };

            base_addr: u64,
            tag: Tag,
            info: union {
                basic: std.c.vm_region_basic_info_64,
                extended: std.c.vm_region_extended_info,
                top: std.c.vm_region_top_info,
            },
        };

        pub fn getRegionInfo(
            task: MachTask,
            address: u64,
            len: usize,
            tag: RegionInfo.Tag,
        ) MachError!RegionInfo {
            var info: RegionInfo = .{
                .base_addr = address,
                .tag = tag,
                .info = undefined,
            };
            switch (tag) {
                .basic => info.info = .{ .basic = undefined },
                .extended => info.info = .{ .extended = undefined },
                .top => info.info = .{ .top = undefined },
            }
            var base_len: std.c.mach_vm_size_t = if (len == 1) 2 else len;
            var objname: std.c.mach_port_t = undefined;
            var count: std.c.mach_msg_type_number_t = switch (tag) {
                .basic => std.c.VM_REGION_BASIC_INFO_COUNT,
                .extended => std.c.VM_REGION_EXTENDED_INFO_COUNT,
                .top => std.c.VM_REGION_TOP_INFO_COUNT,
            };
            switch (std.c.getKernError(std.c.mach_vm_region(
                task.port,
                &info.base_addr,
                &base_len,
                switch (tag) {
                    .basic => std.c.VM_REGION_BASIC_INFO_64,
                    .extended => std.c.VM_REGION_EXTENDED_INFO,
                    .top => std.c.VM_REGION_TOP_INFO,
                },
                switch (tag) {
                    .basic => @ptrCast(std.c.vm_region_info_t, &info.info.basic),
                    .extended => @ptrCast(std.c.vm_region_info_t, &info.info.extended),
                    .top => @ptrCast(std.c.vm_region_info_t, &info.info.top),
                },
                &count,
                &objname,
            ))) {
                .SUCCESS => return info,
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("mach_vm_region kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub const RegionSubmapInfo = struct {
            pub const Tag = enum {
                short,
                full,
            };

            tag: Tag,
            base_addr: u64,
            info: union {
                short: std.c.vm_region_submap_short_info_64,
                full: std.c.vm_region_submap_info_64,
            },
        };

        pub fn getRegionSubmapInfo(
            task: MachTask,
            address: u64,
            len: usize,
            nesting_depth: u32,
            tag: RegionSubmapInfo.Tag,
        ) MachError!RegionSubmapInfo {
            var info: RegionSubmapInfo = .{
                .base_addr = address,
                .tag = tag,
                .info = undefined,
            };
            switch (tag) {
                .short => info.info = .{ .short = undefined },
                .full => info.info = .{ .full = undefined },
            }
            var nesting = nesting_depth;
            var base_len: std.c.mach_vm_size_t = if (len == 1) 2 else len;
            var count: std.c.mach_msg_type_number_t = switch (tag) {
                .short => std.c.VM_REGION_SUBMAP_SHORT_INFO_COUNT_64,
                .full => std.c.VM_REGION_SUBMAP_INFO_COUNT_64,
            };
            switch (std.c.getKernError(std.c.mach_vm_region_recurse(
                task.port,
                &info.base_addr,
                &base_len,
                &nesting,
                switch (tag) {
                    .short => @ptrCast(std.c.vm_region_recurse_info_t, &info.info.short),
                    .full => @ptrCast(std.c.vm_region_recurse_info_t, &info.info.full),
                },
                &count,
            ))) {
                .SUCCESS => return info,
                .FAILURE => return error.PermissionDenied,
                else => |err| {
                    log.err("mach_vm_region kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub fn getCurrProtection(task: MachTask, address: u64, len: usize) MachError!std.c.vm_prot_t {
            const info = try task.getRegionSubmapInfo(address, len, 0, .short);
            return info.info.short.protection;
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

        pub fn basicTaskInfo(task: MachTask) MachError!std.c.mach_task_basic_info {
            var info: std.c.mach_task_basic_info = undefined;
            var count = std.c.MACH_TASK_BASIC_INFO_COUNT;
            switch (std.c.getKernError(std.c.task_info(
                task.port,
                std.c.MACH_TASK_BASIC_INFO,
                @ptrCast(std.c.task_info_t, &info),
                &count,
            ))) {
                .SUCCESS => return info,
                else => |err| {
                    log.err("task_info kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub fn @"resume"(task: MachTask) MachError!void {
            switch (std.c.getKernError(std.c.task_resume(task.port))) {
                .SUCCESS => {},
                else => |err| {
                    log.err("task_resume kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub fn @"suspend"(task: MachTask) MachError!void {
            switch (std.c.getKernError(std.c.task_suspend(task.port))) {
                .SUCCESS => {},
                else => |err| {
                    log.err("task_suspend kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        const ThreadList = struct {
            buf: []MachThread,

            pub fn deinit(list: ThreadList) void {
                const self_task = machTaskForSelf();
                _ = std.c.vm_deallocate(
                    self_task.port,
                    @ptrToInt(list.buf.ptr),
                    @intCast(std.c.vm_size_t, list.buf.len * @sizeOf(std.c.mach_port_t)),
                );
            }
        };

        pub fn getThreads(task: MachTask) MachError!ThreadList {
            var thread_list: std.c.mach_port_array_t = undefined;
            var thread_count: std.c.mach_msg_type_number_t = undefined;
            switch (std.c.getKernError(std.c.task_threads(task.port, &thread_list, &thread_count))) {
                .SUCCESS => return ThreadList{ .buf = @ptrCast([*]MachThread, thread_list)[0..thread_count] },
                else => |err| {
                    log.err("task_threads kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }
    };

    pub const MachThread = extern struct {
        port: std.c.mach_port_t,

        pub fn isValid(thread: MachThread) bool {
            return thread.port != std.c.THREAD_NULL;
        }

        pub fn getBasicInfo(thread: MachThread) MachError!std.c.thread_basic_info {
            var info: std.c.thread_basic_info = undefined;
            var count = std.c.THREAD_BASIC_INFO_COUNT;
            switch (std.c.getKernError(std.c.thread_info(
                thread.port,
                std.c.THREAD_BASIC_INFO,
                @ptrCast(std.c.thread_info_t, &info),
                &count,
            ))) {
                .SUCCESS => return info,
                else => |err| {
                    log.err("thread_info kernel call failed with error code: {s}", .{@tagName(err)});
                    return error.Unexpected;
                },
            }
        }

        pub fn getIdentifierInfo(thread: MachThread) MachError!std.c.thread_identifier_info {
            var info: std.c.thread_identifier_info = undefined;
            var count = std.c.THREAD_IDENTIFIER_INFO_COUNT;
            switch (std.c.getKernError(std.c.thread_info(
                thread.port,
                std.c.THREAD_IDENTIFIER_INFO,
                @ptrCast(std.c.thread_info_t, &info),
                &count,
            ))) {
                .SUCCESS => return info,
                else => |err| {
                    log.err("thread_info kernel call failed with error code: {s}", .{@tagName(err)});
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

    pub fn machTaskForSelf() MachTask {
        return .{ .port = std.c.mach_task_self() };
    }
} else struct {};
