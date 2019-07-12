/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INC_DWRITE__
#define __INC_DWRITE__

#define DWRITEAPI DECLSPEC_IMPORT

#include <unknwn.h>

#ifndef DWRITE_DECLARE_INTERFACE
#define DWRITE_DECLARE_INTERFACE(iid) DECLSPEC_UUID(iid) DECLSPEC_NOVTABLE
#endif

#ifndef __IDWriteBitmapRenderTarget_FWD_DEFINED__
#define __IDWriteBitmapRenderTarget_FWD_DEFINED__
typedef struct IDWriteBitmapRenderTarget IDWriteBitmapRenderTarget;
#endif

#ifndef __IDWriteFactory_FWD_DEFINED__
#define __IDWriteFactory_FWD_DEFINED__
typedef struct IDWriteFactory IDWriteFactory;
#endif

#ifndef __IDWriteFont_FWD_DEFINED__
#define __IDWriteFont_FWD_DEFINED__
typedef struct IDWriteFont IDWriteFont;
#endif

#ifndef __IDWriteFontCollection_FWD_DEFINED__
#define __IDWriteFontCollection_FWD_DEFINED__
typedef struct IDWriteFontCollection IDWriteFontCollection;
#endif

#ifndef __IDWriteFontFace_FWD_DEFINED__
#define __IDWriteFontFace_FWD_DEFINED__
typedef struct IDWriteFontFace IDWriteFontFace;
#endif

#ifndef __IDWriteFontFamily_FWD_DEFINED__
#define __IDWriteFontFamily_FWD_DEFINED__
typedef struct IDWriteFontFamily IDWriteFontFamily;
#endif

#ifndef __IDWriteFontList_FWD_DEFINED__
#define __IDWriteFontList_FWD_DEFINED__
typedef struct IDWriteFontList IDWriteFontList;
#endif

#ifndef __IDWriteFontFile_FWD_DEFINED__
#define __IDWriteFontFile_FWD_DEFINED__
typedef struct IDWriteFontFile IDWriteFontFile;
#endif

#ifndef __IDWriteFontFileLoader_FWD_DEFINED__
#define __IDWriteFontFileLoader_FWD_DEFINED__
typedef struct IDWriteFontFileLoader IDWriteFontFileLoader;
#endif

#ifndef __IDWriteFontFileStream_FWD_DEFINED__
#define __IDWriteFontFileStream_FWD_DEFINED__
typedef struct IDWriteFontFileStream IDWriteFontFileStream;
#endif

#ifndef __IDWriteFontCollectionLoader_FWD_DEFINED__
#define __IDWriteFontCollectionLoader_FWD_DEFINED__
typedef struct IDWriteFontCollectionLoader IDWriteFontCollectionLoader;
#endif

#ifndef __IDWriteFontFileEnumerator_FWD_DEFINED__
#define __IDWriteFontFileEnumerator_FWD_DEFINED__
typedef struct IDWriteFontFileEnumerator IDWriteFontFileEnumerator;
#endif

#ifndef __IDWriteGdiInterop_FWD_DEFINED__
#define __IDWriteGdiInterop_FWD_DEFINED__
typedef struct IDWriteGdiInterop IDWriteGdiInterop;
#endif

/* Fixme: MSDN says its a typedef, needs verification */
/* http://msdn.microsoft.com/en-us/library/dd756614%28v=VS.85%29.aspx */
#ifndef __IDWriteGeometrySink_FWD_DEFINED__
#define __IDWriteGeometrySink_FWD_DEFINED__
typedef struct ID2D1SimplifiedGeometrySink IDWriteGeometrySink;
#endif

#ifndef __IDWriteGlyphRunAnalysis_FWD_DEFINED__
#define __IDWriteGlyphRunAnalysis_FWD_DEFINED__
typedef struct IDWriteGlyphRunAnalysis IDWriteGlyphRunAnalysis;
#endif

#ifndef __IDWriteInlineObject_FWD_DEFINED__
#define __IDWriteInlineObject_FWD_DEFINED__
typedef struct IDWriteInlineObject IDWriteInlineObject;
#endif

#ifndef __IDWriteLocalFontFileLoader_FWD_DEFINED__
#define __IDWriteLocalFontFileLoader_FWD_DEFINED__
typedef struct IDWriteLocalFontFileLoader IDWriteLocalFontFileLoader;
#endif

#ifndef __IDWriteLocalizedStrings_FWD_DEFINED__
#define __IDWriteLocalizedStrings_FWD_DEFINED__
typedef struct IDWriteLocalizedStrings IDWriteLocalizedStrings;
#endif

#ifndef __IDWriteNumberSubstitution_FWD_DEFINED__
#define __IDWriteNumberSubstitution_FWD_DEFINED__
typedef struct IDWriteNumberSubstitution IDWriteNumberSubstitution;
#endif

#ifndef __IDWritePixelSnapping_FWD_DEFINED__
#define __IDWritePixelSnapping_FWD_DEFINED__
typedef struct IDWritePixelSnapping IDWritePixelSnapping;
#endif

#ifndef __IDWriteRenderingParams_FWD_DEFINED__
#define __IDWriteRenderingParams_FWD_DEFINED__
typedef struct IDWriteRenderingParams IDWriteRenderingParams;
#endif

#ifndef __IDWriteTextAnalysisSink_FWD_DEFINED__
#define __IDWriteTextAnalysisSink_FWD_DEFINED__
typedef struct IDWriteTextAnalysisSink IDWriteTextAnalysisSink;
#endif

#ifndef __IDWriteTextAnalysisSource_FWD_DEFINED__
#define __IDWriteTextAnalysisSource_FWD_DEFINED__
typedef struct IDWriteTextAnalysisSource IDWriteTextAnalysisSource;
#endif

#ifndef __IDWriteTextAnalyzer_FWD_DEFINED__
#define __IDWriteTextAnalyzer_FWD_DEFINED__
typedef struct IDWriteTextAnalyzer IDWriteTextAnalyzer;
#endif

#ifndef __IDWriteTextFormat_FWD_DEFINED__
#define __IDWriteTextFormat_FWD_DEFINED__
typedef struct IDWriteTextFormat IDWriteTextFormat;
#endif

#ifndef __IDWriteTextLayout_FWD_DEFINED__
#define __IDWriteTextLayout_FWD_DEFINED__
typedef struct IDWriteTextLayout IDWriteTextLayout;
#endif

#ifndef __IDWriteTextRenderer_FWD_DEFINED__
#define __IDWriteTextRenderer_FWD_DEFINED__
typedef struct IDWriteTextRenderer IDWriteTextRenderer;
#endif

#ifndef __IDWriteTypography_FWD_DEFINED__
#define __IDWriteTypography_FWD_DEFINED__
typedef struct IDWriteTypography IDWriteTypography;
#endif

#include <dcommon.h>

typedef enum DWRITE_INFORMATIONAL_STRING_ID {
  DWRITE_INFORMATIONAL_STRING_NONE = 0,
  DWRITE_INFORMATIONAL_STRING_COPYRIGHT_NOTICE,
  DWRITE_INFORMATIONAL_STRING_VERSION_STRINGS,
  DWRITE_INFORMATIONAL_STRING_TRADEMARK,
  DWRITE_INFORMATIONAL_STRING_MANUFACTURER,
  DWRITE_INFORMATIONAL_STRING_DESIGNER,
  DWRITE_INFORMATIONAL_STRING_DESIGNER_URL,
  DWRITE_INFORMATIONAL_STRING_DESCRIPTION,
  DWRITE_INFORMATIONAL_STRING_FONT_VENDOR_URL,
  DWRITE_INFORMATIONAL_STRING_LICENSE_DESCRIPTION,
  DWRITE_INFORMATIONAL_STRING_LICENSE_INFO_URL,
  DWRITE_INFORMATIONAL_STRING_WIN32_FAMILY_NAMES,
  DWRITE_INFORMATIONAL_STRING_WIN32_SUBFAMILY_NAMES,
  DWRITE_INFORMATIONAL_STRING_PREFERRED_FAMILY_NAMES,
  DWRITE_INFORMATIONAL_STRING_PREFERRED_SUBFAMILY_NAMES,
  DWRITE_INFORMATIONAL_STRING_SAMPLE_TEXT,
  DWRITE_INFORMATIONAL_STRING_FULL_NAME,
  DWRITE_INFORMATIONAL_STRING_POSTSCRIPT_NAME,
  DWRITE_INFORMATIONAL_STRING_POSTSCRIPT_CID_NAME
} DWRITE_INFORMATIONAL_STRING_ID;

typedef enum DWRITE_BREAK_CONDITION {
  DWRITE_BREAK_CONDITION_NEUTRAL         = 0,
  DWRITE_BREAK_CONDITION_CAN_BREAK       = 1,
  DWRITE_BREAK_CONDITION_MAY_NOT_BREAK   = 2,
  DWRITE_BREAK_CONDITION_MUST_BREAK      = 3 
} DWRITE_BREAK_CONDITION;

typedef enum DWRITE_FACTORY_TYPE {
  DWRITE_FACTORY_TYPE_SHARED = 0,
  DWRITE_FACTORY_TYPE_ISOLATED 
} DWRITE_FACTORY_TYPE;

typedef enum DWRITE_FLOW_DIRECTION {
  DWRITE_FLOW_DIRECTION_TOP_TO_BOTTOM 
} DWRITE_FLOW_DIRECTION;

typedef enum DWRITE_FONT_FACE_TYPE {
  DWRITE_FONT_FACE_TYPE_CFF = 0,
  DWRITE_FONT_FACE_TYPE_TRUETYPE,
  DWRITE_FONT_FACE_TYPE_TRUETYPE_COLLECTION,
  DWRITE_FONT_FACE_TYPE_TYPE1,
  DWRITE_FONT_FACE_TYPE_VECTOR,
  DWRITE_FONT_FACE_TYPE_BITMAP,
  DWRITE_FONT_FACE_TYPE_UNKNOWN 
} DWRITE_FONT_FACE_TYPE;

typedef enum DWRITE_FONT_FEATURE_TAG {
  DWRITE_FONT_FEATURE_TAG_ALTERNATIVE_FRACTIONS             = 0x63726661,
  DWRITE_FONT_FEATURE_TAG_PETITE_CAPITALS_FROM_CAPITALS     = 0x63703263,
  DWRITE_FONT_FEATURE_TAG_SMALL_CAPITALS_FROM_CAPITALS      = 0x63733263,
  DWRITE_FONT_FEATURE_TAG_CONTEXTUAL_ALTERNATES             = 0x746c6163,
  DWRITE_FONT_FEATURE_TAG_CASE_SENSITIVE_FORMS              = 0x65736163,
  DWRITE_FONT_FEATURE_TAG_GLYPH_COMPOSITION_DECOMPOSITION   = 0x706d6363,
  DWRITE_FONT_FEATURE_TAG_CONTEXTUAL_LIGATURES              = 0x67696c63,
  DWRITE_FONT_FEATURE_TAG_CAPITAL_SPACING                   = 0x70737063,
  DWRITE_FONT_FEATURE_TAG_CONTEXTUAL_SWASH                  = 0x68777363,
  DWRITE_FONT_FEATURE_TAG_CURSIVE_POSITIONING               = 0x73727563,
  DWRITE_FONT_FEATURE_TAG_DISCRETIONARY_LIGATURES           = 0x67696c64,
  DWRITE_FONT_FEATURE_TAG_EXPERT_FORMS                      = 0x74707865,
  DWRITE_FONT_FEATURE_TAG_FRACTIONS                         = 0x63617266,
  DWRITE_FONT_FEATURE_TAG_FULL_WIDTH                        = 0x64697766,
  DWRITE_FONT_FEATURE_TAG_HALF_FORMS                        = 0x666c6168,
  DWRITE_FONT_FEATURE_TAG_HALANT_FORMS                      = 0x6e6c6168,
  DWRITE_FONT_FEATURE_TAG_ALTERNATE_HALF_WIDTH              = 0x746c6168,
  DWRITE_FONT_FEATURE_TAG_HISTORICAL_FORMS                  = 0x74736968,
  DWRITE_FONT_FEATURE_TAG_HORIZONTAL_KANA_ALTERNATES        = 0x616e6b68,
  DWRITE_FONT_FEATURE_TAG_HISTORICAL_LIGATURES              = 0x67696c68,
  DWRITE_FONT_FEATURE_TAG_HALF_WIDTH                        = 0x64697768,
  DWRITE_FONT_FEATURE_TAG_HOJO_KANJI_FORMS                  = 0x6f6a6f68,
  DWRITE_FONT_FEATURE_TAG_JIS04_FORMS                       = 0x3430706a,
  DWRITE_FONT_FEATURE_TAG_JIS78_FORMS                       = 0x3837706a,
  DWRITE_FONT_FEATURE_TAG_JIS83_FORMS                       = 0x3338706a,
  DWRITE_FONT_FEATURE_TAG_JIS90_FORMS                       = 0x3039706a,
  DWRITE_FONT_FEATURE_TAG_KERNING                           = 0x6e72656b,
  DWRITE_FONT_FEATURE_TAG_STANDARD_LIGATURES                = 0x6167696c,
  DWRITE_FONT_FEATURE_TAG_LINING_FIGURES                    = 0x6d756e6c,
  DWRITE_FONT_FEATURE_TAG_LOCALIZED_FORMS                   = 0x6c636f6c,
  DWRITE_FONT_FEATURE_TAG_MARK_POSITIONING                  = 0x6b72616d,
  DWRITE_FONT_FEATURE_TAG_MATHEMATICAL_GREEK                = 0x6b72676d,
  DWRITE_FONT_FEATURE_TAG_MARK_TO_MARK_POSITIONING          = 0x6b6d6b6d,
  DWRITE_FONT_FEATURE_TAG_ALTERNATE_ANNOTATION_FORMS        = 0x746c616e,
  DWRITE_FONT_FEATURE_TAG_NLC_KANJI_FORMS                   = 0x6b636c6e,
  DWRITE_FONT_FEATURE_TAG_OLD_STYLE_FIGURES                 = 0x6d756e6f,
  DWRITE_FONT_FEATURE_TAG_ORDINALS                          = 0x6e64726f,
  DWRITE_FONT_FEATURE_TAG_PROPORTIONAL_ALTERNATE_WIDTH      = 0x746c6170,
  DWRITE_FONT_FEATURE_TAG_PETITE_CAPITALS                   = 0x70616370,
  DWRITE_FONT_FEATURE_TAG_PROPORTIONAL_FIGURES              = 0x6d756e70,
  DWRITE_FONT_FEATURE_TAG_PROPORTIONAL_WIDTHS               = 0x64697770,
  DWRITE_FONT_FEATURE_TAG_QUARTER_WIDTHS                    = 0x64697771,
  DWRITE_FONT_FEATURE_TAG_REQUIRED_LIGATURES                = 0x67696c72,
  DWRITE_FONT_FEATURE_TAG_RUBY_NOTATION_FORMS               = 0x79627572,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_ALTERNATES              = 0x746c6173,
  DWRITE_FONT_FEATURE_TAG_SCIENTIFIC_INFERIORS              = 0x666e6973,
  DWRITE_FONT_FEATURE_TAG_SMALL_CAPITALS                    = 0x70636d73,
  DWRITE_FONT_FEATURE_TAG_SIMPLIFIED_FORMS                  = 0x6c706d73,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_1                   = 0x31307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_2                   = 0x32307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_3                   = 0x33307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_4                   = 0x34307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_5                   = 0x35307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_6                   = 0x36307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_7                   = 0x37307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_8                   = 0x38307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_9                   = 0x39307373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_10                  = 0x30317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_11                  = 0x31317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_12                  = 0x32317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_13                  = 0x33317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_14                  = 0x34317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_15                  = 0x35317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_16                  = 0x36317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_17                  = 0x37317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_18                  = 0x38317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_19                  = 0x39317373,
  DWRITE_FONT_FEATURE_TAG_STYLISTIC_SET_20                  = 0x30327373,
  DWRITE_FONT_FEATURE_TAG_SUBSCRIPT                         = 0x73627573,
  DWRITE_FONT_FEATURE_TAG_SUPERSCRIPT                       = 0x73707573,
  DWRITE_FONT_FEATURE_TAG_SWASH                             = 0x68737773,
  DWRITE_FONT_FEATURE_TAG_TITLING                           = 0x6c746974,
  DWRITE_FONT_FEATURE_TAG_TRADITIONAL_NAME_FORMS            = 0x6d616e74,
  DWRITE_FONT_FEATURE_TAG_TABULAR_FIGURES                   = 0x6d756e74,
  DWRITE_FONT_FEATURE_TAG_TRADITIONAL_FORMS                 = 0x64617274,
  DWRITE_FONT_FEATURE_TAG_THIRD_WIDTHS                      = 0x64697774,
  DWRITE_FONT_FEATURE_TAG_UNICASE                           = 0x63696e75,
  DWRITE_FONT_FEATURE_TAG_SLASHED_ZERO                      = 0x6f72657a 
} DWRITE_FONT_FEATURE_TAG;

