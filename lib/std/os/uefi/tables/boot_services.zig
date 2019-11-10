const uefi = @import("std").os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
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

    raiseTpl: usize, // TODO
    restoreTpl: usize, // TODO
    allocatePages: usize, // TODO
    freePages: usize, // TODO

    /// Returns the current memory map.
    getMemoryMap: extern fn (*usize, [*]MemoryDescriptor, *usize, *usize, *u32) usize,

    /// Allocates pool memory.
    allocatePool: extern fn (MemoryType, usize, *align(8) [*]u8) usize,

    /// Returns pool memory to the system.
    freePool: extern fn ([*]align(8) u8) usize,

    /// Creates an event.
    createEvent: extern fn (u32, usize, ?extern fn (Event, ?*c_void) void, ?*const c_void, *Event) usize,

    /// Sets the type of timer and the trigger time for a timer event.
    setTimer: extern fn (Event, TimerDelay, u64) usize,

    /// Stops execution until an event is signaled.
    waitForEvent: extern fn (usize, [*]const Event, *usize) usize,

    /// Signals an event.
    signalEvent: extern fn (Event) usize,

    /// Closes an event.
    closeEvent: extern fn (Event) usize,

    /// Checks whether an event is in the signaled state.
    checkEvent: extern fn (Event) usize,

    installProtocolInterface: usize, // TODO
    reinstallProtocolInterface: usize, // TODO
    uninstallProtocolInterface: usize, // TODO

    /// Queries a handle to determine if it supports a specified protocol.
    handleProtocol: extern fn (Handle, *align(8) const Guid, *?*c_void) usize,

    reserved: *c_void,

    registerProtocolNotify: usize, // TODO
    locateHandle: usize, // TODO
    locateDevicePath: usize, // TODO
    installConfigurationTable: usize, // TODO

    /// Loads an EFI image into memory.
    loadImage: extern fn (bool, Handle, ?*const DevicePathProtocol, ?[*]const u8, usize, *?Handle) usize,

    /// Transfers control to a loaded image's entry point.
    startImage: extern fn (Handle, ?*usize, ?*[*]u16) usize,

    /// Terminates a loaded EFI image and returns control to boot services.
    exit: extern fn (Handle, usize, usize, ?*const c_void) usize,

    /// Unloads an image.
    unloadImage: extern fn (Handle) usize,

    /// Terminates all boot services.
    exitBootServices: extern fn (Handle, usize) usize,

    getNextMonotonicCount: usize, // TODO

    /// Induces a fine-grained stall.
    stall: extern fn (usize) usize,

    /// Sets the system's watchdog timer.
    setWatchdogTimer: extern fn (usize, u64, usize, ?[*]const u16) usize,

    connectController: usize, // TODO
    disconnectController: usize, // TODO

    /// Queries a handle to determine if it supports a specified protocol.
    openProtocol: extern fn (Handle, *align(8) const Guid, *?*c_void, ?Handle, ?Handle, OpenProtocolAttributes) usize,

    /// Closes a protocol on a handle that was opened using openProtocol().
    closeProtocol: extern fn (Handle, *align(8) const Guid, Handle, ?Handle) usize,

    /// Retrieves the list of agents that currently have a protocol interface opened.
    openProtocolInformation: extern fn (Handle, *align(8) const Guid, *[*]ProtocolInformationEntry, *usize) usize,

    protocolsPerHandle: usize, // TODO

    /// Returns an array of handles that support the requested protocol in a buffer allocated from pool.
    locateHandleBuffer: extern fn (LocateSearchType, ?*align(8) const Guid, ?*const c_void, *usize, *[*]Handle) usize,

    /// Returns the first protocol instance that matches the given protocol.
    locateProtocol: extern fn (*align(8) const Guid, ?*const c_void, *?*c_void) usize,

    installMultipleProtocolInterfaces: usize, // TODO
    uninstallMultipleProtocolInterfaces: usize, // TODO
    calculateCrc32: usize, // TODO
    copyMem: usize, // TODO
    setMem: usize, // TODO
    createEventEx: usize, // TODO

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

pub const TimerDelay = extern enum(u32) {
    TimerCancel,
    TimerPeriodic,
    TimerRelative,
};

pub const MemoryType = extern enum(u32) {
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
};

pub const MemoryDescriptor = extern struct {
    type: MemoryType,
    physical_start: u64,
    virtual_start: u64,
    number_of_pages: usize,
    attribute: packed struct {
        uc: bool,
        wc: bool,
        wt: bool,
        wb: bool,
        uce: bool,
        _pad1: u7,
        wp: bool,
        rp: bool,
        xp: bool,
        nv: bool,
        more_reliable: bool,
        ro: bool,
        sp: bool,
        cpu_crypto: bool,
        _pad2: u43,
        memory_runtime: bool,
    },
};

pub const LocateSearchType = extern enum(u32) {
    AllHandles,
    ByRegisterNotify,
    ByProtocol,
};

pub const OpenProtocolAttributes = packed struct {
    by_handle_protocol: bool,
    get_protocol: bool,
    test_protocol: bool,
    by_child_controller: bool,
    by_driver: bool,
    exclusive: bool,
    _pad: u26,
};

pub const ProtocolInformationEntry = extern struct {
    agent_handle: ?Handle,
    controller_handle: ?Handle,
    attributes: OpenProtocolAttributes,
    open_count: u32,
};
