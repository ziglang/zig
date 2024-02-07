const std = @import("../../../std.zig");
const bits = @import("../bits.zig");

const cc = bits.cc;
const Status = @import("../status.zig").Status;

const Guid = bits.Guid;
const Handle = bits.Handle;

pub fn ServiceBinding(comptime Protocol: type) type {
    return extern struct {
        const Binding = @This();

        _create_child: *const fn (*const Binding, *Handle) callconv(cc) Status,
        _destroy_child: *const fn (*const Binding, Handle) callconv(cc) Status,

        /// Creates a child handle and installs a protocol. The returned handle is guaranteed to have the protocol installed.
        pub fn create(
            this: *const Binding,
            /// The child handle to install the protocol on. If null, a new handle will be created.
            child: ?Handle,
        ) !Handle {
            var handle = child;
            try this._create_child(this, &handle).err();
            return handle orelse unreachable;
        }

        /// Destroys a child handle with a protocol installed on it
        pub fn destroy(
            this: *const Binding,
            /// The child handle the protocol was installed on.
            handle: Handle,
        ) !void {
            try this._destroy_child(this, handle).err();
        }

        pub const guid = Protocol.service_binding_guid;
    };
}
