const std = @import("../../../std.zig");

const bits = @import("../bits.zig");
const table = @import("../table.zig");

const cc = bits.cc;
const Guid = bits.Guid;
const Status = @import("../status.zig").Status;

const MemoryMap = table.BootServices.MemoryMap;

/// Runtime services are provided by the firmware before and after exitBootServices has been called.
///
/// As the runtime_services table may grow with new UEFI versions, it is important to check hdr.header_size.
///
/// Some functions may not be supported. Check the RuntimeServicesSupported variable using getVariable.
/// getVariable is one of the functions that may not be supported.
///
/// Some functions may not be called while other functions are running.
pub const RuntimeServices = extern struct {
    hdr: table.Header,

    _getTime: *const fn (time: *bits.Time, capabilities: ?*bits.TimeCapabilities) callconv(cc) Status,
    _setTime: *const fn (time: *bits.Time) callconv(cc) Status,
    _getWakeupTime: *const fn (enabled: *bool, pending: *bool, time: *bits.Time) callconv(cc) Status,
    _setWakeupTime: *const fn (enable: bool, time: ?*const bits.Time) callconv(cc) Status,

    _setVirtualAddressMap: *const fn (mmap_size: usize, descriptor_size: usize, descriptor_version: u32, virtual_map: *const anyopaque) callconv(cc) Status,
    _convertPointer: *const fn (debug_disposition: usize, address: *?*anyopaque) callconv(cc) Status,

    _getVariable: *const fn (var_name: [*:0]const u16, vendor_guid: *align(8) const Guid, attributes: ?*VariableAttributes, data_size: *usize, data: ?[*]u8) callconv(cc) Status,
    _getNextVariableName: *const fn (var_name_size: *usize, var_name: [*:0]u16, vendor_guid: *align(8) Guid) callconv(cc) Status,
    _setVariable: *const fn (var_name: [*:0]const u16, vendor_guid: *align(8) const Guid, attributes: VariableAttributes, data_size: usize, data: *anyopaque) callconv(cc) Status,

    _getNextHighMonotonicCount: *const fn (high_count: *u32) callconv(cc) Status,
    _resetSystem: *const fn (reset_type: ResetType, reset_status: Status, data_size: usize, reset_data: ?*const anyopaque) callconv(cc) noreturn,

    _updateCapsule: *const fn (capsule_header_array: [*]*CapsuleHeader, capsule_count: usize, scatter_gather_list: bits.PhysicalAddress) callconv(cc) Status,
    _queryCapsuleCapabilities: *const fn (capsule_header_array: [*]*const CapsuleHeader, capsule_count: usize, maximum_capsule_size: *usize, resetType: *ResetType) callconv(cc) Status,

    _queryVariableInfo: *const fn (attributes: *VariableAttributes, maximum_variable_storage_size: *u64, remaining_variable_storage_size: *u64, maximum_variable_size: *u64) callconv(cc) Status,

    /// A tuple of EFI variable data and its attributes.
    pub const Variable = struct { []u8, VariableAttributes };

    /// Returns the size required to hold the value of a variable.
    pub fn getVariableSize(
        self: *const RuntimeServices,
        /// A null terminated string that is the name of the vendor's variable.
        variable_name: [*:0]const u16,
        /// A unique identifier for the vendor.
        vendor_guid: *align(8) const Guid,
    ) !?usize {
        var data_size: usize = 0;

        self._getVariable(variable_name, vendor_guid, null, &data_size, null).err() catch |err| switch (err) {
            error.NotFound => return null,
            else => |e| return e,
        };

        return data_size;
    }

    /// Returns the value of a variable.
    ///
    /// Use `getVariableSize()` to determine the size of the buffer to allocate.
    pub fn getVariable(
        self: *const RuntimeServices,
        /// A null terminated string that is the name of the vendor's variable.
        variable_name: [*:0]const u16,
        /// A unique identifier for the vendor.
        vendor_guid: *align(8) const Guid,
        /// The buffer to store the variable data.
        buffer: []u8,
    ) !?Variable {
        var attributes: VariableAttributes = @bitCast(@as(u32, 0));
        var data_size: usize = buffer.len;
        var data: [*]u8 = buffer.ptr;

        self._getVariable(variable_name, vendor_guid, &attributes, &data_size, data).err() catch |err| switch (err) {
            error.NotFound => return null,
            else => |e| return e,
        };

        return .{ data[0..data_size], attributes };
    }

    /// Enumerates the current variable names.
    ///
    /// Returns `false` if there are no more variables.
    ///
    /// You must handle `error.BufferTooSmall` by calling `getNextVariableName()` again with a buffer fit to hold
    /// the modified value stored in `variable_name_size` in bytes.
    pub fn getNextVariableName(
        self: *const RuntimeServices,
        /// The size of the buffer in bytes that `variable_name` points to.
        variable_name_size: *usize,
        /// On input, supplies the last variable name that was returned by `getNextVariableName()`.
        /// On output, returns the name of the next variable.
        variable_name: [*:0]u16,
        /// On input, supplies the last vendor GUID that was returned by `getNextVariableName()`.
        /// On output, returns the GUID of the next vendor.
        vendor_guid: *align(8) Guid,
    ) !bool {
        self._getNextVariableName(variable_name_size, variable_name, vendor_guid).err() catch |err| switch (err) {
            error.NotFound => return false,
            else => |e| return e,
        };

        return true;
    }

    /// The attributes of a EFI variable.
    pub const VariableAttributes = packed struct(u32) {
        /// Variable is stored in fixed hardware that has a limited storage capacity; sometimes a severly limited capacity.
        /// This should only be used when absolutely necessary. In addition, if software uses a nonvolatile variable it should
        /// use a variable that is only accessible at boot services time if possible.
        non_volatile: bool,

        /// Variable is visible during boot services time. Must be set when `runtime_access` is set.
        boot_service_access: bool,

        /// Variable is visible during runtime services time. After exiting boot services, the contents of this variable
        /// remain available.
        runtime_access: bool,

        /// Variable has defined meaning as a hardware error record.
        hardware_error_record: bool,

        /// Previously "authenticated_write_access", now deprecated and reserved.
        reserved: u1,

        /// Variable uses the EFI_VARIABLE_AUTHENTICATION_2 structure. Mutually exclusive with `enhanced_authenticated_access`.
        time_based_authenticated_write_access: bool,

        /// Variable writes are appended instead of overwriting.
        append_write: bool,

        /// The variable payload begins with a EFI_VARIABLE_AUTHENTICATION_3 structure, and potentially more structures as
        /// indicated by fields of this structure. Mutually exclusive with `time_based_authenticated_write_access`.
        enhanced_authenticated_access: bool,

        _pad1: u24,
    };

    /// Sets, modifies or deletes the value of a variable.
    pub fn setVariable(
        self: *const RuntimeServices,
        /// A null terminated string that is the name of the vendor's variable.
        variable_name: [*:0]const u16,
        /// A unique identifier for the vendor.
        vendor_guid: *align(8) const Guid,
        /// The attributes to set for the variable.
        attributes: VariableAttributes,
        /// The data to set.
        data: []u8,
    ) !void {
        self._setVariable(variable_name, vendor_guid, attributes, data.len, data.ptr).err() catch |err| switch (err) {
            error.NotFound => return,
            else => |e| return e,
        };
    }

    /// Returns the current time and date information.
    pub fn getTime(
        self: *const RuntimeServices,
    ) !bits.Time {
        var time: bits.Time = undefined;
        try self._getTime(&time, null).err();
        return time;
    }

    /// Returns the time-keeping capabilities of the hardware platform.
    pub fn getTimeCapabilities(
        self: *const RuntimeServices,
    ) !bits.TimeCapabilities {
        var time: bits.Time = undefined;
        var capabilities: bits.TimeCapabilities = undefined;
        try self._getTime(&time, &capabilities).err();
        return capabilities;
    }

    /// The state of the wakeup alarm clock.
    pub const Alarm = struct {
        /// Indicates if the alarm is enabled or disabled.
        enabled: bool,

        /// Indicates if the alarm signal is pending and requires acknowledgement.
        pending: bool,

        /// The current alarm setting. Resolution is defined to be one second.
        time: bits.Time,
    };

    /// Returns the current wakeup alarm clock setting.
    pub fn getWakeupTime(
        self: *const RuntimeServices,
    ) !Alarm {
        var enabled: bool = false;
        var pending: bool = false;
        var time: bits.Time = undefined;
        try self._getWakeupTime(&enabled, &pending, &time).err();
        return .{ .enabled = enabled, .pending = pending, .time = time };
    }

    /// Sets the current wakeup alarm clock setting.
    pub fn setWakeupTime(
        self: *const RuntimeServices,
        /// The new alarm setting. Resolution is defined to be one second.
        /// If `null`, the alarm is disabled.
        time: ?bits.Time,
    ) !void {
        const enabled: bool = time != null;
        try self._setWakeupTime(enabled, if (time) |*t| t else null).err();
    }

    /// Changes the runtime addresssing mode of EFI firmware from physical to virtual.
    ///
    /// This can only be called at runtime (ie. after `exitBootServices()` has been called).
    pub fn setVirtualAddressMap(
        self: *const RuntimeServices,
        /// The memory map of the address space.
        map: MemoryMap,
    ) !void {
        try self._setVirtualAddressMap(map.size, map.descriptor_size, map.descriptor_version, map.map).err();
    }

    /// Converts a pointer from physical to virtual addressing mode.
    pub fn convertPointer(
        self: *const RuntimeServices,
        /// The pointer to convert.
        pointer: anytype,
    ) !@TypeOf(pointer) {
        const T = @TypeOf(pointer);
        const info = @typeInfo(T);

        if (info != .Pointer and (info != .Optional or @typeInfo(info.Optional.child) != .Pointer)) {
            @compileError("convertPointer() cannot convert non-pointer type " ++ @typeName(T));
        }

        // If the pointer is nullable, we need to set `EFI_OPTIONAL_PTR`.
        const disposition: usize = if (info == .Optional) 0x1 else 0x0;

        // This pointer needs to be the least qualified form because that's how we need to pass it to UEFI.
        // This is completely safe, because UEFI never dereferences the pointer.
        var address: ?*anyopaque = @volatileCast(@constCast(@ptrCast(pointer)));
        try self._convertPointer(disposition, &address).err();

        // Requalify the pointer and cast it back to the type we originally had.
        return @alignCast(@ptrCast(address));
    }

    pub const ResetType = enum(u32) {
        /// Sets all circuitry in within the system to its initial state. This is tantamount to a system power cycle.
        cold,

        /// The processors are set to their initial state and pending cycles are not corrupted.
        ///
        /// If this is not supported, a `cold` reset must be used.
        warm,

        /// Causes the system to enter a power state equivalent to the ACPI G2/S5 or G3 states.
        ///
        /// If this is not supported, the system will exhibit the same behaviour as `cold`.
        shutdown,

        /// Causes the system to perform a reset defined by a GUID provided after the string in the `reset_data` parameter.
        platform,
    };

    /// Resets the entire platform.
    pub fn resetSystem(
        self: *const RuntimeServices,
        /// The type of reset to perform.
        reset_type: ResetType,
        /// The status code for the reset.
        reset_status: Status,
        /// A null terminated string that describes the reset, followed by optional binary data or a GUID.
        reset_data: ?[]align(2) u8,
    ) noreturn {
        if (reset_data) |data| {
            self._resetSystem(reset_type, reset_status, data.len, data.ptr);
        } else {
            self._resetSystem(reset_type, reset_status, 0, null);
        }
    }

    /// Returns the next high 32 bits of the platform's monotonic counter.
    ///
    /// This value is non-volatile and is incremented whenever the system resets, `getNextHighMonotonicCount()` is called,
    /// or when the lower 32 bits (accessible during boot services) of the monotonic counter wrap around.
    pub fn getNextHighMonotonicCount(
        self: *const RuntimeServices,
    ) !u32 {
        var high_count: u32 = undefined;
        try self._getNextHighMonotonicCount(&high_count).err();

        return high_count;
    }

    pub const CapsuleHeader = extern struct {
        pub const Flags = packed struct(u32) {
            guid_defined: u16,

            /// Firmware will attempt to process or launch the capsule across a system reset. If the capsule is not
            /// recognized or processing requires a reset that is not supported, then expect an error.
            persist_across_reset: bool,

            /// If true, then `persist_across_reset` must be true.
            ///
            /// Firmware will coalese the capsule from the scatter list into a contiguous buffer and place a pointer to it
            /// into the system table. Recognition is not required. If processing requires a reset that is not supported,
            /// then expect an error.
            populate_system_table: bool,

            /// If true, then `persist_across_reset` must be true.
            ///
            /// Firmware will attempt to process or launch the capsule across a system reset. If the capsule is not
            /// recognized or processing requires a reset that is not supported, then expect an error.
            ///
            /// The firmware will initiate a reset which is compatible with the passed-in capsule request and will not
            /// return to the caller.
            initiate_reset: bool,

            _pad1: u13,
        };

        /// A GUID that defines the contents of the capsule.
        capsule_guid: Guid align(8),

        /// The size in bytes of the capsule header. This may be larger than the size of the structure defined here since
        /// `capsule_guid` may imply additional entries.
        header_size: u32,

        /// The capsule flags.
        flags: Flags,

        /// The size in bytes of the capsule, including the capsule header.
        capsule_size: u32,
    };

    pub const CapsuleBlockDescriptor = extern struct {
        /// Length in bytes of the data pointed to by `address`.
        ///
        /// If `length` is zero, then `address.continuation` is active. Otherwise, `address.block` is active.
        length: u64,
        address: extern union {
            /// The physical address of the capsule data.
            block: bits.PhysicalAddress,

            /// The physical address of another list of `CapsuleBlockDescriptor` structures.
            ///
            /// When zero, this indicates the end of the list
            continuation: bits.PhysicalAddress,
        },
    };

    /// Passes capsules to the firmware with both virtual and physical mapping. Depending on the intended consumption,
    /// the firmware may process the capsule immediately. If the payload should persist across a system reset, the
    /// reset value returned from `queryCapsuleCapabilities()` must be passed into `resetSystem()` and will cause the
    /// capsule to be processed by the firmware as part of the reset process.
    pub fn updateCapsule(
        self: *const RuntimeServices,
        /// An array of pointers to capsule headers.
        capsule_headers: []*CapsuleHeader,
        /// A physical pointer to a list of `CapsuleBlockDescriptor` structures that describe the location in physical
        /// memory of a set of capsules. This list must be in the same order as the capsules pointed to by
        /// `capsule_headers`.
        scatter_gather_list: bits.PhysicalAddress,
    ) !void {
        try self._updateCapsule(capsule_headers.ptr, capsule_headers.len, scatter_gather_list).err();
    }

    /// A tuple of the maximum size in bytes of a capsule, and the reset type required to process the capsule.
    pub const CapsuleCapabilities = struct { u64, ResetType };

    /// Returns if the capsule can be supported via `updateCapsule()`.
    pub fn queryCapsuleCapabilities(
        self: *const RuntimeServices,
        /// An array of pointers to capsule headers.
        capsule_headers: []*const CapsuleHeader,
    ) !CapsuleCapabilities {
        var maximum_capsule_size: usize = undefined;
        var reset_type: ResetType = undefined;
        try self._queryCapsuleCapabilities(capsule_headers.ptr, capsule_headers.len, &maximum_capsule_size, &reset_type).err();

        return .{ maximum_capsule_size, reset_type };
    }

    pub const signature: u64 = 0x56524553544e5552;

    /// The EFI Global Variable vendor GUID.
    pub const global_variable align(8) = Guid{
        .time_low = 0x8be4df61,
        .time_mid = 0x93ca,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0xaa,
        .clock_seq_low = 0x0d,
        .node = [_]u8{ 0x00, 0xe0, 0x98, 0x03, 0x2b, 0x8c },
    };
};
