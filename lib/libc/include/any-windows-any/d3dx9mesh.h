#include <_mingw_unicode.h>
#undef INTERFACE
/*
 * Copyright (C) 2009 David Adam
 * Copyright (C) 2010 Tony Wasserka
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

#ifndef __WINE_D3DX9MESH_H
#define __WINE_D3DX9MESH_H

DEFINE_GUID(IID_ID3DXBaseMesh, 0x7ed943dd, 0x52e8, 0x40b5, 0xa8, 0xd8, 0x76, 0x68, 0x5c, 0x40, 0x63, 0x30);
DEFINE_GUID(IID_ID3DXMesh,     0x4020e5c2, 0x1403, 0x4929, 0x88, 0x3f, 0xe2, 0xe8, 0x49, 0xfa, 0xc1, 0x95);
DEFINE_GUID(IID_ID3DXPMesh,    0x8875769a, 0xd579, 0x4088, 0xaa, 0xeb, 0x53, 0x4d, 0x1a, 0xd8, 0x4e, 0x96);
DEFINE_GUID(IID_ID3DXSPMesh,   0x667ea4c7, 0xf1cd, 0x4386, 0xb5, 0x23, 0x7c, 0x02, 0x90, 0xb8, 0x3c, 0xc5);
DEFINE_GUID(IID_ID3DXSkinInfo, 0x11eaa540, 0xf9a6, 0x4d49, 0xae, 0x6a, 0xe1, 0x92, 0x21, 0xf7, 0x0c, 0xc4);
DEFINE_GUID(IID_ID3DXPatchMesh,0x3ce6cc22, 0xdbf2, 0x44f4, 0x89, 0x4d, 0xf9, 0xc3, 0x4a, 0x33, 0x71, 0x39);
DEFINE_GUID(IID_ID3DXPRTBuffer,           0xf1827e47, 0x00a8, 0x49cd, 0x90, 0x8c, 0x9d, 0x11, 0x95, 0x5f, 0x87, 0x28);
DEFINE_GUID(IID_ID3DXPRTCompBuffer,       0xa758d465, 0xfe8d, 0x45ad, 0x9c, 0xf0, 0xd0, 0x1e, 0x56, 0x26, 0x6a, 0x07);
DEFINE_GUID(IID_ID3DXTextureGutterHelper, 0x838f01ec, 0x9729, 0x4527, 0xaa, 0xdb, 0xdf, 0x70, 0xad, 0xe7, 0xfe, 0xa9);
DEFINE_GUID(IID_ID3DXPRTEngine,           0x683a4278, 0xcd5f, 0x4d24, 0x90, 0xad, 0xc4, 0xe1, 0xb6, 0x85, 0x5d, 0x53);

#define UNUSED16 (0xffff)
#define UNUSED32 (0xffffffff)

enum _MAX_FVF_DECL_SIZE
{
    MAX_FVF_DECL_SIZE = MAXD3DDECLLENGTH + 1
};

enum _D3DXMESH
{
    D3DXMESH_32BIT                 = 0x001,
    D3DXMESH_DONOTCLIP             = 0x002,
    D3DXMESH_POINTS                = 0x004,
    D3DXMESH_RTPATCHES             = 0x008,
    D3DXMESH_NPATCHES              = 0x4000,
    D3DXMESH_VB_SYSTEMMEM          = 0x010,
    D3DXMESH_VB_MANAGED            = 0x020,
    D3DXMESH_VB_WRITEONLY          = 0x040,
    D3DXMESH_VB_DYNAMIC            = 0x080,
    D3DXMESH_VB_SOFTWAREPROCESSING = 0x8000,
    D3DXMESH_IB_SYSTEMMEM          = 0x100,
    D3DXMESH_IB_MANAGED            = 0x200,
    D3DXMESH_IB_WRITEONLY          = 0x400,
    D3DXMESH_IB_DYNAMIC            = 0x800,
    D3DXMESH_IB_SOFTWAREPROCESSING = 0x10000,
    D3DXMESH_VB_SHARE              = 0x1000,
    D3DXMESH_USEHWONLY             = 0x2000,
    D3DXMESH_SYSTEMMEM             = 0x110,
    D3DXMESH_MANAGED               = 0x220,
    D3DXMESH_WRITEONLY             = 0x440,
    D3DXMESH_DYNAMIC               = 0x880,
    D3DXMESH_SOFTWAREPROCESSING    = 0x18000
};

enum _D3DXMESHOPT
{
    D3DXMESHOPT_DEVICEINDEPENDENT = 0x00400000,
    D3DXMESHOPT_COMPACT           = 0x01000000,
    D3DXMESHOPT_ATTRSORT          = 0x02000000,
    D3DXMESHOPT_VERTEXCACHE       = 0x04000000,
    D3DXMESHOPT_STRIPREORDER      = 0x08000000,
    D3DXMESHOPT_IGNOREVERTS       = 0x10000000,
    D3DXMESHOPT_DONOTSPLIT        = 0x20000000,
};

typedef enum _D3DXPATCHMESHTYPE
{
    D3DXPATCHMESH_RECT        = 1,
    D3DXPATCHMESH_TRI         = 2,
    D3DXPATCHMESH_NPATCH      = 3,
    D3DXPATCHMESH_FORCE_DWORD = 0x7fffffff,
} D3DXPATCHMESHTYPE;

enum _D3DXPATCHMESH
{
    D3DXPATCHMESH_DEFAULT = 0,
};

enum _D3DXMESHSIMP
{
    D3DXMESHSIMP_VERTEX = 0x1,
    D3DXMESHSIMP_FACE   = 0x2,
};

typedef enum D3DXCLEANTYPE {
    D3DXCLEAN_BACKFACING     = 0x00000001,
    D3DXCLEAN_BOWTIES        = 0x00000002,

    D3DXCLEAN_SKINNING       = D3DXCLEAN_BACKFACING,
    D3DXCLEAN_OPTIMIZATION   = D3DXCLEAN_BACKFACING,
    D3DXCLEAN_SIMPLIFICATION = D3DXCLEAN_BACKFACING | D3DXCLEAN_BOWTIES,
} D3DXCLEANTYPE;

typedef enum _D3DXTANGENT
{
    D3DXTANGENT_WRAP_U =                  0x0001,
    D3DXTANGENT_WRAP_V =                  0x0002,
    D3DXTANGENT_WRAP_UV =                 0x0003,
    D3DXTANGENT_DONT_NORMALIZE_PARTIALS = 0x0004,
    D3DXTANGENT_DONT_ORTHOGONALIZE =      0x0008,
    D3DXTANGENT_ORTHOGONALIZE_FROM_V =    0x0010,
    D3DXTANGENT_ORTHOGONALIZE_FROM_U =    0x0020,
    D3DXTANGENT_WEIGHT_BY_AREA =          0x0040,
    D3DXTANGENT_WEIGHT_EQUAL =            0x0080,
    D3DXTANGENT_WIND_CW =                 0x0100,
    D3DXTANGENT_CALCULATE_NORMALS =       0x0200,
    D3DXTANGENT_GENERATE_IN_PLACE =       0x0400,
} D3DXTANGENT;

typedef enum _D3DXIMT
{
    D3DXIMT_WRAP_U   = 0x01,
    D3DXIMT_WRAP_V   = 0x02,
    D3DXIMT_WRAP_UV  = 0x03,
} D3DXIMT;

typedef enum _D3DXUVATLAS
{
    D3DXUVATLAS_DEFAULT          = 0x00,
    D3DXUVATLAS_GEODESIC_FAST    = 0x01,
    D3DXUVATLAS_GEODESIC_QUALITY = 0x02,
} D3DXUVATLAS;

typedef enum _D3DXEFFECTDEFAULTTYPE
{
    D3DXEDT_STRING     = 1,
    D3DXEDT_FLOATS     = 2,
    D3DXEDT_DWORD      = 3,
    D3DXEDT_FORCEDWORD = 0x7fffffff,
} D3DXEFFECTDEFAULTTYPE;

enum _D3DXWELDEPSILONSFLAGS
{
    D3DXWELDEPSILONS_WELDALL             = 0x1,
    D3DXWELDEPSILONS_WELDPARTIALMATCHES  = 0x2,
    D3DXWELDEPSILONS_DONOTREMOVEVERTICES = 0x4,
    D3DXWELDEPSILONS_DONOTSPLIT          = 0x8,
};

typedef enum _D3DXSHCOMPRESSQUALITYTYPE
{
    D3DXSHCQUAL_FASTLOWQUALITY  = 1,
    D3DXSHCQUAL_SLOWHIGHQUALITY = 2,
    D3DXSHCQUAL_FORCE_DWORD     = 0x7fffffff,
} D3DXSHCOMPRESSQUALITYTYPE;

typedef enum _D3DXSHGPUSIMOPT
{
    D3DXSHGPUSIMOPT_SHADOWRES256   = 1,
    D3DXSHGPUSIMOPT_SHADOWRES512   = 0,
    D3DXSHGPUSIMOPT_SHADOWRES1024  = 2,
    D3DXSHGPUSIMOPT_SHADOWRES2048  = 3,
    D3DXSHGPUSIMOPT_HIGHQUALITY    = 4,
    D3DXSHGPUSIMOPT_FORCE_DWORD    = 0x7fffffff,
} D3DXSHGPUSIMOPT;

typedef struct ID3DXBaseMesh* LPD3DXBASEMESH;
typedef struct ID3DXMesh* LPD3DXMESH;
typedef struct ID3DXPMesh *LPD3DXPMESH;
typedef struct ID3DXSPMesh *LPD3DXSPMESH;
typedef struct ID3DXSkinInfo *LPD3DXSKININFO;
typedef struct ID3DXPatchMesh *LPD3DXPATCHMESH;
typedef struct ID3DXPRTBuffer *LPD3DXPRTBUFFER;
typedef struct ID3DXPRTCompBuffer *LPD3DXPRTCOMPBUFFER;
typedef struct ID3DXPRTEngine *LPD3DXPRTENGINE;
typedef struct ID3DXTextureGutterHelper *LPD3DXTEXTUREGUTTERHELPER;

typedef struct _D3DXATTRIBUTERANGE {
    DWORD AttribId;
    DWORD FaceStart;
    DWORD FaceCount;
    DWORD VertexStart;
    DWORD VertexCount;
} D3DXATTRIBUTERANGE;

typedef D3DXATTRIBUTERANGE* LPD3DXATTRIBUTERANGE;

typedef struct _D3DXMATERIAL
{
    D3DMATERIAL9 MatD3D;
    char *pTextureFilename;
} D3DXMATERIAL, *LPD3DXMATERIAL;

typedef struct _D3DXEFFECTDEFAULT
{
    char *pParamName;
    D3DXEFFECTDEFAULTTYPE Type;
    DWORD NumBytes;
    void *pValue;
} D3DXEFFECTDEFAULT, *LPD3DXEFFECTDEFAULT;

typedef struct _D3DXEFFECTINSTANCE
{
    char *pEffectFilename;
    DWORD NumDefaults;
    LPD3DXEFFECTDEFAULT pDefaults;
} D3DXEFFECTINSTANCE, *LPD3DXEFFECTINSTANCE;

typedef struct _D3DXATTRIBUTEWEIGHTS
{
    FLOAT Position;
    FLOAT Boundary;
    FLOAT Normal;
    FLOAT Diffuse;
    FLOAT Specular;
    FLOAT Texcoords[8];
    FLOAT Tangent;
    FLOAT Binormal;
} D3DXATTRIBUTEWEIGHTS, *LPD3DXATTRIBUTEWEIGHTS;

typedef struct _D3DXWELDEPSILONS
{
    FLOAT Position;
    FLOAT BlendWeights;
    FLOAT Normals;
    FLOAT PSize;
    FLOAT Specular;
    FLOAT Diffuse;
    FLOAT Texcoords[8];
    FLOAT Tangent;
    FLOAT Binormal;
    FLOAT TessFactor;
} D3DXWELDEPSILONS, *LPD3DXWELDEPSILONS;

typedef struct _D3DXBONECOMBINATION
{
    DWORD AttribId;
    DWORD FaceStart;
    DWORD FaceCount;
    DWORD VertexStart;
    DWORD VertexCout;
    DWORD *BoneId;
} D3DXBONECOMBINATION, *LPD3DXBONECOMBINATION;

typedef struct _D3DXPATCHINFO
{
    D3DXPATCHMESHTYPE PatchType;
    D3DDEGREETYPE Degree;
    D3DBASISTYPE Basis;
} D3DXPATCHINFO, *LPD3DXPATCHINFO;

typedef struct _D3DXINTERSECTINFO
{
    DWORD FaceIndex;
    FLOAT U;
    FLOAT V;
    FLOAT Dist;
} D3DXINTERSECTINFO, *LPD3DXINTERSECTINFO;

typedef struct _D3DXSHMATERIAL
{
    D3DCOLORVALUE Diffuse;
    WINBOOL bMirror;
    WINBOOL bSubSurf;
    FLOAT RelativeIndexOfRefraction;
    D3DCOLORVALUE Absorption;
    D3DCOLORVALUE ReducedScattering;
} D3DXSHMATERIAL;

typedef struct _D3DXSHPRTSPLITMESHVERTDATA
{
    UINT uVertRemap;
    UINT uSubCluster;
    UCHAR ucVertStatus;
} D3DXSHPRTSPLITMESHVERTDATA;

typedef struct _D3DXSHPRTSPLITMESHCLUSTERDATA
{
    UINT uVertStart;
    UINT uVertLength;
    UINT uFaceStart;
    UINT uFaceLength;
    UINT uClusterStart;
    UINT uClusterLength;
} D3DXSHPRTSPLITMESHCLUSTERDATA;

typedef struct _XFILECOMPRESSEDANIMATIONSET
{
    DWORD CompressedBlockSize;
    FLOAT TicksPerSec;
    DWORD PlaybackType;
    DWORD BufferLength;
} XFILECOMPRESSEDANIMATIONSET;

typedef HRESULT (WINAPI *LPD3DXUVATLASCB)(float complete, void *ctx);
typedef HRESULT (WINAPI *LPD3DXIMTSIGNALCALLBACK)(const D3DXVECTOR2 *, UINT, UINT, void *, FLOAT *);
typedef HRESULT (WINAPI *LPD3DXSHPRTSIMCB)(float complete, void *ctx);

#undef INTERFACE
#define INTERFACE ID3DXBaseMesh

DECLARE_INTERFACE_(ID3DXBaseMesh, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXBaseMesh ***/
    STDMETHOD(DrawSubset)(THIS_ DWORD attrib_id) PURE;
    STDMETHOD_(DWORD, GetNumFaces)(THIS) PURE;
    STDMETHOD_(DWORD, GetNumVertices)(THIS) PURE;
    STDMETHOD_(DWORD, GetFVF)(THIS) PURE;
    STDMETHOD(GetDeclaration)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
    STDMETHOD_(DWORD, GetNumBytesPerVertex)(THIS) PURE;
    STDMETHOD_(DWORD, GetOptions)(THIS) PURE;
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(CloneMeshFVF)(THIS_ DWORD options, DWORD fvf,
            struct IDirect3DDevice9 *device, struct ID3DXMesh **clone_mesh) PURE;
    STDMETHOD(CloneMesh)(THIS_ DWORD options, const D3DVERTEXELEMENT9 *declaration,
            struct IDirect3DDevice9 *device, struct ID3DXMesh **clone_mesh) PURE;
    STDMETHOD(GetVertexBuffer)(THIS_ struct IDirect3DVertexBuffer9 **vertex_buffer) PURE;
    STDMETHOD(GetIndexBuffer)(THIS_ struct IDirect3DIndexBuffer9 **index_buffer) PURE;
    STDMETHOD(LockVertexBuffer)(THIS_ DWORD flags, void **data) PURE;
    STDMETHOD(UnlockVertexBuffer)(THIS) PURE;
    STDMETHOD(LockIndexBuffer)(THIS_ DWORD flags, void **data) PURE;
    STDMETHOD(UnlockIndexBuffer)(THIS) PURE;
    STDMETHOD(GetAttributeTable)(THIS_ D3DXATTRIBUTERANGE* attrib_table, DWORD* attrib_table_size) PURE;
    STDMETHOD(ConvertPointRepsToAdjacency)(THIS_ const DWORD *point_reps, DWORD *adjacency) PURE;
    STDMETHOD(ConvertAdjacencyToPointReps)(THIS_ const DWORD *adjacency, DWORD *point_reps) PURE;
    STDMETHOD(GenerateAdjacency)(THIS_ FLOAT epsilon, DWORD* adjacency) PURE;
    STDMETHOD(UpdateSemantics)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXMesh
