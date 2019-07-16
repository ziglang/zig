#include <_mingw_unicode.h>
/*
 * Copyright (C) 2008 Tony Wasserka
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#include "d3dx9.h"

#ifndef __WINE_D3DX9TEX_H
#define __WINE_D3DX9TEX_H

/**********************************************
 ***************** Definitions ****************
 **********************************************/
#define D3DX_FILTER_NONE                 0x00000001
#define D3DX_FILTER_POINT                0x00000002
#define D3DX_FILTER_LINEAR               0x00000003
#define D3DX_FILTER_TRIANGLE             0x00000004
#define D3DX_FILTER_BOX                  0x00000005
#define D3DX_FILTER_MIRROR_U             0x00010000
#define D3DX_FILTER_MIRROR_V             0x00020000
#define D3DX_FILTER_MIRROR_W             0x00040000
#define D3DX_FILTER_MIRROR               0x00070000
#define D3DX_FILTER_DITHER               0x00080000
#define D3DX_FILTER_DITHER_DIFFUSION     0x00100000
#define D3DX_FILTER_SRGB_IN              0x00200000
#define D3DX_FILTER_SRGB_OUT             0x00400000
#define D3DX_FILTER_SRGB                 0x00600000

#define D3DX_SKIP_DDS_MIP_LEVELS_MASK    0x1f
#define D3DX_SKIP_DDS_MIP_LEVELS_SHIFT   26
#define D3DX_SKIP_DDS_MIP_LEVELS(l, f)   ((((l) & D3DX_SKIP_DDS_MIP_LEVELS_MASK) \
        << D3DX_SKIP_DDS_MIP_LEVELS_SHIFT) | ((f) == D3DX_DEFAULT ? D3DX_FILTER_BOX : (f)))

#define D3DX_NORMALMAP_MIRROR_U          0x00010000
#define D3DX_NORMALMAP_MIRROR_V          0x00020000
#define D3DX_NORMALMAP_MIRROR            0x00030000
#define D3DX_NORMALMAP_INVERTSIGN        0x00080000
#define D3DX_NORMALMAP_COMPUTE_OCCLUSION 0x00100000

#define D3DX_CHANNEL_RED                 0x00000001
#define D3DX_CHANNEL_BLUE                0x00000002
#define D3DX_CHANNEL_GREEN               0x00000004
#define D3DX_CHANNEL_ALPHA               0x00000008
#define D3DX_CHANNEL_LUMINANCE           0x00000010

/**********************************************
 ****************** Typedefs ******************
 **********************************************/
typedef enum _D3DXIMAGE_FILEFORMAT
{
    D3DXIFF_BMP,
    D3DXIFF_JPG,
    D3DXIFF_TGA,
    D3DXIFF_PNG,
    D3DXIFF_DDS,
    D3DXIFF_PPM,
    D3DXIFF_DIB,
    D3DXIFF_HDR,
    D3DXIFF_PFM,
    D3DXIFF_FORCE_DWORD = 0x7fffffff
} D3DXIMAGE_FILEFORMAT;

typedef struct _D3DXIMAGE_INFO
{
    UINT Width;
    UINT Height;
    UINT Depth;
    UINT MipLevels;
    D3DFORMAT Format;
    D3DRESOURCETYPE ResourceType;
    D3DXIMAGE_FILEFORMAT ImageFileFormat;
} D3DXIMAGE_INFO;

/**********************************************
 ****************** Functions *****************
 **********************************************/
/* Typedefs for callback functions */
typedef void (WINAPI *LPD3DXFILL2D)(D3DXVECTOR4 *out, const D3DXVECTOR2 *texcoord,
        const D3DXVECTOR2 *texelsize, void *data);
typedef void (WINAPI *LPD3DXFILL3D)(D3DXVECTOR4 *out, const D3DXVECTOR3 *texcoord,
        const D3DXVECTOR3 *texelsize, void *data);

