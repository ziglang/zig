/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_SVG_
#define _D2D1_SVG_

#ifndef _D2D1_2_H_
#include <d2d1_2.h>
#endif

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

typedef interface ID2D1SvgDocument ID2D1SvgDocument;
typedef interface ID2D1SvgElement ID2D1SvgElement;

typedef enum D2D1_SVG_PAINT_TYPE {
  D2D1_SVG_PAINT_TYPE_NONE = 0,
  D2D1_SVG_PAINT_TYPE_COLOR = 1,
  D2D1_SVG_PAINT_TYPE_CURRENT_COLOR = 2,
  D2D1_SVG_PAINT_TYPE_URI = 3,
  D2D1_SVG_PAINT_TYPE_URI_NONE = 4,
  D2D1_SVG_PAINT_TYPE_URI_COLOR = 5,
  D2D1_SVG_PAINT_TYPE_URI_CURRENT_COLOR = 6,
  D2D1_SVG_PAINT_TYPE_FORCE_DWORD = 0xffffffff
} D2D1_SVG_PAINT_TYPE;

typedef enum D2D1_SVG_LENGTH_UNITS {
  D2D1_SVG_LENGTH_UNITS_NUMBER = 0,
  D2D1_SVG_LENGTH_UNITS_PERCENTAGE = 1,
  D2D1_SVG_LENGTH_UNITS_FORCE_DWORD = 0xffffffff
} D2D1_SVG_LENGTH_UNITS;

typedef enum D2D1_SVG_DISPLAY {
  D2D1_SVG_DISPLAY_INLINE = 0,
  D2D1_SVG_DISPLAY_NONE = 1,
  D2D1_SVG_DISPLAY_FORCE_DWORD = 0xffffffff
} D2D1_SVG_DISPLAY;

typedef enum D2D1_SVG_VISIBILITY {
  D2D1_SVG_VISIBILITY_VISIBLE = 0,
  D2D1_SVG_VISIBILITY_HIDDEN = 1,
  D2D1_SVG_VISIBILITY_FORCE_DWORD = 0xffffffff
} D2D1_SVG_VISIBILITY;

typedef enum D2D1_SVG_OVERFLOW {
  D2D1_SVG_OVERFLOW_VISIBLE = 0,
  D2D1_SVG_OVERFLOW_HIDDEN = 1,
  D2D1_SVG_OVERFLOW_FORCE_DWORD = 0xffffffff
} D2D1_SVG_OVERFLOW;

typedef enum D2D1_SVG_LINE_CAP {
  D2D1_SVG_LINE_CAP_BUTT = D2D1_CAP_STYLE_FLAT,
  D2D1_SVG_LINE_CAP_SQUARE = D2D1_CAP_STYLE_SQUARE,
  D2D1_SVG_LINE_CAP_ROUND = D2D1_CAP_STYLE_ROUND,
  D2D1_SVG_LINE_CAP_FORCE_DWORD = 0xffffffff
} D2D1_SVG_LINE_CAP;

typedef enum D2D1_SVG_LINE_JOIN {
  D2D1_SVG_LINE_JOIN_BEVEL = D2D1_LINE_JOIN_BEVEL,
  D2D1_SVG_LINE_JOIN_MITER = D2D1_LINE_JOIN_MITER_OR_BEVEL,
  D2D1_SVG_LINE_JOIN_ROUND = D2D1_LINE_JOIN_ROUND,
  D2D1_SVG_LINE_JOIN_FORCE_DWORD = 0xffffffff
} D2D1_SVG_LINE_JOIN;

typedef enum D2D1_SVG_ASPECT_ALIGN {
  D2D1_SVG_ASPECT_ALIGN_NONE = 0,
  D2D1_SVG_ASPECT_ALIGN_X_MIN_Y_MIN = 1,
  D2D1_SVG_ASPECT_ALIGN_X_MID_Y_MIN = 2,
  D2D1_SVG_ASPECT_ALIGN_X_MAX_Y_MIN = 3,
  D2D1_SVG_ASPECT_ALIGN_X_MIN_Y_MID = 4,
  D2D1_SVG_ASPECT_ALIGN_X_MID_Y_MID = 5,
  D2D1_SVG_ASPECT_ALIGN_X_MAX_Y_MID = 6,
  D2D1_SVG_ASPECT_ALIGN_X_MIN_Y_MAX = 7,
  D2D1_SVG_ASPECT_ALIGN_X_MID_Y_MAX = 8,
  D2D1_SVG_ASPECT_ALIGN_X_MAX_Y_MAX = 9,
  D2D1_SVG_ASPECT_ALIGN_FORCE_DWORD = 0xffffffff
} D2D1_SVG_ASPECT_ALIGN;

