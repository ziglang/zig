/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef DWRITE_2_H_INCLUDED
#define DWRITE_2_H_INCLUDED

#include <dwrite_1.h>

typedef enum DWRITE_GRID_FIT_MODE
{
    DWRITE_GRID_FIT_MODE_DEFAULT,
    DWRITE_GRID_FIT_MODE_DISABLED,
    DWRITE_GRID_FIT_MODE_ENABLED
} DWRITE_GRID_FIT_MODE;

#ifndef D3DCOLORVALUE_DEFINED
#define D3DCOLORVALUE_DEFINED
typedef struct _D3DCOLORVALUE {
    union {
        FLOAT r;
        FLOAT dvR;
    } DUMMYUNIONNAME1;
    union {
        FLOAT g;
        FLOAT dvG;
    } DUMMYUNIONNAME2;
    union {
        FLOAT b;
        FLOAT dvB;
    } DUMMYUNIONNAME3;
    union {
        FLOAT a;
        FLOAT dvA;
    } DUMMYUNIONNAME4;
} D3DCOLORVALUE,*LPD3DCOLORVALUE;
#endif /* D3DCOLORVALUE_DEFINED */

typedef D3DCOLORVALUE DWRITE_COLOR_F;

typedef struct DWRITE_COLOR_GLYPH_RUN
{
    DWRITE_GLYPH_RUN glyphRun;
    DWRITE_GLYPH_RUN_DESCRIPTION *glyphRunDescription;
    FLOAT baselineOriginX;
    FLOAT baselineOriginY;
    DWRITE_COLOR_F runColor;
    UINT16 paletteIndex;
} DWRITE_COLOR_GLYPH_RUN;

#undef  INTERFACE
#define INTERFACE IDWriteFontFallback
DECLARE_INTERFACE_(IDWriteFontFallback,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    STDMETHOD(MapCharacters)(THIS_
        IDWriteTextAnalysisSource *analysisSource,
        UINT32 textPosition,
        UINT32 textLength,
        IDWriteFontCollection *baseFontCollection,
        wchar_t const *baseFamilyName,
        DWRITE_FONT_WEIGHT baseWeight,
        DWRITE_FONT_STYLE baseStyle,
        DWRITE_FONT_STRETCH baseStretch,
        UINT32 *mappedLength,
        IDWriteFont **mappedFont,
        FLOAT *scale) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFontFallback, 0xefa008f9,0xf7a1,0x48bf,0xb0,0x5c,0xf2,0x24,0x71,0x3c,0xc0,0xff)

#undef  INTERFACE
#define INTERFACE IDWriteFontFallbackBuilder
DECLARE_INTERFACE_(IDWriteFontFallbackBuilder,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    STDMETHOD(AddMapping)(THIS_
        DWRITE_UNICODE_RANGE const *ranges,
        UINT32 rangesCount,
        WCHAR const **targetFamilyNames,
        UINT32 targetFamilyNamesCount,
        IDWriteFontCollection *fontCollection __MINGW_DEF_ARG_VAL(NULL),
        WCHAR const *localeName __MINGW_DEF_ARG_VAL(NULL),
        WCHAR const *baseFamilyName __MINGW_DEF_ARG_VAL(NULL),
        FLOAT scale __MINGW_DEF_ARG_VAL(1.0f)) PURE;

    STDMETHOD(AddMappings)(THIS_
        IDWriteFontFallback *fontFallback) PURE;

    STDMETHOD(CreateFontFallback)(THIS_
        IDWriteFontFallback **fontFallback) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFontFallbackBuilder, 0xfd882d06,0x8aba,0x4fb8,0xb8,0x49,0x8b,0xe8,0xb7,0x3e,0x14,0xde)

#undef  INTERFACE
#define INTERFACE IDWriteColorGlyphRunEnumerator
DECLARE_INTERFACE_(IDWriteColorGlyphRunEnumerator,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    STDMETHOD(MoveNext)(THIS_
        BOOL *hasRun) PURE;

    STDMETHOD(GetCurrentRun)(THIS_
        DWRITE_COLOR_GLYPH_RUN const **colorGlyphRun) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteColorGlyphRunEnumerator, 0xd31fbe17,0xf157,0x41a2,0x8d,0x24,0xcb,0x77,0x9e,0x05,0x60,0xe8)

