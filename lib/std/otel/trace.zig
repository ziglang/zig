//! This file provides an API to trace the path a request took through your code.
//! Start by using the `scoped` function to create a tracer:
//!
//! ```zig
//! const tracer = std.otel.trace.scoped(.{ .name = "com.example.lib" });
//! ```
//!
//! With `tracer`, you can create a `Span` to indicate how long a particular
//! task/function took:
//!
//! ```zig
//! pub fn doAThing() {
//!     const span = tracer.beginSpan("doing a thing", @src(), .{});
//!     defer span.end(null);
//!
//!     // ... code that does the thing
//! }
//! ```
//!
//! Tracing functions will be a no-op by default. The software developer will need
//! to specify an implementation to actually collect the tracing data. See
//! `std.otel` for more information on setting up an implementation.
//!
//! See the [OpenTelemetry tracing API specification](https://opentelemetry.io/docs/specs/otel/trace/api/)
//! for more information.

const trace = @This();

/// Create a type that will pass the given `InstrumentationScope` to each `createSpan` call.
///
/// In OpenTelemetry, this is called a Tracer, and is used to differentiate between
/// e.g. tracing done by the std library and tracing done by your application.
pub fn scoped(comptime scope: std.otel.InstrumentationScope) type {
    return struct {
        const this_scope = scope;

        pub fn createSpan(
            /// Concisely identifies the work done by the Span.
            ///
            /// For example, here are potential span names for an endpoint that gets a
            /// hypothetical account information:
            ///
            /// |        Span Name        | Guidance                                                 |
            /// |-------------------------|----------------------------------------------------------|
            /// | get                     | Too general                                              |
            /// | get_account/42          | Too specific                                             |
            /// | get_account             | Good, and account_id=42 would make a nice Span attribute |
            /// | get_account/{accountId} | Also good (using the “HTTP route”)                       |
            comptime name: [:0]const u8,
            /// The source location, which you can get with `@src()`. It is up to the
            /// implementation how this is used, though an implementation following the
            /// OpenTelemetry specification will attach it to the Span as `code.*` attributes.
            comptime source_location: ?std.builtin.SourceLocation,
            options: CreateSpanOptions,
        ) Span {
            return .{ .impl = std.otel.functions.trace.tracer_create_span(this_scope, name, source_location, options) };
        }

        /// Create a span using only the instrumentation scope and the source location.
        ///
        /// Technically not allowed by the OpenTelemetry spec. But when the use case is
        /// profiling code and not remote requests, the name is redundant information.
        /// Implementations can construct a name from the source location if they need to;
        /// the function name should be a good first approximation. If you think that will
        /// not be the case, consider using `createSpan` instead.
        pub fn createSpanSourceLocation(
            comptime source_location: std.builtin.SourceLocation,
            options: CreateSpanOptions,
        ) Span {
            return .{ .impl = std.otel.functions.trace.tracer_create_span_source_location(this_scope, source_location, options) };
        }

        pub fn enabled() bool {
            return @call(.auto, std.otel.functions.trace.tracer_enabled, .{this_scope});
        }

        /// Helper function that creates a span, puts it into an otel.Context, and sets that
        /// context as the current context. Designed to minimize friction when marking up
        /// source code. More advanced use cases should use `createSpan` directly. It is
        /// implemented in terms of the OpenTelemetry API primitives.
        pub fn beginSpan(
            comptime name: [:0]const u8,
            comptime source_location: ?std.builtin.SourceLocation,
            options: CreateSpanOptions,
        ) BeginSpanResult {
            const new_span = createSpan(name, source_location, options);
            const new_context = contextWithSpan(std.otel.Context.current(), new_span);
            const attach_token = new_context.attach();
            return .{ .span = new_span, .context = new_context, .attach_token = attach_token };
        }

        /// Helper function that creates a span, puts it into an otel.Context, and sets that
        /// context as the current context. Designed to minimize friction when marking up
        /// source code. More advanced use cases should use `createSpanSourceLocation` directly. It is
        /// implemented in terms of the OpenTelemetry API primitives.
        pub fn beginSpanSrc(
            comptime source_location: std.builtin.SourceLocation,
            options: CreateSpanOptions,
        ) BeginSpanResult {
            const new_span = createSpanSourceLocation(source_location, options);
            const new_context = contextWithSpan(std.otel.Context.current(), new_span);
            const attach_token = new_context.attach();
            return .{ .span = new_span, .context = new_context, .attach_token = attach_token };
        }
    };
}

