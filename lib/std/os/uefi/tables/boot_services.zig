const uefi = @import("std").os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const TableHeader = uefi.tables.TableHeader;

/// UEFI Specification, Version 2.8, 4.4
///
/// As the boot_services table may grow with new UEFI versions, it is important to check hdr.header_size.
///
/// Boot Services must not be used after exitBootServices has been called. The only exception is
/// getMemoryMap, which may be used after the first unsuccessful call to exitBootServices.
/// After successfully calling exitBootServices, system_table.console_in_handle, system_table.con_in,
/// system_table.console_out_handle, system_table.con_out, system_table.standard_error_handle,
/// system_table.std_err, and system_table.boot_services should be set to null. After setting these
/// attributes to null, system_table.hdr.crc32 must be recomputed. See UEFI Specification, Version 2.8, 7.4.
pub const BootServices = extern struct {
    hdr: TableHeader,
    raiseTpl: usize, // TODO
    restoreTpl: usize, // TODO
    allocatePages: usize, // TODO
    freePages: usize, // TODO
    getMemoryMap: extern fn (*usize, [*]MemoryDescriptor, *usize, *usize, *u32) usize,
    allocatePool: extern fn (MemoryType, usize, *align(8) [*]u8) usize,
    freePool: usize, // TODO
    createEvent: extern fn (u32, usize, ?extern fn (Event, ?*const c_void) void, ?*const c_void, *Event) usize,
    setTimer: extern fn (Event, TimerDelay, u64) usize,
    waitForEvent: extern fn (usize, [*]const Event, *usize) usize,
    signalEvent: extern fn (Event) usize,
    closeEvent: extern fn (Event) usize,
    checkEvent: usize, // TODO
    installProtocolInterface: usize, // TODO
    reinstallProtocolInterface: usize, // TODO
    uninstallProtocolInterface: usize, // TODO
    handleProtocol: usize, // TODO
    reserved: *c_void,
    registerProtocolNotify: usize, // TODO
    locateHandle: usize, // TODO
    locateDevicePath: usize, // TODO
    installConfigurationTable: usize, // TODO
    imageLoad: usize, // TODO
    imageStart: usize, // TODO
    exit: extern fn (Handle, usize, usize, ?*const c_void) usize,
    imageUnload: usize, // TODO
    exitBootServices: extern fn (Handle, usize) usize,
    getNextMonotonicCount: usize, // TODO
    stall: extern fn (usize) usize,
    setWatchdogTimer: extern fn (usize, u64, usize, ?[*]const u16) usize,
    connectController: usize, // TODO
    disconnectController: usize, // TODO
    openProtocol: usize, // TODO
    closeProtocol: usize, // TODO
    openProtocolInformation: usize, // TODO
    protocolsPerHandle: usize, // TODO
    locateHandleBuffer: usize, // TODO
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
