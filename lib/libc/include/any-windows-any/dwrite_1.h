/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef DWRITE_1_H_INCLUDED
#define DWRITE_1_H_INCLUDED

#include <dwrite.h>

enum DWRITE_OUTLINE_THRESHOLD {
    DWRITE_OUTLINE_THRESHOLD_ANTIALIASED,
    DWRITE_OUTLINE_THRESHOLD_ALIASED
};

enum DWRITE_BASELINE
{
    DWRITE_BASELINE_DEFAULT,
    DWRITE_BASELINE_ROMAN,
    DWRITE_BASELINE_CENTRAL,
    DWRITE_BASELINE_MATH,
    DWRITE_BASELINE_HANGING,
    DWRITE_BASELINE_IDEOGRAPHIC_BOTTOM,
    DWRITE_BASELINE_IDEOGRAPHIC_TOP,
    DWRITE_BASELINE_MINIMUM,
    DWRITE_BASELINE_MAXIMUM,
};

enum DWRITE_GLYPH_ORIENTATION_ANGLE
{
    DWRITE_GLYPH_ORIENTATION_ANGLE_0_DEGREES,
    DWRITE_GLYPH_ORIENTATION_ANGLE_90_DEGREES,
    DWRITE_GLYPH_ORIENTATION_ANGLE_180_DEGREES,
    DWRITE_GLYPH_ORIENTATION_ANGLE_270_DEGREES,
};

enum DWRITE_TEXT_ANTIALIAS_MODE
{
    DWRITE_TEXT_ANTIALIAS_MODE_CLEARTYPE,
    DWRITE_TEXT_ANTIALIAS_MODE_GRAYSCALE
};

struct DWRITE_CARET_METRICS {
    INT16 slopeRise;
    INT16 slopeRun;
    INT16 offset;
};

struct DWRITE_UNICODE_RANGE {
    UINT32 first;
    UINT32 last;
};

struct DWRITE_FONT_METRICS1 : public DWRITE_FONT_METRICS {
    INT16 glyphBoxLeft;
    INT16 glyphBoxTop;
    INT16 glyphBoxRight;
    INT16 glyphBoxBottom;
    INT16 subscriptPositionX;
    INT16 subscriptPositionY;
    INT16 subscriptSizeX;
    INT16 subscriptSizeY;
    INT16 superscriptPositionX;
    INT16 superscriptPositionY;
    INT16 superscriptSizeX;
    INT16 superscriptSizeY;
    BOOL hasTypographicMetrics;
};

struct DWRITE_SCRIPT_PROPERTIES
{
    UINT32 isoScriptCode;
    UINT32 isoScriptNumber;
    UINT32 clusterLookahead;
    UINT32 justificationCharacter;
    UINT32 restrictCaretToClusters      : 1;
    UINT32 usesWordDividers             : 1;
    UINT32 isDiscreteWriting            : 1;
    UINT32 isBlockWriting               : 1;
    UINT32 isDistributedWithinCluster   : 1;
    UINT32 isConnectedWriting           : 1;
    UINT32 isCursiveWriting             : 1;
    UINT32 reserved                     : 25;
};

struct DWRITE_JUSTIFICATION_OPPORTUNITY
{
    FLOAT expansionMinimum;
    FLOAT expansionMaximum;
    FLOAT compressionMaximum;
    UINT32 expansionPriority         : 8;
    UINT32 compressionPriority       : 8;
    UINT32 allowResidualExpansion    : 1;
    UINT32 allowResidualCompression  : 1;
    UINT32 applyToLeadingEdge        : 1;
    UINT32 applyToTrailingEdge       : 1;
    UINT32 reserved                  : 12;
};

