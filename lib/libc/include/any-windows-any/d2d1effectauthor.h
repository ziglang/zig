/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_EFFECT_AUTHOR_H_
#define _D2D1_EFFECT_AUTHOR_H_

#include <d2d1_1.h>

typedef HRESULT (CALLBACK *PD2D1_PROPERTY_SET_FUNCTION)(IUnknown*,const BYTE*,UINT32);
typedef HRESULT (CALLBACK *PD2D1_PROPERTY_GET_FUNCTION)(const IUnknown*,BYTE*,UINT32 dataSize,UINT32*);

typedef enum D2D1_BLEND_OPERATION {
    D2D1_BLEND_OPERATION_ADD          = 1,
    D2D1_BLEND_OPERATION_SUBTRACT     = 2,
    D2D1_BLEND_OPERATION_REV_SUBTRACT = 3,
    D2D1_BLEND_OPERATION_MIN          = 4,
    D2D1_BLEND_OPERATION_MAX          = 5,
    D2D1_BLEND_OPERATION_FORCE_DWORD = 0xffffffff
} D2D1_BLEND_OPERATION;

typedef enum D2D1_BLEND {
    D2D1_BLEND_ZERO             = 1,
    D2D1_BLEND_ONE              = 2,
    D2D1_BLEND_SRC_COLOR        = 3,
    D2D1_BLEND_INV_SRC_COLOR    = 4,
    D2D1_BLEND_SRC_ALPHA        = 5,
    D2D1_BLEND_INV_SRC_ALPHA    = 6,
    D2D1_BLEND_DEST_ALPHA       = 7,
    D2D1_BLEND_INV_DEST_ALPHA   = 8,
    D2D1_BLEND_DEST_COLOR       = 9,
    D2D1_BLEND_INV_DEST_COLOR   = 10,
    D2D1_BLEND_SRC_ALPHA_SAT    = 11,
    D2D1_BLEND_BLEND_FACTOR     = 14,
    D2D1_BLEND_INV_BLEND_FACTOR = 15,
    D2D1_BLEND_FORCE_DWORD = 0xffffffff
} D2D1_BLEND;

typedef enum D2D1_FILTER {
    D2D1_FILTER_MIN_MAG_MIP_POINT               = 0x00,
    D2D1_FILTER_MIN_MAG_POINT_MIP_LINEAR        = 0x01,
    D2D1_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT  = 0x04,
    D2D1_FILTER_MIN_POINT_MAG_MIP_LINEAR        = 0x05,
    D2D1_FILTER_MIN_LINEAR_MAG_MIP_POINT        = 0x10,
    D2D1_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR = 0x11,
    D2D1_FILTER_MIN_MAG_LINEAR_MIP_POINT        = 0x14,
    D2D1_FILTER_MIN_MAG_MIP_LINEAR              = 0x15,
    D2D1_FILTER_ANISOTROPIC                     = 0x55,
    D2D1_FILTER_FORCE_DWORD = 0xffffffff
} D2D1_FILTER;

typedef enum D2D1_VERTEX_USAGE {
    D2D1_VERTEX_USAGE_STATIC  = 0,
    D2D1_VERTEX_USAGE_DYNAMIC = 1,
    D2D1_VERTEX_USAGE_FORCE_DWORD = 0xffffffff
} D2D1_VERTEX_USAGE;

typedef enum D2D1_FEATURE {
    D2D1_FEATURE_DOUBLES                  = 0,
    D2D1_FEATURE_D3D10_X_HARDWARE_OPTIONS = 1,
    D2D1_FEATURE_FORCE_DWORD = 0xffffffff
} D2D1_FEATURE;

typedef enum D2D1_CHANGE_TYPE {
    D2D1_CHANGE_TYPE_NONE       = 0,
    D2D1_CHANGE_TYPE_PROPERTIES = 1,
    D2D1_CHANGE_TYPE_CONTEXT    = 2,
    D2D1_CHANGE_TYPE_GRAPH      = 3,
    D2D1_CHANGE_TYPE_FORCE_DWORD = 0xffffffff
} D2D1_CHANGE_TYPE;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_CHANGE_TYPE);