/// Helper type designed to minimize friction when marking up source code. See `scoped().beginSpan()`.
pub const BeginSpanResult = struct {
    span: Span,
    context: std.otel.Context,
    attach_token: std.otel.Context.AttachToken,

    /// Helper function that ends the span and detaches and destroys the context.
    /// Designed to minimize friction when marking up source code. To specify an end
    /// time, use `Span.end`, `Context.detach`, and `Context.destroy` directly.
    pub fn end(this: *const @This()) void {
        this.span.end(null);
        this.attach_token.detach();
        this.context.destroy();
    }
};

/// A Span represents a single operation within a trace. Spans can be nested to form
/// a trace tree. Each trace contains a root span, which typically describes the
/// entire operation and, optionally, one or more sub-spans for its sub-operations.
pub const Span = struct {
    impl: std.otel.types.trace.Span,

    /// Gets the `SpanContext` associated with this span.
    pub fn getContext(this: @This()) SpanContext {
        return std.otel.functions.trace.span_get_context(this.impl);
    }

    /// Gets the `SpanContext` associated with this span.
    pub fn isRecording(this: @This()) bool {
        return std.otel.functions.trace.span_is_recording(this.impl);
    }

    pub fn setAttribute(this: @This(), attribute: std.otel.Attribute) void {
        std.otel.functions.trace.span_set_attribute(this.impl, attribute);
    }

    pub fn addEvent(this: @This(), options: AddEventOptions) void {
        std.otel.functions.trace.trace.span_add_event(this.impl, options);
    }

    pub fn setStatus(this: @This(), status: Status) void {
        std.otel.functions.trace.span_set_status(this.impl, status);
    }

    pub fn updateName(this: @This(), new_name: []const u8) void {
        std.otel.functions.trace.span_update_name(this.impl, new_name);
    }

    pub fn end(this: @This(), end_timestamp: ?i128) void {
        std.otel.functions.trace.span_end(this.impl, end_timestamp);
    }

    pub fn recordException(this: @This(), err: anyerror, stack_trace: ?std.builtin.StackTrace) void {
        std.otel.functions.trace.span_record_exception(this.impl, err, stack_trace);
    }
};

pub fn contextWithSpan(context: std.otel.Context, span: Span) std.otel.Context {
    return std.otel.functions.trace.context_with_span(context, span.impl);
}

pub fn contextExtractSpan(context: std.otel.Context) Span {
    return .{ .impl = std.otel.functions.trace.context_extract_span(context) };
}

pub const CreateSpanOptions = struct {
    parent_context: ParentContextOption = .implicit,
    kind: SpanKind = .internal,
    /// A list of attributes to associate with the Span. May be used to sampling decision.
    ///
    /// Adding attributes at creation time is preferred, as attributes added later are
    /// not used when making sampling decisions.
    attributes: []const std.otel.Attribute = &.{},
    /// Linked Spans can be from the same or a different trace. Links added at Span
    /// creation may be considered by Samplers to make a sampling decision.
    links: []const Link = &.{},
    /// Time when the span started in nanoseconds. This argument SHOULD only be set when
    /// span creation time has already passed. If API is called at a moment of a Span
    /// logical start, API user MUST NOT explicitly set this argument.
    start_timestamp: ?i128 = null,
};

pub const ParentContextOption = union(enum) {
    /// The Span is a root span
    none,
    /// Look in `otel.Context.current` for a parent span.
    implicit,
    /// Use the given `otel.Context` as the parent span.
    explicit: std.otel.Context,
};

pub const SpanKind = enum(u32) {
    unspecified = 0,
    /// Default value. Indicates that the Span represents an internal operation within
    /// an application, as opposed to operations with remote parents or children.
    internal = 1,
    /// Indicates that the Span covers server side handling of a remote request while the
    /// client awaits a response.
    server = 2,
    /// Indicates that the Span describes a request to a remote service.
    client = 3,
    /// Indicates that the Span describes the initiation or scheduling of a local or
    /// remote operation. This initiating Span often ends before the correlated
    /// `consumer` Span, possibly even before the `consumer` span begins.
    producer = 4,
    /// Indicates that the Span represents the processing of an operation initiated by a
    /// `producer`, where the `producer` does not wait for the outcome.
    consumer = 5,
};

pub const AddEventOptions = struct {
    name: []const u8,
    timestamp: ?u64 = null,
    attrs: []const std.otel.Attribute = &.{},
};