union DWRITE_PANOSE {
    UINT8 values[10];
    UINT8 familyKind;
    struct {
        UINT8 familyKind;
        UINT8 serifStyle;
        UINT8 weight;
        UINT8 proportion;
        UINT8 contrast;
        UINT8 strokeVariation;
        UINT8 armStyle;
        UINT8 letterform;
        UINT8 midline;
        UINT8 xHeight;
    } text;
    struct {
        UINT8 familyKind;
        UINT8 toolKind;
        UINT8 weight;
        UINT8 spacing;
        UINT8 aspectRatio;
        UINT8 contrast;
        UINT8 scriptTopology;
        UINT8 scriptForm;
        UINT8 finials;
        UINT8 xAscent;
    } script;
    struct {
        UINT8 familyKind;
        UINT8 decorativeClass;
        UINT8 weight;
        UINT8 aspect;
        UINT8 contrast;
        UINT8 serifVariant;
        UINT8 fill;
        UINT8 lining;
        UINT8 decorativeTopology;
        UINT8 characterRange;
    } decorative;
    struct {
        UINT8 familyKind;
        UINT8 symbolKind;
        UINT8 weight;
        UINT8 spacing;
        UINT8 aspectRatioAndContrast;
        UINT8 aspectRatio94;
        UINT8 aspectRatio119;
        UINT8 aspectRatio157;
        UINT8 aspectRatio163;
        UINT8 aspectRatio211;
    } symbol;
};

#undef  INTERFACE
#define INTERFACE IDWriteFontCollection
DECLARE_INTERFACE_(IDWriteFontFace1, IDWriteFontFace)
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
#endif

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
};

__CRT_UUID_DECL(IDWriteFontFace1, 0xa71efdb4,0x9fdb,0x4838,0xad,0x90,0xcf,0xc3,0xbe,0x8c,0x3d,0xaf);

#undef  INTERFACE
#define INTERFACE IDWriteRenderingParams1
DECLARE_INTERFACE_(IDWriteRenderingParams1,IDWriteRenderingParams)
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
#endif

    /* IDWriteRenderingParams1 methods */
    STDMETHOD_(FLOAT, GetGrayscaleEnhancedContrast)(THIS) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteRenderingParams1, 0x94413cf4,0xa6fc,0x4248,0x8b,0x50,0x66,0x74,0x34,0x8f,0xca,0xd3)

interface IDWriteTextAnalysisSource1;
interface IDWriteTextAnalysisSink1;
interface IDWriteRenderingParams1;

#undef  INTERFACE
#define INTERFACE IDWriteTextAnalyzer1
DECLARE_INTERFACE_(IDWriteTextAnalyzer1,IDWriteTextAnalyzer)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWriteTextAnalyzer methods */
    STDMETHOD(AnalyzeScript)(THIS_
        IDWriteTextAnalysisSource* analysisSource,
        UINT32 textPosition,
        UINT32 textLength,
        IDWriteTextAnalysisSink *analysisSink) PURE;

    STDMETHOD(AnalyzeBidi)(THIS_
        IDWriteTextAnalysisSource *analysisSource,
        UINT32 textPosition,
        UINT32 textLength,
        IDWriteTextAnalysisSink *analysisSink) PURE;

    STDMETHOD(AnalyzeNumberSubstitution)(THIS_
        IDWriteTextAnalysisSource *analysisSource,
        UINT32 textPosition,
        UINT32 textLength,
        IDWriteTextAnalysisSink *analysisSink) PURE;

    STDMETHOD(AnalyzeLineBreakpoints)(THIS_
        IDWriteTextAnalysisSource *analysisSource,
        UINT32 textPosition,
        UINT32 textLength,
        IDWriteTextAnalysisSink *analysisSink) PURE;

    STDMETHOD(GetGlyphs)(THIS_
        WCHAR const *textString,
        UINT32 textLength,
        IDWriteFontFace *fontFace,
        WINBOOL isSideways,
        WINBOOL isRightToLeft,
        DWRITE_SCRIPT_ANALYSIS const *scriptAnalysis,
        WCHAR const *localeName,
        IDWriteNumberSubstitution *numberSubstitution,
        DWRITE_TYPOGRAPHIC_FEATURES const **features,
        UINT32 const *featureRangeLengths,
        UINT32 featureRanges,
        UINT32 maxGlyphCount,
        UINT16 *clusterMap,
        DWRITE_SHAPING_TEXT_PROPERTIES *textProps,
        UINT16 *glyphIndices,
        DWRITE_SHAPING_GLYPH_PROPERTIES *glyphProps,
        UINT32 *actualGlyphCount) PURE;

    STDMETHOD(GetGlyphPlacements)(THIS_
        WCHAR const *textString,
        UINT16 const *clusterMap,
        DWRITE_SHAPING_TEXT_PROPERTIES *textProps,
        UINT32 textLength,
        UINT16 const *glyphIndices,
        DWRITE_SHAPING_GLYPH_PROPERTIES const *glyphProps,
        UINT32 glyphCount,
        IDWriteFontFace *fontFace,
        FLOAT fontEmSize,
        WINBOOL isSideways,
        WINBOOL isRightToLeft,
        DWRITE_SCRIPT_ANALYSIS const *scriptAnalysis,
        WCHAR const *localeName,
        DWRITE_TYPOGRAPHIC_FEATURES const **features,
        UINT32 const *featureRangeLengths,
        UINT32 featureRanges,
        FLOAT *glyphAdvances,
        DWRITE_GLYPH_OFFSET *glyphOffsets) PURE;

    STDMETHOD(GetGdiCompatibleGlyphPlacements)(THIS_
        WCHAR const *textString,
        UINT16 const *clusterMap,
        DWRITE_SHAPING_TEXT_PROPERTIES *textProps,
        UINT32 textLength,
        UINT16 const *glyphIndices,
        DWRITE_SHAPING_GLYPH_PROPERTIES const *glyphProps,
        UINT32 glyphCount,
        IDWriteFontFace *fontFace,
        FLOAT fontEmSize,
        FLOAT pixelsPerDip,
        DWRITE_MATRIX const *transform,
        WINBOOL useGdiNatural,
        WINBOOL isSideways,
        WINBOOL isRightToLeft,
        DWRITE_SCRIPT_ANALYSIS const* scriptAnalysis,
        WCHAR const *localeName,
        DWRITE_TYPOGRAPHIC_FEATURES const **features,
        UINT32 const *featureRangeLengths,
        UINT32 featureRanges,
        FLOAT *glyphAdvances,
        DWRITE_GLYPH_OFFSET *glyphOffsets) PURE;
