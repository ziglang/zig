const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const EventRegistration = uefi.EventRegistration;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const Page = uefi.Page;
const Pages = uefi.Pages;
const Status = uefi.Status;
const TableHeader = uefi.tables.TableHeader;
const DevicePathProtocol = uefi.protocol.DevicePath;
const AllocateLocation = uefi.tables.AllocateLocation;
const AllocateType = uefi.tables.AllocateType;
const MemoryType = uefi.tables.MemoryType;
const MemoryDescriptor = uefi.tables.MemoryDescriptor;
const MemoryMapKey = uefi.tables.MemoryMapKey;
const MemoryMapInfo = uefi.tables.MemoryMapInfo;
const MemoryMapSlice = uefi.tables.MemoryMapSlice;
const TimerDelay = uefi.tables.TimerDelay;
const InterfaceType = uefi.tables.InterfaceType;
const LocateSearch = uefi.tables.LocateSearch;
const LocateSearchType = uefi.tables.LocateSearchType;
const OpenProtocolAttributes = uefi.tables.OpenProtocolAttributes;
const OpenProtocolFlag = uefi.tables.OpenProtocolFlag;
const ProtocolInformationEntry = uefi.tables.ProtocolInformationEntry;
const EventNotify = uefi.tables.EventNotify;
const cc = uefi.cc;
const Error = Status.Error;

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
    hdr: TableHeader,

    /// Raises a task's priority level and returns its previous level.
    raiseTpl: *const fn (new_tpl: TaskPriorityLevel) callconv(cc) TaskPriorityLevel,

    /// Restores a task's priority level to its previous value.
    restoreTpl: *const fn (old_tpl: TaskPriorityLevel) callconv(cc) void,

    /// Allocates memory pages from the system.
    _allocatePages: *const fn (alloc_type: AllocateType, mem_type: MemoryType, pages: usize, memory: *[*]align(4096) Page) callconv(cc) Status,

    /// Frees memory pages.
    _freePages: *const fn (memory: [*]align(4096) Page, pages: usize) callconv(cc) Status,

    /// Returns the current memory map.
    _getMemoryMap: *const fn (mmap_size: *usize, mmap: ?[*]MemoryDescriptor, map_key: *MemoryMapKey, descriptor_size: *usize, descriptor_version: *u32) callconv(cc) Status,

    /// Allocates pool memory.
    _allocatePool: *const fn (pool_type: MemoryType, size: usize, buffer: *[*]align(8) u8) callconv(cc) Status,

    /// Returns pool memory to the system.
    _freePool: *const fn (buffer: [*]align(8) u8) callconv(cc) Status,

    /// Creates an event.
    _createEvent: *const fn (type: u32, notify_tpl: usize, notify_func: ?*const fn (Event, ?*anyopaque) callconv(cc) void, notify_ctx: ?*anyopaque, event: *Event) callconv(cc) Status,

    /// Sets the type of timer and the trigger time for a timer event.
    _setTimer: *const fn (event: Event, type: TimerDelay, trigger_time: u64) callconv(cc) Status,

    /// Stops execution until an event is signaled.
    _waitForEvent: *const fn (event_len: usize, events: [*]const Event, index: *usize) callconv(cc) Status,

    /// Signals an event.
    _signalEvent: *const fn (event: Event) callconv(cc) Status,

    /// Closes an event.
    _closeEvent: *const fn (event: Event) callconv(cc) Status,

    /// Checks whether an event is in the signaled state.
    _checkEvent: *const fn (event: Event) callconv(cc) Status,

    /// Installs a protocol interface on a device handle. If the handle does not exist, it is created
    /// and added to the list of handles in the system. installMultipleProtocolInterfaces()
    /// performs more error checking than installProtocolInterface(), so its use is recommended over this.
    _installProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, interface_type: InterfaceType, interface: *anyopaque) callconv(cc) Status,

    /// Reinstalls a protocol interface on a device handle
    _reinstallProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, old_interface: *anyopaque, new_interface: *anyopaque) callconv(cc) Status,

    /// Removes a protocol interface from a device handle. Usage of
    /// uninstallMultipleProtocolInterfaces is recommended over this.
    _uninstallProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: *anyopaque) callconv(cc) Status,

    /// Queries a handle to determine if it supports a specified protocol.
    _handleProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: *?*anyopaque) callconv(cc) Status,

    _reserved: *anyopaque,

    /// Creates an event that is to be signaled whenever an interface is installed for a specified protocol.
    _registerProtocolNotify: *const fn (protocol: *align(8) const Guid, event: Event, registration: *EventRegistration) callconv(cc) Status,

    /// Returns an array of handles that support a specified protocol.
    _locateHandle: *const fn (search_type: LocateSearchType, protocol: ?*align(8) const Guid, search_key: ?*const anyopaque, buffer_size: *usize, buffer: ?[*]Handle) callconv(cc) Status,

    /// Locates the handle to a device on the device path that supports the specified protocol
    _locateDevicePath: *const fn (protocols: *align(8) const Guid, device_path: **const DevicePathProtocol, device: *?Handle) callconv(cc) Status,

    /// Adds, updates, or removes a configuration table entry from the EFI System Table.
    _installConfigurationTable: *const fn (guid: *align(8) const Guid, table: ?*anyopaque) callconv(cc) Status,

    /// Loads an EFI image into memory.
    _loadImage: *const fn (boot_policy: bool, parent_image_handle: Handle, device_path: ?*const DevicePathProtocol, source_buffer: ?[*]const u8, source_size: usize, image_handle: *?Handle) callconv(cc) Status,

    /// Transfers control to a loaded image's entry point.
    _startImage: *const fn (image_handle: Handle, exit_data_size: ?*usize, exit_data: ?*[*]u16) callconv(cc) Status,

    /// Terminates a loaded EFI image and returns control to boot services.
    exit: *const fn (image_handle: Handle, exit_status: Status, exit_data_size: usize, exit_data: ?*const anyopaque) callconv(cc) noreturn,

    /// Unloads an image.
    _unloadImage: *const fn (image_handle: Handle) callconv(cc) Status,

    /// Terminates all boot services.
    _exitBootServices: *const fn (image_handle: Handle, map_key: MemoryMapKey) callconv(cc) Status,

    /// Returns a monotonically increasing count for the platform.
    _getNextMonotonicCount: *const fn (count: *u64) callconv(cc) Status,

    /// Induces a fine-grained stall.
    _stall: *const fn (microseconds: usize) callconv(cc) Status,

    /// Sets the system's watchdog timer.
    _setWatchdogTimer: *const fn (timeout: usize, watchdog_code: u64, data_size: usize, watchdog_data: ?[*]const u16) callconv(cc) Status,

    /// Connects one or more drives to a controller.
    _connectController: *const fn (controller_handle: Handle, driver_image_handle: ?[*:null]Handle, remaining_device_path: ?*const DevicePathProtocol, recursive: bool) callconv(cc) Status,

    // Disconnects one or more drivers from a controller
    _disconnectController: *const fn (controller_handle: Handle, driver_image_handle: ?Handle, child_handle: ?Handle) callconv(cc) Status,

    /// Queries a handle to determine if it supports a specified protocol.
    _openProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: ?**anyopaque, agent_handle: ?Handle, controller_handle: ?Handle, attributes: OpenProtocolAttributes) callconv(cc) Status,

    /// Closes a protocol on a handle that was opened using openProtocol().
    _closeProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, agent_handle: Handle, controller_handle: ?Handle) callconv(cc) Status,

    /// Retrieves the list of agents that currently have a protocol interface opened.
    _openProtocolInformation: *const fn (handle: Handle, protocol: *align(8) const Guid, entry_buffer: *[*]ProtocolInformationEntry, entry_count: *usize) callconv(cc) Status,

    /// Retrieves the list of protocol interface GUIDs that are installed on a handle in a buffer allocated from pool.
    _protocolsPerHandle: *const fn (handle: Handle, protocol_buffer: *[*]*align(8) const Guid, protocol_buffer_count: *usize) callconv(cc) Status,

    /// Returns an array of handles that support the requested protocol in a buffer allocated from pool.
    _locateHandleBuffer: *const fn (search_type: LocateSearchType, protocol: ?*align(8) const Guid, search_key: ?*const anyopaque, num_handles: *usize, buffer: *[*]Handle) callconv(cc) Status,

    /// Returns the first protocol instance that matches the given protocol.
    _locateProtocol: *const fn (protocol: *align(8) const Guid, registration: ?EventRegistration, interface: *?*anyopaque) callconv(cc) Status,

    /// Installs one or more protocol interfaces into the boot services environment
    // TODO: use callconv(cc) instead once that works
    _installMultipleProtocolInterfaces: *const fn (handle: *Handle, ...) callconv(.c) Status,

    /// Removes one or more protocol interfaces into the boot services environment
    // TODO: use callconv(cc) instead once that works
    _uninstallMultipleProtocolInterfaces: *const fn (handle: *Handle, ...) callconv(.c) Status,

    /// Computes and returns a 32-bit CRC for a data buffer.
    _calculateCrc32: *const fn (data: [*]const u8, data_size: usize, *u32) callconv(cc) Status,

    /// Copies the contents of one buffer to another buffer
    _copyMem: *const fn (dest: [*]u8, src: [*]const u8, len: usize) callconv(cc) void,

    /// Fills a buffer with a specified value
    _setMem: *const fn (buffer: [*]u8, size: usize, value: u8) callconv(cc) void,

    /// Creates an event in a group.
    _createEventEx: *const fn (type: u32, notify_tpl: usize, notify_func: EventNotify, notify_ctx: *const anyopaque, event_group: *align(8) const Guid, event: *Event) callconv(cc) Status,

    pub const AllocatePagesError = uefi.UnexpectedError || error{
        OutOfResources,
        InvalidParameter,
        NotFound,
    };

    pub const FreePagesError = uefi.UnexpectedError || error{
        NotFound,
        InvalidParameter,
    };

    pub const GetMemoryMapError = uefi.UnexpectedError || error{
        InvalidParameter,
        BufferTooSmall,
    };

    pub const AllocatePoolError = uefi.UnexpectedError || error{
        OutOfResources,
        InvalidParameter,
    };

    pub const FreePoolError = uefi.UnexpectedError || error{
        InvalidParameter,
    };

    pub const CreateEventError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
    };

    pub const SetTimerError = uefi.UnexpectedError || error{
        InvalidParameter,
    };

    pub const WaitForEventError = uefi.UnexpectedError || error{
        InvalidParameter,
        Unsupported,
    };

    pub const CheckEventError = uefi.UnexpectedError || error{
        InvalidParameter,
    };

    pub const ReinstallProtocolInterfaceError = uefi.UnexpectedError || error{
        NotFound,
        AccessDenied,
        InvalidParameter,
    };

    pub const HandleProtocolError = uefi.UnexpectedError || error{
        Unsupported,
    };

    pub const RegisterProtocolNotifyError = uefi.UnexpectedError || error{
        OutOfResources,
        InvalidParameter,
    };

    pub const LocateHandleError = uefi.UnexpectedError || error{
        BufferTooSmall,
        NotFound,
        InvalidParameter,
    };

    pub const LocateDevicePathError = uefi.UnexpectedError || error{
        NotFound,
        InvalidParameter,
    };

    pub const InstallConfigurationTableError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
    };

    pub const UninstallConfigurationTableError = InstallConfigurationTableError || error{
        NotFound,
    };

    pub const LoadImageError = uefi.UnexpectedError || error{
        NotFound,
        InvalidParameter,
        Unsupported,
        OutOfResources,
        LoadError,
        DeviceError,
        AccessDenied,
        SecurityViolation,
    };

    pub const StartImageError = uefi.UnexpectedError || error{
        InvalidParameter,
        SecurityViolation,
    };

    pub const ExitBootServicesError = uefi.UnexpectedError || error{
        InvalidParameter,
    };

    pub const GetNextMonotonicCountError = uefi.UnexpectedError || error{
        DeviceError,
        InvalidParameter,
    };

    pub const SetWatchdogTimerError = uefi.UnexpectedError || error{
        InvalidParameter,
        Unsupported,
        DeviceError,
    };

    pub const ConnectControllerError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotFound,
        SecurityViolation,
    };

    pub const DisconnectControllerError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
        DeviceError,
    };

    pub const OpenProtocolError = uefi.UnexpectedError || error{
        InvalidParameter,
        Unsupported,
        AccessDenied,
        AlreadyStarted,
    };

    pub const CloseProtocolError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotFound,
    };

    pub const OpenProtocolInformationError = uefi.UnexpectedError || error{
        NotFound,
        OutOfResources,
    };

    pub const ProtocolsPerHandleError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
    };

    pub const LocateHandleBufferError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotFound,
        OutOfResources,
    };

    pub const LocateProtocolError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotFound,
    };

    pub const InstallProtocolInterfacesError = uefi.UnexpectedError || error{};

    pub const UninstallProtocolInterfacesError = uefi.UnexpectedError || error{
        InvalidParameter,
    };

    pub const CalculateCrc32Error = uefi.UnexpectedError || error{
        InvalidParameter,
    };

    /// Allocates pages of memory.
    ///
    /// This function scans the memory map to locate free pages. When it finds a
    /// physically contiguous block of pages that is large enough and also satisfies
    /// the allocation requirements of `alloc_type`, it changes the memory map to
    /// indicate that the pages are now of type `mem_type`.
    ///
    /// In general, UEFI OS loaders and UEFI applications should allocate memory
    /// (and pool) of type `.loader_data`. UEFI boot service drivers must allocate
    /// memory (and pool) of type `.boot_services_data`. UREFI runtime drivers
    /// should allocate memory (and pool) of type `.runtime_services_data`
    /// (although such allocation can only be made during boot services time).
    ///
    /// Allocation requests of `.allocate_any_pages` allocate any available range
    /// of pages that satisfies the request.
    ///
    /// Allocation requests of `.allocate_max_address` allocate any available range
    /// of pages whose uppermost address is less than or equal to the address
    /// pointed to by the input.
    ///
    /// Allocation requests of `.allocate_address` allocate pages at the address
    /// pointed to by the input.
    pub fn allocatePages(
        self: *BootServices,
        location: AllocateLocation,
        mem_type: MemoryType,
        pages: usize,
    ) AllocatePagesError![]align(4096) Page {
        if (mem_type == .persistent_memory or
            mem_type == .unaccepted_memory or
            mem_type.isInvalid())
            return Error.InvalidParameter;

        var ptr: [*]align(4096) Page = switch (location) {
            .allocate_any_pages => undefined,
            inline .allocate_addres, .allocate_max_address => |ptr| ptr,
            else => return Error.InvalidParameter,
        };

        switch (self._allocatePages(
            std.meta.activeTag(location),
            mem_type,
            pages,
            &ptr,
        )) {
            .success => return ptr[0..pages],
            .out_of_resources => return Error.OutOfResources,
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn freePages(self: *BootServices, pages: []align(4096) Page) FreePagesError!void {
        switch (self._freePages(pages.ptr, pages.len)) {
            .success => {},
            .not_found => Error.NotFound,
            .invalid_parameter => Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn getMemoryMapInfo(self: *const BootServices) uefi.UnexpectedError!MemoryMapInfo {
        var info: MemoryMapInfo = undefined;
        info.len = 0;

        switch (self._getMemoryMap(
            &info.len,
            null,
            &info.key,
            &info.descriptor_size,
            &info.descriptor_version,
        )) {
            .success, .buffer_too_small => return info,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn getMemoryMap(
        self: *const BootServices,
        buffer: []align(@alignOf(MemoryDescriptor)) u8,
    ) GetMemoryMapError!MemoryMapSlice {
        var info: MemoryMapInfo = undefined;
        info.len = buffer.len;

        switch (self._getMemoryMap(
            &info.len,
            buffer.ptr,
            &info.key,
            &info.descriptor_size,
            &info.descriptor_version,
        )) {
            .success => return .{ .info = info, .ptr = buffer.ptr },
            .buffer_too_small => return Error.BufferTooSmall,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Allocates a memory region of `size` bytes from memory of type `pool_type`
    /// and returns the allocated memory. Allocates pages from `.conventional_memory`
    /// as needed to grow the requested pool type.
    pub fn allocatePool(
        self: *BootServices,
        pool_type: MemoryType,
        size: usize,
    ) AllocatePoolError![]align(8) u8 {
        var ptr: [*]align(8) u8 = undefined;

        if (pool_type == .persistent_memory or pool_type.isInvalid())
            return Error.InvalidParameter;

        switch (self._allocatePool(pool_type, size, &ptr)) {
            .success => return ptr[0..size],
            .out_of_resources => return Error.OutOfResources,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn freePool(self: *BootServices, ptr: [*]align(8) u8) FreePoolError!void {
        switch (self._freePool(ptr)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn createEvent(
        self: *BootServices,
        event_type: uefi.EventType,
        notify_opts: NotifyOpts,
    ) CreateEventError!Event {
        var evt: Event = undefined;

        switch (self._createEvent(
            @bitCast(event_type),
            @bitCast(notify_opts.tpl),
            notify_opts.func,
            notify_opts.ctx,
            &evt,
        )) {
            .success => return evt,
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Cancels any previous time trigger setting for the event, and sets a new
    /// trigger timer for the event.
    ///
    /// Returns `Error.InvalidParameter` if the event is not a timer event.
    pub fn setTimer(
        self: *BootServices,
        event: Event,
        @"type": TimerDelay,
        trigger_time: u64,
    ) SetTimerError!void {
        switch (self._setTimer(event, @"type", trigger_time)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Returns the event that was signaled, along with its index in the slice.
    pub fn waitForEvent(
        self: *BootServices,
        events: []const Event,
    ) WaitForEventError!struct { *const Event, usize } {
        var idx: usize = undefined;
        switch (self._waitForEvent(events.len, events.ptr, &idx)) {
            .success => return .{ &events[idx], idx },
            .invalid_parameter => return Error.InvalidParameter,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// If `event` is `EventType.signal`, then the event’s notification function
    /// is scheduled to be invoked at the event’s notification task priority level.
    /// This function may be invoked from any task priority level.
    ///
    /// If the supplied Event is a part of an event group, then all of the events
    /// in the event group are also signaled and their notification functions are
    /// scheduled.
    ///
    /// When signaling an event group, it is possible to create an event in the
    /// group, signal it and then close the event to remove it from the group.
    pub fn signalEvent(self: *BootServices, event: Event) uefi.UnexpectedError!void {
        switch (self._signalEvent(event)) {
            .success => {},
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn closeEvent(self: *BootServices, event: Event) uefi.UnexpectedError!void {
        switch (self._closeEvent(event)) {
            .success => {},
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Checks to see whether an event is signaled.
    ///
    /// The underlying function is equivalent to this pseudo-code:
    /// ```
    /// if (event.type.signal)
    ///     return Error.InvalidParameter;
    ///
    /// if (event.signaled) {
    ///     event.signaled = false;
    ///     return true;
    /// }
    ///
    /// const notify = event.notification_function orelse return false;
    /// notify();
    ///
    /// if (event.signaled) {
    ///     event.signaled = false;
    ///     return true;
    /// }
    ///
    /// return false;
    /// ```
    pub fn checkEvent(self: *BootServices, event: Event) CheckEventError!bool {
        switch (self._checkEvent(event)) {
            .success => return true,
            .not_ready => return false,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// See `installProtocolInterfaces`.
    ///
    /// Does not call `self._installProtocolInterface`, because
    /// `self._installMultipleProtocolInterfaces` performs more error checks.
    pub fn installProtocolInterface(
        self: *BootServices,
        handle: ?Handle,
        interface: anytype,
    ) InstallProtocolInterfacesError!Handle {
        return self.installProtocolInterfaces(handle, .{
            interface,
        });
    }

    /// Reinstalls a protocol interface on a device handle.
    ///
    /// `new` may be the same as `old`. If it is, the registered protocol notifications
    /// occur for the handle without replacing the interface on the handle.
    ///
    /// Any process that has registered to wait for the installation of the interface
    /// is notified.
    ///
    /// The caller is responsible for ensuring that there are no references to `old`
    /// if it is being removed.
    pub fn reinstallProtocolInterface(
        self: *BootServices,
        handle: Handle,
        Protocol: type,
        old: ?*const Protocol,
        new: ?*const Protocol,
    ) ReinstallProtocolInterfaceError!void {
        if (!@hasDecl(Protocol, "guid"))
            @compileError("protocol is missing guid");

        switch (self._reinstallProtocolInterface(
            handle,
            &Protocol.guid,
            old,
            new,
        )) {
            .success => {},
            .not_found => return Error.NotFound,
            .access_denied => return Error.AccessDenied,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// See `uninstallProtocolInterfaces`.
    ///
    /// Does not call `self._uninstallProtocolInterface`, because
    /// `self._uninstallMultipleProtocolInterfaces` performs more error checks.
    pub fn uninstallProtocolInterface(
        self: *BootServices,
        handle: Handle,
        interface: anytype,
    ) UninstallProtocolInterfacesError!void {
        return self.uninstallProtocolInterfaces(handle, .{
            interface,
        });
    }

    /// Returns a pointer to the `Protocol` interface if it's supported by the
    /// handle.
    ///
    /// Note that UEFI implementations are no longer required to implement this
    /// function, so it's implemented using `openProtocol` instead.
    pub fn handleProtocol(
        self: *BootServices,
        handle: Handle,
        Protocol: type,
    ) HandleProtocolError!?*Protocol {
        // per https://uefi.org/specs/UEFI/2.10/07_Services_Boot_Services.html#efi-boot-services-handleprotocol
        // handleProtocol is basically `openProtocol` where:
        // 1. agent_handle is `uefi.handle` (aka handle passed to `EfiMain`)
        // 2. controller_handle is `null`
        // 3. attributes is `EFI_OPEN_PROTOCOL_BY_HANDLE_PROTOCOL`

        return self.openProtocol(
            Protocol,
            handle,
            uefi.handle orelse return error.Unexpected,
            null,
            .{ .by_handle_protocol = true },
        ) catch |err| switch (err) {
            OpenProtocolError.AlreadyStarted => return uefi.unexpectedStatus(.already_started),
            OpenProtocolError.AccessDenied => return uefi.unexpectedStatus(.access_denied),
            OpenProtocolError.InvalidParameter => return uefi.unexpectedStatus(.invalid_parameter),
            else => @errorCast(err),
        };
    }

    pub fn registerProtocolNotify(
        self: *BootServices,
        Protocol: type,
        event: Event,
    ) RegisterProtocolNotifyError!EventRegistration {
        if (!@hasDecl(Protocol, "guid"))
            @compileError("Protocol is missing guid");

        var registration: *anyopaque = undefined;
        switch (self._registerProtocolNotify(
            &Protocol.guid,
            event,
            &registration,
        )) {
            .success => return @bitCast(@intFromPtr(registration)),
            .out_of_resources => return Error.OutOfResources,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Returns the number of handles that match the given search criteria.
    pub fn numHandles(self: *const BootServices, search: LocateSearch) !usize {
        var len: usize = 0;
        switch (self._locateHandle(
            std.meta.activeTag(search),
            if (search == .by_protocol) search.by_protocol else null,
            if (search == .by_register_notify) search.by_register_notify else null,
            &len,
            null,
        )) {
            .success => return @divExact(len, @sizeOf(Handle)),
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// To determine the necessary size of `buffer`, call `numHandles` first.
    pub fn locateHandle(
        self: *BootServices,
        search: LocateSearch,
        buffer: []Handle,
    ) LocateHandleError![]Handle {
        var len: usize = @sizeOf(Handle) * (if (buffer) |b| b.len else 0);
        switch (self._locateHandle(
            std.meta.activeTag(search),
            if (search == .by_protocol) search.by_protocol else null,
            if (search == .by_register_notify) search.by_register_notify else null,
            &len,
            if (buffer) |b| b.ptr else null,
        )) {
            .success => return buffer[0..@divExact(len, @sizeOf(Handle))],
            .buffer_too_small => return Error.BufferTooSmall,
            .not_found => return Error.NotFound,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Locates all devices on `device_path` that support `Protocol`. Once the closest
    /// match to `device_path` is found, it returns the unmatched device path and handle.
    pub fn locateDevicePath(
        self: *const BootServices,
        device_path: *const DevicePathProtocol,
        Protocol: type,
    ) LocateHandleError!struct { *const DevicePathProtocol, Handle } {
        if (!@hasDecl(Protocol, "guid"))
            @compileError("Protocol is missing guid");

        var dev_path = device_path;
        var device: ?Handle = undefined;
        switch (self._locateDevicePath(
            &Protocol.guid,
            &dev_path,
            &device,
        )) {
            .success => return .{ dev_path, device.? },
            .not_found => return Error.NotFound,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn installConfigurationTable(
        self: *BootServices,
        guid: *align(8) const Guid,
        table: *anyopaque,
    ) InstallConfigurationTableError!void {
        switch (self._installConfigurationTable(
            guid,
            table,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn uninstallConfigurationTable(
        self: *BootServices,
        guid: *align(8) const Guid,
    ) UninstallConfigurationTableError!void {
        switch (self._installConfigurationTable(
            guid,
            null,
        )) {
            .success => {},
            .not_found => return Error.NotFound,
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const LoadImageSource = union(enum) {
        buffer: []const u8,
        device_path: *const DevicePathProtocol,
    };

    pub fn loadImage(
        self: *BootServices,
        boot_policy: bool,
        parent_image: Handle,
        source: LoadImageSource,
    ) LoadImageError!Handle {
        var handle: Handle = undefined;

        switch (self._loadImage(
            boot_policy,
            parent_image,
            if (source == .device_path) source.device_path else null,
            if (source == .buffer) source.buffer.ptr else null,
            if (source == .buffer) source.buffer.len else 0,
            &handle,
        )) {
            .success => return handle,
            .not_found => return Error.NotFound,
            .invalid_parameter => return Error.InvalidParameter,
            .unsupported => return Error.Unsupported,
            .out_of_resources => return Error.OutOfResources,
            .load_error => return Error.LoadError,
            .device_error => return Error.DeviceError,
            .access_denied => return Error.AccessDenied,
            .security_violation => return Error.SecurityViolation,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn startImage(self: *BootServices, image: Handle) StartImageError!ImageExitData {
        var exit_data_size: usize = undefined;
        var exit_data: [*]u16 = undefined;

        const exit_code = switch (self._startImage(
            image,
            &exit_data_size,
            &exit_data,
        )) {
            .invalid_parameter => return Error.InvalidParameter,
            .security_violation => return Error.SecurityViolation,
            else => |exit_code| exit_code,
        };

        if (exit_data_size == 0) return .{
            .code = exit_code,
            .description = null,
            .data = null,
        };

        const description: [*:0]const u16 = @ptrCast(exit_data);
        const description_len = std.mem.indexOfSentinel(u16, 0, description);

        return ImageExitData{
            .code = exit_code,
            .description = description[0..description_len],
            .data = exit_data[description_len + 1 .. exit_data_size],
        };
    }

    /// The result is the exit code of the unload handler. Any error codes are
    /// `try/catch`-able, leaving only success and warning codes as the result.
    pub fn unloadImage(
        self: *BootServices,
        image: Handle,
    ) Status.Error!Status {
        const status = self._unloadImage(image);
        try status.err();
        return status;
    }

    pub fn exitBootServices(
        self: *BootServices,
        image: Handle,
        map_key: MemoryMapKey,
    ) ExitBootServicesError!void {
        switch (self._exitBootServices(image, map_key)) {
            .success => {},
            .invalid_parameter => Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn getNextMonotonicCount(
        self: *const BootServices,
        count: *u64,
    ) GetNextMonotonicCountError!void {
        switch (self._getNextMonotonicCount(count)) {
            .success => {},
            .device_error => return Error.DeviceError,
            .invalid_paramter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn stall(self: *const BootServices, microseconds: usize) uefi.UnexpectedError!void {
        switch (self._stall(microseconds)) {
            .success => {},
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn setWatchdogTimer(
        self: *BootServices,
        timeout: usize,
        watchdog_code: u64,
        data: ?[]const u16,
    ) SetWatchdogTimerError!void {
        switch (self._setWatchdogTimer(
            timeout,
            watchdog_code,
            if (data) |d| d.len else 0,
            if (data) |d| d.ptr else null,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .unsupported => return Error.Unsupported,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn connectController(
        self: *BootServices,
        controller: Handle,
        driver_image: ?[*:null]Handle,
        remaining_device_path: ?*const DevicePathProtocol,
        recursive: bool,
    ) ConnectControllerError!void {
        switch (self._connectController(
            controller,
            driver_image,
            remaining_device_path,
            recursive,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            .security_violation => return Error.SecurityViolation,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn disconnectController(
        self: *BootServices,
        controller: Handle,
        driver_image: ?Handle,
        child: ?Handle,
    ) DisconnectControllerError!void {
        switch (self._disconnectController(
            controller,
            driver_image,
            child,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Opens a protocol with a structure as the loaded image for a UEFI application
    ///
    /// If `flag` is `.test_protocol`, then the only valid return value is `null`,
    /// and `Status.unsupported` is returned. Otherwise, if `_openProtocol` returns
    /// `Status.unsupported`, then `null` is returned.
    pub fn openProtocol(
        self: *BootServices,
        Protocol: type,
        handle: Handle,
        agent_handle: ?Handle,
        flag: OpenProtocolFlag,
    ) OpenProtocolError!?*Protocol {
        if (!@hasDecl(Protocol, "guid"))
            @compileError("protocol is missing guid: " ++ @typeName(Protocol));

        const attributes: OpenProtocolAttributes = @bitCast(@intFromEnum(flag));
        const controller_handle: ?Handle = controller: switch (flag) {
            .by_handle_protocol, .get_protocol, .test_protocol => |controller| controller,
            inline .exclusive, .by_driver, .by_driver_exclusive => |h| {
                if (agent_handle == null)
                    return Error.InvalidParameter;
                break :controller h;
            },
            .by_child_controller => |h| {
                if (agent_handle == null or
                    @intFromPtr(h) == @intFromPtr(handle))
                    return Error.InvalidParameter;
                break :controller h;
            },
            else => return Error.InvalidParameter,
        };

        var ptr: *Protocol = undefined;

        switch (self._openProtocol(
            handle,
            &Protocol.guid,
            @as(**anyopaque, @ptrCast(&ptr)),
            agent_handle,
            controller_handle,
            attributes,
        )) {
            .success => return if (flag == .test_protocol) null else ptr,
            .unsupported => return if (flag == .test_protocol) Error.Unsupported else null,
            .access_denied => return Error.AccessDenied,
            .already_started => return Error.AlreadyStarted,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn closeProtocol(
        self: *BootServices,
        handle: Handle,
        Protocol: type,
        agent: Handle,
        controller: ?Handle,
    ) CloseProtocolError!void {
        if (!@hasDecl(Protocol, "guid"))
            @compileError("protocol is missing guid: " ++ @typeName(Protocol));

        switch (self._closeProtocol(
            handle,
            &Protocol.guid,
            agent,
            controller,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn openProtocolInformation(
        self: *const BootServices,
        handle: Handle,
        Protocol: type,
    ) ![]ProtocolInformationEntry {
        var entries: [*]ProtocolInformationEntry = undefined;
        var len: usize = undefined;

        switch (self._openProtocolInformation(
            handle,
            &Protocol.guid,
            &entries,
            &len,
        )) {
            .success => return entries[0..len],
            .not_found => return Error.NotFound,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn protocolsPerHandle(
        self: *const BootServices,
        handle: Handle,
    ) ProtocolsPerHandleError![]*align(8) const Guid {
        var guids: [*]*align(8) const Guid = undefined;
        var guids_len: usize = undefined;

        switch (self._protocolsPerHandle(
            handle,
            &guids,
            &guids_len,
        )) {
            .success => return guids[0..guids_len],
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn locateHandleBuffer(
        self: *const BootServices,
        search: LocateSearch,
    ) LocateHandleBufferError![]Handle {
        var handles: [*]Handle = undefined;
        var len: usize = undefined;

        switch (self._locateHandleBuffer(
            std.meta.activeTag(search),
            if (search == .by_protocol) |guid| guid else null,
            if (search == .by_register_notify) |key| key else null,
            &len,
            &handles,
        )) {
            .success => return handles[0..len],
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn locateProtocol(
        self: *const BootServices,
        Protocol: type,
        registration: ?EventRegistration,
    ) !?*Protocol {
        var interface: ?*Protocol = undefined;

        switch (self._locateProtocol(
            &Protocol.guid,
            registration,
            &interface,
        )) {
            .success => return interface,
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Installs a set of protocol interfaces into the boot services environment.
    ///
    /// This function's final argument should be a tuple of pointers to protocol
    /// interfaces. For example:
    ///
    /// ```
    /// const handle = try boot_services.installProtocolInterfaces(null, .{
    ///     &my_interface_1,
    ///     &my_interface_2,
    /// });
    /// ```
    ///
    /// The underlying function accepts a vararg list of pairs of Guid pointers
    /// and opaque pointers to the interface. To provide a guid, the interface
    /// types should declare a `guid` constant like so:
    ///
    /// ```
    /// pub const guid: align(8) uefi.Guid = .{ ... };
    /// ```
    ///
    /// See `std.os.uefi.protocol` for examples of protocol type definitions.
    pub fn installProtocolInterfaces(
        self: *BootServices,
        handle: ?Handle,
        interfaces: anytype,
    ) InstallProtocolInterfacesError!Handle {
        var hdl: ?Handle = handle;
        const args_tuple = protocolInterfaces(&hdl, interfaces);

        switch (@call(
            .auto,
            self._uninstallMultipleProtocolInterfaces,
            args_tuple,
        )) {
            .success => return handle.?,
            .already_started => return Error.AlreadyStarted,
            .out_of_resources => return Error.OutOfResources,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn uninstallProtocolInterfaces(
        self: *BootServices,
        handle: Handle,
        interfaces: anytype,
    ) UninstallProtocolInterfacesError!void {
        const args_tuple = protocolInterfaces(handle, interfaces);

        switch (@call(
            .auto,
            self._uninstallMultipleProtocolInterfaces,
            args_tuple,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn calculateCrc32(
        self: *const BootServices,
        data: []const u8,
    ) CalculateCrc32Error!u32 {
        var value: u32 = undefined;
        switch (self._calculateCrc32(data.ptr, data.len, &value)) {
            .success => return value,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const signature: u64 = 0x56524553544f4f42;

    pub const NotifyOpts = struct {
        tpl: TaskPriorityLevel = .application,
        func: ?*const fn (Event, ?*anyopaque) callconv(cc) void = null,
        ctx: ?*anyopaque = null,
    };

    pub const TaskPriorityLevel = enum(usize) {
        application = 4,
        callback = 8,
        notify = 16,
        high_level = 31,
        _,
    };

    pub const ImageExitData = struct {
        code: Status,
        description: ?[:0]const u16,
        data: ?[]const u16,
    };
};

fn protocolInterfaces(
    handle_arg: anytype,
    interfaces: anytype,
) ProtocolInterfaces(@TypeOf(handle_arg), @TypeOf(interfaces)) {
    var result: ProtocolInterfaces(
        @TypeOf(handle_arg),
        @TypeOf(interfaces),
    ) = undefined;
    result[0] = handle_arg;

    var idx: usize = 1;
    inline for (interfaces) |interface| {
        const InterfacePtr = @TypeOf(interface);
        const Interface = switch (@typeInfo(InterfacePtr)) {
            .pointer => |pointer| pointer.child,
            else => @compileError("expected tuple of '*const Protocol', got " ++ @typeName(InterfacePtr)),
        };

        if (!@hasDecl(Interface, "guid"))
            @compileError("protocol interface '" ++ @typeName(Interface) ++
                "' does not declare a 'const guid: align(8) uefi.Guid'.");

        switch (@typeInfo(Interface)) {
            .@"struct" => |struct_info| if (struct_info.layout != .@"extern")
                @compileLog("protocol interface '" ++ @typeName(Interface) ++
                    "' is not extern - this is likely a mistake"),
            else => @compileError("protocol interface must be a struct, got " ++ @typeName(Interface)),
        }

        result[idx] = &Interface.guid;
        result[idx + 1] = @ptrCast(interface);
        idx += 2;
    }

    return result;
}

fn ProtocolInterfaces(HandleType: type, Interfaces: type) type {
    const Interfaces_type_info = @typeInfo(Interfaces);
    if (Interfaces_type_info != .@"struct" or !Interfaces_type_info.@"struct".is_tuple)
        @compileError("expected tuple of protocol interfaces, got " ++ @typeName(Interfaces));
    const Interfaces_info = Interfaces_type_info.@"struct";

    var tuple_types: [Interfaces_info.fields.len * 2 + 1]type = undefined;
    tuple_types[0] = HandleType;
    var idx = 1;
    while (idx < tuple_types.len) : (idx += 2) {
        tuple_types[idx] = *align(8) const Guid;
        tuple_types[idx + 1] = *const anyopaque;
    }

    return std.meta.Tuple(tuple_types[0..]);
}
