/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_DXAVHD
#define _INC_DXAVHD
#if (_WIN32_WINNT >= 0x0601)
#ifdef __cplusplus
extern "C" {
#endif

#ifndef CALLBACK
#if defined(_ARM_)
#define CALLBACK
#else
#define CALLBACK __stdcall
#endif
#endif

typedef struct IDXVAHD_Device IDXVAHD_Device;
typedef struct IDXVAHD_VideoProcessor IDXVAHD_VideoProcessor;

  typedef enum _DXVAHD_ALPHA_FILL_MODE {
    DXVAHD_ALPHA_FILL_MODE_OPAQUE          = 0,
    DXVAHD_ALPHA_FILL_MODE_BACKGROUND      = 1,
    DXVAHD_ALPHA_FILL_MODE_DESTINATION     = 2,
    DXVAHD_ALPHA_FILL_MODE_SOURCE_STREAM   = 3 
  } DXVAHD_ALPHA_FILL_MODE;

  typedef struct _DXVAHD_COLOR_YCbCrA {
    FLOAT Y;
    FLOAT Cb;
    FLOAT Cr;
    FLOAT A;
  } DXVAHD_COLOR_YCbCrA;

  typedef struct _DXVAHD_COLOR_RGBA {
    FLOAT R;
    FLOAT G;
    FLOAT B;
    FLOAT A;
  } DXVAHD_COLOR_RGBA;

  typedef union _DXVAHD_COLOR {
    DXVAHD_COLOR_RGBA   RGB;
    DXVAHD_COLOR_YCbCrA YCbCr;
  } DXVAHD_COLOR;

  typedef struct _DXVAHD_BLT_STATE_BACKGROUND_COLOR_DATA {
    WINBOOL         YCbCr;
    DXVAHD_COLOR BackgroundColor;
  } DXVAHD_BLT_STATE_BACKGROUND_COLOR_DATA;

typedef enum _DXVAHD_BLT_STATE {
  DXVAHD_BLT_STATE_TARGET_RECT          = 0,
  DXVAHD_BLT_STATE_BACKGROUND_COLOR     = 1,
  DXVAHD_BLT_STATE_OUTPUT_COLOR_SPACE   = 2,
  DXVAHD_BLT_STATE_ALPHA_FILL           = 3,
  DXVAHD_BLT_STATE_CONSTRICTION         = 4,
  DXVAHD_BLT_STATE_PRIVATE              = 1000 
} DXVAHD_BLT_STATE;

typedef enum _DXVAHD_DEVICE_CAPS {
  DXVAHD_DEVICE_CAPS_LINEAR_SPACE              = 0x1,
  DXVAHD_DEVICE_CAPS_xvYCC                     = 0x2,
  DXVAHD_DEVICE_CAPS_RGB_RANGE_CONVERSION      = 0x4,
  DXVAHD_DEVICE_CAPS_YCbCr_MATRIX_CONVERSION   = 0x8 
} DXVAHD_DEVICE_CAPS;

typedef enum _DXVAHD_DEVICE_TYPE {
  DXVAHD_DEVICE_TYPE_HARDWARE    = 0,
  DXVAHD_DEVICE_TYPE_SOFTWARE    = 1,
  DXVAHD_DEVICE_TYPE_REFERENCE   = 2,
  DXVAHD_DEVICE_TYPE_OTHER       = 3 
} DXVAHD_DEVICE_TYPE;

typedef enum _DXVAHD_DEVICE_USAGE {
  DXVAHD_DEVICE_USAGE_PLAYBACK_NORMAL   = 0,
  DXVAHD_DEVICE_USAGE_OPTIMAL_SPEED     = 1,
  DXVAHD_DEVICE_USAGE_OPTIMAL_QUALITY   = 2 
} DXVAHD_DEVICE_USAGE;


typedef enum _DXVAHD_FEATURE_CAPS {
  DXVAHD_FEATURE_CAPS_ALPHA_FILL      = 0x1,
  DXVAHD_FEATURE_CAPS_CONSTRICTION    = 0x2,
  DXVAHD_FEATURE_CAPS_LUMA_KEY        = 0x4,
  DXVAHD_FEATURE_CAPS_ALPHA_PALETTE   = 0x8 
} DXVAHD_FEATURE_CAPS;

typedef enum _DXVAHD_FILTER {
  DXVAHD_FILTER_BRIGHTNESS           = 0,
  DXVAHD_FILTER_CONTRAST             = 1,
  DXVAHD_FILTER_HUE                  = 2,
  DXVAHD_FILTER_SATURATION           = 3,
  DXVAHD_FILTER_NOISE_REDUCTION      = 4,
  DXVAHD_FILTER_EDGE_ENHANCEMENT     = 5,
  DXVAHD_FILTER_ANAMORPHIC_SCALING   = 6 
} DXVAHD_FILTER;

typedef enum _DXVAHD_FILTER_CAPS {
  DXVAHD_FILTER_CAPS_BRIGHTNESS           = 0x1,
  DXVAHD_FILTER_CAPS_CONTRAST             = 0x2,
  DXVAHD_FILTER_CAPS_HUE                  = 0x4,
  DXVAHD_FILTER_CAPS_SATURATION           = 0x8,
  DXVAHD_FILTER_CAPS_NOISE_REDUCTION      = 0x10,
  DXVAHD_FILTER_CAPS_EDGE_ENHANCEMENT     = 0x20,
  DXVAHD_FILTER_CAPS_ANAMORPHIC_SCALING   = 0x40 
} DXVAHD_FILTER_CAPS;

typedef enum _DXVAHD_FRAME_FORMAT {
  DXVAHD_FRAME_FORMAT_PROGRESSIVE                     = 0,
  DXVAHD_FRAME_FORMAT_INTERLACED_TOP_FIELD_FIRST      = 1,
  DXVAHD_FRAME_FORMAT_INTERLACED_BOTTOM_FIELD_FIRST   = 2 
} DXVAHD_FRAME_FORMAT;

typedef enum _DXVAHD_INPUT_FORMAT_CAPS {
  DXVAHD_INPUT_FORMAT_CAPS_RGB_INTERLACED       = 0x1,
  DXVAHD_INPUT_FORMAT_CAPS_RGB_PROCAMP          = 0x2,
  DXVAHD_INPUT_FORMAT_CAPS_RGB_LUMA_KEY         = 0x4,
  DXVAHD_INPUT_FORMAT_CAPS_PALETTE_INTERLACED   = 0x8 
} DXVAHD_INPUT_FORMAT_CAPS;

typedef enum _DXVAHD_ITELECINE_CAPS {
  DXVAHD_ITELECINE_CAPS_32             = 0x1,
  DXVAHD_ITELECINE_CAPS_22             = 0x2,
  DXVAHD_ITELECINE_CAPS_2224           = 0x4,
  DXVAHD_ITELECINE_CAPS_2332           = 0x8,
  DXVAHD_ITELECINE_CAPS_32322          = 0x10,
  DXVAHD_ITELECINE_CAPS_55             = 0x20,
  DXVAHD_ITELECINE_CAPS_64             = 0x40,
  DXVAHD_ITELECINE_CAPS_87             = 0x80,
  DXVAHD_ITELECINE_CAPS_222222222223   = 0x100,
  DXVAHD_ITELECINE_CAPS_OTHER          = 0x80000000 
} DXVAHD_ITELECINE_CAPS;

typedef enum _DXVAHD_OUTPUT_RATE {
  DXVAHD_OUTPUT_RATE_NORMAL   = 0,
  DXVAHD_OUTPUT_RATE_HALF     = 1,
  DXVAHD_OUTPUT_RATE_CUSTOM   = 2 
} DXVAHD_OUTPUT_RATE;

typedef enum _DXVAHD_PROCESSOR_CAPS {
  DXVAHD_PROCESSOR_CAPS_DEINTERLACE_BLEND                 = 0x1,
  DXVAHD_PROCESSOR_CAPS_DEINTERLACE_BOB                   = 0x2,
  DXVAHD_PROCESSOR_CAPS_DEINTERLACE_ADAPTIVE              = 0x4,
  DXVAHD_PROCESSOR_CAPS_DEINTERLACE_MOTION_COMPENSATION   = 0x8,
  DXVAHD_PROCESSOR_CAPS_INVERSE_TELECINE                  = 0x10,
  DXVAHD_PROCESSOR_CAPS_FRAME_RATE_CONVERSION             = 0x20 
} DXVAHD_PROCESSOR_CAPS;

typedef enum _DXVAHD_STREAM_STATE {
  DXVAHD_STREAM_STATE_D3DFORMAT                   = 0,
  DXVAHD_STREAM_STATE_FRAME_FORMAT                = 1,
  DXVAHD_STREAM_STATE_INPUT_COLOR_SPACE           = 2,
  DXVAHD_STREAM_STATE_OUTPUT_RATE                 = 3,
  DXVAHD_STREAM_STATE_SOURCE_RECT                 = 4,
  DXVAHD_STREAM_STATE_DESTINATION_RECT            = 5,
  DXVAHD_STREAM_STATE_ALPHA                       = 6,
  DXVAHD_STREAM_STATE_PALETTE                     = 7,
  DXVAHD_STREAM_STATE_LUMA_KEY                    = 8,
  DXVAHD_STREAM_STATE_ASPECT_RATIO                = 9,
  DXVAHD_STREAM_STATE_FILTER_BRIGHTNESS           = 100,
  DXVAHD_STREAM_STATE_FILTER_CONTRAST             = 101,
  DXVAHD_STREAM_STATE_FILTER_HUE                  = 102,
  DXVAHD_STREAM_STATE_FILTER_SATURATION           = 103,
  DXVAHD_STREAM_STATE_FILTER_NOISE_REDUCTION      = 104,
  DXVAHD_STREAM_STATE_FILTER_EDGE_ENHANCEMENT     = 105,
  DXVAHD_STREAM_STATE_FILTER_ANAMORPHIC_SCALING   = 106,
  DXVAHD_STREAM_STATE_PRIVATE                     = 1000 
} DXVAHD_STREAM_STATE;

typedef enum _DXVAHD_SURFACE_TYPE {
  DXVAHD_SURFACE_TYPE_VIDEO_INPUT           = 0,
  DXVAHD_SURFACE_TYPE_VIDEO_INPUT_PRIVATE   = 1,
  DXVAHD_SURFACE_TYPE_VIDEO_OUTPUT          = 2 
} DXVAHD_SURFACE_TYPE;

typedef struct _DXVAHD_VPDEVCAPS {
  DXVAHD_DEVICE_TYPE DeviceType;
  UINT               DeviceCaps;
  UINT               FeatureCaps;
  UINT               FilterCaps;
  UINT               InputFormatCaps;
  D3DPOOL            InputPool;
  UINT               OutputFormatCount;
  UINT               InputFormatCount;
  UINT               VideoProcessorCount;
  UINT               MaxInputStreams;
  UINT               MaxStreamStates;
} DXVAHD_VPDEVCAPS;

typedef struct _DXVAHD_BLT_STATE_ALPHA_FILL_DATA {
  DXVAHD_ALPHA_FILL_MODE Mode;
  UINT                   StreamNumber;
} DXVAHD_BLT_STATE_ALPHA_FILL_DATA;

typedef struct _DXVAHD_BLT_STATE_CONSTRICTION_DATA {
  WINBOOL Enable;
  SIZE Size;
} DXVAHD_BLT_STATE_CONSTRICTION_DATA;

typedef struct _DXVAHD_BLT_STATE_OUTPUT_COLOR_SPACE_DATA {
  UINT Usage  :1;
  UINT RGB_Range  :1;
  UINT YCbCr_Matrix  :1;
  UINT YCbCr_xvYCC  :1;
} DXVAHD_BLT_STATE_OUTPUT_COLOR_SPACE_DATA;

typedef struct _DXVAHD_BLT_STATE_PRIVATE_DATA {
  GUID Guid;
  UINT DataSize;
  void *pData;
} DXVAHD_BLT_STATE_PRIVATE_DATA;

typedef struct _DXVAHD_BLT_STATE_TARGET_RECT_DATA {
  WINBOOL Enable;
  RECT TargetRect;
} DXVAHD_BLT_STATE_TARGET_RECT_DATA;

typedef struct _DXVAHD_RATIONAL {
  UINT Numerator;
  UINT Denominator;
} DXVAHD_RATIONAL;

typedef struct _DXVAHD_CONTENT_DESC {
  DXVAHD_FRAME_FORMAT InputFrameFormat;
  DXVAHD_RATIONAL     InputFrameRate;
  UINT                InputWidth;
  UINT                InputHeight;
  DXVAHD_RATIONAL     OutputFrameRate;
  UINT                OutputWidth;
  UINT                OutputHeight;
} DXVAHD_CONTENT_DESC;

typedef struct _DXVAHD_CUSTOM_RATE_DATA {
  DXVAHD_RATIONAL CustomRate;
  UINT            OutputFrames;
  WINBOOL         InputInterlaced;
  UINT            InputFramesOrFields;
} DXVAHD_CUSTOM_RATE_DATA;

typedef struct _DXVAHD_FILTER_RANGE_DATA {
  INT   Minimum;
  INT   Maximum;
  INT   Default;
  FLOAT Multiplier;
} DXVAHD_FILTER_RANGE_DATA;

typedef struct _DXVAHD_STREAM_DATA {
  WINBOOL           Enable;
  UINT              OutputIndex;
  UINT              InputFrameOrField;
  UINT              PastFrames;
  UINT              FutureFrames;
  IDirect3DSurface9 **ppPastSurfaces;
  IDirect3DSurface9 *pInputSurface;
  IDirect3DSurface9 **ppFutureSurfaces;
} DXVAHD_STREAM_DATA;

typedef struct _DXVAHD_VPCAPS {
  GUID VPGuid;
  UINT PastFrames;
  UINT FutureFrames;
  UINT ProcessorCaps;
  UINT ITelecineCaps;
  UINT CustomRateCount;
} DXVAHD_VPCAPS;

typedef struct _DXVAHD_STREAM_STATE_ALPHA_DATA {
  WINBOOL Enable;
  FLOAT   Alpha;
} DXVAHD_STREAM_STATE_ALPHA_DATA;

typedef struct _DXVAHD_STREAM_STATE_ASPECT_RATIO_DATA {
  WINBOOL         Enable;
  DXVAHD_RATIONAL SourceAspectRatio;
  DXVAHD_RATIONAL DestinationAspectRatio;
} DXVAHD_STREAM_STATE_ASPECT_RATIO_DATA, *PDXVAHD_STREAM_STATE_ASPECT_RATIO_DATA;

typedef struct _DXVAHD_STREAM_STATE_D3DFORMAT_DATA {
  D3DFORMAT Format;
} DXVAHD_STREAM_STATE_D3DFORMAT_DATA;

typedef struct _DXVAHD_STREAM_STATE_DESTINATION_RECT_DATA {
  WINBOOL Enable;
  RECT    DestinationRect;
} DXVAHD_STREAM_STATE_DESTINATION_RECT_DATA;

typedef struct _DXVAHD_STREAM_STATE_FILTER_DATA {
  WINBOOL Enable;
  INT     Level;
} DXVAHD_STREAM_STATE_FILTER_DATA;

typedef struct _DXVAHD_STREAM_STATE_FRAME_FORMAT_DATA {
  DXVAHD_FRAME_FORMAT FrameFormat;
} DXVAHD_STREAM_STATE_FRAME_FORMAT_DATA;

typedef struct _DXVAHD_STREAM_STATE_INPUT_COLOR_SPACE_DATA {
  UINT Type  :1;
  UINT RGB_Range  :1;
  UINT YCbCr_Matrix  :1;
  UINT YCbCr_xvYCC  :1;
} DXVAHD_STREAM_STATE_INPUT_COLOR_SPACE_DATA;

typedef struct _DXVAHD_STREAM_STATE_LUMA_KEY_DATA {
  WINBOOL Enable;
  FLOAT   Lower;
  FLOAT   Upper;
} DXVAHD_STREAM_STATE_LUMA_KEY_DATA;

typedef struct _DXVAHD_STREAM_STATE_OUTPUT_RATE_DATA {
  WINBOOL            RepeatFrame;
  DXVAHD_OUTPUT_RATE OutputRate;
  DXVAHD_RATIONAL    CustomRate;
} DXVAHD_STREAM_STATE_OUTPUT_RATE_DATA;

typedef struct _DXVAHD_STREAM_STATE_SOURCE_RECT_DATA {
  WINBOOL Enable;
  RECT    SourceRect;
} DXVAHD_STREAM_STATE_SOURCE_RECT_DATA;

typedef struct _DXVAHD_STREAM_STATE_PRIVATE_IVTC_DATA {
  WINBOOL Enable;
  UINT    ITelecineFlags;
  UINT    Frames;
  UINT    InputField;
} DXVAHD_STREAM_STATE_PRIVATE_IVTC_DATA;

typedef struct _DXVAHD_STREAM_STATE_PRIVATE_DATA {
  GUID Guid;
  UINT DataSize;
  void *pData;
} DXVAHD_STREAM_STATE_PRIVATE_DATA;

typedef struct _DXVAHD_STREAM_STATE_PALETTE_DATA {
  UINT     Count;
  D3DCOLOR *pEntries;
} DXVAHD_STREAM_STATE_PALETTE_DATA;

typedef HRESULT ( CALLBACK *PDXVAHDSW_CreateDevice )(IDirect3DDevice9Ex *pD3DDevice,HANDLE *phDevice);
typedef HRESULT ( CALLBACK *PDXVAHDSW_ProposeVideoPrivateFormat )(HANDLE hDevice,D3DFORMAT *pFormat);
typedef HRESULT ( CALLBACK *PDXVAHDSW_GetVideoProcessorDeviceCaps )(HANDLE hDevice,const DXVAHD_CONTENT_DESC *pContentDesc,DXVAHD_DEVICE_USAGE Usage,DXVAHD_VPDEVCAPS *pCaps);
typedef HRESULT ( CALLBACK *PDXVAHDSW_GetVideoProcessorOutputFormats )(HANDLE hDevice,const DXVAHD_CONTENT_DESC *pContentDesc,DXVAHD_DEVICE_USAGE Usage,UINT Count,D3DFORMAT *pFormats);
typedef HRESULT ( CALLBACK *PDXVAHDSW_GetVideoProcessorInputFormats )(HANDLE hDevice,const DXVAHD_CONTENT_DESC *pContentDesc,DXVAHD_DEVICE_USAGE Usage,UINT Count,D3DFORMAT *pFormats);
typedef HRESULT ( CALLBACK *PDXVAHDSW_GetVideoProcessorCaps )(HANDLE hDevice,const DXVAHD_CONTENT_DESC *pContentDesc,DXVAHD_DEVICE_USAGE Usage,UINT Count,DXVAHD_VPCAPS *pCaps);
typedef HRESULT ( CALLBACK *PDXVAHDSW_GetVideoProcessorCustomRates )(HANDLE hDevice,const GUID *pVPGuid,UINT Count,DXVAHD_CUSTOM_RATE_DATA *pRates);
typedef HRESULT ( CALLBACK *PDXVAHDSW_SetVideoProcessBltState )(HANDLE hVideoProcessor,DXVAHD_BLT_STATE State,UINT DataSize,const void *pData);
typedef HRESULT ( CALLBACK *PDXVAHDSW_CreateVideoProcessor )(HANDLE hDevice,const GUID *pVPGuid,HANDLE *phVideoProcessor);
typedef HRESULT ( CALLBACK *PDXVAHDSW_DestroyDevice )(HANDLE hDevice);
typedef HRESULT ( CALLBACK *PDXVAHDSW_GetVideoProcessorFilterRange )(HANDLE hDevice,DXVAHD_FILTER Filter,DXVAHD_FILTER_RANGE_DATA *pRange);
typedef HRESULT ( CALLBACK *PDXVAHDSW_DestroyVideoProcessor )(HANDLE hVideoProcessor);
typedef HRESULT ( CALLBACK *PDXVAHDSW_VideoProcessBltHD )(HANDLE hVideoProcessor,IDirect3DSurface9 *pOutputSurface,UINT OutputFrame,UINT StreamCount,const DXVAHD_STREAM_DATA *pStreams);
typedef HRESULT ( CALLBACK *PDXVAHDSW_GetVideoProcessStreamStatePrivate )(HANDLE hVideoProcessor,UINT StreamNumber,DXVAHD_STREAM_STATE_PRIVATE_DATA *pData);
typedef HRESULT ( CALLBACK *PDXVAHDSW_SetVideoProcessStreamState )(HANDLE hVideoProcessor,UINT StreamNumber,DXVAHD_STREAM_STATE State,UINT DataSize,const void *pData);
typedef HRESULT ( CALLBACK *PDXVAHDSW_GetVideoProcessBltStatePrivate )(HANDLE hVideoProcessor,DXVAHD_BLT_STATE_PRIVATE_DATA *pData);
typedef HRESULT ( CALLBACK *PDXVAHDSW_Plugin )(UINT Size,void *pCallbacks);

typedef struct _DXVAHDSW_CALLBACKS {
  PDXVAHDSW_CreateDevice                      CreateDevice;
  PDXVAHDSW_ProposeVideoPrivateFormat         ProposeVideoPrivateFormat;
  PDXVAHDSW_GetVideoProcessorDeviceCaps       GetVideoProcessorDeviceCaps;
  PDXVAHDSW_GetVideoProcessorOutputFormats    GetVideoProcessorOutputFormats;
  PDXVAHDSW_GetVideoProcessorInputFormats     GetVideoProcessorInputFormats;
  PDXVAHDSW_GetVideoProcessorCaps             GetVideoProcessorCaps;
  PDXVAHDSW_GetVideoProcessorCustomRates      GetVideoProcessorCustomRates;
  PDXVAHDSW_GetVideoProcessorFilterRange      GetVideoProcessorFilterRange;
  PDXVAHDSW_DestroyDevice                     DestroyDevice;
  PDXVAHDSW_CreateVideoProcessor              CreateVideoProcessor;
  PDXVAHDSW_SetVideoProcessBltState           SetVideoProcessBltState;
  PDXVAHDSW_GetVideoProcessBltStatePrivate    GetVideoProcessBltStatePrivate;
  PDXVAHDSW_SetVideoProcessStreamState        SetVideoProcessStreamState;
  PDXVAHDSW_GetVideoProcessStreamStatePrivate GetVideoProcessStreamStatePrivate;
  PDXVAHDSW_VideoProcessBltHD                 VideoProcessBltHD;
  PDXVAHDSW_DestroyVideoProcessor             DestroyVideoProcessor;
} DXVAHDSW_CALLBACKS;

HRESULT DXVAHD_CreateDevice(IDirect3DDevice9Ex *pD3DDevice,const DXVAHD_CONTENT_DESC *pContentDesc,DXVAHD_DEVICE_USAGE Usage,PDXVAHDSW_Plugin pPlugin,IDXVAHD_Device **ppDevice);

#ifdef __cplusplus
}
#endif