#undef  INTERFACE
#define INTERFACE IDWriteRenderingParams2
DECLARE_INTERFACE_(IDWriteRenderingParams2,IDWriteRenderingParams1)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWriteRenderingParams methods */
    STDMETHOD_(FLOAT, GetGamma)(THIS) PURE;
    STDMETHOD_(FLOAT, GetEnhancedContrast)(THIS) PURE;
    STDMETHOD_(FLOAT, GetClearTypeLevel)(THIS) PURE;
    STDMETHOD_(DWRITE_PIXEL_GEOMETRY, GetPixelGeometry)(THIS) PURE;
    STDMETHOD_(DWRITE_RENDERING_MODE, GetRenderingMode)(THIS) PURE;

    /* IDWriteRenderingParams1 methods */
    STDMETHOD_(FLOAT, GetGrayscaleEnhancedContrast)(THIS) PURE;
#endif

    /* IDWriteRenderingParams2 methods */
    STDMETHOD_(DWRITE_GRID_FIT_MODE, GetGridFitMode)(THIS) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteRenderingParams2, 0xf9d711c3,0x9777,0x40ae,0x87,0xe8,0x3e,0x5a,0xf9,0xbf,0x09,0x48)

#undef  INTERFACE
#define INTERFACE IDWriteFactory2
DECLARE_INTERFACE_(IDWriteFactory2,IDWriteFactory1)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWriteFactory methods */
    STDMETHOD(GetSystemFontCollection)(THIS_
        IDWriteFontCollection **fontCollection,
        WINBOOL checkForUpdates __MINGW_DEF_ARG_VAL(FALSE)) PURE;

    STDMETHOD(CreateCustomFontCollection)(THIS_
        IDWriteFontCollectionLoader *collectionLoader,
        void const *collectionKey,
        UINT32 collectionKeySize,
        IDWriteFontCollection **fontCollection) PURE;

    STDMETHOD(RegisterFontCollectionLoader)(THIS_
        IDWriteFontCollectionLoader *fontCollectionLoader) PURE;

    STDMETHOD(UnregisterFontCollectionLoader)(THIS_
        IDWriteFontCollectionLoader *fontCollectionLoader) PURE;

    STDMETHOD(CreateFontFileReference)(THIS_
        WCHAR const *filePath,
        FILETIME const *lastWriteTime,
        IDWriteFontFile **fontFile) PURE;

    STDMETHOD(CreateCustomFontFileReference)(THIS_
        void const *fontFileReferenceKey,
        UINT32 fontFileReferenceKeySize,
        IDWriteFontFileLoader *fontFileLoader,
        IDWriteFontFile **fontFile) PURE;

    STDMETHOD(CreateFontFace)(THIS_
        DWRITE_FONT_FACE_TYPE fontFaceType,
        UINT32 numberOfFiles,
        IDWriteFontFile *const *fontFiles,
        UINT32 faceIndex,
        DWRITE_FONT_SIMULATIONS fontFaceSimulationFlags,
        IDWriteFontFace **fontFace) PURE;

    STDMETHOD(CreateRenderingParams)(THIS_
        IDWriteRenderingParams **renderingParams) PURE;

    STDMETHOD(CreateMonitorRenderingParams)(THIS_
        HMONITOR monitor,
        IDWriteRenderingParams **renderingParams) PURE;

    STDMETHOD(CreateCustomRenderingParams)(THIS_
        FLOAT gamma,
        FLOAT enhancedContrast,
        FLOAT clearTypeLevel,
        DWRITE_PIXEL_GEOMETRY pixelGeometry,
        DWRITE_RENDERING_MODE renderingMode,
        IDWriteRenderingParams **renderingParams) PURE;

    STDMETHOD(RegisterFontFileLoader)(THIS_
        IDWriteFontFileLoader *fontFileLoader) PURE;

    STDMETHOD(UnregisterFontFileLoader)(THIS_
        IDWriteFontFileLoader *fontFileLoader) PURE;

    STDMETHOD(CreateTextFormat)(THIS_
        WCHAR const *fontFamilyName,
        IDWriteFontCollection *fontCollection,
        DWRITE_FONT_WEIGHT fontWeight,
        DWRITE_FONT_STYLE fontStyle,
        DWRITE_FONT_STRETCH fontStretch,
        FLOAT fontSize,
        WCHAR const *localeName,
        IDWriteTextFormat **textFormat) PURE;

    STDMETHOD(CreateTypography)(THIS_
        IDWriteTypography **typography) PURE;

    STDMETHOD(GetGdiInterop)(THIS_
        IDWriteGdiInterop **gdiInterop) PURE;

    STDMETHOD(CreateTextLayout)(THIS_
        WCHAR const *string,
        UINT32 stringLength,
        IDWriteTextFormat *textFormat,
        FLOAT maxWidth,
        FLOAT maxHeight,
        IDWriteTextLayout **textLayout) PURE;

    STDMETHOD(CreateGdiCompatibleTextLayout)(THIS_
        WCHAR const *string,
        UINT32 stringLength,
        IDWriteTextFormat *textFormat,
        FLOAT layoutWidth,
        FLOAT layoutHeight,
        FLOAT pixelsPerDip,
        DWRITE_MATRIX const *transform,
        WINBOOL useGdiNatural,
        IDWriteTextLayout **textLayout) PURE;

    STDMETHOD(CreateEllipsisTrimmingSign)(THIS_
        IDWriteTextFormat *textFormat,
        IDWriteInlineObject **trimmingSign) PURE;

    STDMETHOD(CreateTextAnalyzer)(THIS_
        IDWriteTextAnalyzer **textAnalyzer) PURE;

    STDMETHOD(CreateNumberSubstitution)(THIS_
        DWRITE_NUMBER_SUBSTITUTION_METHOD substitutionMethod,
        WCHAR const *localeName,
        WINBOOL ignoreUserOverride,
        IDWriteNumberSubstitution **numberSubstitution) PURE;

    STDMETHOD(CreateGlyphRunAnalysis)(THIS_
        DWRITE_GLYPH_RUN const *glyphRun,
        FLOAT pixelsPerDip,
        DWRITE_MATRIX const *transform,
        DWRITE_RENDERING_MODE renderingMode,
        DWRITE_MEASURING_MODE measuringMode,
        FLOAT baselineOriginX,
        FLOAT baselineOriginY,
        IDWriteGlyphRunAnalysis **glyphRunAnalysis) PURE;

    /* IDWriteFactory1 methods */
    STDMETHOD(GetEudcFontCollection)(THIS_
        IDWriteFontCollection **fontCollection,
        BOOL checkForUpdates __MINGW_DEF_ARG_VAL(FALSE)) PURE;

    STDMETHOD(CreateCustomRenderingParams)(THIS_
        FLOAT gamma,
        FLOAT enhancedContrast,
        FLOAT enhancedContrastGrayscale,
        FLOAT clearTypeLevel,
        DWRITE_PIXEL_GEOMETRY pixelGeometry,
        DWRITE_RENDERING_MODE renderingMode,
        IDWriteRenderingParams1 **renderingParams) PURE;
