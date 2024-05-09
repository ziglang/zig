const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const Status = uefi.Status;
const TableHeader = uefi.tables.TableHeader;
const DevicePathProtocol = uefi.protocol.DevicePath;
const AllocateType = uefi.tables.AllocateType;
const MemoryType = uefi.tables.MemoryType;
const MemoryDescriptor = uefi.tables.MemoryDescriptor;
const TimerDelay = uefi.tables.TimerDelay;
const EfiInterfaceType = uefi.tables.EfiInterfaceType;
const LocateSearchType = uefi.tables.LocateSearchType;
const OpenProtocolAttributes = uefi.tables.OpenProtocolAttributes;
const ProtocolInformationEntry = uefi.tables.ProtocolInformationEntry;
const EfiEventNotify = uefi.tables.EfiEventNotify;
const cc = uefi.cc;

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
    raiseTpl: *const fn (new_tpl: usize) callconv(cc) usize,

    /// Restores a task's priority level to its previous value.
    restoreTpl: *const fn (old_tpl: usize) callconv(cc) void,

    /// Allocates memory pages from the system.
    allocatePages: *const fn (alloc_type: AllocateType, mem_type: MemoryType, pages: usize, memory: *[*]align(4096) u8) callconv(cc) Status,

    /// Frees memory pages.
    freePages: *const fn (memory: [*]align(4096) u8, pages: usize) callconv(cc) Status,

    /// Returns the current memory map.
    getMemoryMap: *const fn (mmap_size: *usize, mmap: ?[*]MemoryDescriptor, mapKey: *usize, descriptor_size: *usize, descriptor_version: *u32) callconv(cc) Status,

    /// Allocates pool memory.
    allocatePool: *const fn (pool_type: MemoryType, size: usize, buffer: *[*]align(8) u8) callconv(cc) Status,

    /// Returns pool memory to the system.
    freePool: *const fn (buffer: [*]align(8) u8) callconv(cc) Status,

    /// Creates an event.
    createEvent: *const fn (type: u32, notify_tpl: usize, notify_func: ?*const fn (Event, ?*anyopaque) callconv(cc) void, notifyCtx: ?*const anyopaque, event: *Event) callconv(cc) Status,

    /// Sets the type of timer and the trigger time for a timer event.
    setTimer: *const fn (event: Event, type: TimerDelay, triggerTime: u64) callconv(cc) Status,

    /// Stops execution until an event is signaled.
    waitForEvent: *const fn (event_len: usize, events: [*]const Event, index: *usize) callconv(cc) Status,

    /// Signals an event.
    signalEvent: *const fn (event: Event) callconv(cc) Status,

    /// Closes an event.
    closeEvent: *const fn (event: Event) callconv(cc) Status,

    /// Checks whether an event is in the signaled state.
    checkEvent: *const fn (event: Event) callconv(cc) Status,

    /// Installs a protocol interface on a device handle. If the handle does not exist, it is created
    /// and added to the list of handles in the system. installMultipleProtocolInterfaces()
    /// performs more error checking than installProtocolInterface(), so its use is recommended over this.
    installProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, interface_type: EfiInterfaceType, interface: *anyopaque) callconv(cc) Status,

    /// Reinstalls a protocol interface on a device handle
    reinstallProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, old_interface: *anyopaque, new_interface: *anyopaque) callconv(cc) Status,

    /// Removes a protocol interface from a device handle. Usage of
    /// uninstallMultipleProtocolInterfaces is recommended over this.
    uninstallProtocolInterface: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: *anyopaque) callconv(cc) Status,

    /// Queries a handle to determine if it supports a specified protocol.
    handleProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: *?*anyopaque) callconv(cc) Status,

    reserved: *anyopaque,

    /// Creates an event that is to be signaled whenever an interface is installed for a specified protocol.
    registerProtocolNotify: *const fn (protocol: *align(8) const Guid, event: Event, registration: **anyopaque) callconv(cc) Status,

    /// Returns an array of handles that support a specified protocol.
    locateHandle: *const fn (search_type: LocateSearchType, protocol: ?*align(8) const Guid, search_key: ?*const anyopaque, bufferSize: *usize, buffer: [*]Handle) callconv(cc) Status,

    /// Locates the handle to a device on the device path that supports the specified protocol
    locateDevicePath: *const fn (protocols: *align(8) const Guid, device_path: **const DevicePathProtocol, device: *?Handle) callconv(cc) Status,

    /// Adds, updates, or removes a configuration table entry from the EFI System Table.
    installConfigurationTable: *const fn (guid: *align(8) const Guid, table: ?*anyopaque) callconv(cc) Status,

    /// Loads an EFI image into memory.
    loadImage: *const fn (boot_policy: bool, parent_image_handle: Handle, device_path: ?*const DevicePathProtocol, source_buffer: ?[*]const u8, source_size: usize, imageHandle: *?Handle) callconv(cc) Status,

    /// Transfers control to a loaded image's entry point.
    startImage: *const fn (image_handle: Handle, exit_data_size: ?*usize, exit_data: ?*[*]u16) callconv(cc) Status,

    /// Terminates a loaded EFI image and returns control to boot services.
    exit: *const fn (image_handle: Handle, exit_status: Status, exit_data_size: usize, exit_data: ?*const anyopaque) callconv(cc) Status,

    /// Unloads an image.
    unloadImage: *const fn (image_handle: Handle) callconv(cc) Status,

    /// Terminates all boot services.
    exitBootServices: *const fn (image_handle: Handle, map_key: usize) callconv(cc) Status,

    /// Returns a monotonically increasing count for the platform.
    getNextMonotonicCount: *const fn (count: *u64) callconv(cc) Status,

    /// Induces a fine-grained stall.
    stall: *const fn (microseconds: usize) callconv(cc) Status,

    /// Sets the system's watchdog timer.
    setWatchdogTimer: *const fn (timeout: usize, watchdogCode: u64, data_size: usize, watchdog_data: ?[*]const u16) callconv(cc) Status,

    /// Connects one or more drives to a controller.
    connectController: *const fn (controller_handle: Handle, driver_image_handle: ?Handle, remaining_device_path: ?*DevicePathProtocol, recursive: bool) callconv(cc) Status,

    // Disconnects one or more drivers from a controller
    disconnectController: *const fn (controller_handle: Handle, driver_image_handle: ?Handle, child_handle: ?Handle) callconv(cc) Status,

    /// Queries a handle to determine if it supports a specified protocol.
    openProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, interface: *?*anyopaque, agent_handle: ?Handle, controller_handle: ?Handle, attributes: OpenProtocolAttributes) callconv(cc) Status,

    /// Closes a protocol on a handle that was opened using openProtocol().
    closeProtocol: *const fn (handle: Handle, protocol: *align(8) const Guid, agentHandle: Handle, controller_handle: ?Handle) callconv(cc) Status,

    /// Retrieves the list of agents that currently have a protocol interface opened.
    openProtocolInformation: *const fn (handle: Handle, protocol: *align(8) const Guid, entry_buffer: *[*]ProtocolInformationEntry, entry_count: *usize) callconv(cc) Status,

    /// Retrieves the list of protocol interface GUIDs that are installed on a handle in a buffer allocated from pool.
    protocolsPerHandle: *const fn (handle: Handle, protocol_buffer: *[*]*align(8) const Guid, protocol_buffer_count: *usize) callconv(cc) Status,

    /// Returns an array of handles that support the requested protocol in a buffer allocated from pool.
    locateHandleBuffer: *const fn (search_type: LocateSearchType, protocol: ?*align(8) const Guid, search_key: ?*const anyopaque, num_handles: *usize, buffer: *[*]Handle) callconv(cc) Status,

    /// Returns the first protocol instance that matches the given protocol.
    locateProtocol: *const fn (protocol: *align(8) const Guid, registration: ?*const anyopaque, interface: *?*anyopaque) callconv(cc) Status,

    /// Installs one or more protocol interfaces into the boot services environment
    // TODO: use callconv(cc) instead once that works
    installMultipleProtocolInterfaces: *const fn (handle: *Handle, ...) callconv(.C) Status,

    /// Removes one or more protocol interfaces into the boot services environment
    // TODO: use callconv(cc) instead once that works
    uninstallMultipleProtocolInterfaces: *const fn (handle: *Handle, ...) callconv(.C) Status,

    /// Computes and returns a 32-bit CRC for a data buffer.
    calculateCrc32: *const fn (data: [*]const u8, data_size: usize, *u32) callconv(cc) Status,

    /// Copies the contents of one buffer to another buffer
    copyMem: *const fn (dest: [*]u8, src: [*]const u8, len: usize) callconv(cc) void,

    /// Fills a buffer with a specified value
    setMem: *const fn (buffer: [*]u8, size: usize, value: u8) callconv(cc) void,

    /// Creates an event in a group.
    createEventEx: *const fn (type: u32, notify_tpl: usize, notify_func: EfiEventNotify, notify_ctx: *const anyopaque, event_group: *align(8) const Guid, event: *Event) callconv(cc) Status,

    /// Opens a protocol with a structure as the loaded image for a UEFI application
    pub fn openProtocolSt(self: *BootServices, comptime protocol: type, handle: Handle) !*protocol {
        if (!@hasDecl(protocol, "guid"))
            @compileError("Protocol is missing guid!");

        var ptr: ?*protocol = undefined;

        try self.openProtocol(
            handle,
            &protocol.guid,
            @as(*?*anyopaque, @ptrCast(&ptr)),
            // Invoking handle (loaded image)
            uefi.handle,
            // Control handle (null as not a driver)
            null,
            uefi.tables.OpenProtocolAttributes{ .by_handle_protocol = true },
        ).err();

        return ptr.?;
    }

    pub const signature: u64 = 0x56524553544f4f42;

    pub const event_timer: u32 = 0x80000000;
    pub const event_runtime: u32 = 0x40000000;
    pub const event_notify_wait: u32 = 0x00000100;
    pub const event_notify_signal: u32 = 0x00000200;
    pub const event_signal_exit_boot_services: u32 = 0x00000201;
    pub const event_signal_virtual_address_change: u32 = 0x00000202;

    pub const tpl_application: usize = 4;
    pub const tpl_callback: usize = 8;
    pub const tpl_notify: usize = 16;
    pub const tpl_high_level: usize = 31;
};