#undef  INTERFACE
#define INTERFACE IDXVAHD_Device
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDXVAHD_Device,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDXVAHD_Device methods */
    STDMETHOD_(HRESULT,CreateVideoProcessor)(THIS_ const GUID *pVPGuid,IDXVAHD_VideoProcessor **ppVideoProcessor) PURE;
    STDMETHOD_(HRESULT,CreateVideoSurface)(THIS_ UINT Width,UINT Height,D3DFORMAT Format,D3DPOOL Pool,DWORD Usage,DXVAHD_SURFACE_TYPE Type,UINT NumSurfaces,IDirect3DSurface9 **ppSurfaces,HANDLE *pSharedHandle) PURE;
    STDMETHOD_(HRESULT,GetVideoProcessorCaps)(THIS_ UINT Count,DXVAHD_VPCAPS *pCaps) PURE;
    STDMETHOD_(HRESULT,GetVideoProcessorCustomRates)(THIS_ const GUID *pVPGuid,UINT Count,DXVAHD_CUSTOM_RATE_DATA *pRates) PURE;
    STDMETHOD_(HRESULT,GetVideoProcessorDeviceCaps)(THIS_ DXVAHD_VPDEVCAPS *pCaps) PURE;
    STDMETHOD_(HRESULT,GetVideoProcessorFilterRange)(THIS_ DXVAHD_FILTER Filter,DXVAHD_FILTER_RANGE_DATA *pRange) PURE;
    STDMETHOD_(HRESULT,GetVideoProcessorInputFormats)(THIS_ UINT Count,D3DFORMAT *pFormats) PURE;
    STDMETHOD_(HRESULT,GetVideoProcessorOutputFormats)(THIS_ UINT Count,D3DFORMAT *pFormats) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDXVAHD_Device_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDXVAHD_Device_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDXVAHD_Device_Release(This) (This)->lpVtbl->Release(This)
