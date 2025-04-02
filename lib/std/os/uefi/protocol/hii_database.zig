const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;
const hii = uefi.hii;
const cc = uefi.cc;
const Error = Status.Error;

/// Database manager for HII-related data structures.
pub const HiiDatabase = extern struct {
    _new_package_list: Status, // TODO
    _remove_package_list: *const fn (*HiiDatabase, hii.Handle) callconv(cc) Status,
    _update_package_list: *const fn (*HiiDatabase, hii.Handle, *const hii.PackageList) callconv(cc) Status,
    _list_package_lists: *const fn (*const HiiDatabase, u8, ?*const Guid, *usize, ?[*]hii.Handle) callconv(cc) Status,
    _export_package_lists: *const fn (*const HiiDatabase, ?hii.Handle, *usize, ?[*]hii.PackageList) callconv(cc) Status,
    _register_package_notify: Status, // TODO
    _unregister_package_notify: Status, // TODO
    _find_keyboard_layouts: Status, // TODO
    _get_keyboard_layout: Status, // TODO
    _set_keyboard_layout: Status, // TODO
    _get_package_list_handle: Status, // TODO

    pub const RemovePackageListError = uefi.UnexpectedError || error{NotFound};
    pub const UpdatePackageListError = uefi.UnexpectedError || error{
        OutOfResources,
        InvalidParameter,
        NotFound,
    };
    pub const ActiveHandlesError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotFound,
    };
    pub const ListPackageListsError = ActiveHandlesError || error{
        BufferTooSmall,
    };
    pub const PackageListsLengthError = uefi.UnexpectedError || error{
        InvalidParameter,
        NotFound,
    };
    pub const ExportPackageListError = PackageListsLengthError || error{
        BufferTooSmall,
    };

    /// Removes a package list from the HII database.
    pub fn removePackageList(self: *HiiDatabase, handle: hii.Handle) !void {
        switch (self._remove_package_list(self, handle)) {
            .success => {},
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Update a package list in the HII database.
    pub fn updatePackageList(
        self: *HiiDatabase,
        handle: hii.Handle,
        package_list: *const hii.PackageList,
    ) UpdatePackageListError!void {
        switch (self._update_package_list(self, handle, package_list)) {
            .success => {},
            .out_of_resources => return Error.OutOfResources,
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn activeHandles(
        self: *const HiiDatabase,
        package_type: u8,
        package_guid: ?*align(8) const Guid,
    ) ActiveHandlesError!usize {
        var len: usize = 0;
        switch (self._list_package_lists(
            self,
            package_type,
            package_guid,
            &len,
            null,
        )) {
            .success, .buffer_too_small => return len,
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Determines the handles that are currently active in the database.
    pub fn listPackageLists(
        self: *const HiiDatabase,
        package_type: u8,
        package_guid: ?*align(8) const Guid,
        handles: []hii.Handle,
    ) ListPackageListsError!struct { usize, ?[]hii.Handle } {
        var len = handles.len;
        switch (self._list_package_lists(
            self,
            package_type,
            package_guid,
            &len,
            handles.ptr,
        )) {
            .success => return .{ len, handles[0..len] },
            .buffer_too_small => return .{ len, null },
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn packageListsLength(
        self: *const HiiDatabase,
        handle: ?hii.Handle,
    ) PackageListsLengthError!usize {
        var len: usize = 0;
        switch (self._export_package_lists(
            self,
            handle,
            &len,
            null,
        )) {
            .success, .buffer_too_small => return len,
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Exports the contents of one or all package lists in the HII database into a buffer.
    ///
    /// To get the necessary length of the buffer, call `packageListsLength` first.
    pub fn exportPackageLists(
        self: *const HiiDatabase,
        handle: ?hii.Handle,
        buffer: []hii.PackageList,
    ) ExportPackageListError!struct { usize, ?[]hii.PackageList } {
        var len = buffer.len;
        switch (self._export_package_lists(
            self,
            handle,
            &len,
            buffer.ptr,
        )) {
            .success => return .{ len, buffer[0..len] },
            .buffer_too_small => return .{ len, null },
            .invalid_parameter => return Error.InvalidParameter,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
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
