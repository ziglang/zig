//! A type designed to propagate OpenTelemetry between different APIs in a loosely
//! coupled way.
//!
//! Immutable.
const Context = @This();

/// The value used by the implementation to implement `Context`. No peeking!
impl: std.otel.types.context.Context,

pub fn destroy(context: Context) void {
    std.otel.functions.context.destroy(context.impl);
}

pub fn getValue(context: Context, T: type) ?T {
    var return_value: T = undefined;
    if (std.otel.functions.context.get_value(context.impl, T, std.mem.asBytes(&return_value))) {
        return return_value;
    } else {
        return null;
    }
}

/// Returns a new Context with the given type set to the given `value`.
pub fn withValue(context: Context, T: type, value: T) Context {
    return .{ .impl = std.otel.functions.context.with_value(context.impl, T, std.mem.asBytes(&value)) };
}

/// Get the current context for the current "execution unit".
///
/// "Execution unit" will depend on the implementation, but generally means "the
/// current thread".
pub fn current() Context {
    return .{ .impl = std.otel.functions.context.current() };
}

/// Mark the given Context as the current context for the current "execution unit".
/// Every call to `attach` should be matched with a corresponding call to
/// `AttachToken.detach`
///
/// Returns an `AttachToken` that must be used to detach this context from the
/// execution unit.
///
/// "Execution unit" will depend on the implementation, but generally means "the
/// current thread".
pub fn attach(context: Context) AttachToken {
    return .{ .impl = std.otel.functions.context.attach(context.impl) };
}

/// A value received after attaching a context to the current "execution unit". Used
/// to detach the context, and may be used by the implementation to check that
/// detach order is correct.
pub const AttachToken = struct {
    impl: std.otel.types.context.AttachToken,

    pub fn detach(attach_token: AttachToken) void {
        return std.otel.functions.context.detach(attach_token.impl);
    }
};

/// The list of types that MUST be provided to implement the `otel.Context` api.
pub const Types = struct {
    Context: type,
    AttachToken: type,
};

/// The list of Functions that MUST be provided to implement the `otel.Context` api.
pub const Functions = struct {
    get_value: fn (impl_types.Context, T: type, return_value: []u8) bool,
    with_value: fn (impl_types.Context, T: type, value_bytes: []const u8) impl_types.Context,
    destroy: fn (impl_types.Context) void,
    current: fn () impl_types.Context,
    attach: fn (impl_types.Context) impl_types.AttachToken,
    detach: fn (impl_types.AttachToken) void,

    const impl_types = std.otel.types.context;
};

/// The default types used to implement `Context` that do nothing.
pub const NULL_TYPES: Types = .{
    .Context = struct {},
    .AttachToken = struct {},
};

/// The default functions used to implement `Context` that do nothing.
pub const NULL_FUNCTIONS: Functions = .{
    .get_value = nullGetValue,
    .with_value = nullWithValue,
    .destroy = nullDestroy,
    .current = nullCurrent,
    .attach = nullAttach,
    .detach = nullDetach,
};

fn nullGetValue(context: std.otel.types.context.Context, T: type, return_value: []u8) bool {
    _ = context;
    _ = T;
    _ = return_value;
    return false;
}

fn nullWithValue(context: std.otel.types.context.Context, T: type, value_bytes: []const u8) std.otel.types.context.Context {
    _ = context;
    _ = T;
    _ = value_bytes;
    return .{};
}

fn nullDestroy(context: std.otel.types.context.Context) void {
    _ = context;
}

fn nullCurrent() std.otel.types.context.Context {
    return .{};
}

fn nullAttach(context: std.otel.types.context.Context) std.otel.types.context.AttachToken {
    _ = context;
    return .{};
}

fn nullDetach(attach_token: std.otel.types.context.AttachToken) void {
    _ = attach_token;
}

const std = @import("../std.zig");