typedef enum DWRITE_FONT_FILE_TYPE {
  DWRITE_FONT_FILE_TYPE_UNKNOWN = 0,
  DWRITE_FONT_FILE_TYPE_CFF,
  DWRITE_FONT_FILE_TYPE_TRUETYPE,
  DWRITE_FONT_FILE_TYPE_TRUETYPE_COLLECTION,
  DWRITE_FONT_FILE_TYPE_TYPE1_PFM,
  DWRITE_FONT_FILE_TYPE_TYPE1_PFB,
  DWRITE_FONT_FILE_TYPE_VECTOR,
  DWRITE_FONT_FILE_TYPE_BITMAP 
} DWRITE_FONT_FILE_TYPE;

typedef enum DWRITE_FONT_SIMULATIONS {
  DWRITE_FONT_SIMULATIONS_NONE      = 0x0000,
  DWRITE_FONT_SIMULATIONS_BOLD      = 0x0001,
  DWRITE_FONT_SIMULATIONS_OBLIQUE   = 0x0002 
} DWRITE_FONT_SIMULATIONS;

#ifdef DEFINE_ENUM_FLAG_OPERATORS
DEFINE_ENUM_FLAG_OPERATORS(DWRITE_FONT_SIMULATIONS);
#endif

typedef enum DWRITE_FONT_STRETCH {
  DWRITE_FONT_STRETCH_UNDEFINED         = 0,
  DWRITE_FONT_STRETCH_ULTRA_CONDENSED   = 1,
  DWRITE_FONT_STRETCH_EXTRA_CONDENSED   = 2,
  DWRITE_FONT_STRETCH_CONDENSED         = 3,
  DWRITE_FONT_STRETCH_SEMI_CONDENSED    = 4,
  DWRITE_FONT_STRETCH_NORMAL            = 5,
  DWRITE_FONT_STRETCH_MEDIUM            = 5,
  DWRITE_FONT_STRETCH_SEMI_EXPANDED     = 6,
  DWRITE_FONT_STRETCH_EXPANDED          = 7,
  DWRITE_FONT_STRETCH_EXTRA_EXPANDED    = 8,
  DWRITE_FONT_STRETCH_ULTRA_EXPANDED    = 9 
} DWRITE_FONT_STRETCH;

typedef enum DWRITE_FONT_STYLE {
  DWRITE_FONT_STYLE_NORMAL = 0,
  DWRITE_FONT_STYLE_OBLIQUE,
  DWRITE_FONT_STYLE_ITALIC 
} DWRITE_FONT_STYLE;

typedef enum DWRITE_FONT_WEIGHT {
  DWRITE_FONT_WEIGHT_THIN          = 100,
  DWRITE_FONT_WEIGHT_EXTRA_LIGHT   = 200,
  DWRITE_FONT_WEIGHT_ULTRA_LIGHT   = 200,
  DWRITE_FONT_WEIGHT_LIGHT         = 300,
  DWRITE_FONT_WEIGHT_NORMAL        = 400,
  DWRITE_FONT_WEIGHT_REGULAR       = 400,
  DWRITE_FONT_WEIGHT_MEDIUM        = 500,
  DWRITE_FONT_WEIGHT_DEMI_BOLD     = 600,
  DWRITE_FONT_WEIGHT_SEMI_BOLD     = 600,
  DWRITE_FONT_WEIGHT_BOLD          = 700,
  DWRITE_FONT_WEIGHT_EXTRA_BOLD    = 800,
  DWRITE_FONT_WEIGHT_ULTRA_BOLD    = 800,
  DWRITE_FONT_WEIGHT_BLACK         = 900,
  DWRITE_FONT_WEIGHT_HEAVY         = 900,
  DWRITE_FONT_WEIGHT_EXTRA_BLACK   = 950,
  DWRITE_FONT_WEIGHT_ULTRA_BLACK   = 950 
} DWRITE_FONT_WEIGHT;

typedef enum DWRITE_LINE_SPACING_METHOD {
  DWRITE_LINE_SPACING_METHOD_DEFAULT = 0,
  DWRITE_LINE_SPACING_METHOD_UNIFORM 
} DWRITE_LINE_SPACING_METHOD;

typedef enum DWRITE_NUMBER_SUBSTITUTION_METHOD {
  DWRITE_NUMBER_SUBSTITUTION_METHOD_FROM_CULTURE = 0,
  DWRITE_NUMBER_SUBSTITUTION_METHOD_CONTEXTUAL,
  DWRITE_NUMBER_SUBSTITUTION_METHOD_NONE,
  DWRITE_NUMBER_SUBSTITUTION_METHOD_NATIONAL,
  DWRITE_NUMBER_SUBSTITUTION_METHOD_TRADITIONAL 
} DWRITE_NUMBER_SUBSTITUTION_METHOD;

typedef enum DWRITE_PARAGRAPH_ALIGNMENT {
  DWRITE_PARAGRAPH_ALIGNMENT_NEAR = 0,
  DWRITE_PARAGRAPH_ALIGNMENT_FAR,
  DWRITE_PARAGRAPH_ALIGNMENT_CENTER 
} DWRITE_PARAGRAPH_ALIGNMENT;

typedef enum DWRITE_PIXEL_GEOMETRY {
  DWRITE_PIXEL_GEOMETRY_FLAT = 0,
  DWRITE_PIXEL_GEOMETRY_RGB,
  DWRITE_PIXEL_GEOMETRY_BGR 
} DWRITE_PIXEL_GEOMETRY;

typedef enum DWRITE_READING_DIRECTION {
  DWRITE_READING_DIRECTION_LEFT_TO_RIGHT = 0,
  DWRITE_READING_DIRECTION_RIGHT_TO_LEFT 
} DWRITE_READING_DIRECTION;

typedef enum DWRITE_RENDERING_MODE {
  DWRITE_RENDERING_MODE_DEFAULT = 0,
  DWRITE_RENDERING_MODE_ALIASED,
  DWRITE_RENDERING_MODE_GDI_CLASSIC,
  DWRITE_RENDERING_MODE_GDI_NATURAL,
  DWRITE_RENDERING_MODE_NATURAL,
  DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC,
  DWRITE_RENDERING_MODE_OUTLINE,
  DWRITE_RENDERING_MODE_CLEARTYPE_GDI_CLASSIC       = DWRITE_RENDERING_MODE_GDI_CLASSIC,
  DWRITE_RENDERING_MODE_CLEARTYPE_GDI_NATURAL       = DWRITE_RENDERING_MODE_GDI_NATURAL,
  DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL           = DWRITE_RENDERING_MODE_NATURAL,
  DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC = DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC
} DWRITE_RENDERING_MODE;

typedef enum DWRITE_SCRIPT_SHAPES {
  DWRITE_SCRIPT_SHAPES_DEFAULT     = 0,
  DWRITE_SCRIPT_SHAPES_NO_VISUAL   = 1 
} DWRITE_SCRIPT_SHAPES;

typedef enum DWRITE_TEXT_ALIGNMENT {
  DWRITE_TEXT_ALIGNMENT_LEADING = 0,
  DWRITE_TEXT_ALIGNMENT_TRAILING,
  DWRITE_TEXT_ALIGNMENT_CENTER 
} DWRITE_TEXT_ALIGNMENT;

typedef enum DWRITE_TEXTURE_TYPE {
  DWRITE_TEXTURE_ALIASED_1x1 = 0,
  DWRITE_TEXTURE_CLEARTYPE_3x1 
} DWRITE_TEXTURE_TYPE;

typedef enum DWRITE_TRIMMING_GRANULARITY {
  DWRITE_TRIMMING_GRANULARITY_NONE,
  DWRITE_TRIMMING_GRANULARITY_CHARACTER,
  DWRITE_TRIMMING_GRANULARITY_WORD 
} DWRITE_TRIMMING_GRANULARITY;

typedef enum DWRITE_WORD_WRAPPING {
  DWRITE_WORD_WRAPPING_WRAP,
  DWRITE_WORD_WRAPPING_NO_WRAP 
} DWRITE_WORD_WRAPPING;

typedef struct _DWRITE_OVERHANG_METRICS {
  FLOAT left;
  FLOAT top;
  FLOAT right;
  FLOAT bottom;
} DWRITE_OVERHANG_METRICS, *PDWRITE_OVERHANG_METRICS;

typedef struct DWRITE_CLUSTER_METRICS {
  FLOAT  width;
  UINT16 length;
  UINT16 canWrapLineAfter  :1;
  UINT16 isWhitespace  :1;
  UINT16 isNewline  :1;
  UINT16 isSoftHyphen  :1;
  UINT16 isRightToLeft  :1;
  UINT16 padding  :11;
} DWRITE_CLUSTER_METRICS;

typedef struct DWRITE_FONT_FEATURE {
  DWRITE_FONT_FEATURE_TAG nameTag;
  UINT32                  parameter;
} DWRITE_FONT_FEATURE;

typedef struct DWRITE_FONT_METRICS {
  UINT16 designUnitsPerEm;
  UINT16 ascent;
  UINT16 descent;
  INT16  lineGap;
  UINT16 capHeight;
  UINT16 xHeight;
  INT16  underlinePosition;
  UINT16 underlineThickness;
  INT16  strikethroughPosition;
  UINT16 strikethroughThickness;
} DWRITE_FONT_METRICS;

typedef struct DWRITE_GLYPH_METRICS {
  INT32  leftSideBearing;
  UINT32 advanceWidth;
  INT32  rightSideBearing;
  INT32  topSideBearing;
  UINT32 advanceHeight;
  INT32  bottomSideBearing;
  INT32  verticalOriginY;
} DWRITE_GLYPH_METRICS;

typedef struct DWRITE_GLYPH_OFFSET {
  FLOAT advanceOffset;
  FLOAT ascenderOffset;
} DWRITE_GLYPH_OFFSET;

