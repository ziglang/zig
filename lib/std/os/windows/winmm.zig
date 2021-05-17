// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub const MMRESULT = UINT;
pub const MMSYSERR_BASE = 0;
pub const TIMERR_BASE = 96;
pub const MMSYSERR_ERROR = MMSYSERR_BASE + 1;
pub const MMSYSERR_BADDEVICEID = MMSYSERR_BASE + 2;
pub const MMSYSERR_NOTENABLED = MMSYSERR_BASE + 3;
pub const MMSYSERR_ALLOCATED = MMSYSERR_BASE + 4;
pub const MMSYSERR_INVALHANDLE = MMSYSERR_BASE + 5;
pub const MMSYSERR_NODRIVER = MMSYSERR_BASE + 6;
pub const MMSYSERR_NOMEM = MMSYSERR_BASE + 7;
pub const MMSYSERR_NOTSUPPORTED = MMSYSERR_BASE + 8;
pub const MMSYSERR_BADERRNUM = MMSYSERR_BASE + 9;
pub const MMSYSERR_INVALFLAG = MMSYSERR_BASE + 10;
pub const MMSYSERR_INVALPARAM = MMSYSERR_BASE + 11;
pub const MMSYSERR_HANDLEBUSY = MMSYSERR_BASE + 12;
pub const MMSYSERR_INVALIDALIAS = MMSYSERR_BASE + 13;
pub const MMSYSERR_BADDB = MMSYSERR_BASE + 14;
pub const MMSYSERR_KEYNOTFOUND = MMSYSERR_BASE + 15;
pub const MMSYSERR_READERROR = MMSYSERR_BASE + 16;
pub const MMSYSERR_WRITEERROR = MMSYSERR_BASE + 17;
pub const MMSYSERR_DELETEERROR = MMSYSERR_BASE + 18;
pub const MMSYSERR_VALNOTFOUND = MMSYSERR_BASE + 19;
pub const MMSYSERR_NODRIVERCB = MMSYSERR_BASE + 20;
pub const MMSYSERR_MOREDATA = MMSYSERR_BASE + 21;
pub const MMSYSERR_LASTERROR = MMSYSERR_BASE + 21;

pub const MMTIME = extern struct {
    wType: UINT,
    u: extern union {
        ms: DWORD,
        sample: DWORD,
        cb: DWORD,
        ticks: DWORD,
        smpte: extern struct {
            hour: BYTE,
            min: BYTE,
            sec: BYTE,
            frame: BYTE,
            fps: BYTE,
            dummy: BYTE,
            pad: [2]BYTE,
        },
        midi: extern struct {
            songptrpos: DWORD,
        },
    },
};
pub const LPMMTIME = *MMTIME;
pub const TIME_MS = 0x0001;
pub const TIME_SAMPLES = 0x0002;
pub const TIME_BYTES = 0x0004;
pub const TIME_SMPTE = 0x0008;
pub const TIME_MIDI = 0x0010;
pub const TIME_TICKS = 0x0020;

// timeapi.h
pub const TIMECAPS = extern struct { wPeriodMin: UINT, wPeriodMax: UINT };
pub const LPTIMECAPS = *TIMECAPS;
pub const TIMERR_NOERROR = 0;
pub const TIMERR_NOCANDO = TIMERR_BASE + 1;
pub const TIMERR_STRUCT = TIMERR_BASE + 33;
pub extern "winmm" fn timeBeginPeriod(uPeriod: UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn timeEndPeriod(uPeriod: UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn timeGetDevCaps(ptc: LPTIMECAPS, cbtc: UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn timeGetSystemTime(pmmt: LPMMTIME, cbmmt: UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn timeGetTime() callconv(WINAPI) DWORD;
