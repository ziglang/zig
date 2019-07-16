/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef DWRITE_3_H_INCLUDED
#define DWRITE_3_H_INCLUDED

#include <dwrite_2.h>

#define DWRITE_MAKE_FONT_AXIS_TAG(a,b,c,d) \
    (static_cast<DWRITE_FONT_AXIS_TAG>(DWRITE_MAKE_OPENTYPE_TAG(a,b,c,d)))

enum DWRITE_RENDERING_MODE1 {
    DWRITE_RENDERING_MODE1_DEFAULT = DWRITE_RENDERING_MODE_DEFAULT,
    DWRITE_RENDERING_MODE1_ALIASED = DWRITE_RENDERING_MODE_ALIASED,
    DWRITE_RENDERING_MODE1_GDI_CLASSIC = DWRITE_RENDERING_MODE_GDI_CLASSIC,
    DWRITE_RENDERING_MODE1_GDI_NATURAL = DWRITE_RENDERING_MODE_GDI_NATURAL,
    DWRITE_RENDERING_MODE1_NATURAL = DWRITE_RENDERING_MODE_NATURAL,
    DWRITE_RENDERING_MODE1_NATURAL_SYMMETRIC = DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC,
    DWRITE_RENDERING_MODE1_OUTLINE = DWRITE_RENDERING_MODE_OUTLINE,
    DWRITE_RENDERING_MODE1_NATURAL_SYMMETRIC_DOWNSAMPLED
};

enum DWRITE_FONT_AXIS_TAG : UINT32 {
    DWRITE_FONT_AXIS_TAG_WEIGHT       = DWRITE_MAKE_FONT_AXIS_TAG('w','g','h','t'),
    DWRITE_FONT_AXIS_TAG_WIDTH        = DWRITE_MAKE_FONT_AXIS_TAG('w','d','t','h'),
    DWRITE_FONT_AXIS_TAG_SLANT        = DWRITE_MAKE_FONT_AXIS_TAG('s','l','n','t'),
    DWRITE_FONT_AXIS_TAG_OPTICAL_SIZE = DWRITE_MAKE_FONT_AXIS_TAG('o','p','s','z'),
    DWRITE_FONT_AXIS_TAG_ITALIC       = DWRITE_MAKE_FONT_AXIS_TAG('i','t','a','l')
};

enum DWRITE_FONT_AXIS_ATTRIBUTES {
    DWRITE_FONT_AXIS_ATTRIBUTES_NONE     = 0x0000,
    DWRITE_FONT_AXIS_ATTRIBUTES_VARIABLE = 0x0001,
    DWRITE_FONT_AXIS_ATTRIBUTES_HIDDEN   = 0x0002
};

struct DWRITE_GLYPH_IMAGE_DATA {
    void const *imageData;
    UINT32 imageDataSize;
    UINT32 uniqueDataId;
    UINT32 pixelsPerEm;
    D2D1_SIZE_U pixelSize;
    D2D1_POINT_2L horizontalLeftOrigin;
    D2D1_POINT_2L horizontalRightOrigin;
    D2D1_POINT_2L verticalTopOrigin;
    D2D1_POINT_2L verticalBottomOrigin;
};

struct DWRITE_FONT_AXIS_VALUE {
    DWRITE_FONT_AXIS_TAG axisTag;
    FLOAT value;
};

struct DWRITE_FONT_AXIS_RANGE {
    DWRITE_FONT_AXIS_TAG axisTag;
    FLOAT minValue;
    FLOAT maxValue;
};

interface IDWriteFontResource;
interface IDWriteFontFaceReference1;
interface IDWriteFontFaceReference;