typedef struct DWRITE_GLYPH_RUN {
  IDWriteFontFace           *fontFace;
  FLOAT                     fontEmSize;
  UINT32                    glyphCount;
  const UINT16              *glyphIndices;
  const FLOAT               *glyphAdvances;
  const DWRITE_GLYPH_OFFSET *glyphOffsets;
  WINBOOL                   isSideways;
  UINT32                    bidiLevel;
} DWRITE_GLYPH_RUN;

typedef struct DWRITE_GLYPH_RUN_DESCRIPTION {
  const WCHAR  *localeName;
  const WCHAR  *string;
  UINT32       stringLength;
  const UINT16 *clusterMap;
  UINT32       textPosition;
} DWRITE_GLYPH_RUN_DESCRIPTION;

typedef struct DWRITE_HIT_TEST_METRICS {
  UINT32  textPosition;
  UINT32  length;
  FLOAT   left;
  FLOAT   top;
  FLOAT   width;
  FLOAT   height;
  UINT32  bidiLevel;
  WINBOOL isText;
  WINBOOL isTrimmed;
} DWRITE_HIT_TEST_METRICS;

typedef struct DWRITE_INLINE_OBJECT_METRICS {
  FLOAT   width;
  FLOAT   height;
  FLOAT   baseline;
  WINBOOL supportsSideways;
} DWRITE_INLINE_OBJECT_METRICS;

typedef struct DWRITE_LINE_BREAKPOINT {
  UINT8 breakConditionBefore  :2;
  UINT8 breakConditionAfter  :2;
  UINT8 isWhitespace  :1;
  UINT8 isSoftHyphen  :1;
  UINT8 padding  :2;
} DWRITE_LINE_BREAKPOINT;

typedef struct DWRITE_LINE_METRICS {
  UINT32  length;
  UINT32  trailingWhitespaceLength;
  UINT32  newlineLength;
  FLOAT   height;
  FLOAT   baseline;
  WINBOOL isTrimmed;
} DWRITE_LINE_METRICS;

typedef struct DWRITE_MATRIX {
  FLOAT m11;
  FLOAT m12;
  FLOAT m21;
  FLOAT m22;
  FLOAT dx;
  FLOAT dy;
} DWRITE_MATRIX;

typedef struct DWRITE_SCRIPT_ANALYSIS {
  UINT16               script;
  DWRITE_SCRIPT_SHAPES shapes;
} DWRITE_SCRIPT_ANALYSIS;

typedef struct DWRITE_SHAPING_GLYPH_PROPERTIES {
  UINT16 justification  :4;
  UINT16 isClusterStart  :1;
  UINT16 isDiacritic  :1;
  UINT16 isZeroWidthSpace  :1;
  UINT16 reserved  :9;
} DWRITE_SHAPING_GLYPH_PROPERTIES;

typedef struct DWRITE_SHAPING_TEXT_PROPERTIES {
  UINT16 isShapedAlone  :1;
  UINT16 reserved  :15;
} DWRITE_SHAPING_TEXT_PROPERTIES;

typedef struct DWRITE_STRIKETHROUGH {
  FLOAT                    width;
  FLOAT                    thickness;
  FLOAT                    offset;
  DWRITE_READING_DIRECTION readingDirection;
  DWRITE_FLOW_DIRECTION    flowDirection;
  const WCHAR              *localeName;
  DWRITE_MEASURING_MODE    measuringMode;
} DWRITE_STRIKETHROUGH;

typedef struct DWRITE_TEXT_METRICS {
  FLOAT  left;
  FLOAT  top;
  FLOAT  width;
  FLOAT  widthIncludingTrailingWhitespace;
  FLOAT  height;
  FLOAT  layoutWidth;
  FLOAT  layoutHeight;
  UINT32 maxBidiReorderingDepth;
  UINT32 lineCount;
} DWRITE_TEXT_METRICS;

typedef struct DWRITE_TEXT_RANGE {
  UINT32 startPosition;
  UINT32 length;
} DWRITE_TEXT_RANGE;

typedef struct DWRITE_TRIMMING {
  DWRITE_TRIMMING_GRANULARITY granularity;
  UINT32                      delimiter;
  UINT32                      delimiterCount;
} DWRITE_TRIMMING;

typedef struct DWRITE_TYPOGRAPHIC_FEATURES {
  DWRITE_FONT_FEATURE *features;
  UINT32              featureCount;
} DWRITE_TYPOGRAPHIC_FEATURES;

typedef struct DWRITE_UNDERLINE {
  FLOAT                    width;
  FLOAT                    thickness;
  FLOAT                    offset;
  FLOAT                    runHeight;
  DWRITE_READING_DIRECTION readingDirection;
  DWRITE_FLOW_DIRECTION    flowDirection;
  const WCHAR              *localeName;
  DWRITE_MEASURING_MODE    measuringMode;
} DWRITE_UNDERLINE;

#define DWRITE_MAKE_OPENTYPE_TAG(a,b,c,d) ( \
    (static_cast<UINT32>(static_cast<UINT8>(d)) << 24) | \
    (static_cast<UINT32>(static_cast<UINT8>(c)) << 16) | \
    (static_cast<UINT32>(static_cast<UINT8>(b)) << 8) | \
     static_cast<UINT32>(static_cast<UINT8>(a)))

#ifndef __MINGW_DEF_ARG_VAL
#ifdef __cplusplus
#define __MINGW_DEF_ARG_VAL(x) = x
#else
#define __MINGW_DEF_ARG_VAL(x)
#endif
#endif