typedef enum D2D1_SVG_ASPECT_SCALING {
  D2D1_SVG_ASPECT_SCALING_MEET = 0,
  D2D1_SVG_ASPECT_SCALING_SLICE = 1,
  D2D1_SVG_ASPECT_SCALING_FORCE_DWORD = 0xffffffff
} D2D1_SVG_ASPECT_SCALING;

typedef enum D2D1_SVG_PATH_COMMAND {
  D2D1_SVG_PATH_COMMAND_CLOSE_PATH = 0,
  D2D1_SVG_PATH_COMMAND_MOVE_ABSOLUTE = 1,
  D2D1_SVG_PATH_COMMAND_MOVE_RELATIVE = 2,
  D2D1_SVG_PATH_COMMAND_LINE_ABSOLUTE = 3,
  D2D1_SVG_PATH_COMMAND_LINE_RELATIVE = 4,
  D2D1_SVG_PATH_COMMAND_CUBIC_ABSOLUTE = 5,
  D2D1_SVG_PATH_COMMAND_CUBIC_RELATIVE = 6,
  D2D1_SVG_PATH_COMMAND_QUADRADIC_ABSOLUTE = 7,
  D2D1_SVG_PATH_COMMAND_QUADRADIC_RELATIVE = 8,
  D2D1_SVG_PATH_COMMAND_ARC_ABSOLUTE = 9,
  D2D1_SVG_PATH_COMMAND_ARC_RELATIVE = 10,
  D2D1_SVG_PATH_COMMAND_HORIZONTAL_ABSOLUTE = 11,
  D2D1_SVG_PATH_COMMAND_HORIZONTAL_RELATIVE = 12,
  D2D1_SVG_PATH_COMMAND_VERTICAL_ABSOLUTE = 13,
  D2D1_SVG_PATH_COMMAND_VERTICAL_RELATIVE = 14,
  D2D1_SVG_PATH_COMMAND_CUBIC_SMOOTH_ABSOLUTE = 15,
  D2D1_SVG_PATH_COMMAND_CUBIC_SMOOTH_RELATIVE = 16,
  D2D1_SVG_PATH_COMMAND_QUADRADIC_SMOOTH_ABSOLUTE = 17,
  D2D1_SVG_PATH_COMMAND_QUADRADIC_SMOOTH_RELATIVE = 18,
  D2D1_SVG_PATH_COMMAND_FORCE_DWORD = 0xffffffff
} D2D1_SVG_PATH_COMMAND;

typedef enum D2D1_SVG_UNIT_TYPE {
  D2D1_SVG_UNIT_TYPE_USER_SPACE_ON_USE = 0,
  D2D1_SVG_UNIT_TYPE_OBJECT_BOUNDING_BOX = 1,
  D2D1_SVG_UNIT_TYPE_FORCE_DWORD = 0xffffffff
} D2D1_SVG_UNIT_TYPE;

typedef enum D2D1_SVG_ATTRIBUTE_STRING_TYPE {
  D2D1_SVG_ATTRIBUTE_STRING_TYPE_SVG = 0,
  D2D1_SVG_ATTRIBUTE_STRING_TYPE_ID = 1,
  D2D1_SVG_ATTRIBUTE_STRING_TYPE_FORCE_DWORD = 0xffffffff
} D2D1_SVG_ATTRIBUTE_STRING_TYPE;

typedef enum D2D1_SVG_ATTRIBUTE_POD_TYPE {
  D2D1_SVG_ATTRIBUTE_POD_TYPE_FLOAT = 0,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_COLOR = 1,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_FILL_MODE = 2,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_DISPLAY = 3,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_OVERFLOW = 4,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_LINE_CAP = 5,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_LINE_JOIN = 6,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_VISIBILITY = 7,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_MATRIX = 8,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_UNIT_TYPE = 9,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_EXTEND_MODE = 10,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_PRESERVE_ASPECT_RATIO = 11,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_VIEWBOX = 12,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_LENGTH = 13,
  D2D1_SVG_ATTRIBUTE_POD_TYPE_FORCE_DWORD = 0xffffffff
} D2D1_SVG_ATTRIBUTE_POD_TYPE;

