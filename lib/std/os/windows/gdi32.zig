// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: WORD = @sizeOf(PIXELFORMATDESCRIPTOR),
    nVersion: WORD,
    dwFlags: DWORD,
    iPixelType: BYTE,
    cColorBits: BYTE,
    cRedBits: BYTE,
    cRedShift: BYTE,
    cGreenBits: BYTE,
    cGreenShift: BYTE,
    cBlueBits: BYTE,
    cBlueShift: BYTE,
    cAlphaBits: BYTE,
    cAlphaShift: BYTE,
    cAccumBits: BYTE,
    cAccumRedBits: BYTE,
    cAccumGreenBits: BYTE,
    cAccumBlueBits: BYTE,
    cAccumAlphaBits: BYTE,
    cDepthBits: BYTE,
    cStencilBits: BYTE,
    cAuxBuffers: BYTE,
    iLayerType: BYTE,
    bReserved: BYTE,
    dwLayerMask: DWORD,
    dwVisibleMask: DWORD,
    dwDamageMask: DWORD,
};

pub extern "gdi32" fn SetPixelFormat(
    hdc: ?HDC,
    format: i32,
    ppfd: ?*const PIXELFORMATDESCRIPTOR,
) callconv(WINAPI) bool;

pub extern "gdi32" fn ChoosePixelFormat(
    hdc: ?HDC,
    ppfd: ?*const PIXELFORMATDESCRIPTOR,
) callconv(WINAPI) i32;

pub extern "gdi32" fn SwapBuffers(hdc: ?HDC) callconv(WINAPI) bool;
pub extern "gdi32" fn wglCreateContext(hdc: ?HDC) callconv(WINAPI) ?HGLRC;
pub extern "gdi32" fn wglMakeCurrent(hdc: ?HDC, hglrc: ?HGLRC) callconv(WINAPI) bool;