#undef  INTERFACE
#define INTERFACE IDWriteFontFace3
DECLARE_INTERFACE_(IDWriteFontFace3,IDWriteFontFace2)
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
#endif

    /* IDWriteFontFace3 methods */
    STDMETHOD(GetFontFaceReference)(THIS_ IDWriteFontFaceReference **fontFaceReference) PURE;
    STDMETHOD_(void, GetPanose)(THIS_ DWRITE_PANOSE *panose) PURE;
    STDMETHOD_(DWRITE_FONT_WEIGHT, GetWeight)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STRETCH, GetStretch)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STYLE, GetStyle)(THIS) PURE;
    STDMETHOD(GetFamilyNames)(THIS_ IDWriteLocalizedStrings **names) PURE;
    STDMETHOD(GetFaceNames)(THIS_ IDWriteLocalizedStrings **names) PURE;
    STDMETHOD(GetInformationalStrings)(THIS_ DWRITE_INFORMATIONAL_STRING_ID informationalStringID,
        IDWriteLocalizedStrings **informationalStrings, BOOL *exists) PURE;
    STDMETHOD_(BOOL, HasCharacter)(THIS_ UINT32 unicodeValue) PURE;
    STDMETHOD(GetRecommendedRenderingMode)(THIS_ FLOAT fontEmSize, FLOAT dpiX, FLOAT dpiY,
        DWRITE_MATRIX const *transform, BOOL isSideways, DWRITE_OUTLINE_THRESHOLD outlineThreshold,
        DWRITE_MEASURING_MODE measuringMode, IDWriteRenderingParams *renderingParams,
        DWRITE_RENDERING_MODE1 *renderingMode, DWRITE_GRID_FIT_MODE *gridFitMode) PURE;

#ifdef __cplusplus
    using IDWriteFontFace2::GetRecommendedRenderingMode;
#endif

    STDMETHOD_(BOOL, IsCharacterLocal)(THIS_ UINT32 unicodeValue) PURE;
    STDMETHOD_(BOOL, IsGlyphLocal)(THIS_ UINT16 glyphId) PURE;
    STDMETHOD(AreCharactersLocal)(THIS_ WCHAR const *characters, UINT32 characterCount,
        BOOL enqueueIfNotLocal, BOOL *isLocal) PURE;
    STDMETHOD(AreGlyphsLocal)(THIS_ UINT16 const *glyphIndices, UINT32 glyphCount,
        BOOL enqueueIfNotLocal, BOOL *isLocal) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFontFace3, 0xd37d7598,0x09be,0x4222,0xa2,0x36,0x20,0x81,0x34,0x1c,0xc1,0xf2)

#undef  INTERFACE
#define INTERFACE IDWriteFontFace4
DECLARE_INTERFACE_(IDWriteFontFace4,IDWriteFontFace3)
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

    /* IDWriteFontFace3 methods */
    STDMETHOD(GetFontFaceReference)(THIS_ IDWriteFontFaceReference **fontFaceReference) PURE;
    STDMETHOD_(void, GetPanose)(THIS_ DWRITE_PANOSE *panose) PURE;
    STDMETHOD_(DWRITE_FONT_WEIGHT, GetWeight)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STRETCH, GetStretch)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STYLE, GetStyle)(THIS) PURE;
    STDMETHOD(GetFamilyNames)(THIS_ IDWriteLocalizedStrings **names) PURE;
    STDMETHOD(GetFaceNames)(THIS_ IDWriteLocalizedStrings **names) PURE;
    STDMETHOD(GetInformationalStrings)(THIS_ DWRITE_INFORMATIONAL_STRING_ID informationalStringID,
        IDWriteLocalizedStrings **informationalStrings, BOOL *exists) PURE;
    STDMETHOD_(BOOL, HasCharacter)(THIS_ UINT32 unicodeValue) PURE;
    STDMETHOD(GetRecommendedRenderingMode)(THIS_ FLOAT fontEmSize, FLOAT dpiX, FLOAT dpiY,
        DWRITE_MATRIX const *transform, BOOL isSideways, DWRITE_OUTLINE_THRESHOLD outlineThreshold,
        DWRITE_MEASURING_MODE measuringMode, IDWriteRenderingParams *renderingParams,
        DWRITE_RENDERING_MODE1 *renderingMode, DWRITE_GRID_FIT_MODE *gridFitMode) PURE;
    STDMETHOD_(BOOL, IsCharacterLocal)(THIS_ UINT32 unicodeValue) PURE;
    STDMETHOD_(BOOL, IsGlyphLocal)(THIS_ UINT16 glyphId) PURE;
    STDMETHOD(AreCharactersLocal)(THIS_ WCHAR const *characters, UINT32 characterCount,
        BOOL enqueueIfNotLocal, BOOL *isLocal) PURE;
    STDMETHOD(AreGlyphsLocal)(THIS_ UINT16 const *glyphIndices, UINT32 glyphCount,
        BOOL enqueueIfNotLocal, BOOL *isLocal) PURE;