typedef struct D2D1_SVG_LENGTH {
  FLOAT value;
  D2D1_SVG_LENGTH_UNITS units;
} D2D1_SVG_LENGTH;

typedef struct D2D1_SVG_PRESERVE_ASPECT_RATIO {
  WINBOOL defer;
  D2D1_SVG_ASPECT_ALIGN align;
  D2D1_SVG_ASPECT_SCALING meetOrSlice;
} D2D1_SVG_PRESERVE_ASPECT_RATIO;

typedef struct D2D1_SVG_VIEWBOX {
  FLOAT x;
  FLOAT y;
  FLOAT width;
  FLOAT height;
} D2D1_SVG_VIEWBOX;

#if NTDDI_VERSION >= NTDDI_WIN10_RS2

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SvgAttribute : public ID2D1Resource
{
  STDMETHOD_(void, GetElement)(ID2D1SvgElement **element) PURE;
  STDMETHOD(Clone)(ID2D1SvgAttribute **attribute) PURE;
};
#else
typedef interface ID2D1SvgAttribute ID2D1SvgAttribute;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SvgAttribute, 0xc9cdb0dd, 0xf8c9, 0x4e70, 0xb7, 0xc2, 0x30, 0x1c, 0x80, 0x29, 0x2c, 0x5e);
__CRT_UUID_DECL(ID2D1SvgAttribute, 0xc9cdb0dd, 0xf8c9, 0x4e70, 0xb7, 0xc2, 0x30, 0x1c, 0x80, 0x29, 0x2c, 0x5e);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SvgPaint : public ID2D1SvgAttribute
{
  STDMETHOD(SetPaintType)(D2D1_SVG_PAINT_TYPE paint_type) PURE;
  STDMETHOD_(D2D1_SVG_PAINT_TYPE, GetPaintType)() PURE;
  STDMETHOD(SetColor)(const D2D1_COLOR_F *color) PURE;
  STDMETHOD_(void, GetColor)(D2D1_COLOR_F *color) PURE;
  STDMETHOD(SetId)(PCWSTR id) PURE;
  STDMETHOD(GetId)(PWSTR id, UINT32 id_count) PURE;
  STDMETHOD_(UINT32, GetIdLength)() PURE;

  COM_DECLSPEC_NOTHROW HRESULT SetColor(const D2D1_COLOR_F &color) {
    return SetColor(&color);
  }
};
#else
typedef interface ID2D1SvgPaint ID2D1SvgPaint;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SvgPaint, 0xd59bab0a, 0x68a2, 0x455b, 0xa5, 0xdc, 0x9e, 0xb2, 0x85, 0x4e, 0x24, 0x90);
__CRT_UUID_DECL(ID2D1SvgPaint, 0xd59bab0a, 0x68a2, 0x455b, 0xa5, 0xdc, 0x9e, 0xb2, 0x85, 0x4e, 0x24, 0x90);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SvgStrokeDashArray : public ID2D1SvgAttribute
{
  STDMETHOD(RemoveDashesAtEnd)(UINT32 dashes_count) PURE;
  STDMETHOD(UpdateDashes)(const FLOAT *dashes, UINT32 dashes_count, UINT32 start_index = 0) PURE;
  STDMETHOD(UpdateDashes)(const D2D1_SVG_LENGTH *dashes, UINT32 dashes_count, UINT32 start_index = 0) PURE;
  STDMETHOD(GetDashes)(FLOAT *dashes, UINT32 dashes_count, UINT32 start_index = 0) PURE;
  STDMETHOD(GetDashes)(D2D1_SVG_LENGTH *dashes, UINT32 dashes_count, UINT32 start_index = 0) PURE;
  STDMETHOD_(UINT32, GetDashesCount)() PURE;
};
#else
typedef interface ID2D1SvgStrokeDashArray ID2D1SvgStrokeDashArray;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SvgStrokeDashArray, 0xf1c0ca52, 0x92a3, 0x4f00, 0xb4, 0xce, 0xf3, 0x56, 0x91, 0xef, 0xd9, 0xd9);
__CRT_UUID_DECL(ID2D1SvgStrokeDashArray, 0xf1c0ca52, 0x92a3, 0x4f00, 0xb4, 0xce, 0xf3, 0x56, 0x91, 0xef, 0xd9, 0xd9);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SvgPointCollection : public ID2D1SvgAttribute
{
  STDMETHOD(RemovePointsAtEnd)(UINT32 points_count) PURE;
  STDMETHOD(UpdatePoints)(const D2D1_POINT_2F *points, UINT32 points_count, UINT32 start_index = 0) PURE;
  STDMETHOD(GetPoints)(D2D1_POINT_2F *points, UINT32 points_count, UINT32 start_index = 0) PURE;
  STDMETHOD_(UINT32, GetPointsCount)() PURE;
};
#else
typedef interface ID2D1SvgPointCollection ID2D1SvgPointCollection;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SvgPointCollection, 0x9dbe4c0d, 0x3572, 0x4dd9, 0x98, 0x25, 0x55, 0x30, 0x81, 0x3b, 0xb7, 0x12);
__CRT_UUID_DECL(ID2D1SvgPointCollection, 0x9dbe4c0d, 0x3572, 0x4dd9, 0x98, 0x25, 0x55, 0x30, 0x81, 0x3b, 0xb7, 0x12);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SvgPathData : public ID2D1SvgAttribute
{
  STDMETHOD(RemoveSegmentDataAtEnd)(UINT32 data_count) PURE;
  STDMETHOD(UpdateSegmentData)(const FLOAT *data, UINT32 data_count, UINT32 start_index = 0) PURE;
  STDMETHOD(GetSegmentData)(FLOAT *data, UINT32 data_count, UINT32 start_index = 0) PURE;
  STDMETHOD_(UINT32, GetSegmentDataCount)() PURE;
  STDMETHOD(RemoveCommandsAtEnd)(UINT32 commands_count) PURE;
  STDMETHOD(UpdateCommands)(const D2D1_SVG_PATH_COMMAND *commands, UINT32 commands_count, UINT32 start_index = 0) PURE;
  STDMETHOD(GetCommands)(D2D1_SVG_PATH_COMMAND *commands, UINT32 commands_count, UINT32 start_index = 0) PURE;
  STDMETHOD_(UINT32, GetCommandsCount)() PURE;
  STDMETHOD(CreatePathGeometry)(D2D1_FILL_MODE fill_mode, ID2D1PathGeometry1 **path_geometry) PURE;
};
#else
typedef interface ID2D1SvgPathData ID2D1SvgPathData;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SvgPathData, 0xc095e4f4, 0xbb98, 0x43d6, 0x97, 0x45, 0x4d, 0x1b, 0x84, 0xec, 0x98, 0x88);
__CRT_UUID_DECL(ID2D1SvgPathData, 0xc095e4f4, 0xbb98, 0x43d6, 0x97, 0x45, 0x4d, 0x1b, 0x84, 0xec, 0x98, 0x88);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SvgElement : public ID2D1Resource
{
  STDMETHOD_(void, GetDocument)(ID2D1SvgDocument **document) PURE;
  STDMETHOD(GetTagName)(PWSTR name, UINT32 name_count) PURE;
  STDMETHOD_(UINT32, GetTagNameLength)() PURE;
  STDMETHOD_(WINBOOL, IsTextContent)() PURE;
  STDMETHOD_(void, GetParent)(ID2D1SvgElement **parent) PURE;
  STDMETHOD_(WINBOOL, HasChildren)() PURE;
  STDMETHOD_(void, GetFirstChild)(ID2D1SvgElement **child) PURE;
  STDMETHOD_(void, GetLastChild)(ID2D1SvgElement **child) PURE;
  STDMETHOD(GetPreviousChild)(ID2D1SvgElement *reference_child, ID2D1SvgElement **previous_child) PURE;
  STDMETHOD(GetNextChild)(ID2D1SvgElement *reference_child, ID2D1SvgElement **next_child) PURE;
  STDMETHOD(InsertChildBefore)(ID2D1SvgElement *new_child, ID2D1SvgElement *reference_child = NULL) PURE;
  STDMETHOD(AppendChild)(ID2D1SvgElement *new_child) PURE;
  STDMETHOD(ReplaceChild)(ID2D1SvgElement *new_child, ID2D1SvgElement *old_child) PURE;
  STDMETHOD(RemoveChild)(ID2D1SvgElement *old_child) PURE;
  STDMETHOD(CreateChild)(PCWSTR tag_name, ID2D1SvgElement **new_child) PURE;
  STDMETHOD_(WINBOOL, IsAttributeSpecified)(PCWSTR name, WINBOOL *inherited = NULL) PURE;
  STDMETHOD_(UINT32, GetSpecifiedAttributeCount)() PURE;
  STDMETHOD(GetSpecifiedAttributeName)(UINT32 index, PWSTR name, UINT32 name_count, WINBOOL *inherited = NULL) PURE;
  STDMETHOD(GetSpecifiedAttributeNameLength)(UINT32 index, UINT32 *name_length, WINBOOL *inherited = NULL) PURE;
  STDMETHOD(RemoveAttribute)(PCWSTR name) PURE;
  STDMETHOD(SetTextValue)(const WCHAR *name, UINT32 name_count) PURE;
  STDMETHOD(GetTextValue)(PWSTR name, UINT32 name_count) PURE;
  STDMETHOD_(UINT32, GetTextValueLength)() PURE;
  STDMETHOD(SetAttributeValue)(PCWSTR name, D2D1_SVG_ATTRIBUTE_STRING_TYPE type, PCWSTR value) PURE;
  STDMETHOD(GetAttributeValue)(PCWSTR name, D2D1_SVG_ATTRIBUTE_STRING_TYPE type, PWSTR value, UINT32 value_count) PURE;
  STDMETHOD(GetAttributeValueLength)(PCWSTR name, D2D1_SVG_ATTRIBUTE_STRING_TYPE type, UINT32 *value_length) PURE;
  STDMETHOD(SetAttributeValue)(PCWSTR name, D2D1_SVG_ATTRIBUTE_POD_TYPE type, const void *value, UINT32 value_size_in_bytes) PURE;
  STDMETHOD(GetAttributeValue)(PCWSTR name, D2D1_SVG_ATTRIBUTE_POD_TYPE type, void *value, UINT32 value_size_in_bytes) PURE;
  STDMETHOD(SetAttributeValue)(PCWSTR name, ID2D1SvgAttribute *value) PURE;
  STDMETHOD(GetAttributeValue)(PCWSTR name, REFIID riid, void **value) PURE;

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, FLOAT value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_FLOAT, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, FLOAT *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_FLOAT, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, const D2D1_COLOR_F &value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_COLOR, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_COLOR_F *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_COLOR, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, D2D1_FILL_MODE value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_FILL_MODE, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_FILL_MODE *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_FILL_MODE, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, D2D1_SVG_DISPLAY value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_DISPLAY, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_SVG_DISPLAY *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_DISPLAY, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, D2D1_SVG_OVERFLOW value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_OVERFLOW, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_SVG_OVERFLOW *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_OVERFLOW, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, D2D1_SVG_LINE_JOIN value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_LINE_JOIN, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_SVG_LINE_JOIN *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_LINE_JOIN, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, D2D1_SVG_LINE_CAP value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_LINE_CAP, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_SVG_LINE_CAP *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_LINE_CAP, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, D2D1_SVG_VISIBILITY value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_VISIBILITY, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_SVG_VISIBILITY *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_VISIBILITY, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, const D2D1_MATRIX_3X2_F &value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_MATRIX, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_MATRIX_3X2_F *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_MATRIX, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, D2D1_SVG_UNIT_TYPE value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_UNIT_TYPE, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_SVG_UNIT_TYPE *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_UNIT_TYPE, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, D2D1_EXTEND_MODE value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_EXTEND_MODE, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_EXTEND_MODE *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_EXTEND_MODE, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, const D2D1_SVG_PRESERVE_ASPECT_RATIO &value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_PRESERVE_ASPECT_RATIO, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_SVG_PRESERVE_ASPECT_RATIO *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_PRESERVE_ASPECT_RATIO, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT SetAttributeValue(PCWSTR name, const D2D1_SVG_LENGTH &value) {
    return SetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_LENGTH, &value, sizeof(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, D2D1_SVG_LENGTH *value) {
    return GetAttributeValue(name, D2D1_SVG_ATTRIBUTE_POD_TYPE_LENGTH, value, sizeof(*value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, ID2D1SvgAttribute **value) {
    return GetAttributeValue(name, IID_ID2D1SvgAttribute, reinterpret_cast<void **>(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, ID2D1SvgPaint **value) {
    return GetAttributeValue(name, IID_ID2D1SvgPaint, reinterpret_cast<void **>(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, ID2D1SvgStrokeDashArray **value) {
    return GetAttributeValue(name, IID_ID2D1SvgStrokeDashArray, reinterpret_cast<void **>(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, ID2D1SvgPointCollection **value) {
    return GetAttributeValue(name, IID_ID2D1SvgPointCollection, reinterpret_cast<void **>(value));
  }

  COM_DECLSPEC_NOTHROW HRESULT GetAttributeValue(PCWSTR name, ID2D1SvgPathData **value) {
    return GetAttributeValue(name, IID_ID2D1SvgPathData, reinterpret_cast<void **>(value));
  }
};
#else
typedef interface ID2D1SvgElement ID2D1SvgElement;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SvgElement, 0xac7b67a6, 0x183e, 0x49c1, 0xa8, 0x23, 0x0e, 0xbe, 0x40, 0xb0, 0xdb, 0x29);
__CRT_UUID_DECL(ID2D1SvgElement, 0xac7b67a6, 0x183e, 0x49c1, 0xa8, 0x23, 0x0e, 0xbe, 0x40, 0xb0, 0xdb, 0x29);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SvgDocument : public ID2D1Resource
{
  STDMETHOD(SetViewportSize)(D2D1_SIZE_F viewport_size) PURE;
#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
  STDMETHOD_(D2D1_SIZE_F, GetViewportSize)() const PURE;
#else
  virtual D2D1_SIZE_F* STDMETHODCALLTYPE GetViewportSize(D2D1_SIZE_F*) const = 0;
  D2D1_SIZE_F STDMETHODCALLTYPE GetViewportSize() const {
    D2D1_SIZE_F __ret;
    GetViewportSize(&__ret);
    return __ret;
  }
#endif
  STDMETHOD(SetRoot)(ID2D1SvgElement *root) PURE;
  STDMETHOD_(void, GetRoot)(ID2D1SvgElement **root) PURE;
  STDMETHOD(FindElementById)(PCWSTR id, ID2D1SvgElement **svg_element) PURE;
  STDMETHOD(Serialize)(IStream *output_xml_stream, ID2D1SvgElement *subtree = NULL) PURE;
  STDMETHOD(Deserialize)(IStream *input_xml_stream, ID2D1SvgElement **subtree) PURE;
  STDMETHOD(CreatePaint)(D2D1_SVG_PAINT_TYPE paint_type, const D2D1_COLOR_F *color, PCWSTR id, ID2D1SvgPaint **paint) PURE;
  STDMETHOD(CreateStrokeDashArray)(const D2D1_SVG_LENGTH *dashes, UINT32 dashes_count, ID2D1SvgStrokeDashArray **stroke_dash_array) PURE;
  STDMETHOD(CreatePointCollection)(const D2D1_POINT_2F *points, UINT32 points_count, ID2D1SvgPointCollection **point_collection) PURE;
  STDMETHOD(CreatePathData)(const FLOAT *segment_data, UINT32 segment_data_count, const D2D1_SVG_PATH_COMMAND *commands, UINT32 commands_count, ID2D1SvgPathData **path_data) PURE;

  COM_DECLSPEC_NOTHROW HRESULT CreatePaint(D2D1_SVG_PAINT_TYPE paint_type, const D2D1_COLOR_F &color, PCWSTR id, ID2D1SvgPaint **paint) {
    return CreatePaint(paint_type, &color, id, paint);
  }
};
#else
typedef interface ID2D1SvgDocument ID2D1SvgDocument;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SvgDocument, 0x86b88e4d, 0xafa4, 0x4d7b, 0x88, 0xe4, 0x68, 0xa5, 0x1c, 0x4a, 0x0a, 0xec);
__CRT_UUID_DECL(ID2D1SvgDocument, 0x86b88e4d, 0xafa4, 0x4d7b, 0x88, 0xe4, 0x68, 0xa5, 0x1c, 0x4a, 0x0a, 0xec);

#endif /* NTDDI_VERSION >= NTDDI_WIN10_RS2 */

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#endif /* _D2D1_SVG_ */
