const std = @import("../../../std.zig");

const bits = @import("../bits.zig");
const table = @import("../table.zig");

const cc = bits.cc;
const Status = @import("../status.zig").Status;
const DevicePathProtocol = @import("../protocol.zig").DevicePath;

const Guid = bits.Guid;
const Event = bits.Event;
const Handle = bits.Handle;
const PhysicalAddress = bits.PhysicalAddress;
const VirtualAddress = bits.VirtualAddress;

const ProtocolInterface = *const anyopaque;
const RegistrationValue = *const anyopaque;

/// Boot services are services provided by the system's firmware until the operating system takes
/// over control over the hardware by calling exitBootServices.
///
/// Boot Services must not be used after exitBootServices has been called. The only exception is
/// getMemoryMap, which may be used after the first unsuccessful call to exitBootServices.
/// After successfully calling exitBootServices, system_table.console_in_handle, system_table.con_in,
/// system_table.console_out_handle, system_table.con_out, system_table.standard_error_handle,
/// system_table.std_err, and system_table.boot_services should be set to null. After setting these
/// attributes to null, system_table.hdr.crc32 must be recomputed.
///
/// As the boot_services table may grow with new UEFI versions, it is important to check hdr.header_size.
pub const BootServices = extern struct {
    hdr: table.Header,

    _raiseTpl: *const fn (new_tpl: TaskPriorityLevel) callconv(cc) TaskPriorityLevel,
    _restoreTpl: *const fn (old_tpl: TaskPriorityLevel) callconv(cc) void,

    _allocatePages: *const fn (alloc_type: AllocateType, mem_type: bits.MemoryDescriptor.Type, pages: usize, memory: PhysicalAddress) callconv(cc) Status,
    _freePages: *const fn (memory: [*]align(4096) u8, pages: usize) callconv(cc) Status,
    _getMemoryMap: *const fn (mmap_size: *usize, mmap: ?*anyopaque, mapKey: *MemoryMap.Key, descriptor_size: *usize, descriptor_version: *u32) callconv(cc) Status,
    _allocatePool: *const fn (pool_type: bits.MemoryDescriptor.Type, size: usize, buffer: *[*]align(8) u8) callconv(cc) Status,
    _freePool: *const fn (buffer: [*]align(8) u8) callconv(cc) Status,

    _createEvent: *const fn (type: u32, notify_tpl: TaskPriorityLevel, notify_func: ?EventNotify, notifyCtx: ?EventNotifyContext, event: *Event) callconv(cc) Status,
    _setTimer: *const fn (event: Event, type: TimerKind.Enum, trigger_time: u64) callconv(cc) Status,
    _waitForEvent: *const fn (event_len: usize, events: [*]const Event, index: *usize) callconv(cc) Status,
    _signalEvent: *const fn (event: Event) callconv(cc) Status,
    _closeEvent: *const fn (event: Event) callconv(cc) Status,
    _checkEvent: *const fn (event: Event) callconv(cc) Status,

    _installProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, interface_type: EfiInterfaceType, interface: ProtocolInterface) callconv(cc) Status,
    _reinstallProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, old_interface: ProtocolInterface, new_interface: ProtocolInterface) callconv(cc) Status,
    _uninstallProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: ProtocolInterface) callconv(cc) Status,

    // this function is deprecated, it will not be bound.
    _handleProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: *?ProtocolInterface) callconv(cc) Status,

    reserved: *const anyopaque,

    _registerProtocolNotify: *const fn (protocol: *align(8) const Guid, event: Event, registration: *RegistrationValue) callconv(cc) Status,
    _locateHandle: *const fn (search_type: LocateSearchType, protocol: ?*align(8) const Guid, search_key: ?RegistrationValue, buffer_size: *usize, buffer: [*]Handle) callconv(cc) Status,
    _locateDevicePath: *const fn (protocol: *align(8) const Guid, device_path: **const DevicePathProtocol, device: *Handle) callconv(cc) Status,
    _installConfigurationTable: *const fn (guid: *align(8) const Guid, table: ?*const anyopaque) callconv(cc) Status,

    _loadImage: *const fn (boot_policy: bool, parent_image_handle: Handle, device_path: ?*const DevicePathProtocol, source_buffer: ?[*]const u8, source_size: usize, image_handle: *?Handle) callconv(cc) Status,
    _startImage: *const fn (image_handle: Handle, exit_data_size: ?*usize, exit_data: ?*[*]const u16) callconv(cc) Status,
    _exit: *const fn (image_handle: Handle, exit_status: Status, exit_data_size: usize, exit_data: ?[*]const u16) callconv(cc) Status,
    _unloadImage: *const fn (image_handle: Handle) callconv(cc) Status,
    _exitBootServices: *const fn (image_handle: Handle, map_key: usize) callconv(cc) Status,

    _getNextMonotonicCount: *const fn (count: *u64) callconv(cc) Status,
    _stall: *const fn (microseconds: usize) callconv(cc) Status,
    _setWatchdogTimer: *const fn (timeout: usize, watchdogCode: u64, data_size: usize, watchdog_data: ?[*]const u8) callconv(cc) Status,

    // Following introduced in EFI 1.1
    _connectController: *const fn (controller_handle: Handle, driver_image_handle: ?[*:null]?Handle, remaining_device_path: ?*const DevicePathProtocol, recursive: bool) callconv(cc) Status,
    _disconnectController: *const fn (controller_handle: Handle, driver_image_handle: ?Handle, child_handle: ?Handle) callconv(cc) Status,

    _openProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: *?ProtocolInterface, agent_handle: ?Handle, controller_handle: ?Handle, attributes: OpenProtocolAttributes) callconv(cc) Status,
    _closeProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, agent_handle: Handle, controller_handle: ?Handle) callconv(cc) Status,
    _openProtocolInformation: *const fn (handle: Handle, protocol: *align(8) const Guid, entry_buffer: *[*]const ProtocolInformationEntry, entry_count: *usize) callconv(cc) Status,
    _protocolsPerHandle: *const fn (handle: Handle, protocol_buffer: *[*]*align(8) const Guid, protocol_buffer_count: *usize) callconv(cc) Status,
    _locateHandleBuffer: *const fn (search_type: LocateSearchType, protocol: ?*align(8) const Guid, registration: ?RegistrationValue, num_handles: *usize, buffer: *[*]Handle) callconv(cc) Status,
    _locateProtocol: *const fn (protocol: *align(8) const Guid, registration: ?RegistrationValue, interface: *?ProtocolInterface) callconv(cc) Status,

    // TODO: use callconv(cc) instead once that works
    _installMultipleProtocolInterfaces: *const fn (handle: *Handle, ...) callconv(.C) Status,

    // TODO: use callconv(cc) instead once that works
    _uninstallMultipleProtocolInterfaces: *const fn (handle: *Handle, ...) callconv(.C) Status,

    // this function is just an implementation of the crc32, so we don't need to bind it
    _calculateCrc32: *const fn (data: [*]const u8, data_size: usize, *u32) callconv(cc) Status,

    // these two functions just implement memcpy and memset, so we don't need to bind them
    _copyMem: *const fn (dest: [*]u8, src: [*]const u8, len: usize) callconv(cc) void,
    _setMem: *const fn (buffer: [*]u8, size: usize, value: u8) callconv(cc) void,

    // Following introduced in UEFI 2.0
    _createEventEx: *const fn (type: u32, notify_tpl: TaskPriorityLevel, notify_func: ?EventNotify, notify_ctx: ?EventNotifyContext, event_group: ?*align(8) const Guid, event: *Event) callconv(cc) Status,

    /// Function pointer type of event notification callbacks.
    pub const EventNotify = *const fn (event: Event, ctx: *anyopaque) callconv(cc) void;

    /// The context type passed to event notification callbacks.
    pub const EventNotifyContext = *const anyopaque;

    /// These types can be "ORed" together as needed.
    pub const EventKind = struct {
        /// The event is a timer event and may be used in a call to `setTimer()`. Note that timers only function during boot
        /// services time.
        pub const timer: u32 = 0x80000000;

        /// The event is allocated from runtime memory. If an event is to be signaled after the call to `exitBootServices()`
        /// the event’s data structure and notification function need to be allocated from runtime memory.
        pub const runtime: u32 = 0x40000000;

        /// If an event of this type is not already in the signaled state, then the event’s *notify_func* will be
        /// queued at the event’s *notify_tpl* whenever the event is being waited on via `waitForEvent()` or `checkEvent()`.
        pub const notify_wait: u32 = 0x00000100;

        /// The event’s *notify_func* is queued whenever the event is signaled.
        pub const notify_signal: u32 = 0x00000200;

        /// This event is of type `notify_signal`. It should not be combined with any other event types. This event type
        /// is functionally equivalent to the `EventGroup.exit_boot_services` event group.
        pub const signal_exit_boot_services: u32 = 0x00000201;

        /// This event is of type `notify_signal`. It should not be combined with any other event types. The event is to be
        /// notified by the system when `setVirtualAddressMap()` is performed.
        pub const signal_virtual_address_change: u32 = 0x60000202;
    };

    /// Creates an event.
    pub fn createEvent(
        self: *const BootServices,
        /// The type of event to create and its mode and attributes. See `EventKind` for more information.
        kind: u32,
        /// The task priority level of event notifications.
        notify_tpl: TaskPriorityLevel,
        /// Pointer to the event’s notification function, if any.
        notify_func: ?EventNotify,
        /// Pointer to the notification function’s context; corresponds to the *notify_ctx* parameter of the notification.
        notify_ctx: ?EventNotifyContext,
    ) !Event {
        var event: Event = undefined;
        try self._createEvent(kind, notify_tpl, notify_func, notify_ctx, &event).err();
        return event;
    }

    /// A set of common event group GUIDs.
    pub const EventGroup = struct {
        /// This event group is notified by the system when `exitBootServices()` is invoked after notifying
        /// `before_exit_boot_services` event group. The notification function is not allow to use the Memory Allocation
        /// Services. The notification must not depend on timer events since timer services will be deactivated before
        /// this group is dispatched.
        pub const exit_boot_services align(8) = Guid{
            .time_low = 0x27abf055,
            .time_mid = 0xb1b8,
            .time_high_and_version = 0x4c26,
            .clock_seq_high_and_reserved = 0x80,
            .clock_seq_low = 0x48,
            .node = [_]u8{ 0x74, 0x8f, 0x37, 0xba, 0xa2, 0xdf },
        };

        /// This event group is notified by the system ExitBootServices() is invoked right before notifying
        /// `exit_boot_services` event group. The event presents the last opportunity to use firmware interfaces in the
        /// boot environment. The notification function must not depend on any kind of delayed processing because the
        /// firmware deactivates timer services right after dispatching this event group.
        pub const before_exit_boot_services align(8) = Guid{
            .time_low = 0x8be0e274,
            .time_mid = 0x3970,
            .time_high_and_version = 0x4b44,
            .clock_seq_high_and_reserved = 0x80,
            .clock_seq_low = 0xc5,
            .node = [_]u8{ 0x1a, 0xb9, 0x50, 0x2f, 0x3b, 0xfc },
        };

        /// This event group is notified by the system when `setVirtualAddressMap()` is invoked.
        pub const virtual_address_change align(8) = Guid{
            .time_low = 0x13fa7698,
            .time_mid = 0xc831,
            .time_high_and_version = 0x49c7,
            .clock_seq_high_and_reserved = 0x87,
            .clock_seq_low = 0xea,
            .node = [_]u8{ 0x8f, 0x43, 0xfc, 0xc2, 0x51, 0x96 },
        };

        /// This event group is notified by the system when the memory map has changed. The notification function should
        /// not use Memory Allocation Services to avoid reentrancy issues.
        pub const memory_map_change align(8) = Guid{
            .time_low = 0x78bee926,
            .time_mid = 0x692f,
            .time_high_and_version = 0x48fd,
            .clock_seq_high_and_reserved = 0x9e,
            .clock_seq_low = 0xdb,
            .node = [_]u8{ 0x01, 0x42, 0x2e, 0xf0, 0xd7, 0xab },
        };

        /// This event group is notified by the system right before notifying `after_ready_to_boot`event group when the
        /// Boot Manager is about to load and execute a boot option or a platform or OS recovery option. The event group
        /// presents the last chance to modify device or system configuration prior to passing control to a boot option.
        pub const ready_to_boot align(8) = Guid{
            .time_low = 0x7ce88fb3,
            .time_mid = 0x4bd7,
            .time_high_and_version = 0x4679,
            .clock_seq_high_and_reserved = 0x87,
            .clock_seq_low = 0xa8,
            .node = [_]u8{ 0xa8, 0xd8, 0xde, 0xe5, 0x0d, 0x2b },
        };

        /// This event group is notified by the system immediately after notifying `ready_to_boot` event group when the
        /// Boot Manager is about to load and execute a boot option or a platform or OS recovery option. The event group
        /// presents the last chance to survey device or system configuration prior to passing control to a boot option.
        pub const after_ready_to_boot align(8) = Guid{
            .time_low = 0x3a2a00ad,
            .time_mid = 0x98b9,
            .time_high_and_version = 0x4cdf,
            .clock_seq_high_and_reserved = 0xa4,
            .clock_seq_low = 0x78,
            .node = [_]u8{ 0x70, 0x27, 0x77, 0xf1, 0xc1, 0x0b },
        };

        /// This event group is notified by the system when `resetSystem()` is invoked and the system is about to be reset.
        pub const reset_system align(8) = Guid{
            .time_low = 0x62da6a56,
            .time_mid = 0x13fb,
            .time_high_and_version = 0x485a,
            .clock_seq_high_and_reserved = 0xa8,
            .clock_seq_low = 0xda,
            .node = [_]u8{ 0xa3, 0xdd, 0x79, 0x12, 0xcb, 0x6b },
        };
    };

    /// Creates an event in a group.
    pub fn createEventEx(
        self: *const BootServices,
        /// The type of event to create and its mode and attributes. See `EventKind` for more information.
        kind: u32,
        /// The task priority level of event notifications.
        notify_tpl: TaskPriorityLevel,
        /// Pointer to the event’s notification function, if any.
        notify_func: ?EventNotify,
        /// Pointer to the notification function’s context; corresponds to the *notify_ctx* parameter of the notification.
        notify_ctx: ?EventNotifyContext,
        /// Pointer to the unique identifier of the group to which this event belongs.
        event_group: *align(8) const Guid,
    ) !Event {
        if (!self.hdr.isAtLeastRevision(2, 0))
            return error.Unsupported;

        var event: Event = undefined;
        try self._createEventEx(kind, notify_tpl, notify_func, notify_ctx, event_group, &event).err();
        return event;
    }

    /// Close an event.
    pub fn closeEvent(
        self: *const BootServices,
        /// The event to close.
        event: Event,
    ) void {
        _ = self._closeEvent(event);
    }

    /// Signal an event.
    pub fn signalEvent(
        self: *const BootServices,
        /// The event to signal.
        event: Event,
    ) void {
        _ = self._signalEvent(event);
    }

    /// Stops execution until the first event is signaled.
    ///
    /// Returns the index of the event which was signaled.
    pub fn waitForEvent(
        self: *const BootServices,
        /// A slice of events to wait on.
        events: []const Event,
    ) !usize {
        var index: usize = 0;
        try self._waitForEvent(events.len, events.ptr, &index).err();
        return index;
    }

    /// Checks whether an event is in the signaled state.
    ///
    /// Cannot be called on events of type `EventKind.notify_signal`.
    pub fn checkEvent(
        self: *const BootServices,
        /// The event to check.
        event: Event,
    ) !bool {
        var status: Status = self._checkEvent(event);
        switch (status) {
            .success => return true,
            .not_ready => return false,
            else => return status.err(),
        }
    }

    /// How the timer is to be set.
    pub const TimerKind = union(Enum) {
        pub const Enum = enum(u32) {
            /// The timer is canceled.
            cancel = 0,

            /// The timer is a periodic timer.
            periodic = 1,

            /// The timer is a relative timer.
            relative = 2,
        };

        /// The timer is to be canceled.
        cancel: void,

        /// The timer is to be signaled periodically at `trigger_time` ns intervals. The event timer does not need to be
        /// reset for each notification.
        periodic: u64,

        /// The timer is to be signaled after `trigger_time` ns.
        relative: u64,
    };

    /// Sets the type of timer and the trigger time for a timer event.
    ///
    /// Timers only have 100ns time resolution.
    pub fn setTimer(
        self: *const BootServices,
        /// The event to signal.
        event: Event,
        /// The type of timer and the trigger time for a timer event.
        kind: TimerKind,
    ) !void {
        switch (kind) {
            .cancel => try self._setTimer(event, kind, 0).err(),
            .periodic => |n| try self._setTimer(event, kind, n / 100).err(),
            .relative => |n| try self._setTimer(event, kind, n / 100).err(),
        }
    }

    /// The priority level of a task. The higher the number, the higher the priority.
    pub const TaskPriorityLevel = enum(usize) {
        /// This is the lowest priority level. It is the level of execution which occurs when no event notifications are
        /// pending and which interacts with the user. User I/O (and blocking on User I/O) can be performed at this level.
        /// The boot manager executes at this level and passes control to other UEFI applications at this level.
        application = 4,

        /// Interrupts code executing below TPL_CALLBACK level. Long term operations (such as file system operations and
        /// disk I/O) can occur at this level
        callback = 8,

        /// Interrupts code executing below TPL_NOTIFY level. Blocking is not allowed at this level. Code executes to
        /// completion and returns. If code requires more processing, it needs to signal an event to wait to obtain control
        /// again at whatever level it requires. This level is typically used to process low level IO to or from a device.
        notify = 16,

        /// Interrupts code executing below TPL_HIGH_LEVEL This is the highest priority level. It is not interruptible
        /// (interrupts are disabled) and is used sparingly by firmware to synchronize operations that need to be accessible
        /// from any priority level. For example, it must be possible to signal events while executing at any priority level.
        /// Therefore, firmware manipulates the internal event structure while at this priority level.
        high_level = 31,
    };

    /// Raises a task's priority level and returns its previous level.
    ///
    /// The new TPL *must* be higher than the current TPL, otherwise the system may exhibit indeterminate behavior.
    ///
    /// The caller must restore the task priority level with `restoreTPL()` to the previous level before
    /// returning control to the system.
    pub fn raiseTpl(
        self: *const BootServices,
        /// The new priority level.
        new_tpl: TaskPriorityLevel,
    ) TaskPriorityLevel {
        return self._raiseTpl(new_tpl);
    }

    /// Restores a task's priority level to its previous value.
    pub fn restoreTpl(
        self: *const BootServices,
        /// The previous priority level.
        old_tpl: TaskPriorityLevel,
    ) void {
        self._restoreTpl(old_tpl);
    }

    pub const AllocateType = union(Enum) {
        pub const Enum = enum(u32) {
            /// Allocate any available range of pages that satisfies the request.
            any = 0,

            /// Allocate any available range of pages whose uppermost address is less than or equal to a specified
            /// address.
            max_address = 1,

            /// Allocate pages at a specified address.
            at_address = 2,
        };

        /// Allocate any available range of pages that satisfies the request.
        any: void,

        /// Allocate any available range of pages whose uppermost address is less than or equal to a specified address.
        max_address: PhysicalAddress,

        /// Allocate pages at a specified address.
        at_address: PhysicalAddress,
    };

    /// Allocates memory pages from the system.
    ///
    /// The memory returned is physical memory, apply the virtual address map to get the correct virtual address.
    pub fn allocatePages(
        self: *const BootServices,
        /// The type of allocation to perform.
        alloc_type: AllocateType,
        /// The type of memory to allocate.
        mem_type: bits.MemoryDescriptor.Type,
        /// The number of contiguous 4 KiB pages to allocate.
        pages: usize,
    ) ![]align(4096) u8 {
        var buffer: [*]align(4096) u8 = switch (alloc_type) {
            .any => @ptrFromInt(0),
            .max_address => |addr| @ptrFromInt(addr),
            .at_address => |addr| @ptrFromInt(addr),
        };

        // EFI memory addresses are always 64-bit, even on 32-bit systems
        const pointer: PhysicalAddress = @intFromPtr(&buffer);

        try self._allocatePages(alloc_type, mem_type, pages, pointer).err();
        return buffer[0 .. pages * 4096];
    }

    /// Frees memory pages.
    ///
    /// The slice must point to the physical address of the pages.
    pub fn freePages(
        self: *const BootServices,
        /// The slice of the pages to be freed.
        memory: []align(4096) u8,
    ) void {
        // any error here arises from user error (ie. freeing a page not allocated by allocatePages) or a firmware bug
        _ = self._freePages(memory.ptr, @divExact(memory.len, 4096));
    }

    /// A structure containing all necessary information about a memory map, and providing the methods required to
    /// access it correctly.
    pub const MemoryMap = struct {
        pub const Key = enum(usize) { _ };

        map: *anyopaque,

        /// The length of the memory map in bytes.
        size: usize,

        /// The key for the current memory map.
        key: Key,

        /// The size of each memory descriptor in the memory map.
        descriptor_size: usize,

        /// The version of the memory map.
        descriptor_version: u32,

        /// An iterator over the memory map.
        pub const Iterator = struct {
            map: *const MemoryMap,

            /// The current index of the iterator.
            index: usize = 0,

            /// Returns the next memory descriptor in the map.
            pub fn next(iter: *Iterator) ?*bits.MemoryDescriptor {
                const offset = iter.index * iter.map.descriptor_size;

                // ensure the next descriptor is within the map
                if (offset + iter.map.descriptor_size > iter.map.size)
                    return null;

                const addr = @intFromPtr(iter.map.map) + offset;
                iter.index += 1;

                return @ptrFromInt(addr);
            }
        };

        /// Creates a memory map from a buffer.
        pub fn initFromBuffer(buffer: []u8) MemoryMap {
            return .{
                .map = @ptrCast(buffer.ptr),
                .size = buffer.len,
                .key = 0,
                .descriptor_size = 0,
                .descriptor_version = 0,
            };
        }

        /// Creates a memory map from a list of memory descriptors.
        pub fn initFromList(list: []bits.MemoryDescriptor) MemoryMap {
            return .{
                .map = @ptrCast(list.ptr),
                .size = list.len * @sizeOf(bits.MemoryDescriptor),
                .key = 0,
                .descriptor_size = @sizeOf(bits.MemoryDescriptor),
                .descriptor_version = bits.MemoryDescriptor.revision,
            };
        }

        /// Returns an iterator over the memory map.
        pub fn iterator(self: *const MemoryMap) Iterator {
            return Iterator{ .map = self };
        }

        /// Returns a pointer to the memory descriptor at the given index.
        pub fn at(self: *const MemoryMap, index: usize) ?*bits.MemoryDescriptor {
            const offset = index * self.descriptor_size;

            // ensure the descriptor is within the map
            if (offset + self.descriptor_size > self.size)
                return null;

            const addr = @intFromPtr(self.map) + offset;
            return @ptrFromInt(addr);
        }

        /// Returns the number of memory descriptors in the map.
        pub fn size(self: *const MemoryMap) usize {
            return self.size / self.descriptor_size;
        }
    };

    /// Returns the size of the current memory map. Or null if the buffer size is large enough.
    ///
    /// It is recommended to call this in a loop until it returns `null`.
    pub fn getMemoryMapSize(
        self: *const BootServices,
        /// The size of the memory currently allocated for the map.
        previous_size: usize,
    ) !?usize {
        var mmap_size: usize = previous_size;
        var mmap_key: MemoryMap.Key = 0;
        var descriptor_size: usize = 0;
        var descriptor_version: u32 = 0;

        switch (self._getMemoryMap(&mmap_size, null, &mmap_key, &descriptor_size, &descriptor_version)) {
            .buffer_too_small => return mmap_size,
            .invalid_parameter => return null,
            else => |s| return s.err(),
        }
    }

    /// Fetches the current memory map.
    ///
    /// Use `getMemoryMapSize()` to determine the size of the buffer to allocate.
    pub fn getMemoryMap(
        self: *const BootServices,
        /// The memory map to fill.
        map: *MemoryMap,
    ) !void {
        var mmap_size: usize = map.size;
        var mmap_key: MemoryMap.Key = map.key;
        var descriptor_size: usize = map.descriptor_size;
        var descriptor_version: u32 = map.descriptor_version;

        try self._getMemoryMap(&mmap_size, map.map, &mmap_key, &descriptor_size, &descriptor_version).err();

        map.size = mmap_size;
        map.key = mmap_key;
        map.descriptor_size = descriptor_size;
        map.descriptor_version = descriptor_version;
    }

    /// Allocates pool memory.
    ///
    /// All allocations are 8-byte aligned.
    pub fn allocatePool(
        self: *const BootServices,
        /// The type of pool to allocate.
        pool_type: bits.MemoryDescriptor.Type,
        /// The number of bytes to allocate.
        size: usize,
    ) ![]align(8) u8 {
        var buffer: [*]align(8) u8 = undefined;
        try self._allocatePool(pool_type, size, &buffer).err();

        const aligned_size = std.mem.alignForward(usize, size, 8);
        return buffer[0..aligned_size];
    }

    /// Returns pool memory to the system.
    ///
    /// Does *not* allow partial frees, the entire allocation will be freed, even if the slice is a segment.
    pub fn freePool(
        self: *const BootServices,
        /// The slice of the pool to be freed.
        buffer: []align(8) u8,
    ) void {
        // any error here arises from user error (ie. freeing a page not allocated by allocatePool) or a firmware bug
        _ = self._freePool(buffer.ptr);
    }

    pub const EfiInterfaceType = enum(u32) {
        native,
    };

    /// Installs a protocol interface on a device handle. If the handle does not exist, it is created and added to the
    /// list of handles in the system.
    ///
    /// It is recommended to use `installMultipleProtocolInterfaces()` instead, as it performs more error checking.
    pub fn installProtocolInterface(
        self: *const BootServices,
        /// The handle to install the protocol interface on.
        handle: ?Handle,
        /// The GUID of the protocol.
        protocol_guid: *align(8) const Guid,
        /// The type of interface to install.
        interface_type: EfiInterfaceType,
        /// The interface to install. Can only be `null` if `protocol` refers to a protocol that has no interface.
        interface: ?ProtocolInterface,
    ) !Handle {
        var new_handle: ?Handle = handle;
        try self._installProtocolInterface(&new_handle, protocol_guid, interface_type, interface).err();
        return new_handle;
    }

    /// Uninstalls a protocol interface from a device handle.
    ///
    /// The caller ensures that there are no references to the old interface that is being removed.
    ///
    /// It is recommended to use `uninstallMultipleProtocolInterfaces()` instead.
    pub fn uninstallProtocolInterface(
        self: *const BootServices,
        /// The handle to uninstall the protocol interface from.
        handle: Handle,
        /// The GUID of the protocol.
        protocol_guid: *align(8) const Guid,
        /// The interface to uninstall. Can only be `null` if `protocol` refers to a protocol that has no interface.
        interface: ?ProtocolInterface,
    ) !void {
        try self._uninstallProtocolInterface(handle, protocol_guid, interface).err();
    }

    /// Reinstalls a protocol interface on a device handle.
    ///
    /// The caller ensures that there are no references to the old interface that is being removed.
    pub fn reinstallProtocolInterface(
        self: *const BootServices,
        /// The handle to reinstall the protocol interface on.
        handle: Handle,
        /// The GUID of the protocol.
        protocol_guid: *align(8) const Guid,
        /// The old interface to uninstall. Can only be `null` if `protocol` refers to a protocol that has no interface.
        old_interface: ?ProtocolInterface,
        /// The new interface to install. Can only be `null` if `protocol` refers to a protocol that has no interface.
        new_interface: ?ProtocolInterface,
    ) !void {
        try self._reinstallProtocolInterface(handle, protocol_guid, old_interface, new_interface).err();
    }

    /// Creates an event that is to be signaled whenever an interface is installed for a specified protocol.
    pub fn registerProtocolNotify(
        self: *const BootServices,
        /// The GUID of the protocol.
        protocol_guid: *align(8) const Guid,
        /// The event to signal when the protocol is installed.
        event: Event,
        /// A pointer to a memory location to receive the registration value. THe value must be saved and used by the
        /// notification function to retrieve the list of handles that have added or removed the protocol.
        registration: **const anyopaque,
    ) !void {
        try self._registerProtocolNotify(protocol_guid, event, registration).err();
    }

    /// The type of search to perform.
    pub const LocateSearchType = union(Enum) {
        pub const Enum = enum(u32) {
            all,
            by_notify,
            by_protocol,
        };

        /// Returns all handles in the system
        all: void,

        /// Returns the next handle that is new for the registration. Only one handle is returned at a time, starting
        /// with the first and the caller must loop until no more handles are returned.
        by_notify: *const anyopaque,

        /// Returns all handles that support this protocol.
        by_protocol: *align(8) const Guid,
    };

    /// Returns the size in bytes of the buffer that is required to hold the list of handles that support a specified
    /// protocol.
    ///
    /// Returns null if no handles match the search.
    pub fn locateHandleSize(
        self: *const BootServices,
        /// The type of search to perform.
        search_type: LocateSearchType,
    ) !?usize {
        var buffer_size: usize = 0;

        const status = switch (search_type) {
            .all => self._locateHandle(search_type, null, null, &buffer_size, null),
            .by_notify => |search_key| self._locateHandle(search_type, null, search_key, &buffer_size, null),
            .by_protocol => |protocol_guid| self._locateHandle(search_type, protocol_guid, null, &buffer_size, null),
        };

        switch (status) {
            .buffer_too_small => return buffer_size,
            .not_found => return null,
            else => return status.err(),
        }
    }

    /// Returns an array of handles that support a specified protocol.
    ///
    /// Use `locateHandleSize()` to determine the size of the buffer to allocate.
    ///
    /// Returns null if no handles match the search.
    pub fn locateHandle(
        self: *const BootServices,
        /// The type of search to perform.
        search_type: LocateSearchType,
        /// The buffer in which to return the array of handles.
        buffer: [*]u8,
    ) !?[]Handle {
        var handle_buffer: [*]Handle = @ptrCast(buffer.ptr);
        var buffer_size: usize = buffer.len;

        const status = switch (search_type) {
            .all => self._locateHandle(search_type, null, null, &buffer_size, &handle_buffer),
            .by_notify => |search_key| self._locateHandle(search_type, null, search_key, &buffer_size, &handle_buffer),
            .by_protocol => |protocol_guid| self._locateHandle(search_type, protocol_guid, null, &buffer_size, &handle_buffer),
        };

        switch (status) {
            .success => return handle_buffer[0..@divExact(buffer_size, @sizeOf(Handle))],
            .not_found => return null,
            else => return status.err(),
        }
    }

    /// A tuple of a located device path containing the handle to the device and the remaining device path.
    pub const LocatedDevicePath = struct { ?Handle, *const DevicePathProtocol };

    /// Locates the handle to a device on the device path that supports the specified protocol.
    pub fn locateDevicePath(
        self: *const BootServices,
        /// The GUID of the protocol.
        protocol_guid: *align(8) const Guid,
        /// The device path to search for.
        device_path: *const DevicePathProtocol,
    ) !LocatedDevicePath {
        var handle: ?Handle = null;
        var path: *const DevicePathProtocol = device_path;
        switch (self._locateDevicePath(protocol_guid, &handle, &path)) {
            .success => return .{ handle, path },
            .not_found => return .{ null, path },
            else => |status| return status.err(),
        }
    }

    pub const OpenProtocolAttributes = packed struct(u32) {
        /// Query whether a protocol interface is supported on a handle. If yes, then the protocol interface is returned.
        by_handle_protocol: bool = false,

        /// Used by a driver to get a protocol interface from a handle. Care must be taken when using this mode because the
        /// driver that opens the protocol interface in this manner will not be informed if the protocol interface is
        /// uninstalled or reinstalled. The caller is also not required to close the protocol interface.
        get_protocol: bool = false,

        /// Used by a driver to test for the existence of a protocol interface on a handle. The returned interface will always
        /// be `null`. This mode can be used to determine if a driver is present in the handle's driver stack.
        test_protocol: bool = false,

        /// Used by bus drivers to show that a protocol interface is being used by one of the child controllers of the bus.
        /// This information is used by `connectController` to recursively connect all child controllers and by
        /// `disconnectController` to get the list of child controllers that a bus driver created.
        by_child_controller: bool = false,

        /// Used by a driver to gain access to a protocol interface. When this mode is used, the driver's `stop()` function
        /// will be called by `disconnectController` if the protocol interface is reinstalled or uninstalled. Once a
        /// protocol interface is opened by a driver with this attribute, no other drivers can open that protocol interface
        /// with this attribute.
        by_driver: bool = false,

        /// Used to gain exclusive access to a protocol interface. If any drivers have the protocol interface opened with
        /// the `by_driver` attribute, then an attempt will be made to remove them by calling the driver's `stop()` function.
        exclusive: bool = false,

        reserved: u26 = 0,
    };

    /// Queries a handle to determine if it supports a specified protocol. If the protocol is supported by the handle,
    /// it opens the protocol on behalf of the calling agent.
    pub fn openProtocol(
        self: *const BootServices,
        /// The handle for the protocol interface that is being opened.
        handle: Handle,
        /// The GUID of the protocol to open.
        protocol_guid: *align(8) const Guid,
        /// The handle of the agent that is opening the protocol interface specified by `protocol`.
        agent_handle: ?Handle,
        /// The handle of the controller that requires the protocol interface.
        controller_handle: ?Handle,
        /// Attributes to open the protocol with.
        attributes: OpenProtocolAttributes,
    ) !?ProtocolInterface {
        var interface: ?ProtocolInterface = undefined;
        try self._openProtocol(handle, protocol_guid, &interface, agent_handle, controller_handle, attributes).err();
        return interface;
    }

    /// Closes a protocol on a handle that was opened using `openProtocol()`.
    pub fn closeProtocol(
        self: *const BootServices,
        /// The handle for the protocol interface that was previously opened with `openProtocol()`.
        handle: Handle,
        /// The GUID of the protocol to close.
        protocol_guid: *align(8) const Guid,
        /// The handle of the agent that is closing the protocol interface specified by `protocol`.
        agent_handle: Handle,
        /// The handle of the controller that required the protocol interface.
        controller_handle: ?Handle,
    ) void {
        // any error here arises from user error (ie. closing a protocol that was not supported) or a firmware bug
        _ = self._closeProtocol(handle, protocol_guid, agent_handle, controller_handle);
    }

    pub const ProtocolInformationEntry = extern struct {
        agent_handle: ?Handle,
        controller_handle: ?Handle,
        attributes: OpenProtocolAttributes,
        open_count: u32,
    };

    /// Retrieves the list of agents that currently have a protocol interface opened in a buffer allocated from the pool.
    /// Returns `null` if the handle does not support the requested protocol.
    ///
    /// The caller owns the returned pool memory, it should be freed with `freePool`.
    pub fn openProtocolInformation(
        self: *const BootServices,
        /// The handle for the protocol interface that is being queried.
        handle: Handle,
        /// The GUID of the protocol to list.
        protocol_guid: *align(8) const Guid,
    ) !?[]const ProtocolInformationEntry {
        var entry_buffer: [*]const ProtocolInformationEntry = undefined;
        var entry_count: usize = 0;
        switch (self._openProtocolInformation(handle, protocol_guid, &entry_buffer, &entry_count)) {
            .success => return entry_buffer[0..entry_count],
            .not_found => return null,
            else => |status| return status.err(),
        }
    }

    /// Connects one or more drivers to a controller.
    pub fn connectController(
        self: *const BootServices,
        /// The handle of the controller to connect.
        controller_handle: Handle,
        /// The handle of the driver image that is connecting to the controller.
        driver_image_handle: ?Handle,
        /// The remaining device path.
        ///
        /// If null, then handles for all children of the controller will be created.
        remaining_device_path: ?*const DevicePathProtocol,
        /// Whether to connect all children.
        recursive: bool,
    ) !void {
        try self._connectController(controller_handle, driver_image_handle, remaining_device_path, recursive).err();
    }

    /// Disconnects one or more drivers from a controller.
    pub fn disconnectController(
        self: *const BootServices,
        /// The handle of the controller to disconnect.
        controller_handle: Handle,
        /// The handle of the driver image that is disconnecting from the controller.
        ///
        /// If null, then all drivers currently managing the controller are disconnected from the controller.
        driver_image_handle: ?Handle,
        /// The handle of the child controller to disconnect.
        ///
        /// If null, then all children of the controller are destroyed before the drivers are disconnected from the controller.
        child_handle: ?Handle,
    ) !void {
        try self._disconnectController(controller_handle, driver_image_handle, child_handle).err();
    }

    /// Retrieves the list of protocol interface GUIDs that are installed on a handle in a buffer allocated from the pool.
    ///
    /// The caller owns the returned pool memory, it should be freed with `freePool`.
    pub fn protocolsPerHandle(
        self: *const BootServices,
        /// The handle for the protocol interface that is being queried.
        handle: Handle,
    ) ![]const *const Guid {
        var protocol_buffer: [*]const *const Guid = undefined;
        var protocol_buffer_count: usize = 0;
        try self._protocolsPerHandle(handle, &protocol_buffer, &protocol_buffer_count).err();
        return protocol_buffer[0..protocol_buffer_count];
    }

    /// Returns an array of handles that support the requested protocol in a buffer allocated from the pool.
    ///
    /// The caller owns the returned pool memory, it should be freed with `freePool`.
    pub fn locateHandleBuffer(
        self: *const BootServices,
        /// The type of search to perform.
        search_type: LocateSearchType,
    ) ![]Handle {
        var handle_buffer: [*]Handle = undefined;
        var num_handles: usize = 0;

        switch (search_type) {
            .all => try self._locateHandleBuffer(search_type, null, null, &num_handles, &handle_buffer).err(),
            .by_notify => |search_key| self._locateHandleBuffer(search_type, null, search_key, &num_handles, &handle_buffer),
            .by_protocol => |protocol_guid| self._locateHandleBuffer(search_type, protocol_guid, null, &num_handles, &handle_buffer),
        }

        return handle_buffer[0..num_handles];
    }

    /// Returns the first protocol instance that matches the given protocol.
    pub fn locateProtocol(
        self: *const BootServices,
        /// The GUID of the protocol.
        protocol_guid: *align(8) const Guid,
        /// An optional registration key returned from `registerProtocolNotify()`.
        registration: ?*const anyopaque,
    ) !?ProtocolInterface {
        var interface: ?ProtocolInterface = undefined;
        switch (self._locateProtocol(protocol_guid, registration, &interface)) {
            .success => return interface,
            .not_found => return null,
            else => |status| return status.err(),
        }
    }

    /// Installs one or more protocol interfaces into the boot services environment.
    pub fn installMultipleProtocolInterfaces(
        self: *const BootServices,
        /// The handle to install the protocol interface on.
        ///
        /// If null, a new handle is created and returned.
        handle: ?Handle,
        /// A list of protocol GUIDs and their corresponding interfaces.
        comptime protocols: []const Guid,
    ) !Handle {
        var new_handle: ?Handle = handle;

        try @call(.auto, self._installMultipleProtocolInterfaces, .{&new_handle} ++ protocols).err();

        return new_handle;
    }

    /// Uninstalls one or more protocol interfaces from the boot services environment.
    ///
    /// This action is atomic, if it fails, all protocols will remain installed.
    ///
    /// Will error if any of the protocols are not installed on the handle.
    pub fn uninstallMultipleProtocolInterfaces(
        self: *const BootServices,
        /// The handle to uninstall the protocol interface from.
        handle: Handle,
        /// A list of protocol GUIDs and their corresponding interfaces.
        comptime protocols: []const Guid,
    ) !void {
        try @call(.auto, self._uninstallMultipleProtocolInterfaces, .{&handle} ++ protocols).err();
    }

    /// Loads an EFI image into memory.
    ///
    /// One of `device_path` or `source_buffer` must be non-null.
    pub fn loadImage(
        self: *const BootServices,
        /// If true, indicates the request originates from the boot manager, and that the boot manager is attempting to
        /// load the image as a boot selection. Ignored when `source_buffer` is non-null.
        boot_policy: bool,
        /// The caller's image handle.
        parent_image_handle: Handle,
        /// The device path of the image.
        device_path: ?*const DevicePathProtocol,
        /// A pointer to a memory location with a copy of the image to be loaded.
        source_buffer: ?[*]const u8,
        /// The size of the image's data.
        source_size: usize,
    ) !Handle {
        var image_handle: ?Handle = null;
        try self._loadImage(boot_policy, parent_image_handle, device_path, source_buffer, source_size, &image_handle).err();
        return image_handle;
    }

    pub const ImageReturn = struct { Status, []const u16 };

    /// Transfers control to a loaded image's entry point.
    ///
    /// Returns the exit data as bytes. It will begin with a null terminated UCS2 string, optionally followed by a blob
    /// of binary data.
    pub fn startImage(
        self: *const BootServices,
        /// The image handle.
        image_handle: Handle,
    ) ImageReturn {
        var exit_data_size: usize = 0;
        var exit_data: *[*]u16 = null;
        const status = self._startImage(image_handle, &exit_data_size, &exit_data);

        return .{ status, exit_data[0 .. exit_data_size / 2] };
    }

    /// Unloads an image.
    pub fn unloadImage(
        self: *const BootServices,
        /// The image handle.
        image_handle: Handle,
    ) Status {
        return self._unloadImage(image_handle);
    }

    /// Terminates a loaded EFI image and returns control to boot services.
    ///
    /// This function will not return when `image_handle` is the current image handle.
    pub fn exit(
        self: *const BootServices,
        /// The image handle.
        image_handle: Handle,
        /// The image's exit status.
        exit_status: Status,
        /// The exit data. This must begin with a null terminated utf16 string.
        exit_data: ?[]const u16,
    ) !void {
        if (exit_data) |data| {
            try self._exit(image_handle, exit_status, data.len * 2, data.ptr).err();
        } else {
            try self._exit(image_handle, exit_status, 0, null).err();
        }
    }

    /// Terminates all boot services.
    pub fn exitBootServices(
        self: *const BootServices,
        /// The image handle.
        image_handle: Handle,
        /// The key returned from `getMemoryMap()`. Stored in `MemoryMap.key`.
        map_key: MemoryMap.Key,
    ) !void {
        try self._exitBootServices(image_handle, map_key).err();
    }

    /// Sets the system's watchdog timer.
    pub fn setWatchdogTimer(
        self: *const BootServices,
        /// The number of seconds to set the watchdog timer to.
        timeout: usize,
        /// The numeric code to log on timeout.
        watchdog_code: u64,
        /// A data buffer pointing to a null terminated UCS2 string. Optionally followed by a blob of binary data.
        watchdog_data: ?[]align(2) const u8,
    ) !void {
        if (watchdog_data) |data| {
            try self._setWatchdogTimer(timeout, watchdog_code, data.len, data.ptr).err();
        } else {
            try self._setWatchdogTimer(timeout, watchdog_code, 0, null).err();
        }
    }

    /// Induces a fine-grained stall.
    pub fn stall(
        self: *const BootServices,
        /// The number of microseconds to stall for.
        microseconds: usize,
    ) void {
        _ = self._stall(microseconds);
    }

    /// Returns the next monotonic count.
    pub fn getNextMonotonicCount(
        self: *const BootServices,
    ) !u64 {
        var count: u64 = 0;
        try self._getNextMonotonicCount(&count).err();
        return count;
    }

    /// Adds, updates, or removes a configuration table from the EFI System Table.
    pub fn installConfigurationTable(
        self: *const BootServices,
        /// The GUID of the configuration table.
        guid: *align(8) const Guid,
        /// A pointer to the configuration table.
        config_table: ?*const anyopaque,
    ) !void {
        try self._installConfigurationTable(guid, config_table).err();
    }

    pub const signature: u64 = 0x56524553544f4f42;
};