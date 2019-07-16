/*
 * Copyright 2008 Henri Verbeet for CodeWeavers
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

#ifndef __D3D10MISC_H__
#define __D3D10MISC_H__

#include "d3d10.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum D3D10_DRIVER_TYPE {
    D3D10_DRIVER_TYPE_HARDWARE  = 0,
    D3D10_DRIVER_TYPE_REFERENCE = 1,
    D3D10_DRIVER_TYPE_NULL      = 2,
    D3D10_DRIVER_TYPE_SOFTWARE  = 3,
    D3D10_DRIVER_TYPE_WARP      = 5,
} D3D10_DRIVER_TYPE;

HRESULT WINAPI D3D10CreateDevice(IDXGIAdapter *adapter, D3D10_DRIVER_TYPE driver_type,
        HMODULE swrast, UINT flags, UINT sdk_version, ID3D10Device **device);

HRESULT WINAPI D3D10CreateDeviceAndSwapChain(IDXGIAdapter *adapter, D3D10_DRIVER_TYPE driver_type,
        HMODULE swrast, UINT flags, UINT sdk_version, DXGI_SWAP_CHAIN_DESC *swapchain_desc,
        IDXGISwapChain **swapchain, ID3D10Device **device);

HRESULT WINAPI D3D10CreateBlob(SIZE_T data_size, ID3D10Blob **blob);

#ifdef __cplusplus
}
#endif

#endif /* __D3D10MISC_H__ */
