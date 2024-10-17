//! A set of APIs for instrumenting code with various telemetry data. Currently only
//! two APIs are provided: `otel.Context`, and `otel.trace`.
//!
//! - `otel.Context` provides a way to link telemetry data together, giving you a
//!   fuller picture of what is going on.
//! - `otel.trace` provides a way to trace the flow of execution.
//!
//! By default these APIs do nothing, to collect telemetry data the software
//! developer will need to specify an implementation, like so:
//!
//! ```zig
//! pub const otel_types: std.otel.Types = .{
//!     .context = path.to.context.implementation.TYPES,
//!     .trace = path.to.trace.implementation.TYPES,
//! };
//! pub const otel_functions: std.otel.Functions = .{
//!     .context = path.to.context.implementation.FUNCTIONS,
//!     .trace = path.to.trace.implementation.FUNCTIONS,
//! };
//! ```
//!
//! Implementations will likely require you to call a function at runtime to
//! properly set up it. Something like this:
//!
//! ```zig
//! pub fn main() !void {
//!     try path.to.context.implementation.init(.{});
//!     defer path.to.context.implementation.deinit();
//!     try path.to.trace.implementation.init(.{});
//!     defer path.to.trace.implementation.deinit();
//!
//!     // the application code
//! }
//! ```
//!
//! See <https://opentelemetry.io/> for more information.

pub const Attribute = @import("otel/attribute.zig").Attribute;
pub const Context = @import("otel/Context.zig");

pub const trace = @import("otel/trace.zig");

// application configured options
const root = @import("root");

/// The concrete types that implement the APIs defined here. By default all of the
/// APIs come with a no-op implementation. Library developers can use these APIs to
/// instrument their libraries, and software developers can then choose an
/// implementation of the API that matches the software's telemetry needs, or leave
/// out telemetry all together.
pub const types: Types = if (@hasDecl(root, "otel_types"))
    root.otel_types
else
    .{};

/// The functions that actually implement OpenTelemetry APIs. By default these are
/// set to functions that do nothing.
pub const functions: Functions = if (@hasDecl(root, "otel_functions"))
    root.otel_functions
else
    .{};

pub const Types = struct {
    Context: type = Context.NULL_CONTEXT_TYPE,
    ContextAttachToken: type = Context.NULL_ATTACH_TOKEN_TYPE,
    Span: type = trace.NULL_SPAN_TYPE,
};

pub const Functions = struct {
    context: Context.Functions = Context.NULL_FUNCTIONS,
    trace: trace.Functions = trace.NULL_FUNCTIONS,
};

pub const InstrumentationScope = struct {
    name: []const u8,
    version: ?[]const u8 = null,
    /// since OpenTelemetry API 1.4.0
    schema_url: ?[]const u8 = null,
    /// since OpenTelemetry API 1.13.0
    attributes: ?[]const Attribute = null,
};
