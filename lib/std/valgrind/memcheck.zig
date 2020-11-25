// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const testing = std.testing;
const valgrind = std.valgrind;

pub const MemCheckClientRequest = extern enum {
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

fn doMemCheckClientRequestExpr(default: usize, request: MemCheckClientRequest, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize) usize {
    return valgrind.doClientRequest(default, @intCast(usize, @enumToInt(request)), a1, a2, a3, a4, a5);
}

fn doMemCheckClientRequestStmt(request: MemCheckClientRequest, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize) void {
    _ = doMemCheckClientRequestExpr(0, request, a1, a2, a3, a4, a5);
}

/// Mark memory at qzz.ptr as unaddressable for qzz.len bytes.
/// This returns -1 when run on Valgrind and 0 otherwise.
pub fn makeMemNoAccess(qzz: []u8) i1 {
    return @intCast(i1, doMemCheckClientRequestExpr(0, // default return
        .MakeMemNoAccess, @ptrToInt(qzz.ptr), qzz.len, 0, 0, 0));
}

/// Similarly, mark memory at qzz.ptr as addressable but undefined
/// for qzz.len bytes.
/// This returns -1 when run on Valgrind and 0 otherwise.
pub fn makeMemUndefined(qzz: []u8) i1 {
    return @intCast(i1, doMemCheckClientRequestExpr(0, // default return
        .MakeMemUndefined, @ptrToInt(qzz.ptr), qzz.len, 0, 0, 0));
}

/// Similarly, mark memory at qzz.ptr as addressable and defined
/// for qzz.len bytes.
pub fn makeMemDefined(qzz: []u8) i1 {
    // This returns -1 when run on Valgrind and 0 otherwise.
    return @intCast(i1, doMemCheckClientRequestExpr(0, // default return
        .MakeMemDefined, @ptrToInt(qzz.ptr), qzz.len, 0, 0, 0));
}

/// Similar to makeMemDefined except that addressability is
/// not altered: bytes which are addressable are marked as defined,
/// but those which are not addressable are left unchanged.
/// This returns -1 when run on Valgrind and 0 otherwise.
pub fn makeMemDefinedIfAddressable(qzz: []u8) i1 {
    return @intCast(i1, doMemCheckClientRequestExpr(0, // default return
        .MakeMemDefinedIfAddressable, @ptrToInt(qzz.ptr), qzz.len, 0, 0, 0));
}

/// Create a block-description handle.  The description is an ascii
/// string which is included in any messages pertaining to addresses
/// within the specified memory range.  Has no other effect on the
/// properties of the memory range.
pub fn createBlock(qzz: []u8, desc: [*]u8) usize {
    return doMemCheckClientRequestExpr(0, // default return
        .CreateBlock, @ptrToInt(qzz.ptr), qzz.len, @ptrToInt(desc), 0, 0);
}

/// Discard a block-description-handle. Returns 1 for an
/// invalid handle, 0 for a valid handle.
pub fn discard(blkindex) bool {
    return doMemCheckClientRequestExpr(0, // default return
        .Discard, 0, blkindex, 0, 0, 0) != 0;
}

/// Check that memory at qzz.ptr is addressable for qzz.len bytes.
/// If suitable addressibility is not established, Valgrind prints an
/// error message and returns the address of the first offending byte.
/// Otherwise it returns zero.
pub fn checkMemIsAddressable(qzz: []u8) usize {
    return doMemCheckClientRequestExpr(0, .CheckMemIsAddressable, @ptrToInt(qzz.ptr), qzz.len, 0, 0, 0);
}

/// Check that memory at qzz.ptr is addressable and defined for
/// qzz.len bytes.  If suitable addressibility and definedness are not
/// established, Valgrind prints an error message and returns the
/// address of the first offending byte.  Otherwise it returns zero.
pub fn checkMemIsDefined(qzz: []u8) usize {
    return doMemCheckClientRequestExpr(0, .CheckMemIsDefined, @ptrToInt(qzz.ptr), qzz.len, 0, 0, 0);
}

/// Do a full memory leak check (like --leak-check=full) mid-execution.
pub fn doLeakCheck() void {
    doMemCheckClientRequestStmt(.DO_LEAK_CHECK, 0, 0, 0, 0, 0);
}

/// Same as doLeakCheck() but only showing the entries for
/// which there was an increase in leaked bytes or leaked nr of blocks
/// since the previous leak search.
pub fn doAddedLeakCheck() void {
    doMemCheckClientRequestStmt(.DO_LEAK_CHECK, 0, 1, 0, 0, 0);
}

/// Same as doAddedLeakCheck() but showing entries with
/// increased or decreased leaked bytes/blocks since previous leak
/// search.
pub fn doChangedLeakCheck() void {
    doMemCheckClientRequestStmt(.DO_LEAK_CHECK, 0, 2, 0, 0, 0);
}

/// Do a summary memory leak check (like --leak-check=summary) mid-execution.
pub fn doQuickLeakCheck() void {
    doMemCheckClientRequestStmt(.DO_LEAK_CHECK, 1, 0, 0, 0, 0);
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
    doMemCheckClientRequestStmt(
        .CountLeaks,
        @ptrToInt(&res.leaked),
        @ptrToInt(&res.dubious),
        @ptrToInt(&res.reachable),
        @ptrToInt(&res.suppressed),
        0,
    );
    return res;
}

test "countLeaks" {
    testing.expectEqual(
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
    doMemCheckClientRequestStmt(
        .CountLeakBlocks,
        @ptrToInt(&res.leaked),
        @ptrToInt(&res.dubious),
        @ptrToInt(&res.reachable),
        @ptrToInt(&res.suppressed),
        0,
    );
    return res;
}

test "countLeakBlocks" {
    testing.expectEqual(
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
    return @intCast(u2, doMemCheckClientRequestExpr(0, .GetVbits, @ptrToInt(zza.ptr), @ptrToInt(zzvbits), zza.len, 0, 0));
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
    return @intCast(u2, doMemCheckClientRequestExpr(0, .SetVbits, @ptrToInt(zza.ptr), @ptrToInt(zzvbits), zza.len, 0, 0));
}

/// Disable and re-enable reporting of addressing errors in the
/// specified address range.
pub fn disableAddrErrorReportingInRange(qzz: []u8) usize {
    return doMemCheckClientRequestExpr(0, // default return
        .DisableAddrErrorReportingInRange, @ptrToInt(qzz.ptr), qzz.len, 0, 0, 0);
}

pub fn enableAddrErrorReportingInRange(qzz: []u8) usize {
    return doMemCheckClientRequestExpr(0, // default return
        .EnableAddrErrorReportingInRange, @ptrToInt(qzz.ptr), qzz.len, 0, 0, 0);
}
