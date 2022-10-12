const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const Status = uefi.Status;
const TableHeader = uefi.tables.TableHeader;
const DevicePathProtocol = uefi.protocols.DevicePathProtocol;

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
    raiseTpl: std.meta.FnPtr(fn (new_tpl: usize) callconv(.C) usize),

    /// Restores a task's priority level to its previous value.
    restoreTpl: std.meta.FnPtr(fn (old_tpl: usize) callconv(.C) void),

    /// Allocates memory pages from the system.
    allocatePages: std.meta.FnPtr(fn (alloc_type: AllocateType, mem_type: MemoryType, pages: usize, memory: *[*]align(4096) u8) callconv(.C) Status),

    /// Frees memory pages.
    freePages: std.meta.FnPtr(fn (memory: [*]align(4096) u8, pages: usize) callconv(.C) Status),

    /// Returns the current memory map.
    getMemoryMap: std.meta.FnPtr(fn (mmap_size: *usize, mmap: [*]MemoryDescriptor, mapKey: *usize, descriptor_size: *usize, descriptor_version: *u32) callconv(.C) Status),

    /// Allocates pool memory.
    allocatePool: std.meta.FnPtr(fn (pool_type: MemoryType, size: usize, buffer: *[*]align(8) u8) callconv(.C) Status),

    /// Returns pool memory to the system.
    freePool: std.meta.FnPtr(fn (buffer: [*]align(8) u8) callconv(.C) Status),

    /// Creates an event.
    createEvent: std.meta.FnPtr(fn (type: u32, notify_tpl: usize, notify_func: ?std.meta.FnPtr(fn (Event, ?*anyopaque) callconv(.C) void), notifyCtx: ?*const anyopaque, event: *Event) callconv(.C) Status),

    /// Sets the type of timer and the trigger time for a timer event.
    setTimer: std.meta.FnPtr(fn (event: Event, type: TimerDelay, triggerTime: u64) callconv(.C) Status),

    /// Stops execution until an event is signaled.
    waitForEvent: std.meta.FnPtr(fn (event_len: usize, events: [*]const Event, index: *usize) callconv(.C) Status),

    /// Signals an event.
    signalEvent: std.meta.FnPtr(fn (event: Event) callconv(.C) Status),

    /// Closes an event.
    closeEvent: std.meta.FnPtr(fn (event: Event) callconv(.C) Status),

    /// Checks whether an event is in the signaled state.
    checkEvent: std.meta.FnPtr(fn (event: Event) callconv(.C) Status),

    /// Installs a protocol interface on a device handle. If the handle does not exist, it is created
    /// and added to the list of handles in the system. installMultipleProtocolInterfaces()
    /// performs more error checking than installProtocolInterface(), so its use is recommended over this.
    installProtocolInterface: std.meta.FnPtr(fn (handle: Handle, protocol: *align(8) const Guid, interface_type: EfiInterfaceType, interface: *anyopaque) callconv(.C) Status),

    /// Reinstalls a protocol interface on a device handle
    reinstallProtocolInterface: std.meta.FnPtr(fn (handle: Handle, protocol: *align(8) const Guid, old_interface: *anyopaque, new_interface: *anyopaque) callconv(.C) Status),

    /// Removes a protocol interface from a device handle. Usage of
    /// uninstallMultipleProtocolInterfaces is recommended over this.
    uninstallProtocolInterface: std.meta.FnPtr(fn (handle: Handle, protocol: *align(8) const Guid, interface: *anyopaque) callconv(.C) Status),

    /// Queries a handle to determine if it supports a specified protocol.
    handleProtocol: std.meta.FnPtr(fn (handle: Handle, protocol: *align(8) const Guid, interface: *?*anyopaque) callconv(.C) Status),

    reserved: *anyopaque,

    /// Creates an event that is to be signaled whenever an interface is installed for a specified protocol.
    registerProtocolNotify: std.meta.FnPtr(fn (protocol: *align(8) const Guid, event: Event, registration: **anyopaque) callconv(.C) Status),

    /// Returns an array of handles that support a specified protocol.
    locateHandle: std.meta.FnPtr(fn (search_type: LocateSearchType, protocol: ?*align(8) const Guid, search_key: ?*const anyopaque, bufferSize: *usize, buffer: [*]Handle) callconv(.C) Status),

    /// Locates the handle to a device on the device path that supports the specified protocol
    locateDevicePath: std.meta.FnPtr(fn (protocols: *align(8) const Guid, device_path: **const DevicePathProtocol, device: *?Handle) callconv(.C) Status),

    /// Adds, updates, or removes a configuration table entry from the EFI System Table.
    installConfigurationTable: std.meta.FnPtr(fn (guid: *align(8) const Guid, table: ?*anyopaque) callconv(.C) Status),

    /// Loads an EFI image into memory.
    loadImage: std.meta.FnPtr(fn (boot_policy: bool, parent_image_handle: Handle, device_path: ?*const DevicePathProtocol, source_buffer: ?[*]const u8, source_size: usize, imageHandle: *?Handle) callconv(.C) Status),

    /// Transfers control to a loaded image's entry point.
    startImage: std.meta.FnPtr(fn (image_handle: Handle, exit_data_size: ?*usize, exit_data: ?*[*]u16) callconv(.C) Status),

    /// Terminates a loaded EFI image and returns control to boot services.
    exit: std.meta.FnPtr(fn (image_handle: Handle, exit_status: Status, exit_data_size: usize, exit_data: ?*const anyopaque) callconv(.C) Status),

    /// Unloads an image.
    unloadImage: std.meta.FnPtr(fn (image_handle: Handle) callconv(.C) Status),

    /// Terminates all boot services.
    exitBootServices: std.meta.FnPtr(fn (image_handle: Handle, map_key: usize) callconv(.C) Status),

    /// Returns a monotonically increasing count for the platform.
    getNextMonotonicCount: std.meta.FnPtr(fn (count: *u64) callconv(.C) Status),

    /// Induces a fine-grained stall.
    stall: std.meta.FnPtr(fn (microseconds: usize) callconv(.C) Status),

    /// Sets the system's watchdog timer.
    setWatchdogTimer: std.meta.FnPtr(fn (timeout: usize, watchdogCode: u64, data_size: usize, watchdog_data: ?[*]const u16) callconv(.C) Status),

    /// Connects one or more drives to a controller.
    connectController: std.meta.FnPtr(fn (controller_handle: Handle, driver_image_handle: ?Handle, remaining_device_path: ?*DevicePathProtocol, recursive: bool) callconv(.C) Status),

    // Disconnects one or more drivers from a controller
    disconnectController: std.meta.FnPtr(fn (controller_handle: Handle, driver_image_handle: ?Handle, child_handle: ?Handle) callconv(.C) Status),

    /// Queries a handle to determine if it supports a specified protocol.
    openProtocol: std.meta.FnPtr(fn (handle: Handle, protocol: *align(8) const Guid, interface: *?*anyopaque, agent_handle: ?Handle, controller_handle: ?Handle, attributes: OpenProtocolAttributes) callconv(.C) Status),

    /// Closes a protocol on a handle that was opened using openProtocol().
    closeProtocol: std.meta.FnPtr(fn (handle: Handle, protocol: *align(8) const Guid, agentHandle: Handle, controller_handle: ?Handle) callconv(.C) Status),

    /// Retrieves the list of agents that currently have a protocol interface opened.
    openProtocolInformation: std.meta.FnPtr(fn (handle: Handle, protocol: *align(8) const Guid, entry_buffer: *[*]ProtocolInformationEntry, entry_count: *usize) callconv(.C) Status),

    /// Retrieves the list of protocol interface GUIDs that are installed on a handle in a buffer allocated from pool.
    protocolsPerHandle: std.meta.FnPtr(fn (handle: Handle, protocol_buffer: *[*]*align(8) const Guid, protocol_buffer_count: *usize) callconv(.C) Status),

    /// Returns an array of handles that support the requested protocol in a buffer allocated from pool.
    locateHandleBuffer: std.meta.FnPtr(fn (search_type: LocateSearchType, protocol: ?*align(8) const Guid, search_key: ?*const anyopaque, num_handles: *usize, buffer: *[*]Handle) callconv(.C) Status),

    /// Returns the first protocol instance that matches the given protocol.
    locateProtocol: std.meta.FnPtr(fn (protocol: *align(8) const Guid, registration: ?*const anyopaque, interface: *?*anyopaque) callconv(.C) Status),

    /// Installs one or more protocol interfaces into the boot services environment
    installMultipleProtocolInterfaces: std.meta.FnPtr(fn (handle: *Handle, ...) callconv(.C) Status),

    /// Removes one or more protocol interfaces into the boot services environment
    uninstallMultipleProtocolInterfaces: std.meta.FnPtr(fn (handle: *Handle, ...) callconv(.C) Status),

    /// Computes and returns a 32-bit CRC for a data buffer.
    calculateCrc32: std.meta.FnPtr(fn (data: [*]const u8, data_size: usize, *u32) callconv(.C) Status),

    /// Copies the contents of one buffer to another buffer
    copyMem: std.meta.FnPtr(fn (dest: [*]u8, src: [*]const u8, len: usize) callconv(.C) void),

    /// Fills a buffer with a specified value
    setMem: std.meta.FnPtr(fn (buffer: [*]u8, size: usize, value: u8) callconv(.C) void),

    /// Creates an event in a group.
    createEventEx: std.meta.FnPtr(fn (type: u32, notify_tpl: usize, notify_func: EfiEventNotify, notify_ctx: *const anyopaque, event_group: *align(8) const Guid, event: *Event) callconv(.C) Status),

    /// Opens a protocol with a structure as the loaded image for a UEFI application
    pub fn openProtocolSt(self: *BootServices, comptime protocol: type, handle: Handle) !*protocol {
        if (!@hasDecl(protocol, "guid"))
            @compileError("Protocol is missing guid!");

        var ptr: ?*protocol = undefined;

        try self.openProtocol(
            handle,
            &protocol.guid,
            @ptrCast(*?*anyopaque, &ptr),
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

pub const EfiEventNotify = std.meta.FnPtr(fn (event: Event, ctx: *anyopaque) callconv(.C) void);

pub const TimerDelay = enum(u32) {
    TimerCancel,
    TimerPeriodic,
    TimerRelative,
};

pub const MemoryType = enum(u32) {
    ReservedMemoryType,
    LoaderCode,
    LoaderData,
    BootServicesCode,
    BootServicesData,
    RuntimeServicesCode,
    RuntimeServicesData,
    ConventionalMemory,
    UnusableMemory,
    ACPIReclaimMemory,
    ACPIMemoryNVS,
    MemoryMappedIO,
    MemoryMappedIOPortSpace,
    PalCode,
    PersistentMemory,
    MaxMemoryType,
    _,
};

pub const MemoryDescriptor = extern struct {
    type: MemoryType,
    padding: u32,
    physical_start: u64,
    virtual_start: u64,
    number_of_pages: usize,
    attribute: packed struct {
        uc: bool,
        wc: bool,
        wt: bool,
        wb: bool,
        uce: bool,
        _pad1: u3,
        _pad2: u4,
        wp: bool,
        rp: bool,
        xp: bool,
        nv: bool,
        more_reliable: bool,
        ro: bool,
        sp: bool,
        cpu_crypto: bool,
        _pad3: u4,
        _pad4: u32,
        _pad5: u7,
        memory_runtime: bool,
    },
};

pub const LocateSearchType = enum(u32) {
    AllHandles,
    ByRegisterNotify,
    ByProtocol,
};

pub const OpenProtocolAttributes = packed struct {
    by_handle_protocol: bool = false,
    get_protocol: bool = false,
    test_protocol: bool = false,
    by_child_controller: bool = false,
    by_driver: bool = false,
    exclusive: bool = false,
    _pad: u26 = 0,
};

pub const ProtocolInformationEntry = extern struct {
    agent_handle: ?Handle,
    controller_handle: ?Handle,
    attributes: OpenProtocolAttributes,
    open_count: u32,
};

pub const EfiInterfaceType = enum(u32) {
    EfiNativeInterface,
};

pub const AllocateType = enum(u32) {
    AllocateAnyPages,
    AllocateMaxAddress,
    AllocateAddress,
};