typedef enum D2D1_PIXEL_OPTIONS {
    D2D1_PIXEL_OPTIONS_NONE             = 0,
    D2D1_PIXEL_OPTIONS_TRIVIAL_SAMPLING = 1,
    D2D1_PIXEL_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_PIXEL_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_PIXEL_OPTIONS);

typedef enum D2D1_VERTEX_OPTIONS {
    D2D1_VERTEX_OPTIONS_NONE              = 0,
    D2D1_VERTEX_OPTIONS_DO_NOT_CLEAR      = 1,
    D2D1_VERTEX_OPTIONS_USE_DEPTH_BUFFER  = 2,
    D2D1_VERTEX_OPTIONS_ASSUME_NO_OVERLAP = 4,
    D2D1_VERTEX_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_VERTEX_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_VERTEX_OPTIONS);

typedef struct D2D1_BLEND_DESCRIPTION {
    D2D1_BLEND sourceBlend;
    D2D1_BLEND destinationBlend;
    D2D1_BLEND_OPERATION blendOperation;
    D2D1_BLEND sourceBlendAlpha;
    D2D1_BLEND destinationBlendAlpha;
    D2D1_BLEND_OPERATION blendOperationAlpha;
    FLOAT blendFactor[4];
} D2D1_BLEND_DESCRIPTION;

typedef struct D2D1_RESOURCE_TEXTURE_PROPERTIES {
    CONST UINT32 *extents;
    UINT32 dimensions;
    D2D1_BUFFER_PRECISION bufferPrecision;
    D2D1_CHANNEL_DEPTH channelDepth;
    D2D1_FILTER filter;
    CONST D2D1_EXTEND_MODE *extendModes;
} D2D1_RESOURCE_TEXTURE_PROPERTIES;

typedef struct D2D1_INPUT_ELEMENT_DESC {
    PCSTR semanticName;
    UINT32 semanticIndex;
    DXGI_FORMAT format;
    UINT32 inputSlot;
    UINT32 alignedByteOffset;
} D2D1_INPUT_ELEMENT_DESC;

typedef struct D2D1_VERTEX_BUFFER_PROPERTIES {
    UINT32 inputCount;
    D2D1_VERTEX_USAGE usage;
    CONST BYTE *data;
    UINT32 byteWidth;
} D2D1_VERTEX_BUFFER_PROPERTIES;

typedef struct D2D1_CUSTOM_VERTEX_BUFFER_PROPERTIES {
    CONST BYTE *shaderBufferWithInputSignature;
    UINT32 shaderBufferSize;
    CONST D2D1_INPUT_ELEMENT_DESC *inputElements;
    UINT32 elementCount;
    UINT32 stride;
} D2D1_CUSTOM_VERTEX_BUFFER_PROPERTIES;

typedef struct D2D1_INPUT_DESCRIPTION {
    D2D1_FILTER filter;
    UINT32 levelOfDetailCount;
} D2D1_INPUT_DESCRIPTION;

typedef struct D2D1_VERTEX_RANGE {
    UINT32 startVertex;
    UINT32 vertexCount;
} D2D1_VERTEX_RANGE;

typedef struct D2D1_PROPERTY_BINDING {
    PCWSTR propertyName;
    PD2D1_PROPERTY_SET_FUNCTION setFunction;
    PD2D1_PROPERTY_GET_FUNCTION getFunction;
} D2D1_PROPERTY_BINDING;

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1VertexBuffer : public IUnknown
{
    STDMETHOD(Map)(BYTE **data, UINT32 bufferSize) PURE;
    STDMETHOD(Unmap)() PURE;
};

#else

typedef interface ID2D1VertexBuffer ID2D1VertexBuffer;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1VertexBuffer, 0x9b8b1336,0x00a5,0x4668,0x92,0xb7,0xce,0xd5,0xd8,0xbf,0x9b,0x7b);
__CRT_UUID_DECL(ID2D1VertexBuffer, 0x9b8b1336,0x00a5,0x4668,0x92,0xb7,0xce,0xd5,0xd8,0xbf,0x9b,0x7b);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1ResourceTexture : public IUnknown
{
    STDMETHOD(Update)(CONST UINT32 *minimumExtents, CONST UINT32 *maximimumExtents,
            CONST UINT32 *strides, UINT32 dimensions, CONST BYTE *data, UINT32 dataCount) PURE;
};

#else

