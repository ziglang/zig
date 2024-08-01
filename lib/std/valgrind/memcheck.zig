const std = @import("../std.zig");
const testing = std.testing;
const valgrind = std.valgrind;

pub const ClientRequest = enum(usize) {
    MakeMemNoAccess = valgrind.ToolBase("MC".*),
    MakeMemUndefined,
    MakeMemDefined,
    Discard,
    CheckMemIsAddressable,
    CheckMemIsDefined,
    DoLeakCheck,
    CountLeaks,
    GetVbits,
    SetVbits,
    CreateBlock,
    MakeMemDefinedIfAddressable,
    CountLeakBlocks,
    EnableAddrErrorReportingInRange,
    DisableAddrErrorReportingInRange,
};

pub const MemCheckClientRequest = @compileError("std.valgrind.memcheck.MemCheckClientRequest renamed to std.valgrind.memcheck.ClientRequest");

fn doClientRequestExpr(default: usize, request: ClientRequest, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize) usize {
    return valgrind.doClientRequest(default, @as(usize, @intCast(@intFromEnum(request))), a1, a2, a3, a4, a5);
}

fn doClientRequestStmt(request: ClientRequest, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize) void {
    _ = doClientRequestExpr(0, request, a1, a2, a3, a4, a5);
}

/// Mark memory at qzz.ptr as unaddressable for qzz.len bytes.
pub fn makeMemNoAccess(qzz: []const u8) void {
    _ = doClientRequestExpr(0, // default return
        .MakeMemNoAccess, @intFromPtr(qzz.ptr), qzz.len, 0, 0, 0);
}

/// Mark memory at qzz.ptr as addressable but undefined for qzz.len bytes.
pub fn makeMemUndefined(qzz: []const u8) void {
    _ = doClientRequestExpr(0, // default return
        .MakeMemUndefined, @intFromPtr(qzz.ptr), qzz.len, 0, 0, 0);
}

/// Mark memory at qzz.ptr as addressable and defined or qzz.len bytes.
pub fn makeMemDefined(qzz: []const u8) void {
    _ = doClientRequestExpr(0, // default return
        .MakeMemDefined, @intFromPtr(qzz.ptr), qzz.len, 0, 0, 0);
}

/// Similar to makeMemDefined except that addressability is
/// not altered: bytes which are addressable are marked as defined,
/// but those which are not addressable are left unchanged.
pub fn makeMemDefinedIfAddressable(qzz: []const u8) void {
    _ = doClientRequestExpr(0, // default return
        .MakeMemDefinedIfAddressable, @intFromPtr(qzz.ptr), qzz.len, 0, 0, 0);
}

/// Create a block-description handle.  The description is an ascii
/// string which is included in any messages pertaining to addresses
/// within the specified memory range.  Has no other effect on the
/// properties of the memory range.
pub fn createBlock(qzz: []const u8, desc: [*:0]const u8) usize {
    return doClientRequestExpr(0, // default return
        .CreateBlock, @intFromPtr(qzz.ptr), qzz.len, @intFromPtr(desc), 0, 0);
}

/// Discard a block-description-handle. Returns 1 for an
/// invalid handle, 0 for a valid handle.
pub fn discard(blkindex: usize) bool {
    return doClientRequestExpr(0, // default return
        .Discard, 0, blkindex, 0, 0, 0) != 0;
}

/// Check that memory at qzz.ptr is addressable for qzz.len bytes.
/// If suitable addressability is not established, Valgrind prints an
/// error message and returns the address of the first offending byte.
/// Otherwise it returns zero.
pub fn checkMemIsAddressable(qzz: []const u8) usize {
    return doClientRequestExpr(0, .CheckMemIsAddressable, @intFromPtr(qzz.ptr), qzz.len, 0, 0, 0);
}

/// Check that memory at qzz.ptr is addressable and defined for
/// qzz.len bytes.  If suitable addressability and definedness are not
/// established, Valgrind prints an error message and returns the
/// address of the first offending byte.  Otherwise it returns zero.
pub fn checkMemIsDefined(qzz: []const u8) usize {
    return doClientRequestExpr(0, .CheckMemIsDefined, @intFromPtr(qzz.ptr), qzz.len, 0, 0, 0);
}

/// Do a full memory leak check (like --leak-check=full) mid-execution.
pub fn doLeakCheck() void {
    doClientRequestStmt(.DO_LEAK_CHECK, 0, 0, 0, 0, 0);
}

