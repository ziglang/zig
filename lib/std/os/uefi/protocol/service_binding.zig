const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Handle = uefi.Handle;
const Status = uefi.Status;
const Error = Status.Error;
const cc = uefi.cc;

pub fn ServiceBinding(service_guid: Guid) type {
    return struct {
        const Self = @This();

        _create_child: *const fn (*Self, *?Handle) callconv(cc) Status,
        _destroy_child: *const fn (*Self, Handle) callconv(cc) Status,

        pub const CreateChildError = uefi.UnexpectedError || error{
            InvalidParameter,
            OutOfResources,
        } || Error;
        pub const DestroyChildError = uefi.UnexpectedError || error{
            Unsupported,
            InvalidParameter,
            AccessDenied,
        } || Error;

        /// To add this protocol to an existing handle, use `addToHandle` instead.
        pub fn createChild(self: *Self) CreateChildError!Handle {
            var handle: ?Handle = null;
            switch (self._create_child(self, &handle)) {
                .success => return handle orelse error.Unexpected,
                else => |status| {
                    try status.err();
                    return uefi.unexpectedStatus(status);
                },
            }
        }

        pub fn addToHandle(self: *Self, handle: Handle) CreateChildError!void {
            switch (self._create_child(self, @ptrCast(@constCast(&handle)))) {
                .success => {},
                else => |status| {
                    try status.err();
                    return uefi.unexpectedStatus(status);
                },
            }
        }

        pub fn destroyChild(self: *Self, handle: Handle) DestroyChildError!void {
            switch (self._destroy_child(self, handle)) {
                .success => {},
                else => |status| {
                    try status.err();
                    return uefi.unexpectedStatus(status);
                },
            }
        }

        pub const guid align(8) = service_guid;
    };
}