typedef interface ID2D1ResourceTexture ID2D1ResourceTexture;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1ResourceTexture, 0x688d15c3,0x02b0,0x438d,0xb1,0x3a,0xd1,0xb4,0x4c,0x32,0xc3,0x9a);
__CRT_UUID_DECL(ID2D1ResourceTexture, 0x688d15c3,0x02b0,0x438d,0xb1,0x3a,0xd1,0xb4,0x4c,0x32,0xc3,0x9a);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1RenderInfo : public IUnknown
{
    STDMETHOD(SetInputDescription)(UINT32 inputIndex, D2D1_INPUT_DESCRIPTION inputDescription) PURE;
    STDMETHOD(SetOutputBuffer)(D2D1_BUFFER_PRECISION bufferPrecision, D2D1_CHANNEL_DEPTH channelDepth) PURE;
    STDMETHOD_(void, SetCached)(BOOL isCached) PURE;
    STDMETHOD_(void, SetInstructionCountHint)(UINT32 instructionCount) PURE;
};

#else

typedef interface ID2D1RenderInfo ID2D1RenderInfo;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1RenderInfo, 0x519ae1bd,0xd19a,0x420d,0xb8,0x49,0x36,0x4f,0x59,0x47,0x76,0xb7);
__CRT_UUID_DECL(ID2D1RenderInfo, 0x519ae1bd,0xd19a,0x420d,0xb8,0x49,0x36,0x4f,0x59,0x47,0x76,0xb7);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1DrawInfo : public ID2D1RenderInfo
{
    STDMETHOD(SetPixelShaderConstantBuffer)(CONST BYTE *buffer, UINT32 bufferCount) PURE;
    STDMETHOD(SetResourceTexture)(UINT32 textureIndex, ID2D1ResourceTexture *resourceTexture) PURE;
    STDMETHOD(SetVertexShaderConstantBuffer)(CONST BYTE *buffer, UINT32 bufferCount) PURE;
    STDMETHOD(SetPixelShader)(REFGUID shaderId, D2D1_PIXEL_OPTIONS pixelOptions = D2D1_PIXEL_OPTIONS_NONE) PURE;
    STDMETHOD(SetVertexProcessing)(ID2D1VertexBuffer *vertexBuffer, D2D1_VERTEX_OPTIONS vertexOptions,
            CONST D2D1_BLEND_DESCRIPTION *blendDescription = NULL, CONST D2D1_VERTEX_RANGE *vertexRange = NULL,
            CONST GUID *vertexShader = NULL) PURE;
};

#else

typedef interface ID2D1DrawInfo ID2D1DrawInfo;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1DrawInfo, 0x693ce632,0x7f2f,0x45de,0x93,0xfe,0x18,0xd8,0x8b,0x37,0xaa,0x21);
__CRT_UUID_DECL(ID2D1DrawInfo, 0x693ce632,0x7f2f,0x45de,0x93,0xfe,0x18,0xd8,0x8b,0x37,0xaa,0x21);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1TransformNode : public IUnknown
{
    STDMETHOD_(UINT32, GetInputCount)() CONST PURE;
};

#else

typedef interface ID2D1TransformNode ID2D1TransformNode;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1TransformNode, 0xb2efe1e7,0x729f,0x4102,0x94,0x9f,0x50,0x5f,0xa2,0x1b,0xf6,0x66);
__CRT_UUID_DECL(ID2D1TransformNode, 0xb2efe1e7,0x729f,0x4102,0x94,0x9f,0x50,0x5f,0xa2,0x1b,0xf6,0x66);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Transform : public ID2D1TransformNode
{
    STDMETHOD(MapOutputRectToInputRects)(CONST D2D1_RECT_L *outputRect, D2D1_RECT_L *inputRects,
            UINT32 inputRectsCount) CONST PURE;
    STDMETHOD(MapInputRectsToOutputRect)(CONST D2D1_RECT_L *inputRects, CONST D2D1_RECT_L *inputOpaqueSubRects,
            UINT32 inputRectCount, D2D1_RECT_L *outputRect, D2D1_RECT_L *outputOpaqueSubRect) PURE;
    STDMETHOD(MapInvalidRect)(UINT32 inputIndex, D2D1_RECT_L invalidInputRect, D2D1_RECT_L *invalidOutputRect) CONST PURE;
};

#else