/// Same as doLeakCheck() but only showing the entries for
/// which there was an increase in leaked bytes or leaked nr of blocks
/// since the previous leak search.
pub fn doAddedLeakCheck() void {
    doClientRequestStmt(.DO_LEAK_CHECK, 0, 1, 0, 0, 0);
}

/// Same as doAddedLeakCheck() but showing entries with
/// increased or decreased leaked bytes/blocks since previous leak
/// search.
pub fn doChangedLeakCheck() void {
    doClientRequestStmt(.DO_LEAK_CHECK, 0, 2, 0, 0, 0);
}

/// Do a summary memory leak check (like --leak-check=summary) mid-execution.
pub fn doQuickLeakCheck() void {
    doClientRequestStmt(.DO_LEAK_CHECK, 1, 0, 0, 0, 0);
}

/// Return number of leaked, dubious, reachable and suppressed bytes found by
/// all previous leak checks.
const CountResult = struct {
    leaked: usize,
    dubious: usize,
    reachable: usize,
    suppressed: usize,
};

pub fn countLeaks() CountResult {
    var res: CountResult = .{
        .leaked = 0,
        .dubious = 0,
        .reachable = 0,
        .suppressed = 0,
    };
    doClientRequestStmt(
        .CountLeaks,
        @intFromPtr(&res.leaked),
        @intFromPtr(&res.dubious),
        @intFromPtr(&res.reachable),
        @intFromPtr(&res.suppressed),
        0,
    );
    return res;
}

test countLeaks {
    try testing.expectEqual(
        @as(CountResult, .{
            .leaked = 0,
            .dubious = 0,
            .reachable = 0,
            .suppressed = 0,
        }),
        countLeaks(),
    );
}

pub fn countLeakBlocks() CountResult {
    var res: CountResult = .{
        .leaked = 0,
        .dubious = 0,
        .reachable = 0,
        .suppressed = 0,
    };
    doClientRequestStmt(
        .CountLeakBlocks,
        @intFromPtr(&res.leaked),
        @intFromPtr(&res.dubious),
        @intFromPtr(&res.reachable),
        @intFromPtr(&res.suppressed),
        0,
    );
    return res;
}

test countLeakBlocks {
    try testing.expectEqual(
        @as(CountResult, .{
            .leaked = 0,
            .dubious = 0,
            .reachable = 0,
            .suppressed = 0,
        }),
        countLeakBlocks(),
    );
}

/// Get the validity data for addresses zza and copy it
/// into the provided zzvbits array.  Return values:
///    0   if not running on valgrind
///    1   success
///    2   [previously indicated unaligned arrays;  these are now allowed]
///    3   if any parts of zzsrc/zzvbits are not addressable.
/// The metadata is not copied in cases 0, 2 or 3 so it should be
/// impossible to segfault your system by using this call.
pub fn getVbits(zza: []u8, zzvbits: []u8) u2 {
    std.debug.assert(zzvbits.len >= zza.len / 8);
    return @as(u2, @intCast(doClientRequestExpr(0, .GetVbits, @intFromPtr(zza.ptr), @intFromPtr(zzvbits), zza.len, 0, 0)));
}

/// Set the validity data for addresses zza, copying it
/// from the provided zzvbits array.  Return values:
///    0   if not running on valgrind
///    1   success
///    2   [previously indicated unaligned arrays;  these are now allowed]
///    3   if any parts of zza/zzvbits are not addressable.
/// The metadata is not copied in cases 0, 2 or 3 so it should be
/// impossible to segfault your system by using this call.
pub fn setVbits(zzvbits: []u8, zza: []u8) u2 {
    std.debug.assert(zzvbits.len >= zza.len / 8);
    return @as(u2, @intCast(doClientRequestExpr(0, .SetVbits, @intFromPtr(zza.ptr), @intFromPtr(zzvbits), zza.len, 0, 0)));
}

/// Disable and re-enable reporting of addressing errors in the
/// specified address range.
pub fn disableAddrErrorReportingInRange(qzz: []u8) usize {
    return doClientRequestExpr(0, // default return
        .DisableAddrErrorReportingInRange, @intFromPtr(qzz.ptr), qzz.len, 0, 0, 0);
}

pub fn enableAddrErrorReportingInRange(qzz: []u8) usize {
    return doClientRequestExpr(0, // default return
        .EnableAddrErrorReportingInRange, @intFromPtr(qzz.ptr), qzz.len, 0, 0, 0);
}
