//! std.log is a standardized interface for logging which allows for the logging
//! of programs and libraries using this interface to be formatted and filtered
//! by the implementer of the root.log function.
//!
//! Each log message has an associated scope enum, which can be used to give
//! context to the logging. The logging functions in std.log implicitly use a
//! scope of .default.
//!
//! A logging namespace using a custom scope can be created using the
//! std.log.scoped function, passing the scope as an argument; the logging
//! functions in the resulting struct use the provided scope parameter.
//! For example, a library called 'libfoo' might use
//! `const log = std.log.scoped(.libfoo);` to use .libfoo as the scope of its
//! log messages.
//!
//! An example root.log might look something like this:
//!
//! ```
//! const std = @import("std");
//!
//! // Set the log level to info
//! pub const log_level: std.log.Level = .info;
//!
//! // Define root.log to override the std implementation
//! pub fn log(
//!     comptime level: std.log.Level,
//!     comptime scope: @TypeOf(.EnumLiteral),
//!     comptime format: []const u8,
//!     args: anytype,
//! ) void {
//!     // Ignore all non-error logging from sources other than
//!     // .my_project, .nice_library and .default
//!     const scope_prefix = "(" ++ switch (scope) {
//!         .my_project, .nice_library, .default => @tagName(scope),
//!         else => if (@enumToInt(level) <= @enumToInt(std.log.Level.err))
//!             @tagName(scope)
//!         else
//!             return,
//!     } ++ "): ";
//!
//!     const prefix = "[" ++ level.asText() ++ "] " ++ scope_prefix;
//!
//!     // Print the message to stderr, silently ignoring any errors
//!     std.debug.getStderrMutex().lock();
//!     defer std.debug.getStderrMutex().unlock();
//!     const stderr = std.io.getStdErr().writer();
//!     nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
//! }
//!
//! pub fn main() void {
//!     // Using the default scope:
//!     std.log.debug("A borderline useless debug log message", .{}); // Won't be printed as log_level is .info
//!     std.log.info("Flux capacitor is starting to overheat", .{});
//!
//!     // Using scoped logging:
//!     const my_project_log = std.log.scoped(.my_project);
//!     const nice_library_log = std.log.scoped(.nice_library);
//!     const verbose_lib_log = std.log.scoped(.verbose_lib);
//!
//!     my_project_log.debug("Starting up", .{}); // Won't be printed as log_level is .info
//!     nice_library_log.warn("Something went very wrong, sorry", .{});
//!     verbose_lib_log.warn("Added 1 + 1: {}", .{1 + 1}); // Won't be printed as it gets filtered out by our log function
//! }
//! ```
//! Which produces the following output:
//! ```
//! [info] (default): Flux capacitor is starting to overheat
//! [warning] (nice_library): Something went very wrong, sorry
//! ```

const std = @import("std.zig");
const builtin = @import("builtin");
const root = @import("root");

pub const Level = enum {
    /// Error: something has gone wrong. This might be recoverable or might
    /// be followed by the program exiting.
    err,
    /// Warning: it is uncertain if something has gone wrong or not, but the
    /// circumstances would be worth investigating.
    warn,
    /// Info: general messages about the state of the program.
    info,
    /// Debug: messages only useful for debugging.
    debug,

    /// Returns a string literal of the given level in full text form.
    pub fn asText(comptime self: Level) switch (self) {
        .err => @TypeOf("error"),
        .warn => @TypeOf("warning"),
        .info => @TypeOf("info"),
        .debug => @TypeOf("debug"),
    } {
        return switch (self) {
            .err => "error",
            .warn => "warning",
            .info => "info",
            .debug => "debug",
        };
    }
};

/// The default log level is based on build mode.
pub const default_level: Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe => .info,
    .ReleaseFast, .ReleaseSmall => .err,
};

/// The current log level. This is set to root.log_level if present, otherwise
/// log.default_level.
pub const level: Level = if (@hasDecl(root, "log_level"))
    root.log_level
else
    default_level;

pub const ScopeLevel = struct {
    scope: @Type(.EnumLiteral),
    level: Level,
};

const scope_levels = if (@hasDecl(root, "scope_levels"))
    root.scope_levels
else
    [0]ScopeLevel{};

fn log(
    comptime message_level: Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const effective_log_level = blk: {
        inline for (scope_levels) |scope_level| {
            if (scope_level.scope == scope) break :blk scope_level.level;
        }
        break :blk level;
    };

    if (@enumToInt(message_level) <= @enumToInt(effective_log_level)) {
        if (@hasDecl(root, "log")) {
            if (@typeInfo(@TypeOf(root.log)) != .Fn)
                @compileError("Expected root.log to be a function");
            root.log(message_level, scope, format, args);
        } else {
            defaultLog(message_level, scope, format, args);
        }
    }
}

/// The default implementation for root.log.  root.log may forward log messages
/// to this function.
pub fn defaultLog(
    comptime message_level: Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (builtin.os.tag == .freestanding) {
        // On freestanding one must provide a log function; we do not have
        // any I/O configured.
        return;
    }

    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr().writer();
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    nosuspend stderr.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
}

/// Returns a scoped logging namespace that logs all messages using the scope
/// provided here.
pub fn scoped(comptime scope: @Type(.EnumLiteral)) type {
    return struct {
        pub const emerg = @compileError("deprecated; use err instead of emerg");
        pub const alert = @compileError("deprecated; use err instead of alert");
        pub const crit = @compileError("deprecated; use err instead of crit");

        /// Log an error message. This log level is intended to be used
        /// when something has gone wrong. This might be recoverable or might
        /// be followed by the program exiting.
        pub fn err(
            comptime format: []const u8,
            args: anytype,
        ) void {
            @setCold(true);
            log(.err, scope, format, args);
        }

        /// Log a warning message. This log level is intended to be used if
        /// it is uncertain whether something has gone wrong or not, but the
        /// circumstances would be worth investigating.
        pub fn warn(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.warn, scope, format, args);
        }

        pub const notice = @compileError("deprecated; use info instead of notice");

        /// Log an info message. This log level is intended to be used for
        /// general messages about the state of the program.
        pub fn info(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.info, scope, format, args);
        }

        /// Log a debug message. This log level is intended to be used for
        /// messages which are only useful for debugging.
        pub fn debug(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.debug, scope, format, args);
        }
    };
}

/// The default scoped logging namespace.
pub const default = scoped(.default);

pub const emerg = @compileError("deprecated; use err instead of emerg");
pub const alert = @compileError("deprecated; use err instead of alert");
pub const crit = @compileError("deprecated; use err instead of crit");

/// Log an error message using the default scope. This log level is intended to
/// be used when something has gone wrong. This might be recoverable or might
/// be followed by the program exiting.
pub const err = default.err;

/// Log a warning message using the default scope. This log level is intended
/// to be used if it is uncertain whether something has gone wrong or not, but
/// the circumstances would be worth investigating.
pub const warn = default.warn;

pub const notice = @compileError("deprecated; use info instead of notice");

/// Log an info message using the default scope. This log level is intended to
/// be used for general messages about the state of the program.
pub const info = default.info;

/// Log a debug message using the default scope. This log level is intended to
/// be used for messages which are only useful for debugging.
pub const debug = default.debug;