pub const Status = union(Code) {
    unset,
    ok,
    @"error": []const u8,

    pub const Code = enum(u2) {
        unset = 0,
        ok = 1,
        @"error" = 2,
    };

    pub fn jsonStringify(this: @This(), jw: anytype) !void {
        switch (this) {
            .unset,
            .ok,
            => {
                try jw.beginObject();
                try jw.objectField("code");
                try jw.write(@intFromEnum(@as(Code, this)));
                try jw.endObject();
            },
            .@"error" => |msg| {
                try jw.beginObject();
                try jw.objectField("message");
                try jw.write(msg);
                try jw.objectField("code");
                try jw.write(@intFromEnum(@as(Code, this)));
                try jw.endObject();
            },
        }
    }

    pub fn format(this: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(@tagName(this));
        switch (this) {
            .unset,
            .ok,
            => {},
            .@"error" => |msg| try writer.print("\"{}\"", .{std.zig.fmtEscapes(msg)}),
        }
    }
};

/// Used to link traces that go from client to server and then from server to other
/// servers.
///
/// See W3C's Trace Context: https://www.w3.org/TR/trace-context/
pub const SpanContext = struct {
    trace_id: TraceId,
    span_id: SpanId,
    flags: trace.Flags,
    state: trace.State,
    is_remote: bool,

    pub const INVALID = SpanContext{
        .trace_id = TraceId.INVALID,
        .span_id = SpanId.INVALID,
        .flags = Flags.NONE,
        .state = .{ .values = &.{} },
        .is_remote = false,
    };

    pub fn isValid(this: @This()) bool {
        return this.trace_id.isValid() and this.span_id.isValid();
    }
};

/// See W3C's Trace Context: https://www.w3.org/TR/trace-context/
pub const TraceId = struct {
    bytes: [16]u8,

    pub const INVALID = @This(){ .bytes = [_]u8{0} ** 16 };

    pub fn hex(hex_string: *const [32]u8) @This() {
        var trace_id: @This() = undefined;
        const decoded = std.fmt.hexToBytes(&trace_id.bytes, hex_string) catch @panic("we specified the size of the string, and it should match exactly");
        std.debug.assert(decoded.len == trace_id.bytes.len);
        return trace_id;
    }

    pub fn isValid(this: @This()) bool {
        return !std.mem.allEqual(u8, &this.bytes, 0);
    }

    pub fn jsonStringify(this: *const @This(), jw: anytype) !void {
        try jw.print("\"{}\"", .{std.fmt.fmtSliceHexLower(&this.bytes)});
    }
};

/// A unique id for each span.
///
/// See W3C's Trace Context: https://www.w3.org/TR/trace-context/
pub const SpanId = struct {
    bytes: [8]u8,

    pub const INVALID = SpanId{ .bytes = [_]u8{0} ** 8 };

    pub fn hex(hex_string: *const [16]u8) SpanId {
        var trace_id: SpanId = undefined;
        const decoded = std.fmt.hexToBytes(&trace_id.bytes, hex_string) catch @panic("we specified the size of the string, and it should match exactly");
        std.debug.assert(decoded.len == trace_id.bytes.len);
        return trace_id;
    }

    pub fn isValid(this: @This()) bool {
        return !std.mem.allEqual(u8, &this.bytes, 0);
    }

    pub fn jsonStringify(this: *const @This(), jw: anytype) !void {
        try jw.print("\"{}\"", .{std.fmt.fmtSliceHexLower(&this.bytes)});
    }
};

/// See W3C's Trace Context: https://www.w3.org/TR/trace-context/
pub const Flags = packed struct(u8) {
    sampled: bool,
    _reserved: u7 = 0,

    pub const NONE = .{ .sampled = false };
    pub const SAMPLED = .{ .sampled = true };
};

pub const State = struct {
    values: []const std.meta.Tuple(&.{ []const u8, []const u8 }),
};

pub const Link = struct {
    span_context: SpanContext,
    attrs: []const std.otel.Attribute,
};

pub const Types = struct {
    Span: type,
};

pub const Functions = struct {
    tracer_enabled: fn (comptime std.otel.InstrumentationScope) bool,

    tracer_create_span: fn (
        comptime std.otel.InstrumentationScope,
        comptime name: [:0]const u8,
        comptime ?std.builtin.SourceLocation,
        options: CreateSpanOptions,
    ) impl_types.Span,

    /// Create a span using only the source location.
    ///
    /// Technically not allowed by the OpenTelemetry spec. But when the use case is
    /// profiling code and not remote requests, the name is redundant information.
    /// Implementations can construct a name from the source location if they need to;
    /// the function name should be a good first approximation. If you think that will
    /// not be the case, consider using `tracer_create_span` instead.
    tracer_create_span_source_location: fn (
        comptime std.otel.InstrumentationScope,
        comptime std.builtin.SourceLocation,
        options: CreateSpanOptions,
    ) impl_types.Span,

    context_extract_span: fn (std.otel.Context) impl_types.Span,
    context_with_span: fn (std.otel.Context, impl_types.Span) std.otel.Context,

    span_get_context: fn (impl_types.Span) SpanContext,
    span_is_recording: fn (impl_types.Span) bool,
    span_set_attribute: fn (impl_types.Span, std.otel.Attribute) void,
    span_add_event: fn (impl_types.Span, AddEventOptions) void,
    span_add_link: fn (impl_types.Span, Link) void,
    span_set_status: fn (impl_types.Span, Status) void,
    span_update_name: fn (impl_types.Span, [:0]const u8) void,
    span_end: fn (impl_types.Span, end_timestamp: ?i128) void,
    span_record_exception: fn (impl_types.Span, anyerror, ?std.builtin.StackTrace) void,

    const impl_types = std.otel.types.trace;
};