typedef interface ID2D1Transform ID2D1Transform;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1Transform, 0xef1a287d,0x342a,0x4f76,0x8f,0xdb,0xda,0x0d,0x6e,0xa9,0xf9,0x2b);
__CRT_UUID_DECL(ID2D1Transform, 0xef1a287d,0x342a,0x4f76,0x8f,0xdb,0xda,0x0d,0x6e,0xa9,0xf9,0x2b);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1DrawTransform : public ID2D1Transform
{
    STDMETHOD(SetDrawInfo)(ID2D1DrawInfo *drawInfo) PURE;
};

#else

typedef interface ID2D1DrawTransform ID2D1DrawTransform;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1DrawTransform, 0x36bfdcb6,0x9739,0x435d,0xa3,0x0d,0xa6,0x53,0xbe,0xff,0x6a,0x6f);
__CRT_UUID_DECL(ID2D1DrawTransform, 0x36bfdcb6,0x9739,0x435d,0xa3,0x0d,0xa6,0x53,0xbe,0xff,0x6a,0x6f);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1TransformGraph : public IUnknown
{
    STDMETHOD_(UINT32, GetInputCount)() CONST PURE;
    STDMETHOD(SetSingleTransformNode)(ID2D1TransformNode *node) PURE;
    STDMETHOD(AddNode)(ID2D1TransformNode *node) PURE;
    STDMETHOD(RemoveNode)(ID2D1TransformNode *node) PURE;
    STDMETHOD(SetOutputNode)(ID2D1TransformNode *node) PURE;
    STDMETHOD(ConnectNode)(ID2D1TransformNode *fromNode, ID2D1TransformNode *toNode, UINT32 toNodeInputIndex) PURE;
    STDMETHOD(ConnectToEffectInput)(UINT32 toEffectInputIndex, ID2D1TransformNode *node, UINT32 toNodeInputIndex) PURE;
    STDMETHOD_(void, Clear)() PURE;
    STDMETHOD(SetPassthroughGraph)(UINT32 effectInputIndex) PURE;
};

#else

typedef interface ID2D1TransformGraph ID2D1TransformGraph;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1TransformGraph, 0x13d29038,0xc3e6,0x4034,0x90,0x81,0x13,0xb5,0x3a,0x41,0x79,0x92);
__CRT_UUID_DECL(ID2D1TransformGraph, 0x13d29038,0xc3e6,0x4034,0x90,0x81,0x13,0xb5,0x3a,0x41,0x79,0x92);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1ConcreteTransform : public ID2D1TransformNode
{
    STDMETHOD(SetOutputBuffer)(D2D1_BUFFER_PRECISION bufferPrecision, D2D1_CHANNEL_DEPTH channelDepth) PURE;
    STDMETHOD_(void, SetCached)(BOOL isCached) PURE;
};

#else

typedef interface ID2D1ConcreteTransform ID2D1ConcreteTransform;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1ConcreteTransform, 0x1a799d8a,0x69f7,0x4e4c,0x9f,0xed,0x43,0x7c,0xcc,0x66,0x84,0xcc);
__CRT_UUID_DECL(ID2D1ConcreteTransform, 0x1a799d8a,0x69f7,0x4e4c,0x9f,0xed,0x43,0x7c,0xcc,0x66,0x84,0xcc);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1BlendTransform : public ID2D1ConcreteTransform
{
    STDMETHOD_(void, SetDescription)(CONST D2D1_BLEND_DESCRIPTION *description) PURE;
    STDMETHOD_(void, GetDescription)(D2D1_BLEND_DESCRIPTION *description) CONST PURE;
};

#else

typedef interface ID2D1BlendTransform ID2D1BlendTransform;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1BlendTransform, 0x63ac0b32,0xba44,0x450f,0x88,0x06,0x7f,0x4c,0xa1,0xff,0x2f,0x1b);
__CRT_UUID_DECL(ID2D1BlendTransform, 0x63ac0b32,0xba44,0x450f,0x88,0x06,0x7f,0x4c,0xa1,0xff,0x2f,0x1b);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1BorderTransform : public ID2D1ConcreteTransform
{
    STDMETHOD_(void, SetExtendModeX)(D2D1_EXTEND_MODE extendMode) PURE;
    STDMETHOD_(void, SetExtendModeY)(D2D1_EXTEND_MODE extendMode) PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendModeX)() CONST PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendModeY)() CONST PURE;
};

