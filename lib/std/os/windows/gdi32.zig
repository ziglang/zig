usingnamespace @import("bits.zig");

pub const PFD_TYPE_RGBA = 0;
pub const PFD_TYPE_COLORINDEX = 1;

pub const PFD_UNDERLAY_PLANE = -1;
pub const PFD_MAIN_PLANE = 0;
pub const PFD_OVERLAY_PLANE = 1;

pub const PFD_DOUBLEBUFFER = 0x00000001;
pub const PFD_STEREO = 0x00000002;
pub const PFD_DRAW_TO_WINDOW = 0x00000004;
pub const PFD_DRAW_TO_BITMAP = 0x00000008;
pub const PFD_SUPPORT_GDI = 0x00000010;
pub const PFD_SUPPORT_OPENGL = 0x00000020;
pub const PFD_GENERIC_FORMAT = 0x00000040;
pub const PFD_NEED_PALETTE = 0x00000080;
pub const PFD_NEED_SYSTEM_PALETTE = 0x00000100;
pub const PFD_SWAP_EXCHANGE = 0x00000200;
pub const PFD_SWAP_COPY = 0x00000400;
pub const PFD_SWAP_LAYER_BUFFERS = 0x00000800;
pub const PFD_GENERIC_ACCELERATED = 0x00001000;
pub const PFD_SUPPORT_DIRECTDRAW = 0x00002000;
pub const PFD_DIRECT3D_ACCELERATED = 0x00004000;
pub const PFD_SUPPORT_COMPOSITION = 0x00008000;

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
) callconv(.Stdcall) bool;

pub extern "gdi32" fn ChoosePixelFormat(
    hdc: ?HDC,
    ppfd: ?*const PIXELFORMATDESCRIPTOR,
) callconv(.Stdcall) i32;

pub extern "gdi32" fn SwapBuffers(hdc: ?HDC) callconv(.Stdcall) bool;
pub extern "gdi32" fn wglCreateContext(hdc: ?HDC) callconv(.Stdcall) ?HGLRC;
pub extern "gdi32" fn wglMakeCurrent(hdc: ?HDC, hglrc: ?HGLRC) callconv(.Stdcall) bool;