#endif

    /* IDWriteFactory2 methods */
    STDMETHOD(GetSystemFontFallback)(THIS_
        IDWriteFontFallback **fontFallback) PURE;

    STDMETHOD(CreateFontFallbackBuilder)(THIS_
        IDWriteFontFallbackBuilder **fontFallbackBuilder) PURE;

    STDMETHOD(TranslateColorGlyphRun)(THIS_
        FLOAT baselineOriginX,
        FLOAT baselineOriginY,
        DWRITE_GLYPH_RUN const *glyphRun,
        DWRITE_GLYPH_RUN_DESCRIPTION const *glyphRunDescription,
        DWRITE_MEASURING_MODE measuringMode,
        DWRITE_MATRIX const *worldToDeviceTransform,
        UINT32 colorPaletteIndex,
        IDWriteColorGlyphRunEnumerator **colorLayers) PURE;

    STDMETHOD(CreateCustomRenderingParams)(THIS_
        FLOAT gamma,
        FLOAT enhancedContrast,
        FLOAT grayscaleEnhancedContrast,
        FLOAT clearTypeLevel,
        DWRITE_PIXEL_GEOMETRY pixelGeometry,
        DWRITE_RENDERING_MODE renderingMode,
        DWRITE_GRID_FIT_MODE gridFitMode,
        IDWriteRenderingParams2 **renderingParams) PURE;