#endif

    /* IDWriteTextAnalyzer1 methods */
    STDMETHOD(ApplyCharacterSpacing)(THIS_
        FLOAT leadingSpacing,
        FLOAT trailingSpacing,
        FLOAT minimumAdvanceWidth,
        UINT32 textLength,
        UINT32 glyphCount,
        UINT16 const* clusterMap,
        FLOAT const* glyphAdvances,
        DWRITE_GLYPH_OFFSET const* glyphOffsets,
        DWRITE_SHAPING_GLYPH_PROPERTIES const* glyphProperties,
        FLOAT* modifiedGlyphAdvances,
        DWRITE_GLYPH_OFFSET* modifiedGlyphOffsets) PURE;

    STDMETHOD(GetBaseline)(THIS_
        IDWriteFontFace* fontFace,
        DWRITE_BASELINE baseline,
        BOOL isVertical,
        BOOL isSimulationAllowed,
        DWRITE_SCRIPT_ANALYSIS scriptAnalysis,
        WCHAR const* localeName,
        INT32* baselineCoordinate,
        BOOL* exists
        ) PURE;

    STDMETHOD(AnalyzeVerticalGlyphOrientation)(
        IDWriteTextAnalysisSource1* analysisSource,
        UINT32 textPosition,
        UINT32 textLength,
        IDWriteTextAnalysisSink1* analysisSink
        ) PURE;

    STDMETHOD(GetGlyphOrientationTransform)(
        DWRITE_GLYPH_ORIENTATION_ANGLE glyphOrientationAngle,
        BOOL isSideways,
        DWRITE_MATRIX* transform
        ) PURE;

    STDMETHOD(GetScriptProperties)(
        DWRITE_SCRIPT_ANALYSIS scriptAnalysis,
        DWRITE_SCRIPT_PROPERTIES* scriptProperties
        ) PURE;

    STDMETHOD(GetTextComplexity)(
        WCHAR const* textString,
        UINT32 textLength,
        IDWriteFontFace* fontFace,
        BOOL* isTextSimple,
        UINT32* textLengthRead,
        UINT16* glyphIndices
        ) PURE;

    STDMETHOD(GetJustificationOpportunities)(
        IDWriteFontFace* fontFace,
        FLOAT fontEmSize,
        DWRITE_SCRIPT_ANALYSIS scriptAnalysis,
        UINT32 textLength,
        UINT32 glyphCount,
        WCHAR const* textString,
        UINT16 const* clusterMap,
        DWRITE_SHAPING_GLYPH_PROPERTIES const* glyphProperties,
        DWRITE_JUSTIFICATION_OPPORTUNITY* justificationOpportunities
        ) PURE;

    STDMETHOD(JustifyGlyphAdvances)(
        FLOAT lineWidth,
        UINT32 glyphCount,
        DWRITE_JUSTIFICATION_OPPORTUNITY const* justificationOpportunities,
        FLOAT const* glyphAdvances,
        DWRITE_GLYPH_OFFSET const* glyphOffsets,
        FLOAT* justifiedGlyphAdvances,
        DWRITE_GLYPH_OFFSET* justifiedGlyphOffsets
        ) PURE;

    STDMETHOD(GetJustifiedGlyphs)(
        IDWriteFontFace* fontFace,
        FLOAT fontEmSize,
        DWRITE_SCRIPT_ANALYSIS scriptAnalysis,
        UINT32 textLength,
        UINT32 glyphCount,
        UINT32 maxGlyphCount,
        UINT16 const* clusterMap,
        UINT16 const* glyphIndices,
        FLOAT const* glyphAdvances,
        FLOAT const* justifiedGlyphAdvances,
        DWRITE_GLYPH_OFFSET const* justifiedGlyphOffsets,
        DWRITE_SHAPING_GLYPH_PROPERTIES const* glyphProperties,
        UINT32* actualGlyphCount,
        UINT16* modifiedClusterMap,
        UINT16* modifiedGlyphIndices,
        FLOAT* modifiedGlyphAdvances,
        DWRITE_GLYPH_OFFSET* modifiedGlyphOffsets
        ) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteTextAnalyzer1, 0x80dad800,0xe21f,0x4e83,0x4e,0xce,0xbf,0xcc,0xe5,0x00,0xdb,0x7c);