#ifdef __cplusplus
extern "C" {
#endif


/* Image Information */
HRESULT WINAPI D3DXGetImageInfoFromFileA(const char *file, D3DXIMAGE_INFO *info);
HRESULT WINAPI D3DXGetImageInfoFromFileW(const WCHAR *file, D3DXIMAGE_INFO *info);
#define        D3DXGetImageInfoFromFile __MINGW_NAME_AW(D3DXGetImageInfoFromFile)

HRESULT WINAPI D3DXGetImageInfoFromResourceA(HMODULE module, const char *resource, D3DXIMAGE_INFO *info);
HRESULT WINAPI D3DXGetImageInfoFromResourceW(HMODULE module, const WCHAR *resource, D3DXIMAGE_INFO *info);
#define        D3DXGetImageInfoFromResource __MINGW_NAME_AW(D3DXGetImageInfoFromResource)

HRESULT WINAPI D3DXGetImageInfoFromFileInMemory(const void *data, UINT data_size, D3DXIMAGE_INFO *info);


/* Surface Loading/Saving */
HRESULT WINAPI D3DXLoadSurfaceFromFileA(struct IDirect3DSurface9 *destsurface,
        const PALETTEENTRY *destpalette, const RECT *destrect, const char *srcfile,
        const RECT *srcrect, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);
HRESULT WINAPI D3DXLoadSurfaceFromFileW(struct IDirect3DSurface9 *destsurface,
        const PALETTEENTRY *destpalette, const RECT *destrect, const WCHAR *srcfile,
        const RECT *srcrect, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);
#define D3DXLoadSurfaceFromFile __MINGW_NAME_AW(D3DXLoadSurfaceFromFile)

HRESULT WINAPI D3DXLoadSurfaceFromResourceA(struct IDirect3DSurface9 *destsurface,
        const PALETTEENTRY *destpalette, const RECT *destrect, HMODULE srcmodule, const char *resource,
        const RECT *srcrect, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);
HRESULT WINAPI D3DXLoadSurfaceFromResourceW(struct IDirect3DSurface9 *destsurface,
        const PALETTEENTRY *destpalette, const RECT *destrect, HMODULE srcmodule, const WCHAR *resource,
        const RECT *srcrect, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);
#define D3DXLoadSurfaceFromResource __MINGW_NAME_AW(D3DXLoadSurfaceFromResource)

HRESULT WINAPI D3DXLoadSurfaceFromFileInMemory(struct IDirect3DSurface9 *destsurface,
        const PALETTEENTRY *destpalette, const RECT *destrect, const void *srcdata, UINT srcdatasize,
        const RECT *srcrect, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);

HRESULT WINAPI D3DXLoadSurfaceFromSurface(struct IDirect3DSurface9 *destsurface,
        const PALETTEENTRY *destpalette, const RECT *destrect, struct IDirect3DSurface9 *srcsurface,
        const PALETTEENTRY *srcpalette, const RECT *srcrect, DWORD filter, D3DCOLOR colorkey);

HRESULT WINAPI D3DXLoadSurfaceFromMemory(IDirect3DSurface9 *dst_surface,
        const PALETTEENTRY *dst_palette, const RECT *dst_rect, const void *src_memory,
        D3DFORMAT src_format, UINT src_pitch, const PALETTEENTRY *src_palette, const RECT *src_rect,
        DWORD filter, D3DCOLOR color_key);

HRESULT WINAPI D3DXSaveSurfaceToFileInMemory(struct ID3DXBuffer **destbuffer,
        D3DXIMAGE_FILEFORMAT destformat, struct IDirect3DSurface9 *srcsurface,
        const PALETTEENTRY *srcpalette, const RECT *srcrect);

HRESULT WINAPI D3DXSaveSurfaceToFileA(const char *destfile, D3DXIMAGE_FILEFORMAT destformat,
        struct IDirect3DSurface9 *srcsurface, const PALETTEENTRY *srcpalette, const RECT *srcrect);
HRESULT WINAPI D3DXSaveSurfaceToFileW(const WCHAR *destfile, D3DXIMAGE_FILEFORMAT destformat,
        struct IDirect3DSurface9 *srcsurface, const PALETTEENTRY *srcpalette, const RECT *srcrect);
#define D3DXSaveSurfaceToFile __MINGW_NAME_AW(D3DXSaveSurfaceToFile)


/* Volume Loading/Saving */
HRESULT WINAPI D3DXLoadVolumeFromFileA(struct IDirect3DVolume9 *destvolume,
        const PALETTEENTRY *destpalette, const D3DBOX *destbox, const char *srcfile,
        const D3DBOX *srcbox, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);
HRESULT WINAPI D3DXLoadVolumeFromFileW( struct IDirect3DVolume9 *destvolume,
        const PALETTEENTRY *destpalette, const D3DBOX *destbox, const WCHAR *srcfile,
        const D3DBOX *srcbox, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);
#define D3DXLoadVolumeFromFile __MINGW_NAME_AW(D3DXLoadVolumeFromFile)

HRESULT WINAPI D3DXLoadVolumeFromResourceA(struct IDirect3DVolume9 *destvolume,
        const PALETTEENTRY *destpalette, const D3DBOX *destbox, HMODULE srcmodule, const char *resource,
        const D3DBOX *srcbox, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);
HRESULT WINAPI D3DXLoadVolumeFromResourceW(struct IDirect3DVolume9 *destvolume,
        const PALETTEENTRY *destpalette, const D3DBOX *destbox, HMODULE srcmodule, const WCHAR *resource,
        const D3DBOX *srcbox, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);
#define D3DXLoadVolumeFromResource __MINGW_NAME_AW(D3DXLoadVolumeFromResource)

HRESULT WINAPI D3DXLoadVolumeFromFileInMemory(struct IDirect3DVolume9 *destvolume,
        const PALETTEENTRY *destpalette, const D3DBOX *destbox, const void *srcdata, UINT srcdatasize,
        const D3DBOX *srcbox, DWORD filter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo);

HRESULT WINAPI D3DXLoadVolumeFromVolume(struct IDirect3DVolume9 *destvolume,
        const PALETTEENTRY *destpalette, const D3DBOX *destbox, struct IDirect3DVolume9 *srcvolume,
        const PALETTEENTRY *srcpalette, const D3DBOX *srcbox, DWORD filter, D3DCOLOR colorkey);

HRESULT WINAPI D3DXLoadVolumeFromMemory(struct IDirect3DVolume9 *destvolume,
        const PALETTEENTRY *destpalette, const D3DBOX *destbox, const void *srcmemory,
        D3DFORMAT srcformat, UINT srcrowpitch, UINT srcslicepitch, const PALETTEENTRY *srcpalette,
        const D3DBOX *srcbox, DWORD filter, D3DCOLOR colorkey);

HRESULT WINAPI D3DXSaveVolumeToFileA(const char *destfile, D3DXIMAGE_FILEFORMAT destformat,
        struct IDirect3DVolume9 *srcvolume, const PALETTEENTRY *srcpalette, const D3DBOX *srcbox);
HRESULT WINAPI D3DXSaveVolumeToFileW(const WCHAR *destfile, D3DXIMAGE_FILEFORMAT destformat,
        struct IDirect3DVolume9 *srcvolume, const PALETTEENTRY *srcpalette, const D3DBOX *srcbox);
#define D3DXSaveVolumeToFile __MINGW_NAME_AW(D3DXSaveVolumeToFile)


/* Texture, cube texture and volume texture creation */
HRESULT WINAPI D3DXCheckTextureRequirements(struct IDirect3DDevice9 *device, UINT *width, UINT *height,
        UINT *miplevels, DWORD usage, D3DFORMAT *format, D3DPOOL pool);
HRESULT WINAPI D3DXCheckCubeTextureRequirements(struct IDirect3DDevice9 *device, UINT *size,
        UINT *miplevels, DWORD usage, D3DFORMAT *format, D3DPOOL pool);
HRESULT WINAPI D3DXCheckVolumeTextureRequirements(struct IDirect3DDevice9 *device, UINT *width, UINT *height,
        UINT *depth, UINT *miplevels, DWORD usage, D3DFORMAT *format, D3DPOOL pool);

HRESULT WINAPI D3DXCreateTexture(struct IDirect3DDevice9 *device, UINT width, UINT height,
        UINT miplevels, DWORD usage, D3DFORMAT format, D3DPOOL pool, struct IDirect3DTexture9 **texture);
HRESULT WINAPI D3DXCreateCubeTexture(struct IDirect3DDevice9 *device, UINT size,
        UINT miplevels, DWORD usage, D3DFORMAT format, D3DPOOL pool, struct IDirect3DCubeTexture9 **cube);
HRESULT WINAPI D3DXCreateVolumeTexture(struct IDirect3DDevice9 *device, UINT width, UINT height, UINT depth,
        UINT miplevels, DWORD usage, D3DFORMAT format, D3DPOOL pool, struct IDirect3DVolumeTexture9 **volume);

HRESULT WINAPI D3DXCreateTextureFromFileA(struct IDirect3DDevice9 *device,
        const char *srcfile, struct IDirect3DTexture9 **texture);
HRESULT WINAPI D3DXCreateTextureFromFileW(struct IDirect3DDevice9 *device,
        const WCHAR *srcfile, struct IDirect3DTexture9 **texture);
#define D3DXCreateTextureFromFile __MINGW_NAME_AW(D3DXCreateTextureFromFile)

HRESULT WINAPI D3DXCreateCubeTextureFromFileA(struct IDirect3DDevice9 *device,
        const char *srcfile, struct IDirect3DCubeTexture9 **cube);
HRESULT WINAPI D3DXCreateCubeTextureFromFileW(struct IDirect3DDevice9 *device,
        const WCHAR *srcfile, struct IDirect3DCubeTexture9 **cube);
#define D3DXCreateCubeTextureFromFile __MINGW_NAME_AW(D3DXCreateCubeTextureFromFile)

HRESULT WINAPI D3DXCreateVolumeTextureFromFileA(struct IDirect3DDevice9 *device,
        const char *srcfile, struct IDirect3DVolumeTexture9 **volume);
HRESULT WINAPI D3DXCreateVolumeTextureFromFileW(struct IDirect3DDevice9 *device,
        const WCHAR *srcfile, struct IDirect3DVolumeTexture9 **volume);
#define D3DXCreateVolumeTextureFromFile __MINGW_NAME_AW(D3DXCreateVolumeTextureFromFile)

HRESULT WINAPI D3DXCreateTextureFromResourceA(struct IDirect3DDevice9 *device,
        HMODULE srcmodule, const char *resource, struct IDirect3DTexture9 **texture);
HRESULT WINAPI D3DXCreateTextureFromResourceW(struct IDirect3DDevice9 *device,
        HMODULE srcmodule, const WCHAR *resource, struct IDirect3DTexture9 **texture);
#define D3DXCreateTextureFromResource __MINGW_NAME_AW(D3DXCreateTextureFromResource)

HRESULT WINAPI D3DXCreateCubeTextureFromResourceA(struct IDirect3DDevice9 *device,
        HMODULE srcmodule, const char *resource, struct IDirect3DCubeTexture9 **cube);
HRESULT WINAPI D3DXCreateCubeTextureFromResourceW(struct IDirect3DDevice9 *device,
        HMODULE srcmodule, const WCHAR *resource, struct IDirect3DCubeTexture9 **cube);
#define D3DXCreateCubeTextureFromResource __MINGW_NAME_AW(D3DXCreateCubeTextureFromResource)

HRESULT WINAPI D3DXCreateVolumeTextureFromResourceA(struct IDirect3DDevice9 *device,
        HMODULE srcmodule, const char *resource, struct IDirect3DVolumeTexture9 **volume);
HRESULT WINAPI D3DXCreateVolumeTextureFromResourceW(struct IDirect3DDevice9 *device,
        HMODULE srcmodule, const WCHAR *resource, struct IDirect3DVolumeTexture9 **volume);
#define D3DXCreateVolumeTextureFromResource __MINGW_NAME_AW(D3DXCreateVolumeTextureFromResource)

HRESULT WINAPI D3DXCreateTextureFromFileExA(struct IDirect3DDevice9 *device, const char *srcfile,
        UINT width, UINT height, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DTexture9 **texture);
HRESULT WINAPI D3DXCreateTextureFromFileExW(struct IDirect3DDevice9 *device, const WCHAR *srcfile,
        UINT width, UINT height, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DTexture9 **texture);
#define D3DXCreateTextureFromFileEx __MINGW_NAME_AW(D3DXCreateTextureFromFileEx)

HRESULT WINAPI D3DXCreateCubeTextureFromFileExA(struct IDirect3DDevice9 *device, const char *srcfile,
        UINT size, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DCubeTexture9 **cube);
HRESULT WINAPI D3DXCreateCubeTextureFromFileExW(struct IDirect3DDevice9 *device, const WCHAR *srcfile,
        UINT size, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DCubeTexture9 **cube);
#define D3DXCreateCubeTextureFromFileEx __MINGW_NAME_AW(D3DXCreateCubeTextureFromFileEx)

HRESULT WINAPI D3DXCreateVolumeTextureFromFileExA(struct IDirect3DDevice9 *device, const char *srcfile,
        UINT width, UINT height, UINT depth, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DVolumeTexture9 **volume);
HRESULT WINAPI D3DXCreateVolumeTextureFromFileExW(struct IDirect3DDevice9 *device, const WCHAR *srcfile,
        UINT width, UINT height, UINT depth, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DVolumeTexture9 **volume);
#define D3DXCreateVolumeTextureFromFileEx __MINGW_NAME_AW(D3DXCreateVolumeTextureFromFileEx)

HRESULT WINAPI D3DXCreateTextureFromResourceExA(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const char *resource, UINT width, UINT height, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DTexture9 **texture);
HRESULT WINAPI D3DXCreateTextureFromResourceExW(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const WCHAR *resource, UINT width, UINT height, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DTexture9 **texture);
#define D3DXCreateTextureFromResourceEx __MINGW_NAME_AW(D3DXCreateTextureFromResourceEx)

HRESULT WINAPI D3DXCreateCubeTextureFromResourceExA(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const char *resource, UINT size, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DCubeTexture9 **cube);
HRESULT WINAPI D3DXCreateCubeTextureFromResourceExW(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const WCHAR *resource, UINT size, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DCubeTexture9 **cube);
#define D3DXCreateCubeTextureFromResourceEx __MINGW_NAME_AW(D3DXCreateCubeTextureFromResourceEx)

HRESULT WINAPI D3DXCreateVolumeTextureFromResourceExA(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const char *resource, UINT width, UINT height, UINT depth, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DVolumeTexture9 **volume);
HRESULT WINAPI D3DXCreateVolumeTextureFromResourceExW(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const WCHAR *resource, UINT width, UINT height, UINT depth, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DVolumeTexture9 **volume);
#define D3DXCreateVolumeTextureFromResourceEx __MINGW_NAME_AW(D3DXCreateVolumeTextureFromResourceEx)

HRESULT WINAPI D3DXCreateTextureFromFileInMemory(struct IDirect3DDevice9 *device,
        const void *srcdata, UINT srcdatasize, struct IDirect3DTexture9 **texture);
HRESULT WINAPI D3DXCreateCubeTextureFromFileInMemory(struct IDirect3DDevice9 *device,
        const void *srcdata, UINT srcdatasize, struct IDirect3DCubeTexture9 **cube);
HRESULT WINAPI D3DXCreateVolumeTextureFromFileInMemory(struct IDirect3DDevice9 *device,
        const void *srcdata, UINT srcdatasize, struct IDirect3DVolumeTexture9 **volume);

HRESULT WINAPI D3DXCreateTextureFromFileInMemoryEx(struct IDirect3DDevice9 *device, const void *srcdata,
        UINT srcdatasize, UINT width, UINT height, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DTexture9 **texture);
HRESULT WINAPI D3DXCreateCubeTextureFromFileInMemoryEx(struct IDirect3DDevice9 *device, const void *srcdata,
        UINT srcdatasize, UINT size, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DCubeTexture9 **cube);
HRESULT WINAPI D3DXCreateVolumeTextureFromFileInMemoryEx(struct IDirect3DDevice9 *device, const void *srcdata,
        UINT srcdatasize, UINT width, UINT height, UINT depth, UINT miplevels, DWORD usage, D3DFORMAT format,
        D3DPOOL pool, DWORD filter, DWORD mipfilter, D3DCOLOR colorkey, D3DXIMAGE_INFO *srcinfo,
        PALETTEENTRY *palette, struct IDirect3DVolumeTexture9 **volume);

HRESULT WINAPI D3DXSaveTextureToFileInMemory(struct ID3DXBuffer **destbuffer, D3DXIMAGE_FILEFORMAT destformat,
        struct IDirect3DBaseTexture9 *srctexture, const PALETTEENTRY *srcpalette);
HRESULT WINAPI D3DXSaveTextureToFileA(const char *destfile, D3DXIMAGE_FILEFORMAT destformat,
        struct IDirect3DBaseTexture9 *srctexture, const PALETTEENTRY *srcpalette);
HRESULT WINAPI D3DXSaveTextureToFileW(const WCHAR *destfile, D3DXIMAGE_FILEFORMAT destformat,
        struct IDirect3DBaseTexture9 *srctexture, const PALETTEENTRY *srcpalette);
#define D3DXSaveTextureToFile __MINGW_NAME_AW(D3DXSaveTextureToFile)

/* Other functions */
HRESULT WINAPI D3DXFilterTexture(struct IDirect3DBaseTexture9 *texture,
        const PALETTEENTRY *palette, UINT srclevel, DWORD filter);
#define D3DXFilterCubeTexture D3DXFilterTexture
#define D3DXFilterVolumeTexture D3DXFilterTexture

HRESULT WINAPI D3DXFillTexture(struct IDirect3DTexture9 *texture, LPD3DXFILL2D function, void *data);
HRESULT WINAPI D3DXFillCubeTexture(struct IDirect3DCubeTexture9 *cube, LPD3DXFILL3D function, void *data);
HRESULT WINAPI D3DXFillVolumeTexture(struct IDirect3DVolumeTexture9 *volume, LPD3DXFILL3D function, void *data);

HRESULT WINAPI D3DXFillTextureTX(struct IDirect3DTexture9 *texture, ID3DXTextureShader *texture_shader);
HRESULT WINAPI D3DXFillCubeTextureTX(struct IDirect3DCubeTexture9 *cube, ID3DXTextureShader *texture_shader);
HRESULT WINAPI D3DXFillVolumeTextureTX(struct IDirect3DVolumeTexture9 *volume, ID3DXTextureShader *texture_shader);

HRESULT WINAPI D3DXComputeNormalMap(IDirect3DTexture9 *texture, IDirect3DTexture9 *srctexture,
        const PALETTEENTRY *srcpalette, DWORD flags, DWORD channel, float amplitude);

#ifdef __cplusplus
}
#endif

#endif /* __WINE_D3DX9TEX_H */