#else

typedef interface ID2D1BorderTransform ID2D1BorderTransform;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1BorderTransform, 0x4998735c,0x3a19,0x473c,0x97,0x81,0x65,0x68,0x47,0xe3,0xa3,0x47);
__CRT_UUID_DECL(ID2D1BorderTransform, 0x4998735c,0x3a19,0x473c,0x97,0x81,0x65,0x68,0x47,0xe3,0xa3,0x47);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1OffsetTransform : public ID2D1TransformNode
{
    STDMETHOD_(void, SetOffset)(D2D1_POINT_2L offset) PURE;
    STDMETHOD_(D2D1_POINT_2L, GetOffset)() CONST PURE;
};

#else

typedef interface ID2D1OffsetTransform ID2D1OffsetTransform;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1OffsetTransform, 0x3fe6adea,0x7643,0x4f53,0xbd,0x14,0xa0,0xce,0x63,0xf2,0x40,0x42);
__CRT_UUID_DECL(ID2D1OffsetTransform, 0x3fe6adea,0x7643,0x4f53,0xbd,0x14,0xa0,0xce,0x63,0xf2,0x40,0x42);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1BoundsAdjustmentTransform : public ID2D1TransformNode
{
    STDMETHOD_(void, SetOutputBounds)(CONST D2D1_RECT_L *outputBounds) PURE;
    STDMETHOD_(void, GetOutputBounds)(D2D1_RECT_L *outputBounds) CONST PURE;
};

#else

typedef interface ID2D1BoundsAdjustmentTransform ID2D1BoundsAdjustmentTransform;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1BoundsAdjustmentTransform, 0x90f732e2,0x5092,0x4606,0xa8,0x19,0x86,0x51,0x97,0x0b,0xac,0xcd);
__CRT_UUID_DECL(ID2D1BoundsAdjustmentTransform, 0x90f732e2,0x5092,0x4606,0xa8,0x19,0x86,0x51,0x97,0x0b,0xac,0xcd);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1EffectContext : public IUnknown
{
    STDMETHOD_(void, GetDpi)(FLOAT *dpiX, FLOAT *dpiY) CONST PURE;
    STDMETHOD(CreateEffect)(REFCLSID effectId, ID2D1Effect **effect) PURE;
    STDMETHOD(GetMaximumSupportedFeatureLevel)(CONST D3D_FEATURE_LEVEL *featureLevels, UINT32 featureLevelsCount,
            D3D_FEATURE_LEVEL *maximumSupportedFeatureLevel) CONST PURE;
    STDMETHOD(CreateTransformNodeFromEffect)(ID2D1Effect *effect, ID2D1TransformNode **transformNode) PURE;
    STDMETHOD(CreateBlendTransform)(UINT32 numInputs, CONST D2D1_BLEND_DESCRIPTION *blendDescription, ID2D1BlendTransform **transform) PURE;
    STDMETHOD(CreateBorderTransform)(D2D1_EXTEND_MODE extendModeX, D2D1_EXTEND_MODE extendModeY, ID2D1BorderTransform **transform) PURE;
    STDMETHOD(CreateOffsetTransform)(D2D1_POINT_2L offset, ID2D1OffsetTransform **transform) PURE;
    STDMETHOD(CreateBoundsAdjustmentTransform)(CONST D2D1_RECT_L *outputRectangle, ID2D1BoundsAdjustmentTransform **transform) PURE;
    STDMETHOD(LoadPixelShader)(REFGUID shaderId, CONST BYTE *shaderBuffer, UINT32 shaderBufferCount) PURE;
    STDMETHOD(LoadVertexShader)(REFGUID resourceId, CONST BYTE *shaderBuffer, UINT32 shaderBufferCount) PURE;
    STDMETHOD(LoadComputeShader)(REFGUID resourceId, CONST BYTE *shaderBuffer, UINT32 shaderBufferCount) PURE;
    STDMETHOD_(BOOL, IsShaderLoaded)(REFGUID shaderId) PURE;
    STDMETHOD(CreateResourceTexture)(CONST GUID *resourceId, CONST D2D1_RESOURCE_TEXTURE_PROPERTIES *resourceTextureProperties,
            CONST BYTE *data, CONST UINT32 *strides, UINT32 dataSize, ID2D1ResourceTexture **resourceTexture) PURE;
    STDMETHOD(FindResourceTexture)(CONST GUID *resourceId, ID2D1ResourceTexture **resourceTexture) PURE;
    STDMETHOD(CreateVertexBuffer)(CONST D2D1_VERTEX_BUFFER_PROPERTIES *vertexBufferProperties, CONST GUID *resourceId,
            CONST D2D1_CUSTOM_VERTEX_BUFFER_PROPERTIES *customVertexBufferProperties, ID2D1VertexBuffer **buffer) PURE;
    STDMETHOD(FindVertexBuffer)(CONST GUID *resourceId, ID2D1VertexBuffer **buffer) PURE;
    STDMETHOD(CreateColorContext)(D2D1_COLOR_SPACE space, CONST BYTE *profile, UINT32 profileSize, ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CreateColorContextFromFilename)(PCWSTR filename, ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CreateColorContextFromWicColorContext)(IWICColorContext *wicColorContext, ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CheckFeatureSupport)(D2D1_FEATURE feature, void *featureSupportData, UINT32 featureSupportDataSize) CONST PURE;
    STDMETHOD_(BOOL, IsBufferPrecisionSupported)(D2D1_BUFFER_PRECISION bufferPrecision) CONST PURE;
};

