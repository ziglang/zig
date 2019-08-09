const uefi = @import("std").os.uefi;
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
    getMemoryMap: usize, // TODO
    allocatePool: usize, // TODO
    freePool: usize, // TODO
    createEvent: usize, // TODO
    setTimer: usize, // TODO
    waitForEvent: usize, // TODO
    signalEvent: usize, // TODO
    closeEvent: usize, // TODO
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
    exitBootServices: usize, // TODO
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
};