#undef  INTERFACE
#define INTERFACE IDWriteFactory1
DECLARE_INTERFACE_(IDWriteFactory1,IDWriteFactory)
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
#endif

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

#ifdef __cplusplus
    using IDWriteFactory::CreateCustomRenderingParams;
#endif

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteFactory1, 0x30572f99,0xdac6,0x41db,0xa1,0x6e,0x04,0x86,0x30,0x7e,0x60,0x6a)

#undef  INTERFACE
#define INTERFACE IDWriteBitmapRenderTarget1
DECLARE_INTERFACE_(IDWriteBitmapRenderTarget1,IDWriteBitmapRenderTarget)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWriteBitmapRenderTarget methods */
    STDMETHOD(DrawGlyphRun)(THIS_
        FLOAT baselineOriginX,
        FLOAT baselineOriginY,
        DWRITE_MEASURING_MODE measuringMode,
        DWRITE_GLYPH_RUN const *glyphRun,
        IDWriteRenderingParams *renderingParams,
        COLORREF textColor,
        RECT *blackBoxRect __MINGW_DEF_ARG_VAL(NULL)) PURE;

    STDMETHOD_(HDC, GetMemoryDC)(THIS) PURE;
    STDMETHOD_(FLOAT, GetPixelsPerDip)(THIS) PURE;

    STDMETHOD(SetPixelsPerDip)(THIS_
        FLOAT pixelsPerDip) PURE;

    STDMETHOD(GetCurrentTransform)(THIS_
        DWRITE_MATRIX* transform) PURE;

    STDMETHOD(SetCurrentTransform)(THIS_
        DWRITE_MATRIX const *transform) PURE;

    STDMETHOD(GetSize)(THIS_
        SIZE *size) PURE;

    STDMETHOD(Resize)(THIS_
        UINT32 width,
        UINT32 height) PURE;

#endif

    STDMETHOD_(DWRITE_TEXT_ANTIALIAS_MODE, GetTextAntialiasMode)(THIS) PURE;

    STDMETHOD(SetTextAntialiasMode)(THIS_
        DWRITE_TEXT_ANTIALIAS_MODE antialiasMode) PURE;

    END_INTERFACE
};

__CRT_UUID_DECL(IDWriteBitmapRenderTarget1, 0x791e8298,0x3ef3,0x4230,0x98,0x80,0xc9,0xbd,0xec,0xc4,0x20,0x64)

#endif /* DWRITE_1_H_INCLUDED */