#else

typedef interface ID2D1EffectContext ID2D1EffectContext;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1EffectContext,0x3d9f916b,0x27dc,0x4ad7,0xb4,0xf1,0x64,0x94,0x53,0x40,0xf5,0x63);
__CRT_UUID_DECL(ID2D1EffectContext,0x3d9f916b,0x27dc,0x4ad7,0xb4,0xf1,0x64,0x94,0x53,0x40,0xf5,0x63);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1EffectImpl : public IUnknown {
    STDMETHOD(Initialize)(ID2D1EffectContext *effectContext, ID2D1TransformGraph *transformGraph) PURE;
    STDMETHOD(PrepareForRender)(D2D1_CHANGE_TYPE changeType) PURE;
    STDMETHOD(SetGraph)(ID2D1TransformGraph *transformGraph) PURE;
};

#else

typedef interface ID2D1EffectImpl ID2D1EffectImpl;

typedef struct ID2D1EffectImplVtbl
{
    IUnknownVtbl Base;
    STDMETHOD(Initialize)(ID2D1EffectImpl*,ID2D1EffectContext*,ID2D1TransformGraph*) PURE;
    STDMETHOD(PrepareForRender)(ID2D1EffectImpl*,D2D1_CHANGE_TYPE) PURE;
    STDMETHOD(SetGraph)(ID2D1EffectImpl*,ID2D1TransformGraph*) PURE;
} ID2D1EffectImplVtbl;

interface ID2D1EffectImpl {
    CONST struct ID2D1EffectImplVtbl *lpVtbl;
};


#define ID2D1EffectImpl_QueryInterface(This, riid, ppv) ((This)->lpVtbl->Base.QueryInterface((IUnknown*)(This), riid, ppv))
#define ID2D1EffectImpl_AddRef(This) ((This)->lpVtbl->Base.AddRef((IUnknown*)(This)))
#define ID2D1EffectImpl_Release(This) ((This)->lpVtbl->Base.Release((IUnknown*)(This)))
#define ID2D1EffectImpl_Initialize(This, effectContext, transformGraph) ((This)->lpVtbl->Initialize(This, effectContext, transformGraph))
#define ID2D1EffectImpl_PrepareForRender(This, changeType) ((This)->lpVtbl->PrepareForRender(This, changeType))
#define ID2D1EffectImpl_SetGraph(This, transformGraph) ((This)->lpVtbl->SetGraph(This, transformGraph))

#endif

DEFINE_GUID(IID_ID2D1EffectImpl, 0xa248fd3f,0x3e6c,0x4e63,0x9f,0x03,0x7f,0x68,0xec,0xc9,0x1d,0xb9);
__CRT_UUID_DECL(ID2D1EffectImpl, 0xa248fd3f,0x3e6c,0x4e63,0x9f,0x03,0x7f,0x68,0xec,0xc9,0x1d,0xb9);

#endif /* _D2D1_EFFECT_AUTHOR_H_ */