#endif

    /* IDWriteFontFace4 methods */
    STDMETHOD_(DWRITE_GLYPH_IMAGE_FORMATS, GetGlyphImageFormats)(THIS) PURE;
    STDMETHOD(GetGlyphImageFormats)(THIS_ UINT16 glyphId, UINT32 pixelsPerEmFirst,
        UINT32 pixelsPerEmLast, DWRITE_GLYPH_IMAGE_FORMATS *glyphImageFormats) PURE;
    STDMETHOD(GetGlyphImageData)(THIS_ UINT16 glyphId, UINT32 pixelsPerEm,
        DWRITE_GLYPH_IMAGE_FORMATS glyphImageFormat, DWRITE_GLYPH_IMAGE_DATA *glyphData,
        void **glyphDataContext) PURE;
    STDMETHOD_(void, ReleaseGlyphImageData)(THIS_ void *glyphDataContext) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFontFace4, 0x27f2a904,0x4eb8,0x441d,0x96,0x78,0x05,0x63,0xf5,0x3e,0x3e,0x2f)

#undef  INTERFACE
#define INTERFACE IDWriteFontFace5
DECLARE_INTERFACE_(IDWriteFontFace5,IDWriteFontFace4)
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

    /* IDWriteFontFace3 methods */
    STDMETHOD(GetFontFaceReference)(THIS_ IDWriteFontFaceReference **fontFaceReference) PURE;
    STDMETHOD_(void, GetPanose)(THIS_ DWRITE_PANOSE *panose) PURE;
    STDMETHOD_(DWRITE_FONT_WEIGHT, GetWeight)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STRETCH, GetStretch)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STYLE, GetStyle)(THIS) PURE;
    STDMETHOD(GetFamilyNames)(THIS_ IDWriteLocalizedStrings **names) PURE;
    STDMETHOD(GetFaceNames)(THIS_ IDWriteLocalizedStrings **names) PURE;
    STDMETHOD(GetInformationalStrings)(THIS_ DWRITE_INFORMATIONAL_STRING_ID informationalStringID,
        IDWriteLocalizedStrings **informationalStrings, BOOL *exists) PURE;
    STDMETHOD_(BOOL, HasCharacter)(THIS_ UINT32 unicodeValue) PURE;
    STDMETHOD(GetRecommendedRenderingMode)(THIS_ FLOAT fontEmSize, FLOAT dpiX, FLOAT dpiY,
        DWRITE_MATRIX const *transform, BOOL isSideways, DWRITE_OUTLINE_THRESHOLD outlineThreshold,
        DWRITE_MEASURING_MODE measuringMode, IDWriteRenderingParams *renderingParams,
        DWRITE_RENDERING_MODE1 *renderingMode, DWRITE_GRID_FIT_MODE *gridFitMode) PURE;
    STDMETHOD_(BOOL, IsCharacterLocal)(THIS_ UINT32 unicodeValue) PURE;
    STDMETHOD_(BOOL, IsGlyphLocal)(THIS_ UINT16 glyphId) PURE;
    STDMETHOD(AreCharactersLocal)(THIS_ WCHAR const *characters, UINT32 characterCount,
        BOOL enqueueIfNotLocal, BOOL *isLocal) PURE;
    STDMETHOD(AreGlyphsLocal)(THIS_ UINT16 const *glyphIndices, UINT32 glyphCount,
        BOOL enqueueIfNotLocal, BOOL *isLocal) PURE;

    /* IDWriteFontFace4 methods */
    STDMETHOD_(DWRITE_GLYPH_IMAGE_FORMATS, GetGlyphImageFormats)(THIS) PURE;
    STDMETHOD(GetGlyphImageFormats)(THIS_ UINT16 glyphId, UINT32 pixelsPerEmFirst,
        UINT32 pixelsPerEmLast, DWRITE_GLYPH_IMAGE_FORMATS *glyphImageFormats) PURE;
    STDMETHOD(GetGlyphImageData)(THIS_ UINT16 glyphId, UINT32 pixelsPerEm,
        DWRITE_GLYPH_IMAGE_FORMATS glyphImageFormat, DWRITE_GLYPH_IMAGE_DATA *glyphData,
        void **glyphDataContext) PURE;
    STDMETHOD_(void, ReleaseGlyphImageData)(THIS_ void *glyphDataContext) PURE;