#ifdef __cplusplus
    using IDWriteFactory::CreateCustomRenderingParams;
    using IDWriteFactory1::CreateCustomRenderingParams;
#endif

    STDMETHOD(CreateGlyphRunAnalysis)(THIS_
        DWRITE_GLYPH_RUN const *glyphRun,
        DWRITE_MATRIX const *transform,
        DWRITE_RENDERING_MODE renderingMode,
        DWRITE_MEASURING_MODE measuringMode,
        DWRITE_GRID_FIT_MODE gridFitMode,
        DWRITE_TEXT_ANTIALIAS_MODE antialiasMode,
        FLOAT baselineOriginX,
        FLOAT baselineOriginY,
        IDWriteGlyphRunAnalysis **glyphRunAnalysis) PURE;

#ifdef __cplusplus
    using IDWriteFactory::CreateGlyphRunAnalysis;
#endif

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFactory2, 0x0439fc60,0xca44,0x4994,0x8d,0xee,0x3a,0x9a,0xf7,0xb7,0x32,0xec)

#undef  INTERFACE
#define INTERFACE IDWriteFontFace2
DECLARE_INTERFACE_(IDWriteFontFace2,IDWriteFontFace1)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWriteFontFace methods */
    STDMETHOD_(DWRITE_FONT_FACE_TYPE, GetType)(THIS) PURE;

    STDMETHOD(GetFiles)(THIS_
        UINT32 *numberOfFiles,
        IDWriteFontFile **fontFiles) PURE;

    STDMETHOD_(UINT32, GetIndex)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_SIMULATIONS, GetSimulations)(THIS) PURE;
    STDMETHOD_(WINBOOL, IsSymbolFont)(THIS) PURE;

    STDMETHOD_(void, GetMetrics)(THIS_
        DWRITE_FONT_METRICS *fontFaceMetrics) PURE;

    STDMETHOD_(UINT16, GetGlyphCount)(THIS) PURE;

    STDMETHOD(GetDesignGlyphMetrics)(THIS_
        UINT16 const *glyphIndices,
        UINT32 glyphCount,
        DWRITE_GLYPH_METRICS *glyphMetrics,
        WINBOOL isSideways __MINGW_DEF_ARG_VAL(FALSE)) PURE;

    STDMETHOD(GetGlyphIndices)(THIS_
        UINT32 const *codePoints,
        UINT32 codePointCount,
        UINT16 *glyphIndices) PURE;

    STDMETHOD(TryGetFontTable)(THIS_
        UINT32 openTypeTableTag,
        const void **tableData,
        UINT32 *tableSize,
        void **tableContext,
        WINBOOL *exists) PURE;

    STDMETHOD_(void, ReleaseFontTable)(THIS_
        void *tableContext) PURE;

    STDMETHOD(GetGlyphRunOutline)(THIS_
        FLOAT emSize,
        UINT16 const *glyphIndices,
        FLOAT const *glyphAdvances,
        DWRITE_GLYPH_OFFSET const *glyphOffsets,
        UINT32 glyphCount,
        WINBOOL isSideways,
        WINBOOL isRightToLeft,
        IDWriteGeometrySink *geometrySink) PURE;

    STDMETHOD(GetRecommendedRenderingMode)(THIS_
        FLOAT emSize,
        FLOAT pixelsPerDip,
        DWRITE_MEASURING_MODE measuringMode,
        IDWriteRenderingParams *renderingParams,
        DWRITE_RENDERING_MODE *renderingMode) PURE;

    STDMETHOD(GetGdiCompatibleMetrics)(THIS_
        FLOAT emSize,
        FLOAT pixelsPerDip,
        DWRITE_MATRIX const *transform,
        DWRITE_FONT_METRICS *fontFaceMetrics) PURE;

    STDMETHOD(GetGdiCompatibleGlyphMetrics)(THIS_
        FLOAT emSize,
        FLOAT pixelsPerDip,
        DWRITE_MATRIX const *transform,
        WINBOOL useGdiNatural,
        UINT16 const *glyphIndices,
        UINT32 glyphCount,
        DWRITE_GLYPH_METRICS *glyphMetrics,
        WINBOOL isSideways __MINGW_DEF_ARG_VAL(FALSE)) PURE;

    /* IDWriteFontFace1 methods */
    STDMETHOD_(void, GetMetrics)(THIS_ DWRITE_FONT_METRICS1*) PURE;
    STDMETHOD(GetGdiCompatibleMetrics)(THIS_ FLOAT,FLOAT,DWRITE_MATRIX const*,DWRITE_FONT_METRICS1*) PURE;
    STDMETHOD_(void, GetCaretMetrics)(THIS_ DWRITE_CARET_METRICS*) PURE;
    STDMETHOD(GetUnicodeRanges)(THIS_ UINT32, DWRITE_UNICODE_RANGE*,UINT32*) PURE;
    STDMETHOD_(BOOL, IsMonospacedFont)(THIS) PURE;
    STDMETHOD(GetDesignGlyphAdvances)(THIS_ UINT32,UINT16 const*,INT32*,BOOL isSideways __MINGW_DEF_ARG_VAL(FALSE)) PURE;
    STDMETHOD(GetGdiCompatibleGlyphAdvances)(THIS_ FLOAT,FLOAT,DWRITE_MATRIX const*,BOOL,BOOL,UINT32,
            UINT16 const*,INT32*) PURE;
    STDMETHOD(GetKerningPairAdjustments)(THIS_ UINT32,UINT16 const*,INT32*) PURE;
    STDMETHOD_(BOOL, HasKerningPairs)(THIS);
    STDMETHOD(GetRecommendedRenderingMode)(FLOAT,FLOAT,FLOAT,DWRITE_MATRIX const*,BOOL,
            DWRITE_OUTLINE_THRESHOLD,DWRITE_MEASURING_MODE,DWRITE_RENDERING_MODE*) PURE;
    STDMETHOD(GetVerticalGlyphVariants)(THIS_ UINT32,UINT16 const*,UINT16*);
    STDMETHOD_(BOOL, HasVerticalGlyphVariants)(THIS);
