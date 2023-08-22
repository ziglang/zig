const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;
const hii = uefi.protocols.hii;
const cc = uefi.cc;

/// Database manager for HII-related data structures.
pub const HIIDatabaseProtocol = extern struct {
    _new_package_list: Status, // TODO
    _remove_package_list: *const fn (*const HIIDatabaseProtocol, hii.HIIHandle) callconv(cc) Status,
    _update_package_list: *const fn (*const HIIDatabaseProtocol, hii.HIIHandle, *const hii.HIIPackageList) callconv(cc) Status,
    _list_package_lists: *const fn (*const HIIDatabaseProtocol, u8, ?*const Guid, *usize, [*]hii.HIIHandle) callconv(cc) Status,
    _export_package_lists: *const fn (*const HIIDatabaseProtocol, ?hii.HIIHandle, *usize, *hii.HIIPackageList) callconv(cc) Status,
    _register_package_notify: Status, // TODO
    _unregister_package_notify: Status, // TODO
    _find_keyboard_layouts: Status, // TODO
    _get_keyboard_layout: Status, // TODO
    _set_keyboard_layout: Status, // TODO
    _get_package_list_handle: Status, // TODO

    /// Removes a package list from the HII database.
    pub fn removePackageList(self: *const HIIDatabaseProtocol, handle: hii.HIIHandle) Status {
        return self._remove_package_list(self, handle);
    }

    /// Update a package list in the HII database.
    pub fn updatePackageList(self: *const HIIDatabaseProtocol, handle: hii.HIIHandle, buffer: *const hii.HIIPackageList) Status {
        return self._update_package_list(self, handle, buffer);
    }

    /// Determines the handles that are currently active in the database.
    pub fn listPackageLists(self: *const HIIDatabaseProtocol, package_type: u8, package_guid: ?*const Guid, buffer_length: *usize, handles: [*]hii.HIIHandle) Status {
        return self._list_package_lists(self, package_type, package_guid, buffer_length, handles);
    }

    /// Exports the contents of one or all package lists in the HII database into a buffer.
    pub fn exportPackageLists(self: *const HIIDatabaseProtocol, handle: ?hii.HIIHandle, buffer_size: *usize, buffer: *hii.HIIPackageList) Status {
        return self._export_package_lists(self, handle, buffer_size, buffer);
    }

    pub const guid align(8) = Guid{
        .time_low = 0xef9fc172,
        .time_mid = 0xa1b2,
        .time_high_and_version = 0x4693,
        .clock_seq_high_and_reserved = 0xb3,
        .clock_seq_low = 0x27,
        .node = [_]u8{ 0x6d, 0x32, 0xfc, 0x41, 0x60, 0x42 },
    };
};