/// Types used by the default implementation of the otel.trace API, which does nothing.
pub const NULL_TYPES: Types = .{
    .Span = struct {
        pub const NULL = @This(){};
    },
};

/// Functions used by the default implementation of the otel.trace API, which do nothing.
pub const NULL_FUNCTIONS: Functions = .{
    .tracer_enabled = nullTracerEnabled,
    .tracer_create_span = nullTracerCreateSpan,
    .tracer_create_span_source_location = nullTracerCreateSpanSourceLocation,

    .context_extract_span = nullContextExtractSpan,
    .context_with_span = nullContextWithSpan,

    .span_get_context = nullSpanGetContext,
    .span_is_recording = nullSpanIsRecording,
    .span_set_attribute = nullSpanSetAttribute,
    .span_add_event = nullSpanAddEvent,
    .span_add_link = nullSpanAddLink,
    .span_set_status = nullSpanSetStatus,
    .span_update_name = nullSpanUpdateName,
    .span_end = nullSpanEnd,
    .span_record_exception = nullSpanRecordException,
};

fn nullTracerEnabled(comptime scope: std.otel.InstrumentationScope) bool {
    _ = scope;
    return false;
}

fn nullTracerCreateSpan(
    comptime tracer_scope: std.otel.InstrumentationScope,
    comptime name: []const u8,
    comptime source_location: ?std.builtin.SourceLocation,
    options: CreateSpanOptions,
) std.otel.types.trace.Span {
    _ = tracer_scope;
    _ = name;
    _ = source_location;
    _ = options;
    // TODO: "The API MUST return a non-recording Span with the SpanContext in the parent Context (whether explicitly given or implicit current)."
    // Not sure if we will implement this part of the spec, as it would return at least a SpanContext, which would probably affect performance.
    return std.otel.types.trace.Span.NULL;
}

fn nullTracerCreateSpanSourceLocation(
    comptime tracer_scope: std.otel.InstrumentationScope,
    comptime source_location: std.builtin.SourceLocation,
    options: CreateSpanOptions,
) std.otel.types.trace.Span {
    _ = tracer_scope;
    _ = source_location;
    _ = options;
    // TODO: "The API MUST return a non-recording Span with the SpanContext in the parent Context (whether explicitly given or implicit current)."
    // Not sure if we will implement this part of the spec, as it would return at least a SpanContext, which would probably affect performance.
    return std.otel.types.trace.Span.NULL;
}

fn nullContextExtractSpan(context: std.otel.Context) std.otel.types.trace.Span {
    _ = context;
    return .NULL;
}

fn nullContextWithSpan(context: std.otel.Context, span: std.otel.types.trace.Span) std.otel.Context {
    _ = span;
    return context;
}

fn nullSpanGetContext(span: std.otel.types.trace.Span) SpanContext {
    _ = span;
    return SpanContext.INVALID;
}

fn nullSpanIsRecording(span: std.otel.types.trace.Span) bool {
    _ = span;
    return false;
}

fn nullSpanSetAttribute(span: std.otel.types.trace.Span, attribute: std.otel.Attribute) void {
    _ = span;
    _ = attribute;
}

fn nullSpanAddEvent(span: std.otel.types.trace.Span, options: AddEventOptions) void {
    _ = span;
    _ = options;
}

fn nullSpanAddLink(span: std.otel.types.trace.Span, link: Link) void {
    _ = span;
    _ = link;
}

fn nullSpanSetStatus(span: std.otel.types.trace.Span, status: Status) void {
    _ = span;
    _ = status;
}

fn nullSpanUpdateName(span: std.otel.types.trace.Span, new_name: []const u8) void {
    _ = span;
    _ = new_name;
}

fn nullSpanEnd(span: std.otel.types.trace.Span, end_timestamp: ?i128) void {
    _ = span;
    _ = end_timestamp;
}

fn nullSpanRecordException(span: std.otel.types.trace.Span, err: anyerror, stack_trace: ?std.builtin.StackTrace) void {
    _ = span;
    err catch {};
    _ = stack_trace;
}

const std = @import("../std.zig");