#define IDXVAHD_Device_CreateVideoProcessor(This,pVPGuid,ppVideoProcessor) (This)->lpVtbl->CreateVideoProcessor(This,pVPGuid,ppVideoProcessor)
#define IDXVAHD_Device_CreateVideoSurface(This,Width,Height,Format,Pool,Usage,Type,NumSurfaces,ppSurfaces,pSharedHandle) (This)->lpVtbl->CreateVideoSurface(This,Width,Height,Format,Pool,Usage,Type,NumSurfaces,ppSurfaces,pSharedHandle)
#define IDXVAHD_Device_GetVideoProcessorCaps(This,Count,pCaps) (This)->lpVtbl->GetVideoProcessorCaps(This,Count,pCaps)
#define IDXVAHD_Device_GetVideoProcessorCustomRates(This,pVPGuid,Count,pRates) (This)->lpVtbl->GetVideoProcessorCustomRates(This,pVPGuid,Count,pRates)
#define IDXVAHD_Device_GetVideoProcessorDeviceCaps(This,pCaps) (This)->lpVtbl->GetVideoProcessorDeviceCaps(This,pCaps)
#define IDXVAHD_Device_GetVideoProcessorFilterRange(This,Filter,pRange) (This)->lpVtbl->GetVideoProcessorFilterRange(This,Filter,pRange)
#define IDXVAHD_Device_GetVideoProcessorInputFormats(This,Count,pFormats) (This)->lpVtbl->GetVideoProcessorInputFormats(This,Count,pFormats)
#define IDXVAHD_Device_GetVideoProcessorOutputFormats(This,Count,pFormats) (This)->lpVtbl->GetVideoProcessorOutputFormats(This,Count,pFormats)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDXVAHD_VideoProcessor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDXVAHD_VideoProcessor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDXVAHD_VideoProcessor methods */
    STDMETHOD_(HRESULT,GetVideoProcessBltState)(THIS_ DXVAHD_BLT_STATE State,UINT DataSize,void *pData) PURE;
    STDMETHOD_(HRESULT,GetVideoProcessStreamState)(THIS_ UINT StreamNumber,DXVAHD_STREAM_STATE State,UINT DataSize,void *pData) PURE;
    STDMETHOD_(HRESULT,SetVideoProcessBltState)(THIS_ DXVAHD_BLT_STATE State,UINT DataSize,const void *pData) PURE;
    STDMETHOD_(HRESULT,SetVideoProcessStreamState)(THIS_ UINT StreamNumber,DXVAHD_STREAM_STATE State,UINT DataSize,const void *pData) PURE;
    STDMETHOD_(HRESULT,VideoProcessBltHD)(THIS_ IDirect3DSurface9 *pOutputSurface,UINT OutputFrame,UINT StreamCount,const DXVAHD_STREAM_DATA *pStreams) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDXVAHD_VideoProcessor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDXVAHD_VideoProcessor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDXVAHD_VideoProcessor_Release(This) (This)->lpVtbl->Release(This)
#define IDXVAHD_VideoProcessor_GetVideoProcessBltState(This,State,DataSize,pData) (This)->lpVtbl->GetVideoProcessBltState(This,State,DataSize,pData)
#define IDXVAHD_VideoProcessor_GetVideoProcessStreamState(This,StreamNumber,State,DataSize,pData) (This)->lpVtbl->GetVideoProcessStreamState(This,StreamNumber,State,DataSize,pData)
#define IDXVAHD_VideoProcessor_SetVideoProcessBltState(This,State,DataSize,pData) (This)->lpVtbl->SetVideoProcessBltState(This,State,DataSize,pData)
#define IDXVAHD_VideoProcessor_SetVideoProcessStreamState(This,StreamNumber,State,DataSize,pData) (This)->lpVtbl->SetVideoProcessStreamState(This,StreamNumber,State,DataSize,pData)
#define IDXVAHD_VideoProcessor_VideoProcessBltHD(This,pOutputSurface,OutputFrame,StreamCount,pStreams) (This)->lpVtbl->VideoProcessBltHD(This,pOutputSurface,OutputFrame,StreamCount,pStreams)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0601)*/
#endif /*_INC_DXAVHD*/