#endif

    /* IDWriteFontFace5 methods */
    STDMETHOD_(UINT32, GetFontAxisValueCount)(THIS) PURE;
    STDMETHOD(GetFontAxisValues)(THIS_ DWRITE_FONT_AXIS_VALUE *fontAxisValues,
        UINT32 fontAxisValueCount) PURE;
    STDMETHOD_(BOOL, HasVariations)(THIS) PURE;
    STDMETHOD(GetFontResource)(THIS_ IDWriteFontResource **fontResource) PURE;
    STDMETHOD_(BOOL, Equals)(THIS_ IDWriteFontFace *fontFace) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFontFace5, 0x98eff3a5,0xb667,0x479a,0xb1,0x45,0xe2,0xfa,0x5b,0x9f,0xdc,0x29)

#undef  INTERFACE
#define INTERFACE IDWriteFontResource
DECLARE_INTERFACE_(IDWriteFontResource,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    STDMETHOD(GetFontFile)(THIS_ IDWriteFontFile **fontFile) PURE;
    STDMETHOD_(UINT32, GetFontFaceIndex)(THIS) PURE;
    STDMETHOD_(UINT32, GetFontAxisCount)(THIS) PURE;
    STDMETHOD(GetDefaultFontAxisValues)(THIS_ DWRITE_FONT_AXIS_VALUE *fontAxisValues,
        UINT32 fontAxisValueCount) PURE;
    STDMETHOD(GetFontAxisRanges)(THIS_ DWRITE_FONT_AXIS_RANGE *fontAxisRanges,
        UINT32 fontAxisRangeCount) PURE;
    STDMETHOD_(DWRITE_FONT_AXIS_ATTRIBUTES, GetFontAxisAttributes)(THIS_ UINT32 axisIndex) PURE;
    STDMETHOD(GetAxisNames)(THIS_ UINT32 axisIndex, IDWriteLocalizedStrings **names) PURE;
    STDMETHOD_(UINT32, GetAxisValueNameCount)(THIS_ UINT32 axisIndex) PURE;
    STDMETHOD(GetAxisValueNames)(THIS_ UINT32 axisIndex, UINT32 axisValueIndex,
        DWRITE_FONT_AXIS_RANGE* fontAxisRange, IDWriteLocalizedStrings **names) PURE;
    STDMETHOD_(BOOL, HasVariations)(THIS) PURE;
    STDMETHOD(CreateFontFace)(THIS_ DWRITE_FONT_SIMULATIONS fontSimulations,
        DWRITE_FONT_AXIS_VALUE const *fontAxisValues, UINT32 fontAxisValueCount,
        IDWriteFontFace5 **fontFace) PURE;
    STDMETHOD(CreateFontFaceReference)(THIS_ DWRITE_FONT_SIMULATIONS fontSimulations,
        DWRITE_FONT_AXIS_VALUE const *fontAxisValues, UINT32 fontAxisValueCount,
        IDWriteFontFaceReference1 **fontFaceReference) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFontResource, 0x1f803a76,0x6871,0x48e8,0x98,0x7f,0xb9,0x75,0x55,0x1c,0x50,0xf2)


#endif /* DWRITE_3_H_INCLUDED */
