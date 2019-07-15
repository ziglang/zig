#undef INTERFACE
/*
 * Copyright 2010 Rico Schüller
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

#ifndef __D3D10_1SHADER_H__
#define __D3D10_1SHADER_H__

#include "d3d10shader.h"

DEFINE_GUID(IID_ID3D10ShaderReflection1, 0xc3457783, 0xa846, 0x47ce, 0x95, 0x20, 0xce, 0xa6, 0xf6, 0x6e, 0x74, 0x47);

#define INTERFACE ID3D10ShaderReflection1
DECLARE_INTERFACE_(ID3D10ShaderReflection1, IUnknown)
{
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* ID3D10ShaderReflection1 methods */
    STDMETHOD(GetDesc)(THIS_ D3D10_SHADER_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionConstantBuffer *, GetConstantBufferByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionConstantBuffer *, GetConstantBufferByName)(THIS_ const char *name) PURE;
    STDMETHOD(GetResourceBindingDesc)(THIS_ UINT index, D3D10_SHADER_INPUT_BIND_DESC *desc) PURE;
    STDMETHOD(GetInputParameterDesc)(THIS_ UINT index, D3D10_SIGNATURE_PARAMETER_DESC *desc) PURE;
    STDMETHOD(GetOutputParameterDesc)(THIS_ UINT index, D3D10_SIGNATURE_PARAMETER_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionVariable *, GetVariableByName)(THIS_ const char *name) PURE;
    STDMETHOD(GetResourceBindingDescByName)(THIS_ const char *name, D3D10_SHADER_INPUT_BIND_DESC *desc) PURE;
    STDMETHOD(GetMovInstructionCount)(THIS_ UINT *count) PURE;
    STDMETHOD(GetMovcInstructionCount)(THIS_ UINT *count) PURE;
    STDMETHOD(GetConversionInstructionCount)(THIS_ UINT *count) PURE;
    STDMETHOD(GetBitwiseInstructionCount)(THIS_ UINT *count) PURE;
    STDMETHOD(GetGSInputPrimitive)(THIS_ D3D10_PRIMITIVE *prim) PURE;
    STDMETHOD(IsLevel9Shader)(THIS_ WINBOOL *level9shader) PURE;
    STDMETHOD(IsSampleFrequencyShader)(THIS_ WINBOOL *samplefrequency) PURE;
};
#undef INTERFACE

#endif