DECLARE_INTERFACE_(ID3DXMesh, ID3DXBaseMesh)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXBaseMesh ***/
    STDMETHOD(DrawSubset)(THIS_ DWORD attrib_id) PURE;
    STDMETHOD_(DWORD, GetNumFaces)(THIS) PURE;
    STDMETHOD_(DWORD, GetNumVertices)(THIS) PURE;
    STDMETHOD_(DWORD, GetFVF)(THIS) PURE;
    STDMETHOD(GetDeclaration)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
    STDMETHOD_(DWORD, GetNumBytesPerVertex)(THIS) PURE;
    STDMETHOD_(DWORD, GetOptions)(THIS) PURE;
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(CloneMeshFVF)(THIS_ DWORD options, DWORD fvf,
            struct IDirect3DDevice9 *device, struct ID3DXMesh **clone_mesh) PURE;
    STDMETHOD(CloneMesh)(THIS_ DWORD options, const D3DVERTEXELEMENT9 *declaration,
            struct IDirect3DDevice9 *device, struct ID3DXMesh **clone_mesh) PURE;
    STDMETHOD(GetVertexBuffer)(THIS_ struct IDirect3DVertexBuffer9 **vertex_buffer) PURE;
    STDMETHOD(GetIndexBuffer)(THIS_ struct IDirect3DIndexBuffer9 **index_buffer) PURE;
    STDMETHOD(LockVertexBuffer)(THIS_ DWORD flags, void **data) PURE;
    STDMETHOD(UnlockVertexBuffer)(THIS) PURE;
    STDMETHOD(LockIndexBuffer)(THIS_ DWORD flags, void **data) PURE;
    STDMETHOD(UnlockIndexBuffer)(THIS) PURE;
    STDMETHOD(GetAttributeTable)(THIS_ D3DXATTRIBUTERANGE* attrib_table, DWORD* attrib_table_size) PURE;
    STDMETHOD(ConvertPointRepsToAdjacency)(THIS_ const DWORD *point_reps, DWORD *adjacency) PURE;
    STDMETHOD(ConvertAdjacencyToPointReps)(THIS_ const DWORD *adjacency, DWORD *point_reps) PURE;
    STDMETHOD(GenerateAdjacency)(THIS_ FLOAT epsilon, DWORD* adjacency) PURE;
    STDMETHOD(UpdateSemantics)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
    /*** ID3DXMesh ***/
    STDMETHOD(LockAttributeBuffer)(THIS_ DWORD flags, DWORD** data) PURE;
    STDMETHOD(UnlockAttributeBuffer)(THIS) PURE;
    STDMETHOD(Optimize)(THIS_ DWORD flags, const DWORD *adjacency_in, DWORD *adjacency_out,
            DWORD *face_remap, ID3DXBuffer **vertex_remap, ID3DXMesh **opt_mesh) PURE;
    STDMETHOD(OptimizeInplace)(THIS_ DWORD flags, const DWORD *adjacency_in, DWORD *adjacency_out,
                     DWORD *face_remap, ID3DXBuffer **vertex_remap) PURE;
    STDMETHOD(SetAttributeTable)(THIS_ const D3DXATTRIBUTERANGE *attrib_table,
            DWORD attrib_table_size) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXPMesh
