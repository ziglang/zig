// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const testing = std.testing;
const valgrind = std.valgrind;

// https://github.com/tklengyel/valgrind/blob/xen-patches/helgrind/helgrind.h
pub const HellgrindClientRequest = extern enum {
    CleanMemory = valgrind.ToolBase("HG".*),
    SetPosixThread = valgrind.ToolBase("HG".*) + 256,
    PosixThreadApiError,
    PosixThreadJoinPost,
    PosixMutexInitPost,
    PosixMutexDestroyPre,
    PosixMutexUnlockPre,
    PosixMutexUnlockPost,
    PosixMutexAcquirePre,
    PosixMutexAcquirePost,
    PosixCondSignalPre,
    PosixCondBroadcastPre,
    PosixCondWaitPre,
    PosixCondWaitPost,
    PosixCondDestroyPre,
    PosixRwLockInitPost,
    PosixRwLockDestroyPre,
    PosixRwLockLockPre,
    PosixRwLockAcquired,
    PosixRwLockReleased,
    PosixRwLockUnlockPost,
    PosixSemaphoreInitPost,
    PosixSemaphoreDestroyPre,
    PosixSemaphoreReleased,
    PosixSemaphoreAcquired,
    PosixBarrierInitPre,
    PosixBarrierWaitPre,
    PosixBarrierDestroyPre,
    PosixSpinInitOrUnlockPre,
    PosixSpinInitOrUnlockPost,
    PosixSpinLockPre,
    PosixSpinLockPost,
    PosixSpinDestroyPre,
    ClientRequestUnimplemented,
    UserSharedObjectSendPre,
    UserSharedObjectRecvPost,
    UserSharedObjectForgetAll,
    Reserved2,
    Reserved3,
    Reserved4,
    ArrangeMakeUntracked,
    ArrangeMakeTracked,
    PosixBarrierResizePre,
    CleanMemoryHeapBlock,
    PosixCondInitPost,
    GnatMasterHook,
    GnatMasterCompletedHook,
    GetABits,
    PosixThreadCreateBegin,
    PosixThreadCreateEnd,
    PosixMutexLockPre,
    PosixMutexLockPost,
    PosixRwLockLockPost,
    PosixRwLockUnlockPre,
    PosixSemaphorePostPre,
    PosixSemaphorePostPost,
    PosixSemaphoreWaitPre,
    PosixSemaphoreWaitPost,
    PosixCondSignalPost,
    PosixCondBroadcastPost,
    RtldBindGuard,
    RltdBindClear,
    GnatDependentMasterJoin,
};

fn doHellgrindClientRequestExpr(default: usize, request: HellgrindClientRequest, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize) usize {
    return valgrind.doClientRequest(default, @intCast(usize, @enumToInt(request)), a1, a2, a3, a4, a5);
}

fn doHellgrindkClientRequestStmt(request: HellgrindClientRequest, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize) void {
    _ = doHellgrindClientRequestExpr(0, request, a1, a2, a3, a4, a5);
}

pub fn annotateHappensBefore(obj: usize) void {
    doHellgrindkClientRequestStmt(.UserSharedObjectSendPre, obj, 0, 0, 0, 0);
}

pub fn annotateHappensAfter(obj: usize) void {
    doHellgrindkClientRequestStmt(.UserSharedObjectRecvPost, obj, 0, 0, 0, 0);
}

pub fn annotateHappensBeforeForgetAll(obj: usize) void {
    doHellgrindkClientRequestStmt(.UserSharedObjectForgetAll, obj, 0, 0, 0, 0);
}
