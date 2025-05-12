const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const TableHeader = uefi.tables.TableHeader;
const Time = uefi.Time;
const TimeCapabilities = uefi.TimeCapabilities;
const Status = uefi.Status;
const MemoryDescriptor = uefi.tables.MemoryDescriptor;
const MemoryMapSlice = uefi.tables.MemoryMapSlice;
const ResetType = uefi.tables.ResetType;
const CapsuleHeader = uefi.tables.CapsuleHeader;
const PhysicalAddress = uefi.tables.PhysicalAddress;
const cc = uefi.cc;
const Error = Status.Error;

/// Runtime services are provided by the firmware before and after exitBootServices has been called.
///
/// As the runtime_services table may grow with new UEFI versions, it is important to check hdr.header_size.
///
/// Some functions may not be supported. Check the RuntimeServicesSupported variable using getVariable.
/// getVariable is one of the functions that may not be supported.
///
/// Some functions may not be called while other functions are running.
pub const RuntimeServices = extern struct {
    hdr: TableHeader,

    /// Returns the current time and date information, and the time-keeping capabilities of the hardware platform.
    _getTime: *const fn (time: *Time, capabilities: ?*TimeCapabilities) callconv(cc) Status,

    /// Sets the current local time and date information
    _setTime: *const fn (time: *const Time) callconv(cc) Status,

    /// Returns the current wakeup alarm clock setting
    _getWakeupTime: *const fn (enabled: *bool, pending: *bool, time: *Time) callconv(cc) Status,

    /// Sets the system wakeup alarm clock time
    _setWakeupTime: *const fn (enable: bool, time: ?*const Time) callconv(cc) Status,

    /// Changes the runtime addressing mode of EFI firmware from physical to virtual.
    _setVirtualAddressMap: *const fn (mmap_size: usize, descriptor_size: usize, descriptor_version: u32, virtual_map: [*]align(@alignOf(MemoryDescriptor)) u8) callconv(cc) Status,

    /// Determines the new virtual address that is to be used on subsequent memory accesses.
    _convertPointer: *const fn (debug_disposition: DebugDisposition, address: *?*anyopaque) callconv(cc) Status,

    /// Returns the value of a variable.
    _getVariable: *const fn (var_name: [*:0]const u16, vendor_guid: *const Guid, attributes: ?*VariableAttributes, data_size: *usize, data: ?*anyopaque) callconv(cc) Status,

    /// Enumerates the current variable names.
    _getNextVariableName: *const fn (var_name_size: *usize, var_name: ?[*:0]const u16, vendor_guid: *Guid) callconv(cc) Status,

    /// Sets the value of a variable.
    _setVariable: *const fn (var_name: [*:0]const u16, vendor_guid: *const Guid, attributes: VariableAttributes, data_size: usize, data: [*]const u8) callconv(cc) Status,

    /// Return the next high 32 bits of the platform's monotonic counter
    _getNextHighMonotonicCount: *const fn (high_count: *u32) callconv(cc) Status,

    /// Resets the entire platform.
    _resetSystem: *const fn (reset_type: ResetType, reset_status: Status, data_size: usize, reset_data: ?[*]const u16) callconv(cc) noreturn,

    /// Passes capsules to the firmware with both virtual and physical mapping.
    /// Depending on the intended consumption, the firmware may process the capsule immediately.
    /// If the payload should persist across a system reset, the reset value returned from
    /// `queryCapsuleCapabilities` must be passed into resetSystem and will cause the capsule
    /// to be processed by the firmware as part of the reset process.
    _updateCapsule: *const fn (capsule_header_array: [*]*const CapsuleHeader, capsule_count: usize, scatter_gather_list: PhysicalAddress) callconv(cc) Status,

    /// Returns if the capsule can be supported via `updateCapsule`
    _queryCapsuleCapabilities: *const fn (capsule_header_array: [*]*const CapsuleHeader, capsule_count: usize, maximum_capsule_size: *usize, reset_type: *ResetType) callconv(cc) Status,

    /// Returns information about the EFI variables
    _queryVariableInfo: *const fn (attributes: VariableAttributes, maximum_variable_storage_size: *u64, remaining_variable_storage_size: *u64, maximum_variable_size: *u64) callconv(cc) Status,

    pub const GetTimeError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };

    pub const SetTimeError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };

    pub const GetWakeupTimeError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };

    pub const SetWakeupTimeError = uefi.UnexpectedError || error{
        InvalidParameter,
        DeviceError,
        Unsupported,
    };

    pub const SetVirtualAddressMapError = uefi.UnexpectedError || error{
        Unsupported,
        NoMapping,
        NotFound,
    };

    pub const ConvertPointerError = uefi.UnexpectedError || error{
        InvalidParameter,
        Unsupported,
    };

    pub const GetVariableSizeError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };

    pub const GetVariableError = GetVariableSizeError || error{
        BufferTooSmall,
    };

    pub const SetVariableError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
        DeviceError,
        WriteProtected,
        SecurityViolation,
        NotFound,
        Unsupported,
    };

    pub const GetNextHighMonotonicCountError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };

    pub const UpdateCapsuleError = uefi.UnexpectedError || error{
        InvalidParameter,
        DeviceError,
        Unsupported,
        OutOfResources,
    };

    pub const QueryCapsuleCapabilitiesError = uefi.UnexpectedError || error{
        Unsupported,
        OutOfResources,
    };

    pub const QueryVariableInfoError = uefi.UnexpectedError || error{
        InvalidParameter,
        Unsupported,
    };

    /// Returns the current time and the time capabilities of the platform.
    pub fn getTime(
        self: *const RuntimeServices,
    ) GetTimeError!struct { Time, TimeCapabilities } {
        var time: Time = undefined;
        var capabilities: TimeCapabilities = undefined;

        switch (self._getTime(&time, &capabilities)) {
            .success => return .{ time, capabilities },
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn setTime(self: *RuntimeServices, time: *const Time) SetTimeError!void {
        switch (self._setTime(time)) {
            .success => {},
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const GetWakeupTime = struct {
        enabled: bool,
        pending: bool,
        time: Time,
    };

    pub fn getWakeupTime(
        self: *const RuntimeServices,
    ) GetWakeupTimeError!GetWakeupTime {
        var result: GetWakeupTime = undefined;
        switch (self._getWakeupTime(
            &result.enabled,
            &result.pending,
            &result.time,
        )) {
            .success => return result,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const SetWakeupTime = union(enum) {
        enabled: *const Time,
        disabled,
    };

    pub fn setWakeupTime(
        self: *RuntimeServices,
        set: SetWakeupTime,
    ) SetWakeupTimeError!void {
        switch (self._setWakeupTime(
            set != .disabled,
            if (set == .enabled) set.enabled else null,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn setVirtualAddressMap(
        self: *RuntimeServices,
        map: MemoryMapSlice,
    ) SetVirtualAddressMapError!void {
        switch (self._setVirtualAddressMap(
            map.info.len * map.info.descriptor_size,
            map.info.descriptor_size,
            map.info.descriptor_version,
            @ptrCast(map.ptr),
        )) {
            .success => {},
            .unsupported => return Error.Unsupported,
            .no_mapping => return Error.NoMapping,
            .not_found => return Error.NotFound,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn convertPointer(
        self: *const RuntimeServices,
        comptime disposition: DebugDisposition,
        cvt: @FieldType(PointerConversion, @tagName(disposition)),
    ) ConvertPointerError!?@FieldType(PointerConversion, @tagName(disposition)) {
        var pointer = cvt;

        switch (self._convertPointer(disposition, @ptrCast(&pointer))) {
            .success => return pointer,
            .not_found => return null,
            .invalid_parameter => return Error.InvalidParameter,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Returns the length of the variable's data and its attributes.
    pub fn getVariableSize(
        self: *const RuntimeServices,
        name: [*:0]const u16,
        guid: *const Guid,
    ) GetVariableSizeError!?struct { usize, VariableAttributes } {
        var size: usize = 0;
        var attrs: VariableAttributes = undefined;

        switch (self._getVariable(
            name,
            guid,
            &attrs,
            &size,
            null,
        )) {
            .buffer_too_small => return .{ size, attrs },
            .not_found => return null,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// To determine the minimum necessary buffer size for the variable, call
    /// `getVariableSize` first.
    pub fn getVariable(
        self: *const RuntimeServices,
        name: [*:0]const u16,
        guid: *const Guid,
        buffer: []u8,
    ) GetVariableError!?struct { []u8, VariableAttributes } {
        var attrs: VariableAttributes = undefined;
        var len = buffer.len;

        switch (self._getVariable(
            name,
            guid,
            &attrs,
            &len,
            buffer.ptr,
        )) {
            .success => return .{ buffer[0..len], attrs },
            .not_found => return null,
            .buffer_too_small => return Error.BufferTooSmall,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn variableNameIterator(
        self: *const RuntimeServices,
        buffer: []u16,
    ) VariableNameIterator {
        buffer[0] = 0;
        return .{
            .services = self,
            .buffer = buffer,
            .guid = undefined,
        };
    }

    pub fn setVariable(
        self: *RuntimeServices,
        name: [*:0]const u16,
        guid: *const Guid,
        attributes: VariableAttributes,
        data: []const u8,
    ) SetVariableError!void {
        switch (self._setVariable(
            name,
            guid,
            attributes,
            data.len,
            data.ptr,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .out_of_resources => return Error.OutOfResources,
            .device_error => return Error.DeviceError,
            .write_protected => return Error.WriteProtected,
            .security_violation => return Error.SecurityViolation,
            .not_found => return Error.NotFound,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn getNextHighMonotonicCount(self: *const RuntimeServices) GetNextHighMonotonicCountError!u32 {
        var cnt: u32 = undefined;
        switch (self._getNextHighMonotonicCount(&cnt)) {
            .success => return cnt,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn resetSystem(
        self: *RuntimeServices,
        reset_type: ResetType,
        reset_status: Status,
        data: ?[]const u8,
    ) noreturn {
        self._resetSystem(
            reset_type,
            reset_status,
            if (data) |d| d.len else 0,
            if (data) |d| @alignCast(@ptrCast(d.ptr)) else null,
        );
    }

    pub fn updateCapsule(
        self: *RuntimeServices,
        capsules: []*const CapsuleHeader,
        scatter_gather_list: PhysicalAddress,
    ) UpdateCapsuleError!void {
        switch (self._updateCapsule(
            capsules.ptr,
            capsules.len,
            scatter_gather_list,
        )) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn queryCapsuleCapabilities(
        self: *const RuntimeServices,
        capsules: []*const CapsuleHeader,
    ) QueryCapsuleCapabilitiesError!struct { u64, ResetType } {
        var max_capsule_size: u64 = undefined;
        var reset_type: ResetType = undefined;

        switch (self._queryCapsuleCapabilities(
            capsules.ptr,
            capsules.len,
            &max_capsule_size,
            &reset_type,
        )) {
            .success => return .{ max_capsule_size, reset_type },
            .unsupported => return Error.Unsupported,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub fn queryVariableInfo(
        self: *const RuntimeServices,
        // Note: .append_write is ignored
        attributes: VariableAttributes,
    ) QueryVariableInfoError!VariableInfo {
        var res: VariableInfo = undefined;

        switch (self._queryVariableInfo(
            attributes,
            &res.max_variable_storage_size,
            &res.remaining_variable_storage_size,
            &res.max_variable_size,
        )) {
            .success => return res,
            .invalid_parameter => return Error.InvalidParameter,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const DebugDisposition = enum(usize) {
        const Bits = packed struct(usize) {
            optional_ptr: bool = false,
            _pad: std.meta.Int(.unsigned, @bitSizeOf(usize) - 1) = 0,
        };

        pointer = @bitCast(Bits{}),
        optional = @bitCast(Bits{ .optional_ptr = true }),
        _,
    };

    pub const PointerConversion = union(DebugDisposition) {
        pointer: *anyopaque,
        optional: ?*anyopaque,
    };

    pub const VariableAttributes = packed struct(u32) {
        non_volatile: bool = false,
        bootservice_access: bool = false,
        runtime_access: bool = false,
        hardware_error_record: bool = false,
        /// Note: deprecated and should be considered reserved.
        authenticated_write_access: bool = false,
        time_based_authenticated_write_access: bool = false,
        append_write: bool = false,
        /// Indicates that the variable payload begins with a EFI_VARIABLE_AUTHENTICATION_3
        /// structure, and potentially more structures as indicated by fields of
        /// this structure.
        enhanced_authenticated_access: bool = false,
        _pad: u24 = 0,
    };

    pub const VariableAuthentication3 = extern struct {
        version: u8 = 1,
        type: Type,
        metadata_size: u32,
        flags: Flags,

        pub fn payloadConst(self: *const VariableAuthentication3) []const u8 {
            return @constCast(self).payload();
        }

        pub fn payload(self: *VariableAuthentication3) []u8 {
            var ptr: [*]u8 = @ptrCast(self);
            return ptr[@sizeOf(VariableAuthentication3)..self.metadata_size];
        }

        pub const Flags = packed struct(u32) {
            update_cert: bool = false,
            _pad: u31 = 0,
        };

        pub const Type = enum(u8) {
            timestamp = 1,
            nonce = 2,
            _,
        };
    };

    pub const VariableInfo = struct {
        max_variable_storage_size: u64,
        remaining_variable_storage_size: u64,
        max_variable_size: u64,
    };

    pub const VariableNameIterator = struct {
        pub const NextSizeError = uefi.UnexpectedError || error{
            DeviceError,
            Unsupported,
        };

        pub const IterateVariableNameError = NextSizeError || error{
            BufferTooSmall,
        };

        services: *const RuntimeServices,
        buffer: []u16,
        guid: Guid,

        pub fn nextSize(self: *VariableNameIterator) NextSizeError!?usize {
            var len: usize = 0;
            switch (self.services._getNextVariableName(
                &len,
                null,
                &self.guid,
            )) {
                .buffer_too_small => return len,
                .not_found => return null,
                .device_error => return Error.DeviceError,
                .unsupported => return Error.Unsupported,
                else => |status| return uefi.unexpectedStatus(status),
            }
        }

        /// Call `nextSize` to get the length of the next variable name and check
        /// if `buffer` is large enough to hold the name.
        pub fn next(
            self: *VariableNameIterator,
        ) IterateVariableNameError!?[:0]const u16 {
            var len = self.buffer.len;
            switch (self.services._getNextVariableName(
                &len,
                @ptrCast(self.buffer.ptr),
                &self.guid,
            )) {
                .success => return self.buffer[0 .. len - 1 :0],
                .not_found => return null,
                .buffer_too_small => return Error.BufferTooSmall,
                .device_error => return Error.DeviceError,
                .unsupported => return Error.Unsupported,
                else => |status| return uefi.unexpectedStatus(status),
            }
        }
    };

    pub const signature: u64 = 0x56524553544e5552;
};