DECLARE_INTERFACE_(ID3DXPMesh, ID3DXBaseMesh)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXBaseMesh ***/
    STDMETHOD(DrawSubset)(THIS_ DWORD attrib_id) PURE;
    STDMETHOD_(DWORD, GetNumFaces)(THIS) PURE;
    STDMETHOD_(DWORD, GetNumVertices)(THIS) PURE;
    STDMETHOD_(DWORD, GetFVF)(THIS) PURE;
    STDMETHOD(GetDeclaration)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
    STDMETHOD_(DWORD, GetNumBytesPerVertex)(THIS) PURE;
    STDMETHOD_(DWORD, GetOptions)(THIS) PURE;
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(CloneMeshFVF)(THIS_ DWORD options, DWORD fvf,
            struct IDirect3DDevice9 *device, struct ID3DXMesh **clone_mesh) PURE;
    STDMETHOD(CloneMesh)(THIS_ DWORD options, const D3DVERTEXELEMENT9 *declaration,
            struct IDirect3DDevice9 *device, struct ID3DXMesh **clone_mesh) PURE;
    STDMETHOD(GetVertexBuffer)(THIS_ struct IDirect3DVertexBuffer9 **vertex_buffer) PURE;
    STDMETHOD(GetIndexBuffer)(THIS_ struct IDirect3DIndexBuffer9 **index_buffer) PURE;
    STDMETHOD(LockVertexBuffer)(THIS_ DWORD flags, void **data) PURE;
    STDMETHOD(UnlockVertexBuffer)(THIS) PURE;
    STDMETHOD(LockIndexBuffer)(THIS_ DWORD flags, void **data) PURE;
    STDMETHOD(UnlockIndexBuffer)(THIS) PURE;
    STDMETHOD(GetAttributeTable)(THIS_ D3DXATTRIBUTERANGE* attrib_table, DWORD* attrib_table_size) PURE;
    STDMETHOD(ConvertPointRepsToAdjacency)(THIS_ const DWORD *point_reps, DWORD *adjacency) PURE;
    STDMETHOD(ConvertAdjacencyToPointReps)(THIS_ const DWORD *adjacency, DWORD *point_reps) PURE;
    STDMETHOD(GenerateAdjacency)(THIS_ FLOAT epsilon, DWORD* adjacency) PURE;
    STDMETHOD(UpdateSemantics)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
    /*** ID3DXPMesh ***/
    STDMETHOD(ClonePMeshFVF)(THIS_ DWORD options, DWORD fvf,
            struct IDirect3DDevice9 *device, struct ID3DXPMesh **clone_mesh) PURE;
    STDMETHOD(ClonePMesh)(THIS_ DWORD options, const D3DVERTEXELEMENT9 *declaration,
            struct IDirect3DDevice9 *device, struct ID3DXPMesh **clone_mesh) PURE;
    STDMETHOD(SetNumFaces)(THIS_ DWORD faces) PURE;
    STDMETHOD(SetNumVertices)(THIS_ DWORD vertices) PURE;
    STDMETHOD_(DWORD, GetMaxFaces)(THIS) PURE;
    STDMETHOD_(DWORD, GetMinFaces)(THIS) PURE;
    STDMETHOD_(DWORD, GetMaxVertices)(THIS) PURE;
    STDMETHOD_(DWORD, GetMinVertices)(THIS) PURE;
    STDMETHOD(Save)(THIS_ IStream *stream, const D3DXMATERIAL *material,
            const D3DXEFFECTINSTANCE *effect_instance, DWORD num_materials) PURE;
    STDMETHOD(Optimize)(THIS_ DWORD flags, DWORD *adjacency_out, DWORD *face_remap,
            ID3DXBuffer **vertex_remap, ID3DXMesh **opt_mesh) PURE;
    STDMETHOD(OptimizeBaseLOD)(THIS_ DWORD flags, DWORD* face_remap) PURE;
    STDMETHOD(TrimByFaces)(THIS_ DWORD new_faces_min, DWORD new_faces_max, DWORD* face_remap, DWORD* vertex_remap) PURE;
    STDMETHOD(TrimByVertices)(THIS_ DWORD new_vertices_min, DWORD new_vertices_max, DWORD* face_remap, DWORD* vertex_remap) PURE;
    STDMETHOD(GetAdjacency)(THIS_ DWORD* adjacency) PURE;
    STDMETHOD(GenerateVertexHistory)(THIS_ DWORD* vertex_history) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXSPMesh
DECLARE_INTERFACE_(ID3DXSPMesh, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXSPMesh ***/
    STDMETHOD_(DWORD, GetNumFaces)(THIS) PURE;
    STDMETHOD_(DWORD, GetNumVertices)(THIS) PURE;
    STDMETHOD_(DWORD, GetNumFVF)(THIS) PURE;
    STDMETHOD(GetDeclaration)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
    STDMETHOD_(DWORD, GetOptions)(THIS) PURE;
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(CloneMeshFVF)(THIS_ DWORD options, DWORD fvf,
            struct IDirect3DDevice9 *device, DWORD *adjacency_out,
            DWORD *vertex_remap_out, struct ID3DXMesh **clone_mesh) PURE;
    STDMETHOD(CloneMesh)(THIS_ DWORD options, const D3DVERTEXELEMENT9 *declaration,
            struct IDirect3DDevice9 *device, DWORD *adjacency_out,
            DWORD *vertex_remap_out, struct ID3DXMesh **clone_mesh) PURE;
    STDMETHOD(ClonePMeshFVF)(THIS_ DWORD options, DWORD fvf,
            struct IDirect3DDevice9 *device, DWORD *vertex_remap_out,
            float *errors_by_face, struct ID3DXPMesh **clone_mesh) PURE;
    STDMETHOD(ClonePMesh)(THIS_ DWORD options, const D3DVERTEXELEMENT9 *declaration,
            struct IDirect3DDevice9 *device, DWORD *vertex_remap_out,
            float *errors_by_face, struct ID3DXPMesh **clone_mesh) PURE;
    STDMETHOD(ReduceFaces)(THIS_ DWORD faces) PURE;
    STDMETHOD(ReduceVertices)(THIS_ DWORD vertices) PURE;
    STDMETHOD_(DWORD, GetMaxFaces)(THIS) PURE;
    STDMETHOD_(DWORD, GetMaxVertices)(THIS) PURE;
    STDMETHOD(GetVertexAttributeWeights)(THIS_ LPD3DXATTRIBUTEWEIGHTS vertex_attribute_weights) PURE;
    STDMETHOD(GetVertexWeights)(THIS_ FLOAT* vertex_weights) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXPatchMesh
DECLARE_INTERFACE_(ID3DXPatchMesh, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXPatchMesh ***/
    STDMETHOD_(DWORD, GetNumPatches)(THIS) PURE;
    STDMETHOD_(DWORD, GetNumVertices)(THIS) PURE;
    STDMETHOD(GetDeclaration)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
    STDMETHOD_(DWORD, GetControlVerticesPerPatch)(THIS) PURE;
    STDMETHOD_(DWORD, GetOptions)(THIS) PURE;
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(GetPatchInfo)(THIS_ LPD3DXPATCHINFO patch_info) PURE;
    STDMETHOD(GetVertexBuffer)(THIS_ struct IDirect3DVertexBuffer9 **vertex_buffer) PURE;
    STDMETHOD(GetIndexBuffer)(THIS_ struct IDirect3DIndexBuffer9 **index_buffer) PURE;
    STDMETHOD(LockVertexBuffer)(THIS_ DWORD flags, void **data) PURE;
    STDMETHOD(UnlockVertexBuffer)(THIS) PURE;
    STDMETHOD(LockIndexBuffer)(THIS_ DWORD flags, void **data) PURE;
    STDMETHOD(UnlockIndexBuffer)(THIS) PURE;
    STDMETHOD(LockAttributeBuffer)(THIS_ DWORD flags, DWORD** data) PURE;
    STDMETHOD(UnlockAttributeBuffer)(THIS) PURE;
    STDMETHOD(GetTessSize)(THIS_ FLOAT tess_level, DWORD adaptive, DWORD* num_triangles, DWORD* num_vertices) PURE;
    STDMETHOD(GenerateAdjacency)(THIS_ FLOAT tolerance) PURE;
    STDMETHOD(CloneMesh)(THIS_ DWORD options, const D3DVERTEXELEMENT9 *declaration, ID3DXPatchMesh **clone_mesh) PURE;
    STDMETHOD(Optimize)(THIS_ DWORD flags) PURE;
    STDMETHOD(SetDisplaceParam)(THIS_ struct IDirect3DBaseTexture9 *texture, D3DTEXTUREFILTERTYPE min_filter,
            D3DTEXTUREFILTERTYPE mag_filter, D3DTEXTUREFILTERTYPE mip_filter, D3DTEXTUREADDRESS wrap,
            DWORD lod_bias) PURE;
    STDMETHOD(GetDisplaceParam)(THIS_ struct IDirect3DBaseTexture9 **texture, D3DTEXTUREFILTERTYPE *min_filter,
            D3DTEXTUREFILTERTYPE *mag_filter, D3DTEXTUREFILTERTYPE *mip_filter, D3DTEXTUREADDRESS *wrap,
            DWORD *lod_bias) PURE;
    STDMETHOD(Tessellate)(THIS_ float tess_level, ID3DXMesh *mesh) PURE;
    STDMETHOD(TessellateAdaptive)(THIS_ const D3DXVECTOR4 *trans, DWORD max_tess_level,
            DWORD min_tess_level, ID3DXMesh *mesh) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXSkinInfo
DECLARE_INTERFACE_(ID3DXSkinInfo, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXSkinInfo ***/
    STDMETHOD(SetBoneInfluence)(THIS_ DWORD bone, DWORD num_influences, const DWORD *vertices,
            const FLOAT *weights) PURE;
    STDMETHOD(SetBoneVertexInfluence)(THIS_ DWORD bone_num, DWORD influence_num, float weight) PURE;
    STDMETHOD_(DWORD, GetNumBoneInfluences)(THIS_ DWORD bone) PURE;
    STDMETHOD(GetBoneInfluence)(THIS_ DWORD bone, DWORD* vertices, FLOAT* weights) PURE;
    STDMETHOD(GetBoneVertexInfluence)(THIS_ DWORD bone_num, DWORD influence_num, float *weight, DWORD* vertex_num) PURE;
    STDMETHOD(GetMaxVertexInfluences)(THIS_ DWORD* max_vertex_influences) PURE;
    STDMETHOD_(DWORD, GetNumBones)(THIS) PURE;
    STDMETHOD(FindBoneVertexInfluenceIndex)(THIS_ DWORD bone_num, DWORD vertex_num, DWORD* influence_index) PURE;
    STDMETHOD(GetMaxFaceInfluences)(THIS_ struct IDirect3DIndexBuffer9 *index_buffer,
            DWORD num_faces, DWORD *max_face_influences) PURE;
    STDMETHOD(SetMinBoneInfluence)(THIS_ FLOAT min_influence) PURE;
    STDMETHOD_(FLOAT, GetMinBoneInfluence)(THIS) PURE;
    STDMETHOD(SetBoneName)(THIS_ DWORD bone_idx, const char *name) PURE;
    STDMETHOD_(const char *, GetBoneName)(THIS_ DWORD bone_idx) PURE;
    STDMETHOD(SetBoneOffsetMatrix)(THIS_ DWORD bone, const D3DXMATRIX *bone_transform) PURE;
    STDMETHOD_(D3DXMATRIX *, GetBoneOffsetMatrix)(THIS_ DWORD bone) PURE;
    STDMETHOD(Clone)(THIS_ ID3DXSkinInfo **skin_info) PURE;
    STDMETHOD(Remap)(THIS_ DWORD num_vertices, DWORD* vertex_remap) PURE;
    STDMETHOD(SetFVF)(THIS_ DWORD FVF) PURE;
    STDMETHOD(SetDeclaration)(THIS_ const D3DVERTEXELEMENT9 *declaration) PURE;
    STDMETHOD_(DWORD, GetFVF)(THIS) PURE;
    STDMETHOD(GetDeclaration)(THIS_ D3DVERTEXELEMENT9 declaration[MAX_FVF_DECL_SIZE]) PURE;
    STDMETHOD(UpdateSkinnedMesh)(THIS_ const D3DXMATRIX *bone_transforms,
            const D3DXMATRIX *bone_inv_transpose_transforms, const void *src_vertices, void *dst_vertices) PURE;
    STDMETHOD(ConvertToBlendedMesh)(THIS_ ID3DXMesh *mesh_in, DWORD options, const DWORD *adjacency_in,
            DWORD *adjacency_out, DWORD *face_remap, ID3DXBuffer **vertex_remap, DWORD *max_face_infl,
            DWORD *num_bone_combinations, ID3DXBuffer **bone_combination_table, ID3DXMesh **mesh_out) PURE;
    STDMETHOD(ConvertToIndexedBlendedMesh)(THIS_ ID3DXMesh *mesh_in, DWORD options, DWORD palette_size,
            const DWORD *adjacency_in, DWORD *adjacency_out, DWORD *face_remap, ID3DXBuffer **vertex_remap,
            DWORD *max_face_infl, DWORD *num_bone_combinations, ID3DXBuffer **bone_combination_table,
            ID3DXMesh **mesh_out) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXPRTBuffer
DECLARE_INTERFACE_(ID3DXPRTBuffer, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXPRTBuffer methods ***/
    STDMETHOD_(UINT, GetNumSamples)(THIS) PURE;
    STDMETHOD_(UINT, GetNumCoeffs)(THIS) PURE;
    STDMETHOD_(UINT, GetNumChannels)(THIS) PURE;
    STDMETHOD_(WINBOOL, IsTexture)(THIS) PURE;
    STDMETHOD_(WINBOOL, GetWidth)(THIS) PURE;
    STDMETHOD_(WINBOOL, GetHeight)(THIS) PURE;
    STDMETHOD(Resize)(THIS_ UINT new_size) PURE;
    STDMETHOD(LockBuffer)(THIS_ UINT start, UINT num_samples, FLOAT **data) PURE;
    STDMETHOD(UnlockBuffer)(THIS) PURE;
    STDMETHOD(ScaleBuffer)(THIS_ FLOAT scale) PURE;
    STDMETHOD(AddBuffer)(THIS_ ID3DXPRTBuffer *buffer) PURE;
    STDMETHOD(AttachGH)(THIS_ struct ID3DXTextureGutterHelper *gh) PURE;
    STDMETHOD(ReleaseGH)(THIS) PURE;
    STDMETHOD(EvalGH)(THIS) PURE;
    STDMETHOD(ExtractTexture)(THIS_ UINT channel, UINT start_coefficient,
        UINT num_coefficients, struct IDirect3DTexture9 *texture) PURE;
    STDMETHOD(ExtractToMesh)(THIS_ UINT num_coefficients, D3DDECLUSAGE usage,
            UINT usage_index_start, ID3DXMesh *scene) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXPRTCompBuffer
DECLARE_INTERFACE_(ID3DXPRTCompBuffer, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXPRTCompBuffer methods ***/
    STDMETHOD_(UINT, GetNumSamples)(THIS) PURE;
    STDMETHOD_(UINT, GetNumCoeffs)(THIS) PURE;
    STDMETHOD_(UINT, GetNumChannels)(THIS) PURE;
    STDMETHOD_(WINBOOL, IsTexture)(THIS) PURE;
    STDMETHOD_(UINT, GetWidth)(THIS) PURE;
    STDMETHOD_(UINT, GetHeight)(THIS) PURE;
    STDMETHOD_(UINT, GetNumClusters)(THIS) PURE;
    STDMETHOD_(UINT, GetNumPCA)(THIS) PURE;
    STDMETHOD(NormalizeData)(THIS) PURE;
    STDMETHOD(ExtractBasis)(THIS_ UINT cluster, FLOAT *cluster_basis) PURE;
    STDMETHOD(ExtractClusterIDs)(THIS_ UINT *cluster_ids) PURE;
    STDMETHOD(ExtractPCA)(THIS_ UINT start_pca, UINT num_extract, FLOAT *pca_coefficients) PURE;
    STDMETHOD(ExtractTexture)(THIS_ UINT start_pca, UINT num_pca, struct IDirect3DTexture9 *texture) PURE;
    STDMETHOD(ExtractToMesh)(THIS_ UINT num_pca, D3DDECLUSAGE usage, UINT usage_index_start, ID3DXMesh *scene) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXTextureGutterHelper
DECLARE_INTERFACE_(ID3DXTextureGutterHelper, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXTextureGutterHelper methods ***/
    STDMETHOD_(UINT, GetWidth)(THIS) PURE;
    STDMETHOD_(UINT, GetHeight)(THIS) PURE;

    STDMETHOD(ApplyGuttersFloat)(THIS_ FLOAT *data_in, UINT num_coeffs, UINT width, UINT height) PURE;
    STDMETHOD(ApplyGuttersTex)(THIS_ struct IDirect3DTexture9 *texture) PURE;
    STDMETHOD(ApplyGuttersPRT)(THIS_ ID3DXPRTBuffer *buffer) PURE;
    STDMETHOD(ResampleTex)(THIS_ struct IDirect3DTexture9 *texture_in, struct ID3DXMesh *mesh_in,
        D3DDECLUSAGE usage, UINT usage_index, struct IDirect3DTexture9 *texture_out) PURE;
    STDMETHOD(GetFaceMap)(THIS_ UINT *face_data) PURE;
    STDMETHOD(GetBaryMap)(THIS_ D3DXVECTOR2 *bary_data) PURE;
    STDMETHOD(GetTexelMap)(THIS_ D3DXVECTOR2 *texel_data) PURE;
    STDMETHOD(GetGutterMap)(THIS_ BYTE *gutter_data) PURE;
    STDMETHOD(SetFaceMap)(THIS_ UINT *face_data) PURE;
    STDMETHOD(SetBaryMap)(THIS_ D3DXVECTOR2 *bary_data) PURE;
    STDMETHOD(SetTexelMap)(THIS_ D3DXVECTOR2 *texel_data) PURE;
    STDMETHOD(SetGutterMap)(THIS_ BYTE *gutter_data) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXPRTEngine
DECLARE_INTERFACE_(ID3DXPRTEngine, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXPRTEngine methods ***/
    STDMETHOD(SetMeshMaterials)(THIS_ const D3DXSHMATERIAL **materials, UINT num_meshes,
        UINT num_channels, WINBOOL set_albedo, FLOAT length_scale) PURE;
    STDMETHOD(SetPerVertexAlbedo)(THIS_ const void *data_in, UINT num_channels, UINT stride) PURE;
    STDMETHOD(SetPerTexelAlbedo)(THIS_ struct IDirect3DTexture9 *albedo_texture,
            UINT num_channels, struct ID3DXTextureGutterHelper *gh) PURE;
    STDMETHOD(GetVertexAlbedo)(THIS_ D3DXCOLOR *vert_colors, UINT num_verts) PURE;
    STDMETHOD(SetPerTexelNormals)(THIS_ struct IDirect3DTexture9 *normal_texture) PURE;
    STDMETHOD(ExtractPerVertexAlbedo)(THIS_ ID3DXMesh *mesh, D3DDECLUSAGE usage, UINT num_channels) PURE;
    STDMETHOD(ResampleBuffer)(THIS_ ID3DXPRTBuffer *buffer_in, ID3DXPRTBuffer *buffer_out) PURE;
    STDMETHOD(GetAdaptedMesh)(THIS_ struct IDirect3DDevice9 *device, UINT *face_remap,
            UINT *vert_remap, float *vert_weights, struct ID3DXMesh **mesh) PURE;
    STDMETHOD_(UINT, GetNumVerts)(THIS) PURE;
    STDMETHOD_(UINT, GetNumFaces)(THIS) PURE;
    STDMETHOD(SetMinMaxIntersection)(THIS_ FLOAT min, FLOAT max) PURE;
    STDMETHOD(RobustMeshRefine)(THIS_ FLOAT min_edge_length, UINT max_subdiv) PURE;
    STDMETHOD(SetSamplingInfo)(THIS_ UINT num_rays, WINBOOL use_sphere,
        WINBOOL use_cosine, WINBOOL adaptive, FLOAT adpative_thresh) PURE;
    STDMETHOD(ComputeDirectLightingSH)(THIS_ UINT sh_order, ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(ComputeDirectLightingSHAdaptive)(THIS_ UINT sh_order, float adaptive_thresh,
            float min_edge_length, UINT max_subdiv, ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(ComputeDirectLightingSHGPU)(THIS_ struct IDirect3DDevice9 *device, UINT flags,
            UINT sh_order, float zbias, float zangle_bias, struct ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(ComputeSS)(THIS_ ID3DXPRTBuffer *data_in, ID3DXPRTBuffer *data_out,
            ID3DXPRTBuffer *data_total) PURE;
    STDMETHOD(ComputeSSAdaptive)(THIS_ ID3DXPRTBuffer *data_in, float adaptive_thres,
            float min_edge_length, UINT max_subdiv, ID3DXPRTBuffer *data_out, ID3DXPRTBuffer *data_total) PURE;
    STDMETHOD(ComputeBounce)(THIS_ ID3DXPRTBuffer *data_in, ID3DXPRTBuffer *data_out,
            ID3DXPRTBuffer *data_total) PURE;
    STDMETHOD(ComputeBounceAdaptive)(THIS_ ID3DXPRTBuffer *data_in, float adaptive_thres,
            float min_edge_length, UINT max_subdiv, ID3DXPRTBuffer *data_out, ID3DXPRTBuffer *data_total) PURE;
    STDMETHOD(ComputeVolumeSamplesDirectSH)(THIS_ UINT sh_order_in, UINT sh_order_out,
            UINT num_vol_samples, const D3DXVECTOR3 *sample_locs, ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(ComputeVolumeSamples)(THIS_ ID3DXPRTBuffer *surf_data_in, UINT sh_order,
            UINT num_vol_samples, const D3DXVECTOR3 *sample_locs, ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(ComputeSurfSamplesDirectSH)(THIS_ UINT sh_order, UINT num_samples,
            const D3DXVECTOR3 *sample_locs, const D3DXVECTOR3 *sample_norms, ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(ComputeSurfSamplesBounce)(THIS_ ID3DXPRTBuffer *surf_data_in, UINT num_samples,
            const D3DXVECTOR3 *sample_locs, const D3DXVECTOR3 *sample_norms, ID3DXPRTBuffer *data_out,
            ID3DXPRTBuffer *data_total) PURE;
    STDMETHOD(FreeSSData)(THIS) PURE;
    STDMETHOD(FreeBounceData)(THIS) PURE;
    STDMETHOD(ComputeLDPRTCoeffs)(THIS_ ID3DXPRTBuffer *data_in, UINT sh_order, D3DXVECTOR3 *norm_out,
            ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(ScaleMeshChunk)(THIS_ UINT mesh_chunk, float scale, ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(MultiplyAlbedo)(THIS_ ID3DXPRTBuffer *data_out) PURE;
    STDMETHOD(SetCallback)(THIS_ LPD3DXSHPRTSIMCB cb, float frequency, void *user_context) PURE;
    STDMETHOD_(WINBOOL, ShadowRayIntersects)(THIS_ const D3DXVECTOR3 *ray_pos,
            const D3DXVECTOR3 *ray_dir) PURE;
    STDMETHOD_(WINBOOL, ClosestRayIntersects)(THIS_ const D3DXVECTOR3 *ray_pos,
            const D3DXVECTOR3 *ray_dir, DWORD *face_index, FLOAT *u, FLOAT *v, FLOAT *dist) PURE;
};
#undef INTERFACE

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI D3DXCreateMesh(DWORD face_count, DWORD vertex_count, DWORD flags,
        const D3DVERTEXELEMENT9 *declaration, struct IDirect3DDevice9 *device, struct ID3DXMesh **mesh);
HRESULT WINAPI D3DXCreateMeshFVF(DWORD face_count, DWORD vertex_count, DWORD flags,
        DWORD fvf, struct IDirect3DDevice9 *device, struct ID3DXMesh **mesh);
HRESULT WINAPI D3DXCreateBuffer(DWORD size, ID3DXBuffer **buffer);
HRESULT WINAPI D3DXCreateSPMesh(ID3DXMesh *mesh, const DWORD *adjacency,
        const D3DXATTRIBUTEWEIGHTS *attribute_weights, const float *vertex_weights, ID3DXSPMesh **spmesh);
HRESULT WINAPI D3DXCreatePMeshFromStream(struct IStream *stream, DWORD flags, struct IDirect3DDevice9 *device,
        struct ID3DXBuffer **materials, struct ID3DXBuffer **effect_instances,
        DWORD *material_count, struct ID3DXPMesh **mesh);
HRESULT WINAPI D3DXCreateSkinInfo(DWORD vertex_count, const D3DVERTEXELEMENT9 *declaration,
        DWORD bone_count, ID3DXSkinInfo **skin_info);
HRESULT WINAPI D3DXCreateSkinInfoFVF(DWORD vertex_count, DWORD fvf, DWORD bone_count, ID3DXSkinInfo **skin_info);
HRESULT WINAPI D3DXCreateSkinInfoFromBlendedMesh(ID3DXBaseMesh *mesh, DWORD bone_count,
        const D3DXBONECOMBINATION *bone_combination_table, ID3DXSkinInfo **skin_info);
HRESULT WINAPI D3DXCreatePatchMesh(const D3DXPATCHINFO *patch_info, DWORD patch_count,
        DWORD vertex_count, DWORD flags, const D3DVERTEXELEMENT9 *declaration,
        struct IDirect3DDevice9 *device, struct ID3DXPatchMesh **mesh);
HRESULT WINAPI D3DXCreatePRTBuffer(UINT sample_count, UINT coeff_count, UINT channel_count, ID3DXPRTBuffer **buffer);
HRESULT WINAPI D3DXCreatePRTBufferTex(UINT width, UINT height, UINT coeff_count,
        UINT channel_count, ID3DXPRTBuffer **buffer);
HRESULT WINAPI D3DXCreatePRTCompBuffer(D3DXSHCOMPRESSQUALITYTYPE quality, UINT cluster_count, UINT pca_count,
        LPD3DXSHPRTSIMCB cb, void *ctx, ID3DXPRTBuffer *input, ID3DXPRTCompBuffer **buffer);
HRESULT WINAPI D3DXCreateTextureGutterHelper(UINT width, UINT height, ID3DXMesh *mesh,
        float gutter_size, ID3DXTextureGutterHelper **gh);
HRESULT WINAPI D3DXCreatePRTEngine(ID3DXMesh *mesh, DWORD *adjacency, WINBOOL extract_uv,
        ID3DXMesh *blocker_mesh, ID3DXPRTEngine **engine);
HRESULT WINAPI D3DXLoadMeshFromXA(const char *filename, DWORD flags, struct IDirect3DDevice9 *device,
        struct ID3DXBuffer **adjacency, struct ID3DXBuffer **materials, struct ID3DXBuffer **effect_instances,
        DWORD *material_count, struct ID3DXMesh **mesh);
HRESULT WINAPI D3DXLoadMeshFromXW(const WCHAR *filename, DWORD flags, struct IDirect3DDevice9 *device,
        struct ID3DXBuffer **adjacency, struct ID3DXBuffer **materials, struct ID3DXBuffer **effect_instances,
        DWORD *material_count, struct ID3DXMesh **mesh);
#define D3DXLoadMeshFromX __MINGW_NAME_AW(D3DXLoadMeshFromX)
HRESULT WINAPI D3DXLoadMeshFromXInMemory(const void *data, DWORD data_size, DWORD flags,
        struct IDirect3DDevice9 *device, struct ID3DXBuffer **adjacency, struct ID3DXBuffer **materials,
        struct ID3DXBuffer **effect_instances, DWORD *material_count, struct ID3DXMesh **mesh);
HRESULT WINAPI D3DXLoadMeshFromXResource(HMODULE module, const char *resource, const char *resource_type,
        DWORD flags, struct IDirect3DDevice9 *device, struct ID3DXBuffer **adjacency,
        struct ID3DXBuffer **materials, struct ID3DXBuffer **effect_instances,
        DWORD *material_count, struct ID3DXMesh **mesh);
HRESULT WINAPI D3DXLoadMeshFromXof(struct ID3DXFileData *file_data, DWORD flags, struct IDirect3DDevice9 *device,
        struct ID3DXBuffer **adjacency, struct ID3DXBuffer **materials, struct ID3DXBuffer **effect_instances,
        DWORD *material_count, struct ID3DXMesh **mesh);
HRESULT WINAPI D3DXLoadPatchMeshFromXof(struct ID3DXFileData *file_data, DWORD flags, struct IDirect3DDevice9 *device,
        struct ID3DXBuffer **adjacency, struct ID3DXBuffer **materials, struct ID3DXBuffer **effect_instances,
        DWORD *material_count, struct ID3DXPatchMesh **mesh);
HRESULT WINAPI D3DXLoadSkinMeshFromXof(struct ID3DXFileData *file_data, DWORD flags, struct IDirect3DDevice9 *device,
        struct ID3DXBuffer **adjacency, struct ID3DXBuffer **materials, struct ID3DXBuffer **effect_instances,
        DWORD *material_count, struct ID3DXSkinInfo **skin_info, struct ID3DXMesh **mesh);
HRESULT WINAPI D3DXLoadPRTBufferFromFileA(const char *filename, ID3DXPRTBuffer **buffer);
HRESULT WINAPI D3DXLoadPRTBufferFromFileW(const WCHAR *filename, ID3DXPRTBuffer **buffer);
#define D3DXLoadPRTBufferFromFile __MINGW_NAME_AW(D3DXLoadPRTBufferFromFile)
HRESULT WINAPI D3DXLoadPRTCompBufferFromFileA(const char *filename, ID3DXPRTCompBuffer **buffer);
HRESULT WINAPI D3DXLoadPRTCompBufferFromFileW(const WCHAR *filename, ID3DXPRTCompBuffer **buffer);
#define D3DXLoadPRTCompBufferFromFile __MINGW_NAME_AW(D3DXLoadPRTCompBufferFromFile)
HRESULT WINAPI D3DXSaveMeshToXA(const char *filename, ID3DXMesh *mesh, const DWORD *adjacency,
        const D3DXMATERIAL *materials, const D3DXEFFECTINSTANCE *effect_instances, DWORD material_count, DWORD format);
HRESULT WINAPI D3DXSaveMeshToXW(const WCHAR *filename, ID3DXMesh *mesh, const DWORD *adjacency,
        const D3DXMATERIAL *materials, const D3DXEFFECTINSTANCE *effect_instances, DWORD material_count, DWORD format);
#define D3DXSaveMeshToX __MINGW_NAME_AW(D3DXSaveMeshToX)
HRESULT WINAPI D3DXSavePRTBufferToFileA(const char *filename, ID3DXPRTBuffer *buffer);
HRESULT WINAPI D3DXSavePRTBufferToFileW(const WCHAR *filename, ID3DXPRTBuffer *buffer);
#define D3DXSavePRTBufferToFile __MINGW_NAME_AW(D3DXSavePRTBufferToFile)
HRESULT WINAPI D3DXSavePRTCompBufferToFileA(const char *filename, ID3DXPRTCompBuffer *buffer);
HRESULT WINAPI D3DXSavePRTCompBufferToFileW(const WCHAR *filename, ID3DXPRTCompBuffer *buffer);
#define D3DXSavePRTCompBufferToFile __MINGW_NAME_AW(D3DXSavePRTCompBufferToFile)
UINT    WINAPI D3DXGetDeclLength(const D3DVERTEXELEMENT9 *decl);
UINT    WINAPI D3DXGetDeclVertexSize(const D3DVERTEXELEMENT9 *decl, DWORD stream_idx);
UINT    WINAPI D3DXGetFVFVertexSize(DWORD);
WINBOOL WINAPI D3DXBoxBoundProbe(const D3DXVECTOR3 *vmin, const D3DXVECTOR3 *vmax,
        const D3DXVECTOR3 *ray_pos, const D3DXVECTOR3 *ray_dir);
WINBOOL WINAPI D3DXSphereBoundProbe(const D3DXVECTOR3 *center, FLOAT radius,
        const D3DXVECTOR3 *ray_pos, const D3DXVECTOR3 *ray_dir);
HRESULT WINAPI D3DXCleanMesh(D3DXCLEANTYPE clean_type, ID3DXMesh *mesh_in, const DWORD *adjacency_in,
        ID3DXMesh **mesh_out, DWORD *adjacency_out, ID3DXBuffer **errors);
HRESULT WINAPI D3DXConcatenateMeshes(struct ID3DXMesh **meshes, UINT mesh_count, DWORD flags,
        const D3DXMATRIX *geometry_matrices, const D3DXMATRIX *texture_matrices,
        const D3DVERTEXELEMENT9 *declaration, struct IDirect3DDevice9 *device, struct ID3DXMesh **mesh);
HRESULT WINAPI D3DXComputeBoundingBox(const D3DXVECTOR3 *first_pos, DWORD num_vertices,
        DWORD stride, D3DXVECTOR3 *vmin, D3DXVECTOR3 *vmax);
HRESULT WINAPI D3DXComputeBoundingSphere(const D3DXVECTOR3 *first_pos, DWORD num_vertices,
        DWORD stride, D3DXVECTOR3 *center, FLOAT *radius);
HRESULT WINAPI D3DXComputeIMTFromPerTexelSignal(ID3DXMesh *mesh, DWORD texture_idx, float *texel_signal,
        UINT width, UINT height, UINT signal_dimension, UINT component_count, DWORD flags,
        LPD3DXUVATLASCB cb, void *ctx, ID3DXBuffer **buffer);
HRESULT WINAPI D3DXComputeIMTFromPerVertexSignal(ID3DXMesh *mesh, const float *vertex_signal,
        UINT signal_dimension, UINT signal_stride, DWORD flags,
        LPD3DXUVATLASCB cb, void *ctx, ID3DXBuffer **buffer);
HRESULT WINAPI D3DXComputeIMTFromSignal(ID3DXMesh *mesh, DWORD texture_idx, UINT signal_dimension,
        float max_uv_distance, DWORD flags, LPD3DXIMTSIGNALCALLBACK signal_cb, void *signal_ctx,
        LPD3DXUVATLASCB status_cb, void *status_ctx, ID3DXBuffer **buffer);
HRESULT WINAPI D3DXComputeIMTFromTexture(struct ID3DXMesh *mesh, struct IDirect3DTexture9 *texture,
        DWORD texture_idx, DWORD options, LPD3DXUVATLASCB cb, void *ctx, struct ID3DXBuffer **out);
HRESULT WINAPI D3DXComputeNormals(ID3DXBaseMesh *mesh, const DWORD *adjacency);
HRESULT WINAPI D3DXComputeTangentFrameEx(ID3DXMesh *mesh_in, DWORD texture_in_semantic, DWORD texture_in_idx,
        DWORD u_partial_out_semantic, DWORD u_partial_out_idx, DWORD v_partial_out_semantic,
        DWORD v_partial_out_idx, DWORD normal_out_semantic, DWORD normal_out_idx, DWORD flags,
        const DWORD *adjacency, float partial_edge_threshold, float singular_point_threshold,
        float normal_edge_threshold, ID3DXMesh **mesh_out, ID3DXBuffer **buffer);
HRESULT WINAPI D3DXComputeTangent(ID3DXMesh *mesh, DWORD stage, DWORD tangent_idx,
        DWORD binorm_idx, DWORD wrap, const DWORD *adjacency);
HRESULT WINAPI D3DXConvertMeshSubsetToSingleStrip(struct ID3DXBaseMesh *mesh_in, DWORD attribute_id,
        DWORD ib_flags, struct IDirect3DIndexBuffer9 **index_buffer, DWORD *index_count);
HRESULT WINAPI D3DXConvertMeshSubsetToStrips(struct ID3DXBaseMesh *mesh_in, DWORD attribute_id,
        DWORD ib_flags, struct IDirect3DIndexBuffer9 **index_buffer, DWORD *index_count,
        struct ID3DXBuffer **strip_lengths, DWORD *strip_count);
HRESULT WINAPI D3DXDeclaratorFromFVF(DWORD, D3DVERTEXELEMENT9[MAX_FVF_DECL_SIZE]);
HRESULT WINAPI D3DXFVFFromDeclarator(const D3DVERTEXELEMENT9 *decl, DWORD *fvf);
HRESULT WINAPI D3DXGenerateOutputDecl(D3DVERTEXELEMENT9 *decl_out, const D3DVERTEXELEMENT9 *decl_in);
HRESULT WINAPI D3DXGeneratePMesh(ID3DXMesh *mesh, const DWORD *adjacency,
        const D3DXATTRIBUTEWEIGHTS *attribute_weights, const float *vertex_weights,
        DWORD min_value, DWORD flags, ID3DXPMesh **pmesh);
HRESULT WINAPI D3DXIntersect(ID3DXBaseMesh *mesh, const D3DXVECTOR3 *ray_position, const D3DXVECTOR3 *ray_direction,
        WINBOOL *hit, DWORD *face_idx, float *u, float *v, float *distance, ID3DXBuffer **hits, DWORD *hit_count);
HRESULT WINAPI D3DXIntersectSubset(ID3DXBaseMesh *mesh, DWORD attribute_id, const D3DXVECTOR3 *ray_position,
        const D3DXVECTOR3 *ray_direction, WINBOOL *hit, DWORD *face_idx, float *u, float *v, float *distance,
        ID3DXBuffer **hits, DWORD *hit_count);
WINBOOL WINAPI D3DXIntersectTri(const D3DXVECTOR3 *vtx0, const D3DXVECTOR3 *vtx1,
        const D3DXVECTOR3 *vtx2, const D3DXVECTOR3 *ray_pos, const D3DXVECTOR3 *ray_dir, FLOAT *u,
        FLOAT *v, FLOAT *dist);
HRESULT WINAPI D3DXOptimizeFaces(const void *indices, UINT face_count,
        UINT vertex_count, WINBOOL idx_32bit, DWORD *face_remap);
HRESULT WINAPI D3DXOptimizeVertices(const void *indices, UINT face_count,
        UINT vertex_count, WINBOOL idx_32bit, DWORD *vertex_remap);
HRESULT WINAPI D3DXRectPatchSize(const FLOAT *segment_count, DWORD *num_triangles,
        DWORD *num_vertices);
HRESULT WINAPI D3DXSHPRTCompSuperCluster(UINT *cluster_ids, ID3DXMesh *scene, UINT max_cluster_count,
        UINT cluster_count, UINT *scluster_ids, UINT *scluster_count);
HRESULT WINAPI D3DXSHPRTCompSplitMeshSC(UINT *cluster_idx, UINT vertex_count, UINT cluster_count, UINT *scluster_ids,
        UINT scluster_count, void *index_buffer_in, WINBOOL ib_in_32bit, UINT face_count, ID3DXBuffer **index_buffer_out,
        UINT *index_buffer_size, WINBOOL ib_out_32bit, ID3DXBuffer **face_remap, ID3DXBuffer **vertex_data,
        UINT *vertex_data_length, UINT *sc_cluster_list, D3DXSHPRTSPLITMESHCLUSTERDATA *sc_data);
HRESULT WINAPI D3DXSimplifyMesh(ID3DXMesh *mesh_in, const DWORD *adjacency,
        const D3DXATTRIBUTEWEIGHTS *attribute_weights, const float *vertex_weights, DWORD min_value,
        DWORD flags, ID3DXMesh **mesh_out);
HRESULT WINAPI D3DXSplitMesh(ID3DXMesh *mesh_in, const DWORD *adjacency_in, const DWORD max_size,
        const DWORD flags, DWORD *mesh_out_count, ID3DXBuffer **mesh_out, ID3DXBuffer **adjacency_out,
        ID3DXBuffer **face_remap_out, ID3DXBuffer **vertex_remap_out);
HRESULT WINAPI D3DXTessellateNPatches(ID3DXMesh *mesh_in, const DWORD *adjacency_in, float segment_count,
        WINBOOL quad_interp, ID3DXMesh **mesh_out, ID3DXBuffer **adjacency_out);
HRESULT WINAPI D3DXTessellateRectPatch(struct IDirect3DVertexBuffer9 *buffer, const float *segment_count,
        const D3DVERTEXELEMENT9 *declaration, const D3DRECTPATCH_INFO *patch_info, struct ID3DXMesh *mesh);
HRESULT WINAPI D3DXTessellateTriPatch(struct IDirect3DVertexBuffer9 *buffer, const float *segment_count,
        const D3DVERTEXELEMENT9 *declaration, const D3DTRIPATCH_INFO *patch_info, struct ID3DXMesh *mesh);
HRESULT WINAPI D3DXTriPatchSize(const FLOAT *segment_count, DWORD *num_triangles,
        DWORD *num_vertices);
HRESULT WINAPI D3DXUVAtlasCreate(ID3DXMesh *mesh_in, UINT max_chart_count, float max_stretch_in,
        UINT width, UINT height, float gutter, DWORD texture_idx, const DWORD *adjacency, const DWORD *false_edges,
        const float *imt_array, LPD3DXUVATLASCB cb, float cb_freq, void *ctx, DWORD flags, ID3DXMesh **mesh_out,
        ID3DXBuffer **face_partitioning_out, ID3DXBuffer **vertex_remap_out, float *max_stretch_out, UINT *chart_count);
HRESULT WINAPI D3DXUVAtlasPack(ID3DXMesh *mesh, UINT width, UINT height, float gutter, DWORD texture_idx,
        const DWORD *partition_result_adjacency, LPD3DXUVATLASCB cb, float cb_freq, void *ctx, DWORD flags,
        ID3DXBuffer *face_partitioning);
HRESULT WINAPI D3DXUVAtlasPartition(ID3DXMesh *mesh_in, UINT max_chart_count, float max_stretch_in,
        DWORD texture_idx, const DWORD *adjacency, const DWORD *false_edges, const float *imt_array,
        LPD3DXUVATLASCB cb, float cb_freq, void *ctx, DWORD flags, ID3DXMesh **mesh_out,
        ID3DXBuffer **face_partitioning_out, ID3DXBuffer **vertex_remap_out, ID3DXBuffer **adjacency_out,
        float *max_stretch_out, UINT *chart_count);
HRESULT WINAPI D3DXValidMesh(ID3DXMesh *mesh, const DWORD *adjacency, ID3DXBuffer **errors);
HRESULT WINAPI D3DXValidPatchMesh(ID3DXPatchMesh *mesh, DWORD *degenerate_vertex_count,
        DWORD *degenerate_patch_count, ID3DXBuffer **errors);
HRESULT WINAPI D3DXWeldVertices(ID3DXMesh *mesh, DWORD flags, const D3DXWELDEPSILONS *epsilons,
        const DWORD *adjacency_in, DWORD *adjacency_out, DWORD *face_remap_out, ID3DXBuffer **vertex_remap_out);

#ifdef __cplusplus
}
#endif

DEFINE_GUID(DXFILEOBJ_XSkinMeshHeader,          0x3cf169ce, 0xff7c, 0x44ab, 0x93, 0xc0, 0xf7, 0x8f, 0x62, 0xd1, 0x72, 0xe2);
DEFINE_GUID(DXFILEOBJ_VertexDuplicationIndices, 0xb8d65549, 0xd7c9, 0x4995, 0x89, 0xcf, 0x53, 0xa9, 0xa8, 0xb0, 0x31, 0xe3);
DEFINE_GUID(DXFILEOBJ_FaceAdjacency,            0xa64c844a, 0xe282, 0x4756, 0x8b, 0x80, 0x25, 0x0c, 0xde, 0x04, 0x39, 0x8c);
DEFINE_GUID(DXFILEOBJ_SkinWeights,              0x6f0d123b, 0xbad2, 0x4167, 0xa0, 0xd0, 0x80, 0x22, 0x4f, 0x25, 0xfa, 0xbb);
DEFINE_GUID(DXFILEOBJ_Patch,                    0xa3eb5d44, 0xfc22, 0x429d, 0x9a, 0xfb, 0x32, 0x21, 0xcb, 0x97, 0x19, 0xa6);
DEFINE_GUID(DXFILEOBJ_PatchMesh,                0xd02c95cc, 0xedba, 0x4305, 0x9b, 0x5d, 0x18, 0x20, 0xd7, 0x70, 0x4b, 0xbf);
DEFINE_GUID(DXFILEOBJ_PatchMesh9,               0xb9ec94e1, 0xb9a6, 0x4251, 0xba, 0x18, 0x94, 0x89, 0x3f, 0x02, 0xc0, 0xea);
DEFINE_GUID(DXFILEOBJ_PMInfo,                   0xb6c3e656, 0xec8b, 0x4b92, 0x9b, 0x62, 0x68, 0x16, 0x59, 0x52, 0x29, 0x47);
DEFINE_GUID(DXFILEOBJ_PMAttributeRange,         0x917e0427, 0xc61e, 0x4a14, 0x9c, 0x64, 0xaf, 0xe6, 0x5f, 0x9e, 0x98, 0x44);
DEFINE_GUID(DXFILEOBJ_PMVSplitRecord,           0x574ccc14, 0xf0b3, 0x4333, 0x82, 0x2d, 0x93, 0xe8, 0xa8, 0xa0, 0x8e, 0x4c);
DEFINE_GUID(DXFILEOBJ_FVFData,                  0xb6e70a0e, 0x8ef9, 0x4e83, 0x94, 0xad, 0xec, 0xc8, 0xb0, 0xc0, 0x48, 0x97);
DEFINE_GUID(DXFILEOBJ_VertexElement,            0xf752461c, 0x1e23, 0x48f6, 0xb9, 0xf8, 0x83, 0x50, 0x85, 0x0f, 0x33, 0x6f);
DEFINE_GUID(DXFILEOBJ_DeclData,                 0xbf22e553, 0x292c, 0x4781, 0x9f, 0xea, 0x62, 0xbd, 0x55, 0x4b, 0xdd, 0x93);
DEFINE_GUID(DXFILEOBJ_EffectFloats,             0xf1cfe2b3, 0x0de3, 0x4e28, 0xaf, 0xa1, 0x15, 0x5a, 0x75, 0x0a, 0x28, 0x2d);
DEFINE_GUID(DXFILEOBJ_EffectString,             0xd55b097e, 0xbdb6, 0x4c52, 0xb0, 0x3d, 0x60, 0x51, 0xc8, 0x9d, 0x0e, 0x42);
DEFINE_GUID(DXFILEOBJ_EffectDWord,              0x622c0ed0, 0x956e, 0x4da9, 0x90, 0x8a, 0x2a, 0xf9, 0x4f, 0x3c, 0xe7, 0x16);
DEFINE_GUID(DXFILEOBJ_EffectParamFloats,        0x3014b9a0, 0x62f5, 0x478c, 0x9b, 0x86, 0xe4, 0xac, 0x9f, 0x4e, 0x41, 0x8b);
DEFINE_GUID(DXFILEOBJ_EffectParamString,        0x1dbc4c88, 0x94c1, 0x46ee, 0x90, 0x76, 0x2c, 0x28, 0x81, 0x8c, 0x94, 0x81);
DEFINE_GUID(DXFILEOBJ_EffectParamDWord,         0xe13963bc, 0xae51, 0x4c5d, 0xb0, 0x0f, 0xcf, 0xa3, 0xa9, 0xd9, 0x7c, 0xe5);
DEFINE_GUID(DXFILEOBJ_EffectInstance,           0xe331f7e4, 0x0559, 0x4cc2, 0x8e, 0x99, 0x1c, 0xec, 0x16, 0x57, 0x92, 0x8f);
DEFINE_GUID(DXFILEOBJ_AnimTicksPerSecond,       0x9e415a43, 0x7ba6, 0x4a73, 0x87, 0x43, 0xb7, 0x3d, 0x47, 0xe8, 0x84, 0x76);
DEFINE_GUID(DXFILEOBJ_CompressedAnimationSet,   0x7f9b00b3, 0xf125, 0x4890, 0x87, 0x6e, 0x1c, 0x42, 0xbf, 0x69, 0x7c, 0x4d);

#define XSKINEXP_TEMPLATES \
        "xof 0303txt 0032\
        template XSkinMeshHeader \
        { \
            <3CF169CE-FF7C-44ab-93C0-F78F62D172E2> \
            WORD nMaxSkinWeightsPerVertex; \
            WORD nMaxSkinWeightsPerFace; \
            WORD nBones; \
        } \
        template VertexDuplicationIndices \
        { \
            <B8D65549-D7C9-4995-89CF-53A9A8B031E3> \
            DWORD nIndices; \
            DWORD nOriginalVertices; \
            array DWORD indices[nIndices]; \
        } \
        template FaceAdjacency \
        { \
            <A64C844A-E282-4756-8B80-250CDE04398C> \
            DWORD nIndices; \
            array DWORD indices[nIndices]; \
        } \
        template SkinWeights \
        { \
            <6F0D123B-BAD2-4167-A0D0-80224F25FABB> \
            STRING transformNodeName; \
            DWORD nWeights; \
            array DWORD vertexIndices[nWeights]; \
            array float weights[nWeights]; \
            Matrix4x4 matrixOffset; \
        } \
        template Patch \
        { \
            <A3EB5D44-FC22-429D-9AFB-3221CB9719A6> \
            DWORD nControlIndices; \
            array DWORD controlIndices[nControlIndices]; \
        } \
        template PatchMesh \
        { \
            <D02C95CC-EDBA-4305-9B5D-1820D7704BBF> \
            DWORD nVertices; \
            array Vector vertices[nVertices]; \
            DWORD nPatches; \
            array Patch patches[nPatches]; \
            [ ... ] \
        } \
        template PatchMesh9 \
        { \
            <B9EC94E1-B9A6-4251-BA18-94893F02C0EA> \
            DWORD Type; \
            DWORD Degree; \
            DWORD Basis; \
            DWORD nVertices; \
            array Vector vertices[nVertices]; \
            DWORD nPatches; \
            array Patch patches[nPatches]; \
            [ ... ] \
        } template EffectFloats \
        { \
            <F1CFE2B3-0DE3-4e28-AFA1-155A750A282D> \
            DWORD nFloats; \
            array float Floats[nFloats]; \
        } \
        template EffectString \
        { \
            <D55B097E-BDB6-4c52-B03D-6051C89D0E42> \
            STRING Value; \
        } \
        template EffectDWord \
        { \
            <622C0ED0-956E-4da9-908A-2AF94F3CE716> \
            DWORD Value; \
        } template EffectParamFloats \
        { \
            <3014B9A0-62F5-478c-9B86-E4AC9F4E418B> \
            STRING ParamName; \
            DWORD nFloats; \
            array float Floats[nFloats]; \
        } template EffectParamString \
        { \
            <1DBC4C88-94C1-46ee-9076-2C28818C9481> \
            STRING ParamName; \
            STRING Value; \
        } \
        template EffectParamDWord \
        { \
            <E13963BC-AE51-4c5d-B00F-CFA3A9D97CE5> \
            STRING ParamName; \
            DWORD Value; \
        } \
        template EffectInstance \
        { \
            <E331F7E4-0559-4cc2-8E99-1CEC1657928F> \
            STRING EffectFilename; \
            [ ... ] \
        } template AnimTicksPerSecond \
        { \
            <9E415A43-7BA6-4a73-8743-B73D47E88476> \
            DWORD AnimTicksPerSecond; \
        } \
        template CompressedAnimationSet \
        { \
            <7F9B00B3-F125-4890-876E-1C42BF697C4D> \
            DWORD CompressedBlockSize; \
            FLOAT TicksPerSec; \
            DWORD PlaybackType; \
            DWORD BufferLength; \
            array DWORD CompressedData[BufferLength]; \
        } "

#define XEXTENSIONS_TEMPLATES \
        "xof 0303txt 0032\
        template FVFData \
        { \
            <B6E70A0E-8EF9-4e83-94AD-ECC8B0C04897> \
            DWORD dwFVF; \
            DWORD nDWords; \
            array DWORD data[nDWords]; \
        } \
        template VertexElement \
        { \
            <F752461C-1E23-48f6-B9F8-8350850F336F> \
            DWORD Type; \
            DWORD Method; \
            DWORD Usage; \
            DWORD UsageIndex; \
        } \
        template DeclData \
        { \
            <BF22E553-292C-4781-9FEA-62BD554BDD93> \
            DWORD nElements; \
            array VertexElement Elements[nElements]; \
            DWORD nDWords; \
            array DWORD data[nDWords]; \
        } \
        template PMAttributeRange \
        { \
            <917E0427-C61E-4a14-9C64-AFE65F9E9844> \
            DWORD iFaceOffset; \
            DWORD nFacesMin; \
            DWORD nFacesMax; \
            DWORD iVertexOffset; \
            DWORD nVerticesMin; \
            DWORD nVerticesMax; \
        } \
        template PMVSplitRecord \
        { \
            <574CCC14-F0B3-4333-822D-93E8A8A08E4C> \
            DWORD iFaceCLW; \
            DWORD iVlrOffset; \
            DWORD iCode; \
        } \
        template PMInfo \
        { \
            <B6C3E656-EC8B-4b92-9B62-681659522947> \
            DWORD nAttributes; \
            array PMAttributeRange attributeRanges[nAttributes]; \
            DWORD nMaxValence; \
            DWORD nMinLogicalVertices; \
            DWORD nMaxLogicalVertices; \
            DWORD nVSplits; \
            array PMVSplitRecord splitRecords[nVSplits]; \
            DWORD nAttributeMispredicts; \
            array DWORD attributeMispredicts[nAttributeMispredicts]; \
        } "

#endif /* __WINE_D3DX9MESH_H */