#undef  INTERFACE
#define INTERFACE IDWriteBitmapRenderTarget
DECLARE_INTERFACE_(IDWriteBitmapRenderTarget,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

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

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteBitmapRenderTarget_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteBitmapRenderTarget_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteBitmapRenderTarget_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteBitmapRenderTarget_DrawGlyphRun(This,baselineOriginX,baselineOriginY,measuringMode,glyphRun,renderingParams,textColor,blackBoxRect) (This)->lpVtbl->DrawGlyphRun(This,baselineOriginX,baselineOriginY,measuringMode,glyphRun,renderingParams,textColor,blackBoxRect)
#define IDWriteBitmapRenderTarget_GetCurrentTransform(This,transform) (This)->lpVtbl->GetCurrentTransform(This,transform)
#define IDWriteBitmapRenderTarget_GetMemoryDC() (This)->lpVtbl->GetMemoryDC(This)
#define IDWriteBitmapRenderTarget_GetPixelsPerDip() (This)->lpVtbl->GetPixelsPerDip(This)
#define IDWriteBitmapRenderTarget_GetSize(This,size) (This)->lpVtbl->GetSize(This,size)
#define IDWriteBitmapRenderTarget_Resize(This,width,height) (This)->lpVtbl->Resize(This,width,height)
#define IDWriteBitmapRenderTarget_SetCurrentTransform(This,transform) (This)->lpVtbl->SetCurrentTransform(This,transform)
#define IDWriteBitmapRenderTarget_SetPixelsPerDip(This,pixelsPerDip) (This)->lpVtbl->SetPixelsPerDip(This,pixelsPerDip)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFactory
DECLARE_INTERFACE_(IDWriteFactory,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

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

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFactory_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFactory_CreateCustomFontCollection(This,collectionLoader,collectionKey,collectionKeySize,fontCollection) (This)->lpVtbl->CreateCustomFontCollection(This,collectionLoader,collectionKey,collectionKeySize,fontCollection)
#define IDWriteFactory_CreateCustomFontFileReference(This,fontFileReferenceKey,fontFileReferenceKeySize,fontFileLoader,fontFile) (This)->lpVtbl->CreateCustomFontFileReference(This,fontFileReferenceKey,fontFileReferenceKeySize,fontFileLoader,fontFile)
#define IDWriteFactory_CreateCustomRenderingParams(This,gamma,enhancedContrast,clearTypeLevel,pixelGeometry,renderingMode,renderingParams) (This)->lpVtbl->CreateCustomRenderingParams(This,gamma,enhancedContrast,clearTypeLevel,pixelGeometry,renderingMode,renderingParams)
#define IDWriteFactory_CreateGdiCompatibleTextLayout(This,string,stringLength,textFormat,layoutWidth,layoutHeight,pixelsPerDip,transform,useGdiNatural,textLayout) (This)->lpVtbl->CreateGdiCompatibleTextLayout(This,string,stringLength,textFormat,layoutWidth,layoutHeight,pixelsPerDip,transform,useGdiNatural,textLayout)
#define IDWriteFactory_CreateEllipsisTrimmingSign(This,textFormat,trimmingSign) (This)->lpVtbl->CreateEllipsisTrimmingSign(This,textFormat,trimmingSign)
#define IDWriteFactory_CreateFontFace(This,fontFaceType,numberOfFiles,fontFiles,faceIndex,fontFaceSimulationFlags,fontFace) (This)->lpVtbl->CreateFontFace(This,fontFaceType,numberOfFiles,fontFiles,faceIndex,fontFaceSimulationFlags,fontFace)
#define IDWriteFactory_CreateFontFileReference(This,filePath,lastWriteTime,fontFile) (This)->lpVtbl->CreateFontFileReference(This,filePath,lastWriteTime,fontFile)
#define IDWriteFactory_CreateGlyphRunAnalysis(This,glyphRun,pixelsPerDip,transform,renderingMode,measuringMode,baselineOriginX,baselineOriginY,glyphRunAnalysis) (This)->lpVtbl->CreateGlyphRunAnalysis(This,glyphRun,pixelsPerDip,transform,renderingMode,measuringMode,baselineOriginX,baselineOriginY,glyphRunAnalysis)
#define IDWriteFactory_CreateMonitorRenderingParams(This,monitor,renderingParams) (This)->lpVtbl->CreateMonitorRenderingParams(This,monitor,renderingParams)
#define IDWriteFactory_CreateNumberSubstitution(This,substitutionMethod,localeName,ignoreUserOverride,numberSubstitution) (This)->lpVtbl->CreateNumberSubstitution(This,substitutionMethod,localeName,ignoreUserOverride,numberSubstitution)
#define IDWriteFactory_CreateRenderingParams(This,renderingParams) (This)->lpVtbl->CreateRenderingParams(This,renderingParams)
#define IDWriteFactory_CreateTextAnalyzer(This,textAnalyzer) (This)->lpVtbl->CreateTextAnalyzer(This,textAnalyzer)
#define IDWriteFactory_CreateTextFormat(This,fontFamilyName,fontCollection,fontWeight,fontStyle,fontStretch,fontSize,localeName,textFormat) (This)->lpVtbl->CreateTextFormat(This,fontFamilyName,fontCollection,fontWeight,fontStyle,fontStretch,fontSize,localeName,textFormat)
#define IDWriteFactory_CreateTextLayout(This,string,stringLength,textFormat,maxWidth,maxHeight,textLayout) (This)->lpVtbl->CreateTextLayout(This,string,stringLength,textFormat,maxWidth,maxHeight,textLayout)
#define IDWriteFactory_CreateTypography(This,typography) (This)->lpVtbl->CreateTypography(This,typography)
#define IDWriteFactory_GetGdiInterop(This,gdiInterop) (This)->lpVtbl->GetGdiInterop(This,gdiInterop)
#define IDWriteFactory_GetSystemFontCollection(This,fontCollection,checkForUpdates) (This)->lpVtbl->GetSystemFontCollection(This,fontCollection,checkForUpdates)
#define IDWriteFactory_RegisterFontCollectionLoader(This,fontCollectionLoader) (This)->lpVtbl->RegisterFontCollectionLoader(This,fontCollectionLoader)
#define IDWriteFactory_RegisterFontFileLoader(This,fontFileLoader) (This)->lpVtbl->RegisterFontFileLoader(This,fontFileLoader)
#define IDWriteFactory_UnregisterFontCollectionLoader(This,fontCollectionLoader) (This)->lpVtbl->UnregisterFontCollectionLoader(This,fontCollectionLoader)
#define IDWriteFactory_UnregisterFontFileLoader(This,fontFileLoader) (This)->lpVtbl->UnregisterFontFileLoader(This,fontFileLoader)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFont
DECLARE_INTERFACE_(IDWriteFont,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteFont methods */
    STDMETHOD(GetFontFamily)(THIS_
        IDWriteFontFamily **fontFamily) PURE;

    STDMETHOD_(DWRITE_FONT_WEIGHT, GetWeight)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STRETCH, GetStretch)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STYLE, GetStyle)(THIS) PURE;
    STDMETHOD_(WINBOOL, IsSymbolFont)(THIS) PURE;

    STDMETHOD(GetFaceNames)(THIS_
        IDWriteLocalizedStrings **names) PURE;

    STDMETHOD(GetInformationalStrings)(THIS_
        DWRITE_INFORMATIONAL_STRING_ID informationalStringID,
        IDWriteLocalizedStrings **informationalStrings,
        WINBOOL *exists) PURE;

    STDMETHOD_(DWRITE_FONT_SIMULATIONS, GetSimulations)(THIS) PURE;

    STDMETHOD_(void, GetMetrics)(THIS_
        DWRITE_FONT_METRICS *fontMetrics) PURE;

    STDMETHOD(HasCharacter)(THIS_
        UINT32 unicodeValue,
        WINBOOL *exists) PURE;

    STDMETHOD(CreateFontFace)(THIS_
        IDWriteFontFace **fontFace) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFont_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFont_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFont_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFont_CreateFontFace(This,fontFace) (This)->lpVtbl->CreateFontFace(This,fontFace)
#define IDWriteFont_GetFaceNames(This,names) (This)->lpVtbl->GetFaceNames(This,names)
#define IDWriteFont_GetFontFamily(This,fontFamily) (This)->lpVtbl->GetFontFamily(This,fontFamily)
#define IDWriteFont_GetInformationalStrings(This,informationalStringID,informationalStrings,exists) (This)->lpVtbl->GetInformationalStrings(This,informationalStringID,informationalStrings,exists)
#define IDWriteFont_GetMetrics(This,fontMetrics) (This)->lpVtbl->GetMetrics(This,fontMetrics)
#define IDWriteFont_GetSimulations() (This)->lpVtbl->GetSimulations(This)
#define IDWriteFont_GetStretch() (This)->lpVtbl->GetStretch(This)
#define IDWriteFont_GetStyle() (This)->lpVtbl->GetStyle(This)
#define IDWriteFont_GetWeight() (This)->lpVtbl->GetWeight(This)
#define IDWriteFont_HasCharacter(This,unicodeValue,exists) (This)->lpVtbl->HasCharacter(This,unicodeValue,exists)
#define IDWriteFont_IsSymbolFont() (This)->lpVtbl->IsSymbolFont(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontCollection
DECLARE_INTERFACE_(IDWriteFontCollection,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteFontCollection methods */
    STDMETHOD_(UINT32, GetFontFamilyCount)(THIS) PURE;

    STDMETHOD(GetFontFamily)(THIS_
        UINT32 index,
        IDWriteFontFamily **fontFamily) PURE;

    STDMETHOD(FindFamilyName)(THIS_
        WCHAR const *familyName,
        UINT32 *index,
        WINBOOL *exists) PURE;

    STDMETHOD(GetFontFromFontFace)(THIS_
        IDWriteFontFace* fontFace,
        IDWriteFont **font) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontCollection_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontCollection_FindFamilyName(This,familyName,index,exists) (This)->lpVtbl->FindFamilyName(This,familyName,index,exists)
#define IDWriteFontCollection_GetFontFamily(This,index,fontFamily) (This)->lpVtbl->GetFontFamily(This,index,fontFamily)
#define IDWriteFontCollection_GetFontFamilyCount() (This)->lpVtbl->GetFontFamilyCount(This)
#define IDWriteFontCollection_GetFontFromFontFace(This,fontFace,font) (This)->lpVtbl->GetFontFromFontFace(This,fontFace,font)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontFace
DECLARE_INTERFACE_(IDWriteFontFace,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

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

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontFace_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontFace_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontFace_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontFace_GetDesignGlyphMetrics(This,glyphIndices,glyphCount,glyphMetrics,isSideways) (This)->lpVtbl->GetDesignGlyphMetrics(This,glyphIndices,glyphCount,glyphMetrics,isSideways)
#define IDWriteFontFace_GetFiles(This,fontFiles) (This)->lpVtbl->GetFiles(This,fontFiles)
#define IDWriteFontFace_GetGdiCompatibleMetrics(This,emSize,pixelsPerDip,transform,fontFaceMetrics) (This)->lpVtbl->GetGdiCompatibleMetrics(This,emSize,pixelsPerDip,transform,fontFaceMetrics)
#define IDWriteFontFace_GetGdiCompatibleGlyphMetrics(This,emSize,pixelsPerDip,transform,useGdiNatural,glyphIndices,glyphCount,glyphMetrics,isSideways) (This)->lpVtbl->GetGdiCompatibleGlyphMetrics(This,emSize,pixelsPerDip,transform,useGdiNatural,glyphIndices,glyphCount,glyphMetrics,isSideways)
#define IDWriteFontFace_GetGlyphCount() (This)->lpVtbl->GetGlyphCount(This)
#define IDWriteFontFace_GetGlyphIndices(This,codePoints,codePointCount,glyphIndices) (This)->lpVtbl->GetGlyphIndices(This,codePoints,codePointCount,glyphIndices)
#define IDWriteFontFace_GetGlyphRunOutline(This,emSize,glyphIndices,glyphOffsets,glyphCount,isSideways,isRightToLeft,geometrySink) (This)->lpVtbl->GetGlyphRunOutline(This,emSize,glyphIndices,glyphOffsets,glyphCount,isSideways,isRightToLeft,geometrySink)
#define IDWriteFontFace_GetIndex() (This)->lpVtbl->GetIndex(This)
#define IDWriteFontFace_GetMetrics(This,fontFaceMetrics) (This)->lpVtbl->GetMetrics(This,fontFaceMetrics)
#define IDWriteFontFace_GetRecommendedRenderingMode(This,emSize,pixelsPerDip,measuringMode,renderingParams,renderingMode) (This)->lpVtbl->GetRecommendedRenderingMode(This,emSize,pixelsPerDip,measuringMode,renderingParams,renderingMode)
#define IDWriteFontFace_GetSimulations() (This)->lpVtbl->GetSimulations(This)
#define IDWriteFontFace_GetType() (This)->lpVtbl->GetType(This)
#define IDWriteFontFace_IsSymbolFont() (This)->lpVtbl->IsSymbolFont(This)
#define IDWriteFontFace_ReleaseFontTable(This,tableContext) (This)->lpVtbl->ReleaseFontTable(This,tableContext)
#define IDWriteFontFace_TryGetFontTable(This,openTypeTableTag,tableData,tableSize,tableContext,exists) (This)->lpVtbl->TryGetFontTable(This,openTypeTableTag,tableData,tableSize,tableContext,exists)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontList
DECLARE_INTERFACE_(IDWriteFontList,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteFontList methods */
    STDMETHOD(GetFontCollection)(THIS_
        IDWriteFontCollection** fontCollection) PURE;

    STDMETHOD_(UINT32, GetFontCount)(THIS) PURE;

    STDMETHOD(GetFont)(THIS_
        UINT32 index,
        IDWriteFont **font) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontList_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontList_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontList_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontList_GetFont(This,index,font) (This)->lpVtbl->GetFont(This,index,font)
#define IDWriteFontList_GetFontCollection(This,fontCollection) (This)->lpVtbl->GetFontCollection(This,fontCollection)
#define IDWriteFontList_GetFontCount() (This)->lpVtbl->GetFontCount(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontFamily
DECLARE_INTERFACE_(IDWriteFontFamily,IDWriteFontList)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWriteFontList methods */
    STDMETHOD(GetFontCollection)(THIS_
        IDWriteFontCollection** fontCollection) PURE;

    STDMETHOD_(UINT32, GetFontCount)(THIS) PURE;

    STDMETHOD(GetFont)(THIS_
        UINT32 index,
        IDWriteFont **font) PURE;
#endif

    /* IDWriteFontFamily methods */
    STDMETHOD(GetFamilyNames)(THIS_
        IDWriteLocalizedStrings **names) PURE;

    STDMETHOD(GetFirstMatchingFont)(THIS_
        DWRITE_FONT_WEIGHT weight,
        DWRITE_FONT_STRETCH stretch,
        DWRITE_FONT_STYLE style,
        IDWriteFont **matchingFont) PURE;

    STDMETHOD(GetMatchingFonts)(THIS_
        DWRITE_FONT_WEIGHT weight,
        DWRITE_FONT_STRETCH stretch,
        DWRITE_FONT_STYLE style,
        IDWriteFontList **matchingFonts) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontFamily_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontFamily_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontFamily_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontFamily_GetFont(This,index,font) (This)->lpVtbl->GetFont(This,index,font)
#define IDWriteFontFamily_GetFontCollection(This,fontCollection) (This)->lpVtbl->GetFontCollection(This,fontCollection)
#define IDWriteFontFamily_GetFontCount() (This)->lpVtbl->GetFontCount(This)
#define IDWriteFontFamily_GetFamilyNames(This,names) (This)->lpVtbl->GetFamilyNames(This,names)
#define IDWriteFontFamily_GetFirstMatchingFont(This,weight,stretch,style,matchingFont) (This)->lpVtbl->GetFirstMatchingFont(This,weight,stretch,style,matchingFont)
#define IDWriteFontFamily_GetMatchingFonts(This,weight,stretch,style,matchingFonts) (This)->lpVtbl->GetMatchingFonts(This,weight,stretch,style,matchingFonts)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontFile
DECLARE_INTERFACE_(IDWriteFontFile,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteFontFile methods */
    STDMETHOD(GetReferenceKey)(THIS_
        void const **fontFileReferenceKey,
        UINT32 *fontFileReferenceKeySize) PURE;

    STDMETHOD(GetLoader)(THIS_
        IDWriteFontFileLoader **fontFileLoader) PURE;

    STDMETHOD(Analyze)(THIS_
        WINBOOL *isSupportedFontType,
        DWRITE_FONT_FILE_TYPE *fontFileType,
        DWRITE_FONT_FACE_TYPE *fontFaceType,
        UINT32 *numberOfFaces) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontFile_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontFile_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontFile_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontFile_Analyze(This,isSupportedFontType,fontFileType,fontFaceType,numberOfFaces) (This)->lpVtbl->Analyze(This,isSupportedFontType,fontFileType,fontFaceType,numberOfFaces)
#define IDWriteFontFile_GetLoader(This,fontFileLoader) (This)->lpVtbl->GetLoader(This,fontFileLoader)
#define IDWriteFontFile_GetReferenceKey(This,fontFileReferenceKey,fontFileReferenceKeySize) (This)->lpVtbl->GetReferenceKey(This,fontFileReferenceKey,fontFileReferenceKeySize)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontFileLoader
DECLARE_INTERFACE_(IDWriteFontFileLoader,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteFontFileLoader methods */
    STDMETHOD(CreateStreamFromKey)(
        void const *fontFileReferenceKey,
        UINT32 fontFileReferenceKeySize,
        IDWriteFontFileStream **fontFileStream) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontFileLoader_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontFileLoader_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontFileLoader_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontFileLoader_CreateStreamFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,fontFileStream) (This)->lpVtbl->CreateStreamFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,fontFileStream)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontFileStream
DECLARE_INTERFACE_(IDWriteFontFileStream,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteFontFileStream methods */
    STDMETHOD(ReadFileFragment)(THIS_
        void const **fragmentStart,
        UINT64 fileOffset,
        UINT64 fragmentSize,
        void** fragmentContext) PURE;

    STDMETHOD_(void, ReleaseFileFragment)(THIS_
        void *fragmentContext) PURE;

    STDMETHOD(GetFileSize)(THIS_
        UINT64 *fileSize) PURE;

    STDMETHOD(GetLastWriteTime)(THIS_
        UINT64 *lastWriteTime) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontFileStream_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontFileStream_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontFileStream_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontFileStream_GetFileSize(This,fileSize) (This)->lpVtbl->GetFileSize(This,fileSize)
#define IDWriteFontFileStream_GetLastWriteTime(This,lastWriteTime) (This)->lpVtbl->GetLastWriteTime(This,lastWriteTime)
#define IDWriteFontFileStream_ReadFileFragment(This,fragmentStart,fileOffset,fragmentSize,fragmentContext) (This)->lpVtbl->ReadFileFragment(This,fragmentStart,fileOffset,fragmentSize,fragmentContext)
#define IDWriteFontFileStream_ReleaseFileFragment(This,fragmentContext) (This)->lpVtbl->ReleaseFileFragment(This,fragmentContext)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontCollectionLoader
DECLARE_INTERFACE_(IDWriteFontCollectionLoader,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteFontCollectionLoader methods */
    STDMETHOD_(HRESULT,CreateEnumeratorFromKey)(THIS_ IDWriteFactory * factory,const void * collectionKey,UINT32  collectionKeySize,IDWriteFontFileEnumerator ** fontFileEnumerator) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontCollectionLoader_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontCollectionLoader_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontCollectionLoader_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontCollectionLoader_CreateEnumeratorFromKey(This,factory,collectionKey,collectionKeySize,fontFileEnumerator) (This)->lpVtbl->CreateEnumeratorFromKey(This,factory,collectionKey,collectionKeySize,fontFileEnumerator)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteFontFileEnumerator
DECLARE_INTERFACE_(IDWriteFontFileEnumerator,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteFontFileEnumerator methods */
    STDMETHOD_(HRESULT,MoveNext)(THIS_ WINBOOL * hasCurrentFile) PURE;
    STDMETHOD_(HRESULT,GetCurrentFontFile)(THIS_ IDWriteFontFile ** fontFile) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteFontFileEnumerator_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteFontFileEnumerator_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteFontFileEnumerator_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteFontFileEnumerator_GetCurrentFontFile(This,fontFile) (This)->lpVtbl->GetCurrentFontFile(This,fontFile)
#define IDWriteFontFileEnumerator_MoveNext(This,hasCurrentFile) (This)->lpVtbl->MoveNext(This,hasCurrentFile)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteGdiInterop
DECLARE_INTERFACE_(IDWriteGdiInterop,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteGdiInterop methods */
    STDMETHOD(CreateFontFromLOGFONT)(THIS_
        LOGFONTW const *logFont,
        IDWriteFont **font) PURE;

    STDMETHOD(ConvertFontToLOGFONT)(THIS_
        IDWriteFont *font,
        LOGFONTW *logFont,
        WINBOOL *isSystemFont) PURE;

    STDMETHOD(ConvertFontFaceToLOGFONT)(THIS_
        IDWriteFontFace *font,
        LOGFONTW *logFont) PURE;

    STDMETHOD(CreateFontFaceFromHdc)(THIS_
        HDC hdc,
        IDWriteFontFace **fontFace) PURE;

    STDMETHOD(CreateBitmapRenderTarget)(THIS_
        HDC hdc,
        UINT32 width,
        UINT32 height,
        IDWriteBitmapRenderTarget **renderTarget) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteGdiInterop_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteGdiInterop_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteGdiInterop_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteGdiInterop_ConvertFontFaceToLOGFONT(This,font,logFont) (This)->lpVtbl->ConvertFontFaceToLOGFONT(This,font,logFont)
#define IDWriteGdiInterop_ConvertFontToLOGFONT(This,font,logFont,isSystemFont) (This)->lpVtbl->ConvertFontToLOGFONT(This,font,logFont,isSystemFont)
#define IDWriteGdiInterop_CreateBitmapRenderTarget(This,hdc,width,height,renderTarget) (This)->lpVtbl->CreateBitmapRenderTarget(This,hdc,width,height,renderTarget)
#define IDWriteGdiInterop_CreateFontFaceFromHdc(This,hdc,fontFace) (This)->lpVtbl->CreateFontFaceFromHdc(This,hdc,fontFace)
#define IDWriteGdiInterop_CreateFontFromLOGFONT(This,logFont,font) (This)->lpVtbl->CreateFontFromLOGFONT(This,logFont,font)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteGlyphRunAnalysis
DECLARE_INTERFACE_(IDWriteGlyphRunAnalysis,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteGlyphRunAnalysis methods */
    STDMETHOD(GetAlphaTextureBounds)(THIS_
        DWRITE_TEXTURE_TYPE textureType,
        RECT *textureBounds) PURE;

    STDMETHOD(CreateAlphaTexture)(THIS_
        DWRITE_TEXTURE_TYPE textureType,
        RECT const *textureBounds,
        BYTE *alphaValues,
        UINT32 bufferSize) PURE;

    STDMETHOD(GetAlphaBlendParams)(THIS_
        IDWriteRenderingParams *renderingParams,
        FLOAT *blendGamma,
        FLOAT *blendEnhancedContrast,
        FLOAT *blendClearTypeLevel) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteGlyphRunAnalysis_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteGlyphRunAnalysis_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteGlyphRunAnalysis_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteGlyphRunAnalysis_CreateAlphaTexture(This,textureType,textureBounds,alphaValues,bufferSize) (This)->lpVtbl->CreateAlphaTexture(This,textureType,textureBounds,alphaValues,bufferSize)
#define IDWriteGlyphRunAnalysis_GetAlphaBlendParams(This,renderingParams,blendGamma,blendEnhancedContrast,blendClearTypeLevel) (This)->lpVtbl->GetAlphaBlendParams(This,renderingParams,blendGamma,blendEnhancedContrast,blendClearTypeLevel)
#define IDWriteGlyphRunAnalysis_GetAlphaTextureBounds(This,textureType,textureBounds) (This)->lpVtbl->GetAlphaTextureBounds(This,textureType,textureBounds)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteInlineObject
DECLARE_INTERFACE_(IDWriteInlineObject,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteInlineObject methods */
    STDMETHOD(Draw)(THIS_
            void *clientDrawingContext,
            IDWriteTextRenderer *renderer,
            FLOAT originX,
            FLOAT originY,
            WINBOOL isSideways,
            WINBOOL isRightToLeft,
            IUnknown *clientDrawingEffect) PURE;
    STDMETHOD(GetMetrics)(THIS_
            DWRITE_INLINE_OBJECT_METRICS *metrics) PURE;
    STDMETHOD(GetOverhangMetrics)(THIS_
            DWRITE_OVERHANG_METRICS *overhangs) PURE;
    STDMETHOD(GetBreakConditions)(THIS_
            DWRITE_BREAK_CONDITION *breakConditionBefore,
            DWRITE_BREAK_CONDITION *breakConditionAfter) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteInlineObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteInlineObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteInlineObject_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteInlineObject_Draw(This,clientDrawingContext,renderer,originX,originY,isSideways,isRightToLeft,clientDrawingEffect) (This)->lpVtbl->Draw(This,clientDrawingContext,renderer,originX,originY,isSideways,isRightToLeft,clientDrawingEffect)
#define IDWriteInlineObject_GetBreakConditions(This,breakConditionBefore,breakConditionAfter) (This)->lpVtbl->GetBreakConditions(This,breakConditionBefore,breakConditionAfter)
#define IDWriteInlineObject_GetMetrics(This,metrics) (This)->lpVtbl->GetMetrics(This,metrics)
#define IDWriteInlineObject_GetOverhangMetrics(This,overhangs) (This)->lpVtbl->GetOverhangMetrics(This,overhangs)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteLocalFontFileLoader
DECLARE_INTERFACE_(IDWriteLocalFontFileLoader,IDWriteFontFileLoader)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWriteFontFileLoader methods */
    STDMETHOD(CreateStreamFromKey(THIS_ const void *fontFileReferenceKey,UINT32 fontFileReferenceKeySize,IDWriteFontFileStream **fileStream) PURE;
#endif

    /* IDWriteLocalFontFileLoader methods */
    STDMETHOD(GetFilePathLengthFromKey)(THIS_ const void *fontFileReferenceKey,UINT32 fontFileReferenceKeySize,UINT32 *filePathLength) PURE;
    STDMETHOD(GetFilePathFromKey)(THIS_ const void *fontFileReferenceKey,UINT32 fontFileReferenceKeySize,WCHAR *filePath,UINT32 filePathSize) PURE;
    STDMETHOD(GetLastWriteTimeFromKey)(THIS_ const void *fontFileReferenceKey,UINT32 fontFileReferenceKeySize,FILETIME *lastWriteTime) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteLocalFontFileLoader_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteLocalFontFileLoader_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteLocalFontFileLoader_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteLocalFontFileLoader_CreateStreamFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,fileStream) (This)->lpVtbl->CreateStreamFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,fileStream)
#define IDWriteLocalFontFileLoader_GetFilePathLengthFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,filePathLength) (This)->lpVtbl->GetFilePathLengthFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,filePathLength)
#define IDWriteLocalFontFileLoader_GetFilePathFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,filePath,filePathSize) (This)->lpVtbl->GetFilePathFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,filePath,filePathSize)
#define IDWriteLocalFontFileLoader_GetLastWriteTimeFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,lastWriteTime) (This)->lpVtbl->GetLastWriteTimeFromKey(This,fontFileReferenceKey,fontFileReferenceKeySize,lastWriteTime)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteLocalizedStrings
DECLARE_INTERFACE_(IDWriteLocalizedStrings,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteLocalizedStrings methods */
    STDMETHOD_(UINT32, GetCount)(THIS) PURE;

    STDMETHOD(FindLocaleName)(THIS_
        WCHAR const *localeName,
        UINT32 *index,
        WINBOOL *exists) PURE;

    STDMETHOD(GetLocaleNameLength)(THIS_
        UINT32 index,
        UINT32 *length) PURE;

    STDMETHOD(GetLocaleName)(THIS_
        UINT32 index,
        WCHAR *localeName,
        UINT32 size) PURE;

    STDMETHOD(GetStringLength)(THIS_
        UINT32 index,
        UINT32 *length) PURE;

    STDMETHOD(GetString)(THIS_
        UINT32 index,
        WCHAR *stringBuffer,
        UINT32 size) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteLocalizedStrings_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteLocalizedStrings_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteLocalizedStrings_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteLocalizedStrings_FindLocaleName(This,localeName,index,exists) (This)->lpVtbl->FindLocaleName(This,localeName,index,exists)
#define IDWriteLocalizedStrings_GetCount() (This)->lpVtbl->GetCount(This)
#define IDWriteLocalizedStrings_GetLocaleName(This,index,localeName,size) (This)->lpVtbl->GetLocaleName(This,index,localeName,size)
#define IDWriteLocalizedStrings_GetLocaleNameLength(This,index,length) (This)->lpVtbl->GetLocaleNameLength(This,index,length)
#define IDWriteLocalizedStrings_GetString(This,index,stringBuffer,size) (This)->lpVtbl->GetString(This,index,stringBuffer,size)
#define IDWriteLocalizedStrings_GetStringLength(This,index,length) (This)->lpVtbl->GetStringLength(This,index,length)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteNumberSubstitution
DECLARE_INTERFACE_(IDWriteNumberSubstitution,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteNumberSubstitution methods */

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteNumberSubstitution_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteNumberSubstitution_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteNumberSubstitution_Release(This) (This)->lpVtbl->Release(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWritePixelSnapping
DECLARE_INTERFACE_(IDWritePixelSnapping,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWritePixelSnapping methods */
    STDMETHOD(IsPixelSnappingDisabled)(THIS_
            void *clientDrawingContext,
            WINBOOL *isDisabled) PURE;
    STDMETHOD(GetCurrentTransform)(THIS_
            void *clientDrawingContext,
            DWRITE_MATRIX *transform) PURE;
    STDMETHOD(GetPixelsPerDip)(THIS_
            void *clientDrawingContext,
            FLOAT *pixelsPerDip) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWritePixelSnapping_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWritePixelSnapping_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWritePixelSnapping_Release(This) (This)->lpVtbl->Release(This)
#define IDWritePixelSnapping_GetCurrentTransform(This,clientDrawingContext,transform) (This)->lpVtbl->GetCurrentTransform(This,clientDrawingContext,transform)
#define IDWritePixelSnapping_GetPixelsPerDip(This,clientDrawingContext,pixelsPerDip) (This)->lpVtbl->GetPixelsPerDip(This,clientDrawingContext,pixelsPerDip)
#define IDWritePixelSnapping_IsPixelSnappingEnabled(This,clientDrawingContext,isDisabled) (This)->lpVtbl->IsPixelSnappingEnabled(This,clientDrawingContext,isDisabled)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteRenderingParams
DECLARE_INTERFACE_(IDWriteRenderingParams,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteRenderingParams methods */
    STDMETHOD_(FLOAT, GetGamma)(THIS) PURE;
    STDMETHOD_(FLOAT, GetEnhancedContrast)(THIS) PURE;
    STDMETHOD_(FLOAT, GetClearTypeLevel)(THIS) PURE;
    STDMETHOD_(DWRITE_PIXEL_GEOMETRY, GetPixelGeometry)(THIS) PURE;
    STDMETHOD_(DWRITE_RENDERING_MODE, GetRenderingMode)(THIS) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteRenderingParams_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteRenderingParams_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteRenderingParams_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteRenderingParams_GetClearTypeLevel() (This)->lpVtbl->GetClearTypeLevel(This)
#define IDWriteRenderingParams_GetEnhancedContrast() (This)->lpVtbl->GetEnhancedContrast(This)
#define IDWriteRenderingParams_GetGamma() (This)->lpVtbl->GetGamma(This)
#define IDWriteRenderingParams_GetPixelGeometry() (This)->lpVtbl->GetPixelGeometry(This)
#define IDWriteRenderingParams_GetRenderingMode() (This)->lpVtbl->GetRenderingMode(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteTextAnalysisSink
DECLARE_INTERFACE_(IDWriteTextAnalysisSink,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteTextAnalysisSink methods */
    STDMETHOD(SetScriptAnalysis)(
            UINT32 textPosition,
            UINT32 textLength,
            DWRITE_SCRIPT_ANALYSIS const *scriptAnalysis) PURE;

    STDMETHOD(SetLineBreakpoints)(
            UINT32 textPosition,
            UINT32 textLength,
            DWRITE_LINE_BREAKPOINT const *lineBreakpoints) PURE;

    STDMETHOD(SetBidiLevel)(
            UINT32 textPosition,
            UINT32 textLength,
            UINT8 explicitLevel,
            UINT8 resolvedLevel) PURE;

    STDMETHOD(SetNumberSubstitution)(
            UINT32 textPosition,
            UINT32 textLength,
            IDWriteNumberSubstitution *numberSubstitution) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteTextAnalysisSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteTextAnalysisSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteTextAnalysisSink_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteTextAnalysisSink_SetBidiLevel(This,textPosition,textLength,explicitLevel,resolvedLevel) (This)->lpVtbl->SetBidiLevel(This,textPosition,textLength,explicitLevel,resolvedLevel)
#define IDWriteTextAnalysisSink_SetLineBreakpoints(This,textPosition,textLength,lineBreakpoints) (This)->lpVtbl->SetLineBreakpoints(This,textPosition,textLength,lineBreakpoints)
#define IDWriteTextAnalysisSink_SetNumberSubstitution(This,textPosition,textLength,numberSubstitution) (This)->lpVtbl->SetNumberSubstitution(This,textPosition,textLength,numberSubstitution)
#define IDWriteTextAnalysisSink_SetScriptAnalysis(This,textPosition,textLength,scriptAnalysis) (This)->lpVtbl->SetScriptAnalysis(This,textPosition,textLength,scriptAnalysis)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteTextAnalysisSource
DECLARE_INTERFACE_(IDWriteTextAnalysisSource,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteTextAnalysisSource methods */
    STDMETHOD(GetTextAtPosition)(THIS_
        UINT32 textPosition,
        WCHAR const **textString,
        UINT32 *textLength) PURE;

    STDMETHOD(GetTextBeforePosition)(THIS_
        UINT32 textPosition,
        WCHAR const **textString,
        UINT32 *textLength) PURE;

    STDMETHOD_(DWRITE_READING_DIRECTION, GetParagraphReadingDirection)(THIS) PURE;

    STDMETHOD(GetLocaleName)(THIS_
        UINT32 textPosition,
        UINT32 *textLength,
        WCHAR const **localeName) PURE;

    STDMETHOD(GetNumberSubstitution)(THIS_
        UINT32 textPosition,
        UINT32 *textLength,
        IDWriteNumberSubstitution **numberSubstitution) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteTextAnalysisSource_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteTextAnalysisSource_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteTextAnalysisSource_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteTextAnalysisSource_GetLocaleName(This,textPosition,textLength,localeName) (This)->lpVtbl->GetLocaleName(This,textPosition,textLength,localeName)
#define IDWriteTextAnalysisSource_GetNumberSubstitution(This,textPosition,textLength,numberSubstitution) (This)->lpVtbl->GetNumberSubstitution(This,textPosition,textLength,numberSubstitution)
#define IDWriteTextAnalysisSource_GetParagraphReadingDirection() (This)->lpVtbl->GetParagraphReadingDirection(This)
#define IDWriteTextAnalysisSource_GetTextAtPosition(This,textPosition,textString,textLength) (This)->lpVtbl->GetTextAtPosition(This,textPosition,textString,textLength)
#define IDWriteTextAnalysisSource_GetTextBeforePosition(This,textPosition,textString,textLength) (This)->lpVtbl->GetTextBeforePosition(This,textPosition,textString,textLength)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteTextAnalyzer
DECLARE_INTERFACE_(IDWriteTextAnalyzer,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

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

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteTextAnalyzer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteTextAnalyzer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteTextAnalyzer_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteTextAnalyzer_AnalyzeBidi(This,analysisSource,textPosition,textLength,analysisSink) (This)->lpVtbl->AnalyzeBidi(This,analysisSource,textPosition,textLength,analysisSink)
#define IDWriteTextAnalyzer_AnalyzeLineBreakpoints(This,analysisSource,textPosition,textLength,analysisSink) (This)->lpVtbl->AnalyzeLineBreakpoints(This,analysisSource,textPosition,textLength,analysisSink)
#define IDWriteTextAnalyzer_AnalyzeNumberSubstitution(This,analysisSource,textPosition,textLength,analysisSink) (This)->lpVtbl->AnalyzeNumberSubstitution(This,analysisSource,textPosition,textLength,analysisSink)
#define IDWriteTextAnalyzer_AnalyzeScript(This,analysisSource,textPosition,textLength,analysisSink) (This)->lpVtbl->AnalyzeScript(This,analysisSource,textPosition,textLength,analysisSink)
#define IDWriteTextAnalyzer_GetGdiCompatibleGlyphPlacements(This,textString,clusterMap,textProps,textLength,glyphIndices,glyphProps,glyphCount,fontFace,fontEmSize,pixelsPerDip,transform,useGdiNatural,isSideways,isRightToLeft,scriptAnalysis,featureRangeLengths,featureRanges,glyphAdvances,glyphOffsets) (This)->lpVtbl->GetGdiCompatibleGlyphPlacements(This,textString,clusterMap,textProps,textLength,glyphIndices,glyphProps,glyphCount,fontFace,fontEmSize,pixelsPerDip,transform,useGdiNatural,isSideways,isRightToLeft,scriptAnalysis,featureRangeLengths,featureRanges,glyphAdvances,glyphOffsets)
#define IDWriteTextAnalyzer_GetGlyphPlacements(This,textString,clusterMap,textProps,textLength,glyphIndices,glyphProps,glyphCount,fontFace,fontEmSize,isSideways,isRightToLeft,scriptAnalysis,featureRangeLengths,featureRanges,glyphAdvances,glyphOffsets) (This)->lpVtbl->GetGlyphPlacements(This,textString,clusterMap,textProps,textLength,glyphIndices,glyphProps,glyphCount,fontFace,fontEmSize,isSideways,isRightToLeft,scriptAnalysis,featureRangeLengths,featureRanges,glyphAdvances,glyphOffsets)
#define IDWriteTextAnalyzer_GetGlyphs(This,textString,textLength,fontFace,isSideways,isRightToLeft,scriptAnalysis,featureRangeLengths,featureRanges,maxGlyphCount,clusterMap,textProps,glyphIndices,glyphProps,actualGlyphCount) (This)->lpVtbl->GetGlyphs(This,textString,textLength,fontFace,isSideways,isRightToLeft,scriptAnalysis,featureRangeLengths,featureRanges,maxGlyphCount,clusterMap,textProps,glyphIndices,glyphProps,actualGlyphCount)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteTextFormat
DECLARE_INTERFACE_(IDWriteTextFormat,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteTextFormat methods */
    STDMETHOD(SetTextAlignment)(THIS_
            DWRITE_TEXT_ALIGNMENT textAlignment) PURE;
    STDMETHOD(SetParagraphAlignment)(THIS_
            DWRITE_PARAGRAPH_ALIGNMENT paragraphAlignment) PURE;
    STDMETHOD(SetWordWrapping)(THIS_
            DWRITE_WORD_WRAPPING wordWrapping) PURE;
    STDMETHOD(SetReadingDirection)(THIS_
            DWRITE_READING_DIRECTION readingDirection) PURE;
    STDMETHOD(SetFlowDirection)(THIS_
            DWRITE_FLOW_DIRECTION flowDirection) PURE;
    STDMETHOD(SetIncrementalTabStop)(THIS_
            FLOAT incrementalTabStop) PURE;
    STDMETHOD(SetTrimming)(THIS_
            DWRITE_TRIMMING const *trimmingOptions,
            IDWriteInlineObject *trimmingSign) PURE;
    STDMETHOD(SetLineSpacing)(THIS_
            DWRITE_LINE_SPACING_METHOD lineSpacingMethod,
            FLOAT lineSpacing,
            FLOAT baseline) PURE;
    STDMETHOD_(DWRITE_TEXT_ALIGNMENT, GetTextAlignment)(THIS) PURE;
    STDMETHOD_(DWRITE_PARAGRAPH_ALIGNMENT, GetParagraphAlignment)(THIS) PURE;
    STDMETHOD_(DWRITE_WORD_WRAPPING, GetWordWrapping)(THIS) PURE;
    STDMETHOD_(DWRITE_READING_DIRECTION, GetReadingDirection)(THIS) PURE;
    STDMETHOD_(DWRITE_FLOW_DIRECTION, GetFlowDirection)(THIS) PURE;
    STDMETHOD_(FLOAT, GetIncrementalTabStop)(THIS) PURE;
    STDMETHOD(GetTrimming)(THIS_
            DWRITE_TRIMMING* trimmingOptions,
            IDWriteInlineObject **trimmingSign) PURE;
    STDMETHOD(GetLineSpacing)(THIS_
            DWRITE_LINE_SPACING_METHOD *lineSpacingMethod,
            FLOAT *lineSpacing,
            FLOAT *baseline) PURE;
    STDMETHOD(GetFontCollection)(THIS_
            IDWriteFontCollection **fontCollection) PURE;
    STDMETHOD_(UINT32, GetFontFamilyNameLength)(THIS) PURE;
    STDMETHOD(GetFontFamilyName)(THIS_
            WCHAR *fontFamilyName,
            UINT32 nameSize) PURE;
    STDMETHOD_(DWRITE_FONT_WEIGHT, GetFontWeight)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STYLE, GetFontStyle)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STRETCH, GetFontStretch)(THIS) PURE;
    STDMETHOD_(FLOAT, GetFontSize)(THIS) PURE;
    STDMETHOD_(UINT32, GetLocaleNameLength)(THIS) PURE;
    STDMETHOD(GetLocaleName)(THIS_
            WCHAR *localeName,
            UINT32 nameSize) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteTextFormat_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteTextFormat_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteTextFormat_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteTextFormat_GetFlowDirection() (This)->lpVtbl->GetFlowDirection(This)
#define IDWriteTextFormat_GetFontCollection(This,fontCollection) (This)->lpVtbl->GetFontCollection(This,fontCollection)
#define IDWriteTextFormat_GetFontFamilyName(This,fontFamilyName,nameSize) (This)->lpVtbl->GetFontFamilyName(This,fontFamilyName,nameSize)
#define IDWriteTextFormat_GetFontFamilyNameLength() (This)->lpVtbl->GetFontFamilyNameLength(This)
#define IDWriteTextFormat_GetFontSize() (This)->lpVtbl->GetFontSize(This)
#define IDWriteTextFormat_GetFontStretch() (This)->lpVtbl->GetFontStretch(This)
#define IDWriteTextFormat_GetFontStyle() (This)->lpVtbl->GetFontStyle(This)
#define IDWriteTextFormat_GetFontWeight() (This)->lpVtbl->GetFontWeight(This)
#define IDWriteTextFormat_GetIncrementalTabStop() (This)->lpVtbl->GetIncrementalTabStop(This)
#define IDWriteTextFormat_GetLineSpacing(This,lineSpacingMethod,lineSpacing,baseline) (This)->lpVtbl->GetLineSpacing(This,lineSpacingMethod,lineSpacing,baseline)
#define IDWriteTextFormat_GetLocaleName(This,localeName,nameSize) (This)->lpVtbl->GetLocaleName(This,localeName,nameSize)
#define IDWriteTextFormat_GetLocaleNameLength() (This)->lpVtbl->GetLocaleNameLength(This)
#define IDWriteTextFormat_GetParagraphAlignment() (This)->lpVtbl->GetParagraphAlignment(This)
#define IDWriteTextFormat_GetReadingDirection() (This)->lpVtbl->GetReadingDirection(This)
#define IDWriteTextFormat_GetTextAlignment() (This)->lpVtbl->GetTextAlignment(This)
#define IDWriteTextFormat_GetTrimming(This,trimmingOptions,trimmingSign) (This)->lpVtbl->GetTrimming(This,trimmingOptions,trimmingSign)
#define IDWriteTextFormat_GetWordWrapping() (This)->lpVtbl->GetWordWrapping(This)
#define IDWriteTextFormat_SetFlowDirection(This,flowDirection) (This)->lpVtbl->SetFlowDirection(This,flowDirection)
#define IDWriteTextFormat_SetIncrementalTabStop(This,incrementalTabStop) (This)->lpVtbl->SetIncrementalTabStop(This,incrementalTabStop)
#define IDWriteTextFormat_SetLineSpacing(This,lineSpacingMethod,lineSpacing,baseline) (This)->lpVtbl->SetLineSpacing(This,lineSpacingMethod,lineSpacing,baseline)
#define IDWriteTextFormat_SetParagraphAlignment(This,paragraphAlignment) (This)->lpVtbl->SetParagraphAlignment(This,paragraphAlignment)
#define IDWriteTextFormat_SetReadingDirection(This,readingDirection) (This)->lpVtbl->SetReadingDirection(This,readingDirection)
#define IDWriteTextFormat_SetTextAlignment(This,textAlignment) (This)->lpVtbl->SetTextAlignment(This,textAlignment)
#define IDWriteTextFormat_SetTrimming(This,trimmingOptions,trimmingSign) (This)->lpVtbl->SetTrimming(This,trimmingOptions,trimmingSign)
#define IDWriteTextFormat_SetWordWrapping(This,wordWrapping) (This)->lpVtbl->SetWordWrapping(This,wordWrapping)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteTextLayout
DECLARE_INTERFACE_(IDWriteTextLayout,IDWriteTextFormat)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWriteTextFormat methods */
    STDMETHOD(SetTextAlignment)(THIS_
            DWRITE_TEXT_ALIGNMENT textAlignment) PURE;
    STDMETHOD(SetParagraphAlignment)(THIS_
            DWRITE_PARAGRAPH_ALIGNMENT paragraphAlignment) PURE;
    STDMETHOD(SetWordWrapping)(THIS_
            DWRITE_WORD_WRAPPING wordWrapping) PURE;
    STDMETHOD(SetReadingDirection)(THIS_
            DWRITE_READING_DIRECTION readingDirection) PURE;
    STDMETHOD(SetFlowDirection)(THIS_
            DWRITE_FLOW_DIRECTION flowDirection) PURE;
    STDMETHOD(SetIncrementalTabStop)(THIS_
            FLOAT incrementalTabStop) PURE;
    STDMETHOD(SetTrimming)(THIS_
            DWRITE_TRIMMING const *trimmingOptions,
            IDWriteInlineObject *trimmingSign) PURE;
    STDMETHOD(SetLineSpacing)(THIS_
            DWRITE_LINE_SPACING_METHOD lineSpacingMethod,
            FLOAT lineSpacing,
            FLOAT baseline) PURE;
    STDMETHOD_(DWRITE_TEXT_ALIGNMENT, GetTextAlignment)(THIS) PURE;
    STDMETHOD_(DWRITE_PARAGRAPH_ALIGNMENT, GetParagraphAlignment)(THIS) PURE;
    STDMETHOD_(DWRITE_WORD_WRAPPING, GetWordWrapping)(THIS) PURE;
    STDMETHOD_(DWRITE_READING_DIRECTION, GetReadingDirection)(THIS) PURE;
    STDMETHOD_(DWRITE_FLOW_DIRECTION, GetFlowDirection)(THIS) PURE;
    STDMETHOD_(FLOAT, GetIncrementalTabStop)(THIS) PURE;
    STDMETHOD(GetTrimming)(THIS_
            DWRITE_TRIMMING* trimmingOptions,
            IDWriteInlineObject **trimmingSign) PURE;
    STDMETHOD(GetLineSpacing)(THIS_
            DWRITE_LINE_SPACING_METHOD *lineSpacingMethod,
            FLOAT *lineSpacing,
            FLOAT *baseline) PURE;
    STDMETHOD(GetFontCollection)(THIS_
            IDWriteFontCollection **fontCollection) PURE;
    STDMETHOD_(UINT32, GetFontFamilyNameLength)(THIS) PURE;
    STDMETHOD(GetFontFamilyName)(THIS_
            WCHAR *fontFamilyName,
            UINT32 nameSize) PURE;
    STDMETHOD_(DWRITE_FONT_WEIGHT, GetFontWeight)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STYLE, GetFontStyle)(THIS) PURE;
    STDMETHOD_(DWRITE_FONT_STRETCH, GetFontStretch)(THIS) PURE;
    STDMETHOD_(FLOAT, GetFontSize)(THIS) PURE;
    STDMETHOD_(UINT32, GetLocaleNameLength)(THIS) PURE;
    STDMETHOD(GetLocaleName)(THIS_
            WCHAR *localeName,
            UINT32 nameSize) PURE;
#endif

    /* IDWriteTextLayout methods */
    STDMETHOD(SetMaxWidth)(THIS_
            FLOAT maxWidth) PURE;
    STDMETHOD(SetMaxHeight)(THIS_
            FLOAT maxHeight) PURE;
    STDMETHOD(SetFontCollection)(THIS_
            IDWriteFontCollection *fontCollection,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetFontFamilyName)(THIS_
            WCHAR const *fontFamilyName,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetFontWeight)(THIS_
            DWRITE_FONT_WEIGHT fontWeight,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetFontStyle)(THIS_
            DWRITE_FONT_STYLE fontStyle,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetFontStretch)(THIS_
            DWRITE_FONT_STRETCH fontStretch,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetFontSize)(THIS_
            FLOAT fontSize,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetUnderline)(THIS_
            WINBOOL hasUnderline,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetStrikethrough)(THIS_
            WINBOOL hasStrikethrough,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetDrawingEffect)(THIS_
            IUnknown *drawingEffect,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetInlineObject)(THIS_
            IDWriteInlineObject *inlineObject,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetTypography)(THIS_
            IDWriteTypography *typography,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD(SetLocaleName)(THIS_
            WCHAR const *localeName,
            DWRITE_TEXT_RANGE textRange) PURE;
    STDMETHOD_(FLOAT, GetMaxWidth)(THIS) PURE;
    STDMETHOD_(FLOAT, GetMaxHeight)(THIS) PURE;
    STDMETHOD(GetFontCollection)(THIS_
            UINT32 currentPosition,
            IDWriteFontCollection** fontCollection,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetFontFamilyNameLength)(THIS_
            UINT32 currentPosition,
            UINT32 *nameLength,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetFontFamilyName)(THIS_
            UINT32 currentPosition,
            WCHAR *fontFamilyName,
            UINT32 nameSize,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetFontWeight)(THIS_
            UINT32 currentPosition,
            DWRITE_FONT_WEIGHT *fontWeight,
            DWRITE_TEXT_RANGE* textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetFontStyle)(THIS_
            UINT32 currentPosition,
            DWRITE_FONT_STYLE *fontStyle,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetFontStretch)(THIS_
            UINT32 currentPosition,
            DWRITE_FONT_STRETCH* fontStretch,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetFontSize)(THIS_
            UINT32 currentPosition,
            FLOAT *fontSize,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetUnderline)(THIS_
            UINT32 currentPosition,
            WINBOOL *hasUnderline,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetStrikethrough)(THIS_
            UINT32 currentPosition,
            WINBOOL *hasStrikethrough,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetDrawingEffect)(THIS_
            UINT32 currentPosition,
            IUnknown **drawingEffect,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetInlineObject)(THIS_
            UINT32 currentPosition,
            IDWriteInlineObject **inlineObject,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetTypography)(THIS_
            UINT32 currentPosition,
            IDWriteTypography **typography,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetLocaleNameLength)(THIS_
            UINT32 currentPosition,
            UINT32 *nameLength,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(GetLocaleName)(THIS_
            UINT32 currentPosition,
            WCHAR *localeName,
            UINT32 nameSize,
            DWRITE_TEXT_RANGE *textRange __MINGW_DEF_ARG_VAL(NULL)) PURE;
    STDMETHOD(Draw)(THIS_
            void *clientDrawingContext,
            IDWriteTextRenderer *renderer,
            FLOAT originX,
            FLOAT originY) PURE;
    STDMETHOD(GetLineMetrics)(THIS_
            DWRITE_LINE_METRICS *lineMetrics,
            UINT32 maxLineCount,
            UINT32 *actualLineCount) PURE;
    STDMETHOD(GetMetrics)(THIS_
            DWRITE_TEXT_METRICS *textMetrics) PURE;
    STDMETHOD(GetOverhangMetrics)(THIS_
            DWRITE_OVERHANG_METRICS *overhangs) PURE;
    STDMETHOD(GetClusterMetrics)(THIS_
            DWRITE_CLUSTER_METRICS *clusterMetrics,
            UINT32 maxClusterCount,
            UINT32 *actualClusterCount) PURE;
    STDMETHOD(DetermineMinWidth)(THIS_
            FLOAT *minWidth) PURE;
    STDMETHOD(HitTestPoint)(THIS_
            FLOAT pointX,
            FLOAT pointY,
            WINBOOL *isTrailingHit,
            WINBOOL *isInside,
            DWRITE_HIT_TEST_METRICS *hitTestMetrics) PURE;
    STDMETHOD(HitTestTextPosition)(THIS_
            UINT32 textPosition,
            WINBOOL isTrailingHit,
            FLOAT *pointX,
            FLOAT *pointY,
            DWRITE_HIT_TEST_METRICS *hitTestMetrics) PURE;
    STDMETHOD(HitTestTextRange)(THIS_
            UINT32 textPosition,
            UINT32 textLength,
            FLOAT originX,
            FLOAT originY,
            DWRITE_HIT_TEST_METRICS *hitTestMetrics,
            UINT32 maxHitTestMetricsCount,
            UINT32 *actualHitTestMetricsCount) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteTextLayout_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteTextLayout_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteTextLayout_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteTextLayout_GetFlowDirection() (This)->lpVtbl->GetFlowDirection(This)
#define IDWriteTextLayout_GetFontCollection(This,fontCollection) (This)->lpVtbl->GetFontCollection(This,fontCollection)
#define IDWriteTextLayout_GetFontFamilyName(This,fontFamilyName,nameSize) (This)->lpVtbl->GetFontFamilyName(This,fontFamilyName,nameSize)
#define IDWriteTextLayout_GetFontFamilyNameLength() (This)->lpVtbl->GetFontFamilyNameLength(This)
#define IDWriteTextLayout_GetFontSize() (This)->lpVtbl->GetFontSize(This)
#define IDWriteTextLayout_GetFontStretch() (This)->lpVtbl->GetFontStretch(This)
#define IDWriteTextLayout_GetFontStyle() (This)->lpVtbl->GetFontStyle(This)
#define IDWriteTextLayout_GetFontWeight() (This)->lpVtbl->GetFontWeight(This)
#define IDWriteTextLayout_GetIncrementalTabStop() (This)->lpVtbl->GetIncrementalTabStop(This)
#define IDWriteTextLayout_GetLineSpacing(This,lineSpacingMethod,lineSpacing,baseline) (This)->lpVtbl->GetLineSpacing(This,lineSpacingMethod,lineSpacing,baseline)
#define IDWriteTextLayout_GetLocaleName(This,localeName,nameSize) (This)->lpVtbl->GetLocaleName(This,localeName,nameSize)
#define IDWriteTextLayout_GetLocaleNameLength() (This)->lpVtbl->GetLocaleNameLength(This)
#define IDWriteTextLayout_GetParagraphAlignment() (This)->lpVtbl->GetParagraphAlignment(This)
#define IDWriteTextLayout_GetReadingDirection() (This)->lpVtbl->GetReadingDirection(This)
#define IDWriteTextLayout_GetTextAlignment() (This)->lpVtbl->GetTextAlignment(This)
#define IDWriteTextLayout_GetTrimming(This,trimmingOptions,trimmingSign) (This)->lpVtbl->GetTrimming(This,trimmingOptions,trimmingSign)
#define IDWriteTextLayout_GetWordWrapping() (This)->lpVtbl->GetWordWrapping(This)
#define IDWriteTextLayout_SetFlowDirection(This,flowDirection) (This)->lpVtbl->SetFlowDirection(This,flowDirection)
#define IDWriteTextLayout_SetIncrementalTabStop(This,incrementalTabStop) (This)->lpVtbl->SetIncrementalTabStop(This,incrementalTabStop)
#define IDWriteTextLayout_SetLineSpacing(This,lineSpacingMethod,lineSpacing,baseline) (This)->lpVtbl->SetLineSpacing(This,lineSpacingMethod,lineSpacing,baseline)
#define IDWriteTextLayout_SetParagraphAlignment(This,paragraphAlignment) (This)->lpVtbl->SetParagraphAlignment(This,paragraphAlignment)
#define IDWriteTextLayout_SetReadingDirection(This,readingDirection) (This)->lpVtbl->SetReadingDirection(This,readingDirection)
#define IDWriteTextLayout_SetTextAlignment(This,textAlignment) (This)->lpVtbl->SetTextAlignment(This,textAlignment)
#define IDWriteTextLayout_SetTrimming(This,trimmingOptions,trimmingSign) (This)->lpVtbl->SetTrimming(This,trimmingOptions,trimmingSign)
#define IDWriteTextLayout_SetWordWrapping(This,wordWrapping) (This)->lpVtbl->SetWordWrapping(This,wordWrapping)
#define IDWriteTextLayout_Draw(This,clientDrawingContext,renderer,originX,originY) (This)->lpVtbl->Draw(This,clientDrawingContext,renderer,originX,originY)
#define IDWriteTextLayout_GetClusterMetrics(This,clusterMetrics,maxClusterCount,actualClusterCount) (This)->lpVtbl->GetClusterMetrics(This,clusterMetrics,maxClusterCount,actualClusterCount)
#define IDWriteTextLayout_DetermineMinWidth(This,minWidth) (This)->lpVtbl->DetermineMinWidth(This,minWidth)
#define IDWriteTextLayout_GetDrawingEffect(This,currentPosition,drawingEffect,textRange) (This)->lpVtbl->GetDrawingEffect(This,currentPosition,drawingEffect,textRange)
#define IDWriteTextLayout_GetFontCollection(This,currentPosition,fontCollection,textRange) (This)->lpVtbl->GetFontCollection(This,currentPosition,fontCollection,textRange)
#define IDWriteTextLayout_GetFontFamilyName(This,currentPosition,fontFamilyName,nameSize,textRange) (This)->lpVtbl->GetFontFamilyName(This,currentPosition,fontFamilyName,nameSize,textRange)
#define IDWriteTextLayout_GetFontFamilyNameLength(This,currentPosition,nameLength,textRange) (This)->lpVtbl->GetFontFamilyNameLength(This,currentPosition,nameLength,textRange)
#define IDWriteTextLayout_GetFontSize(This,currentPosition,fontSize,textRange) (This)->lpVtbl->GetFontSize(This,currentPosition,fontSize,textRange)
#define IDWriteTextLayout_GetFontStretch(This,currentPosition,fontStretch,textRange) (This)->lpVtbl->GetFontStretch(This,currentPosition,fontStretch,textRange)
#define IDWriteTextLayout_GetFontStyle(This,currentPosition,fontStyle,textRange) (This)->lpVtbl->GetFontStyle(This,currentPosition,fontStyle,textRange)
#define IDWriteTextLayout_GetFontWeight(This,currentPosition,fontWeight,textRange) (This)->lpVtbl->GetFontWeight(This,currentPosition,fontWeight,textRange)
#define IDWriteTextLayout_GetInlineObject(This,currentPosition,inlineObject,textRange) (This)->lpVtbl->GetInlineObject(This,currentPosition,inlineObject,textRange)
#define IDWriteTextLayout_GetLineMetrics(This,lineMetrics,maxLineCount,actualLineCount) (This)->lpVtbl->GetLineMetrics(This,lineMetrics,maxLineCount,actualLineCount)
#define IDWriteTextLayout_GetLocaleName(This,currentPosition,localeName,nameSize,textRange) (This)->lpVtbl->GetLocaleName(This,currentPosition,localeName,nameSize,textRange)
#define IDWriteTextLayout_GetLocaleNameLength(This,currentPosition,nameLength,textRange) (This)->lpVtbl->GetLocaleNameLength(This,currentPosition,nameLength,textRange)
#define IDWriteTextLayout_GetMaxHeight() (This)->lpVtbl->GetMaxHeight(This)
#define IDWriteTextLayout_GetMaxWidth() (This)->lpVtbl->GetMaxWidth(This)
#define IDWriteTextLayout_GetMetrics(This,textMetrics) (This)->lpVtbl->GetMetrics(This,textMetrics)
#define IDWriteTextLayout_GetOverhangMetrics(This,overhangs) (This)->lpVtbl->GetOverhangMetrics(This,overhangs)
#define IDWriteTextLayout_GetStrikethrough(This,currentPosition,hasStrikethrough,textRange) (This)->lpVtbl->GetStrikethrough(This,currentPosition,hasStrikethrough,textRange)
#define IDWriteTextLayout_GetTypography(This,currentPosition,typography,textRange) (This)->lpVtbl->GetTypography(This,currentPosition,typography,textRange)
#define IDWriteTextLayout_GetUnderline(This,currentPosition,hasUnderline,textRange) (This)->lpVtbl->GetUnderline(This,currentPosition,hasUnderline,textRange)
#define IDWriteTextLayout_HitTestPoint(This,pointX,pointY,isTrailingHit,isInside,hitTestMetrics) (This)->lpVtbl->HitTestPoint(This,pointX,pointY,isTrailingHit,isInside,hitTestMetrics)
#define IDWriteTextLayout_HitTestTextPosition(This,textPosition,isTrailingHit,pointX,pointY,hitTestMetrics) (This)->lpVtbl->HitTestTextPosition(This,textPosition,isTrailingHit,pointX,pointY,hitTestMetrics)
#define IDWriteTextLayout_HitTestTextRange(This,textPosition,textLength,originX,originY,hitTestMetrics,maxHitTestMetricsCount,actualHitTestMetricsCount) (This)->lpVtbl->HitTestTextRange(This,textPosition,textLength,originX,originY,hitTestMetrics,maxHitTestMetricsCount,actualHitTestMetricsCount)
#define IDWriteTextLayout_SetDrawingEffect(This,drawingEffect,textRange) (This)->lpVtbl->SetDrawingEffect(This,drawingEffect,textRange)
#define IDWriteTextLayout_SetFontCollection(This,fontCollection,textRange) (This)->lpVtbl->SetFontCollection(This,fontCollection,textRange)
#define IDWriteTextLayout_SetFontFamilyName(This,fontFamilyName,textRange) (This)->lpVtbl->SetFontFamilyName(This,fontFamilyName,textRange)
#define IDWriteTextLayout_SetFontSize(This,fontSize,textRange) (This)->lpVtbl->SetFontSize(This,fontSize,textRange)
#define IDWriteTextLayout_SetFontStretch(This,fontStretch,textRange) (This)->lpVtbl->SetFontStretch(This,fontStretch,textRange)
#define IDWriteTextLayout_SetFontStyle(This,fontStyle,textRange) (This)->lpVtbl->SetFontStyle(This,fontStyle,textRange)
#define IDWriteTextLayout_SetFontWeight(This,fontWeight,textRange) (This)->lpVtbl->SetFontWeight(This,fontWeight,textRange)
#define IDWriteTextLayout_SetInlineObject(This,inlineObject,textRange) (This)->lpVtbl->SetInlineObject(This,inlineObject,textRange)
#define IDWriteTextLayout_SetLocaleName(This,localeName,textRange) (This)->lpVtbl->SetLocaleName(This,localeName,textRange)
#define IDWriteTextLayout_SetMaxHeight(This,maxHeight) (This)->lpVtbl->SetMaxHeight(This,maxHeight)
#define IDWriteTextLayout_SetMaxWidth(This,maxWidth) (This)->lpVtbl->SetMaxWidth(This,maxWidth)
#define IDWriteTextLayout_SetStrikethrough(This,hasStrikethrough,textRange) (This)->lpVtbl->SetStrikethrough(This,hasStrikethrough,textRange)
#define IDWriteTextLayout_SetTypography(This,typography,textRange) (This)->lpVtbl->SetTypography(This,typography,textRange)
#define IDWriteTextLayout_SetUnderline(This,hasUnderline,textRange) (This)->lpVtbl->SetUnderline(This,hasUnderline,textRange)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteTextRenderer
DECLARE_INTERFACE_(IDWriteTextRenderer,IDWritePixelSnapping)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDWritePixelSnapping methods */
    STDMETHOD(IsPixelSnappingDisabled)(THIS_
            void *clientDrawingContext,
            WINBOOL *isDisabled) PURE;
    STDMETHOD(GetCurrentTransform)(THIS_
            void *clientDrawingContext,
            DWRITE_MATRIX *transform) PURE;
    STDMETHOD(GetPixelsPerDip)(THIS_
            void *clientDrawingContext,
            FLOAT *pixelsPerDip) PURE;
#endif

    /* IDWriteTextRenderer methods */
    STDMETHOD(DrawGlyphRun)(THIS_
            void *clientDrawingContext,
            FLOAT baselineOriginX,
            FLOAT baselineOriginY,
            DWRITE_MEASURING_MODE measuringMode,
            DWRITE_GLYPH_RUN const *glyphRun,
            DWRITE_GLYPH_RUN_DESCRIPTION const *glyphRunDescription,
            IUnknown* clientDrawingEffect) PURE;
    STDMETHOD(DrawUnderline)(THIS_
            void *clientDrawingContext,
            FLOAT baselineOriginX,
            FLOAT baselineOriginY,
            DWRITE_UNDERLINE const *underline,
            IUnknown *clientDrawingEffect) PURE;
    STDMETHOD(DrawStrikethrough)(THIS_
            void *clientDrawingContext,
            FLOAT baselineOriginX,
            FLOAT baselineOriginY,
            DWRITE_STRIKETHROUGH const *strikethrough,
            IUnknown* clientDrawingEffect) PURE;
    STDMETHOD(DrawInlineObject)(
            void *clientDrawingContext,
            FLOAT originX,
            FLOAT originY,
            IDWriteInlineObject *inlineObject,
            WINBOOL isSideways,
            WINBOOL isRightToLeft,
            IUnknown *clientDrawingEffect) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteTextRenderer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteTextRenderer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteTextRenderer_GetCurrentTransform(This,clientDrawingContext,transform) (This)->lpVtbl->GetCurrentTransform(This,clientDrawingContext,transform)
#define IDWriteTextRenderer_GetPixelsPerDip(This,clientDrawingContext,pixelsPerDip) (This)->lpVtbl->GetPixelsPerDip(This,clientDrawingContext,pixelsPerDip)
#define IDWriteTextRenderer_IsPixelSnappingEnabled(This,clientDrawingContext,isDisabled) (This)->lpVtbl->IsPixelSnappingEnabled(This,clientDrawingContext,isDisabled)
#define IDWriteTextRenderer_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteTextRenderer_DrawGlyphRun(This,clientDrawingContext,baselineOriginX,baselineOriginY,measuringMode,glyphRun,glyphRunDescription,clientDrawingEffect) (This)->lpVtbl->DrawGlyphRun(This,clientDrawingContext,baselineOriginX,baselineOriginY,measuringMode,glyphRun,glyphRunDescription,clientDrawingEffect)
#define IDWriteTextRenderer_DrawInlineObject(This,clientDrawingContext,originX,originY,inlineObject,isSideways,isRightToLeft,clientDrawingEffect) (This)->lpVtbl->DrawInlineObject(This,clientDrawingContext,originX,originY,inlineObject,isSideways,isRightToLeft,clientDrawingEffect)
#define IDWriteTextRenderer_DrawStrikethrough(This,clientDrawingContext,baselineOriginX,baselineOriginY,strikethrough,clientDrawingEffect) (This)->lpVtbl->DrawStrikethrough(This,clientDrawingContext,baselineOriginX,baselineOriginY,strikethrough,clientDrawingEffect)
#define IDWriteTextRenderer_DrawUnderline(This,clientDrawingContext,baselineOriginX,baselineOriginY,underline,clientDrawingEffect) (This)->lpVtbl->DrawUnderline(This,clientDrawingContext,baselineOriginX,baselineOriginY,underline,clientDrawingEffect)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDWriteTypography
DECLARE_INTERFACE_(IDWriteTypography,IUnknown)
{
    BEGIN_INTERFACE

#ifndef __cplusplus
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif

    /* IDWriteTypography methods */
    STDMETHOD(AddFontFeature)(THIS_ DWRITE_FONT_FEATURE fontFeature) PURE;
    STDMETHOD_(UINT32,GetFontFeatureCount)(THIS) PURE;
    STDMETHOD(GetFontFeature)(THIS_ UINT32 fontFeatureIndex, DWRITE_FONT_FEATURE *fontFeature) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDWriteTypography_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDWriteTypography_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDWriteTypography_Release(This) (This)->lpVtbl->Release(This)
#define IDWriteTypography_AddFontFeature(This,fontFeature) (This)->lpVtbl->AddFontFeature(This,fontFeature)
#define IDWriteTypography_GetFontFeatureCount() (This)->lpVtbl->GetFontFeatureCount(This)
#define IDWriteTypography_GetFontFeature(This,fontFeatureIndex,fontFeature) (This)->lpVtbl->GetFontFeature(This,fontFeatureIndex,fontFeature)
#endif /*COBJMACROS*/

#ifdef __cplusplus
extern "C" {
#endif

DWRITEAPI HRESULT WINAPI DWriteCreateFactory(
  DWRITE_FACTORY_TYPE factoryType,
  REFIID iid,
  IUnknown **factory
);

#ifdef __cplusplus
}
#endif

__CRT_UUID_DECL(IDWriteBitmapRenderTarget, 0x5e5a32a3,0x8dff,0x4773,0x9f,0xf6,0x06,0x96,0xea,0xb7,0x72,0x67);
__CRT_UUID_DECL(IDWriteFactory, 0xb859ee5a,0xd838,0x4b5b,0xa2,0xe8,0x1a,0xdc,0x7d,0x93,0xdb,0x48);
__CRT_UUID_DECL(IDWriteFont, 0xacd16696,0x8c14,0x4f5d,0x87,0x7e,0xfe,0x3f,0xc1,0xd3,0x27,0x37);
__CRT_UUID_DECL(IDWriteFontCollection, 0xa84cee02,0x3eea,0x4eee,0xa8,0x27,0x87,0xc1,0xa0,0x2a,0x0f,0xcc);
__CRT_UUID_DECL(IDWriteFontFace, 0x5f49804d,0x7024,0x4d43,0xbf,0xa9,0xd2,0x59,0x84,0xf5,0x38,0x49);
__CRT_UUID_DECL(IDWriteFontList, 0x1a0d8438,0x1d97,0x4ec1,0xae,0xf9,0xa2,0xfb,0x86,0xed,0x6a,0xcb);
__CRT_UUID_DECL(IDWriteFontFamily, 0xda20d8ef,0x812a,0x4c43,0x98,0x02,0x62,0xec,0x4a,0xbd,0x7a,0xdd);
__CRT_UUID_DECL(IDWriteFontFile, 0x739d886a,0xcef5,0x47dc,0x87,0x69,0x1a,0x8b,0x41,0xbe,0xbb,0xb0);
__CRT_UUID_DECL(IDWriteFontFileLoader, 0x727cad4e,0xd6af,0x4c9e,0x8a,0x08,0xd6,0x95,0xb1,0x1c,0xaa,0x49);
__CRT_UUID_DECL(IDWriteFontFileStream, 0x6d4865fe,0x0ab8,0x4d91,0x8f,0x62,0x5d,0xd6,0xbe,0x34,0xa3,0xe0);
__CRT_UUID_DECL(IDWriteGdiInterop, 0x1edd9491,0x9853,0x4299,0x89,0x8f,0x64,0x32,0x98,0x3b,0x6f,0x3a);
__CRT_UUID_DECL(IDWriteGlyphRunAnalysis, 0x7d97dbf7,0xe085,0x42d4,0x81,0xe3,0x6a,0x88,0x3b,0xde,0xd1,0x18);
__CRT_UUID_DECL(IDWriteLocalizedStrings, 0x08256209,0x099a,0x4b34,0xb8,0x6d,0xc2,0x2b,0x11,0x0e,0x77,0x71);
__CRT_UUID_DECL(IDWriteRenderingParams, 0x2f0da53a,0x2add,0x47cd,0x82,0xee,0xd9,0xec,0x34,0x68,0x8e,0x75);
__CRT_UUID_DECL(IDWriteTextAnalysisSink, 0x5810cd44,0x0ca0,0x4701,0xb3,0xfa,0xbe,0xc5,0x18,0x2a,0xe4,0xf6);
__CRT_UUID_DECL(IDWriteTextAnalysisSource, 0x688e1a58,0x5094,0x47c8,0xad,0xc8,0xfb,0xce,0xa6,0x0a,0xe9,0x2b);
__CRT_UUID_DECL(IDWriteTextAnalyzer, 0xb7e6163e,0x7f46,0x43b4,0x84,0xb3,0xe4,0xe6,0x24,0x9c,0x36,0x5d);
__CRT_UUID_DECL(IDWritePixelSnapping, 0xeaf3a2da,0xecf4,0x4d24,0xb6,0x44,0xb3,0x4f,0x68,0x42,0x02,0x4b);
__CRT_UUID_DECL(IDWriteTextRenderer, 0xef8a8135,0x5cc6,0x45fe,0x88,0x25,0xc5,0xa0,0x72,0x4e,0xb8,0x19);
__CRT_UUID_DECL(IDWriteInlineObject, 0x8339fde3,0x106f,0x47ab,0x83,0x73,0x1c,0x62,0x95,0xeb,0x10,0xb3);
__CRT_UUID_DECL(IDWriteTextFormat, 0x9c906818,0x31d7,0x4fd3,0xa1,0x51,0x7c,0x5e,0x22,0x5d,0xb5,0x5a);
__CRT_UUID_DECL(IDWriteTextLayout, 0x53737037,0x6d14,0x410b,0x9b,0xfe,0x0b,0x18,0x2b,0xb7,0x09,0x61);
__CRT_UUID_DECL(IDWriteFontFileEnumerator, 0x72755049,0x5ff7,0x435d,0x83,0x48,0x4b,0xe9,0x7c,0xfa,0x6c,0x7c);
__CRT_UUID_DECL(IDWriteFontCollectionLoader, 0xcca920e4,0x52f0,0x492b,0xbf,0xa8,0x29,0xc7,0x2e,0xe0,0xa4,0x68);
__CRT_UUID_DECL(IDWriteTypography, 0x55f1112b,0x1dc2,0x4b3c,0x95,0x41,0xf4,0x68,0x94,0xed,0x85,0xb6);
__CRT_UUID_DECL(IDWriteLocalFontFileLoader,0xb2d9f3ec,0xc9fe,0x4a11,0xa2,0xec,0xd8,0x62,0x08,0xf7,0xc0,0xa2);

#endif /* __INC_DWRITE__ */
