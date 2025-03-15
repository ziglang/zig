const std = @import("std");
const uefi = std.os.uefi;
const Handle = uefi.Handle;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

pub const Ip6ServiceBinding = extern struct {
    _create_child: *const fn (*const Ip6ServiceBinding, *?Handle) callconv(cc) Status,
    _destroy_child: *const fn (*const Ip6ServiceBinding, Handle) callconv(cc) Status,

    pub const CreateChildError = uefi.UnexpectedError || error{
        InvalidParameter,
        OutOfResources,
    } || Error; // TODO: according to the spec, _any other_ status is returnable?
    pub const DestroyChildError = uefi.UnexpectedError || error{
        Unsupported,
        InvalidParameter,
        AccessDenied,
    } || Error; // TODO: according to the spec, _any other_ status is returnable?

    pub fn createChild(self: *const Ip6ServiceBinding, handle: *?Handle) Status {
        switch (self._create_child(self, handle)) {
            .success => {},
            // .invalid_parameter => return Error.InvalidParameter,
            // .out_of_resources => return Error.OutOfResources,
            else => |status| {
                try status.err();
                // TODO: only warnings get here???
                return uefi.unexpectedStatus(status);
            },
        }
    }

    pub fn destroyChild(self: *const Ip6ServiceBinding, handle: Handle) Status {
        switch (self._destroy_child(self, handle)) {
            .success => {},
            // .unsupported => return Error.Unsupported,
            // .invalid_parameter => return Error.InvalidParameter,
            // .access_denied => return Error.AccessDenied,
            else => |status| {
                try status.err();
                // TODO: only warnings get here???
                return uefi.unexpectedStatus(status);
            },
        }
    }

    pub const guid align(8) = Guid{
        .time_low = 0xec835dd3,
        .time_mid = 0xfe0f,
        .time_high_and_version = 0x617b,
        .clock_seq_high_and_reserved = 0xa6,
        .clock_seq_low = 0x21,
        .node = [_]u8{ 0xb3, 0x50, 0xc3, 0xe1, 0x33, 0x88 },
    };
};