#endif

    /* IDWriteFontFace2 methods */
    STDMETHOD_(BOOL, IsColorFont)(THIS) PURE;
    STDMETHOD_(UINT32, GetColorPaletteCount)(THIS) PURE;
    STDMETHOD_(UINT32, GetPaletteEntryCount)(THIS) PURE;
        STDMETHOD(GetPaletteEntries)(THIS_
        UINT32 colorPaletteIndex,
        UINT32 firstEntryIndex,
        UINT32 entryCount,
        DWRITE_COLOR_F* paletteEntries
        ) PURE;

    STDMETHOD(GetRecommendedRenderingMode)(THIS_
        FLOAT fontEmSize,
        FLOAT dpiX,
        FLOAT dpiY,
        DWRITE_MATRIX const* transform,
        BOOL isSideways,
        DWRITE_OUTLINE_THRESHOLD outlineThreshold,
        DWRITE_MEASURING_MODE measuringMode,
        IDWriteRenderingParams* renderingParams,
        DWRITE_RENDERING_MODE* renderingMode,
        DWRITE_GRID_FIT_MODE* gridFitMode
        ) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFontFace2, 0xd8b768ff,0x64bc,0x4e66,0x98,0x2b,0xec,0x8e,0x87,0xf6,0x93,0xf7)

#endif /* DWRITE_2_H_INCLUDED */
