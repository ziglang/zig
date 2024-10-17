//! A type designed to propagate OpenTelemetry between different APIs in a loosely
//! coupled way.
//!
//! Immutable.
const Context = @This();

/// The inner value used to implement Context. The default implementation
/// (NULL_CONTEXT_TYPE) is an empty struct.
inner: otel.types.Context,

pub fn destroy(context: Context) void {
    otel.functions.context.destroy(context.inner);
}

pub fn getValue(context: Context, T: type) ?T {
    var return_value: T = undefined;
    if (otel.functions.context.get_value(context.inner, T, std.mem.asBytes(&return_value))) {
        return return_value;
    } else {
        return null;
    }
}

/// Returns a new Context with the given type set to the given `value`.
pub fn withValue(context: Context, T: type, value: T) Context {
    return Context{ .inner = otel.functions.context.with_value(context.inner, T, std.mem.asBytes(&value)) };
}

/// Get the current context for the current "execution unit".
///
/// "Execution unit" will depend on the implementation, but generally means "the
/// current thread".
pub fn current() Context {
    return Context{ .inner = otel.functions.context.current() };
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
    return AttachToken{ .inner = otel.functions.context.attach(context.inner) };
}

/// A value received after attaching a context to the current "execution unit". Used
/// to detach the context, and may be used by the implementation to check that
/// detach order is correct.
pub const AttachToken = struct {
    inner: otel.types.ContextAttachToken,

    pub fn detach(attach_token: AttachToken) void {
        return otel.functions.context.detach(attach_token.inner);
    }
};

/// The list of Functions that MUST be provided to implement the `otel.Context` api.
pub const Functions = struct {
    get_value: fn (otel.types.Context, T: type, return_value: []u8) bool,
    with_value: fn (otel.types.Context, T: type, value_bytes: []const u8) otel.types.Context,
    destroy: fn (otel.types.Context) void,
    current: fn () otel.types.Context,
    attach: fn (otel.types.Context) otel.types.ContextAttachToken,
    detach: fn (otel.types.ContextAttachToken) void,
};

/// The default types used to implement `Context` that do nothing.
pub const NULL_CONTEXT_TYPE = struct {};
pub const NULL_ATTACH_TOKEN_TYPE = struct {};

/// The default functions used to implement `Context` that do nothing.
pub const NULL_FUNCTIONS: Functions = .{
    .get_value = nullGetValue,
    .with_value = nullWithValue,
    .destroy = nullDestroy,
    .current = nullCurrent,
    .attach = nullAttach,
    .detach = nullDetach,
};

fn nullGetValue(context: otel.types.Context, T: type, return_value: []u8) bool {
    _ = context;
    _ = T;
    _ = return_value;
    return false;
}

fn nullWithValue(context: otel.types.Context, T: type, value_bytes: []const u8) otel.types.Context {
    _ = context;
    _ = T;
    _ = value_bytes;
    return .{};
}

fn nullDestroy(context: otel.types.Context) void {
    _ = context;
}

fn nullCurrent() otel.types.Context {
    return .{};
}

fn nullAttach(context: otel.types.Context) otel.types.ContextAttachToken {
    _ = context;
    return .{};
}

fn nullDetach(attach_token: otel.types.ContextAttachToken) void {
    _ = attach_token;
}

const otel = @import("../otel.zig");
const std = @import("../std.zig");
