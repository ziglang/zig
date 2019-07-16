/*
 * gdipluscolor.h
 *
 * GDI+ color
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Markus Koenig <markus@stber-koenig.de>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __GDIPLUS_COLOR_H
#define __GDIPLUS_COLOR_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

typedef enum ColorChannelFlags {
	ColorChannelFlagsC = 0,
	ColorChannelFlagsM = 1,
	ColorChannelFlagsY = 2,
	ColorChannelFlagsK = 3,
	ColorChannelFlagsLast = 4
} ColorChannelFlags;

typedef struct Color
{
	#ifdef __cplusplus
	private:
	#endif
	ARGB Value;

	#ifdef __cplusplus
	public:
	friend class Bitmap;
	friend class Graphics;
	friend class HatchBrush;
	friend class PathGradientBrush;
	friend class Pen;
	friend class SolidBrush;

	static ARGB MakeARGB(BYTE a, BYTE r, BYTE g, BYTE b)
	{
		return (ARGB) ((((DWORD) a) << 24) | (((DWORD) r) << 16)
		             | (((DWORD) g) << 8) | ((DWORD) b));
	}

	static const ARGB AlphaMask            = 0xFF000000;

	static const ARGB AliceBlue            = 0xFFF0F8FF;
	static const ARGB AntiqueWhite         = 0xFFFAEBD7;
	static const ARGB Aqua                 = 0xFF00FFFF;
	static const ARGB Aquamarine           = 0xFF7FFFD4;
	static const ARGB Azure                = 0xFFF0FFFF;
	static const ARGB Beige                = 0xFFF5F5DC;
	static const ARGB Bisque               = 0xFFFFE4C4;
	static const ARGB Black                = 0xFF000000;
	static const ARGB BlanchedAlmond       = 0xFFFFEBCD;
	static const ARGB Blue                 = 0xFF0000FF;
	static const ARGB BlueViolet           = 0xFF8A2BE2;
	static const ARGB Brown                = 0xFFA52A2A;
	static const ARGB BurlyWood            = 0xFFDEB887;
	static const ARGB CadetBlue            = 0xFF5F9EA0;
	static const ARGB Chartreuse           = 0xFF7FFF00;
	static const ARGB Chocolate            = 0xFFD2691E;
	static const ARGB Coral                = 0xFFFF7F50;
	static const ARGB CornflowerBlue       = 0xFF6495ED;
	static const ARGB Cornsilk             = 0xFFFFF8DC;
	static const ARGB Crimson              = 0xFFDC143C;
	static const ARGB Cyan                 = 0xFF00FFFF;
	static const ARGB DarkBlue             = 0xFF00008B;
	static const ARGB DarkCyan             = 0xFF008B8B;
	static const ARGB DarkGoldenrod        = 0xFFB8860B;
	static const ARGB DarkGray             = 0xFFA9A9A9;
	static const ARGB DarkGreen            = 0xFF006400;
	static const ARGB DarkKhaki            = 0xFFBDB76B;
	static const ARGB DarkMagenta          = 0xFF8B008B;
	static const ARGB DarkOliveGreen       = 0xFF556B2F;
	static const ARGB DarkOrange           = 0xFFFF8C00;
	static const ARGB DarkOrchid           = 0xFF9932CC;
	static const ARGB DarkRed              = 0xFF8B0000;
	static const ARGB DarkSalmon           = 0xFFE9967A;
	static const ARGB DarkSeaGreen         = 0xFF8FBC8F;
	static const ARGB DarkSlateBlue        = 0xFF483D8B;
	static const ARGB DarkSlateGray        = 0xFF2F4F4F;
	static const ARGB DarkTurquoise        = 0xFF00CED1;
	static const ARGB DarkViolet           = 0xFF9400D3;
	static const ARGB DeepPink             = 0xFFFF1493;
	static const ARGB DeepSkyBlue          = 0xFF00BFFF;
	static const ARGB DimGray              = 0xFF696969;
	static const ARGB DodgerBlue           = 0xFF1E90FF;
	static const ARGB Firebrick            = 0xFFB22222;
	static const ARGB FloralWhite          = 0xFFFFFAF0;
	static const ARGB ForestGreen          = 0xFF228B22;
	static const ARGB Fuchsia              = 0xFFFF00FF;
	static const ARGB Gainsboro            = 0xFFDCDCDC;
	static const ARGB GhostWhite           = 0xFFF8F8FF;
	static const ARGB Gold                 = 0xFFFFD700;
	static const ARGB Goldenrod            = 0xFFDAA520;
	static const ARGB Gray                 = 0xFF808080;
	static const ARGB Green                = 0xFF008000;
	static const ARGB GreenYellow          = 0xFFADFF2F;
	static const ARGB Honeydew             = 0xFFF0FFF0;
	static const ARGB HotPink              = 0xFFFF69B4;
	static const ARGB IndianRed            = 0xFFCD5C5C;
	static const ARGB Indigo               = 0xFF4B0082;
	static const ARGB Ivory                = 0xFFFFFFF0;
	static const ARGB Khaki                = 0xFFF0E68C;
	static const ARGB Lavender             = 0xFFE6E6FA;
	static const ARGB LavenderBlush        = 0xFFFFF0F5;
	static const ARGB LawnGreen            = 0xFF7CFC00;
	static const ARGB LemonChiffon         = 0xFFFFFACD;
	static const ARGB LightBlue            = 0xFFADD8E6;
	static const ARGB LightCoral           = 0xFFF08080;
	static const ARGB LightCyan            = 0xFFE0FFFF;
	static const ARGB LightGoldenrodYellow = 0xFFFAFAD2;
	static const ARGB LightGray            = 0xFFD3D3D3;
	static const ARGB LightGreen           = 0xFF90EE90;
	static const ARGB LightPink            = 0xFFFFB6C1;
	static const ARGB LightSalmon          = 0xFFFFA07A;
	static const ARGB LightSeaGreen        = 0xFF20B2AA;
	static const ARGB LightSkyBlue         = 0xFF87CEFA;
	static const ARGB LightSlateGray       = 0xFF778899;
	static const ARGB LightSteelBlue       = 0xFFB0C4DE;
	static const ARGB LightYellow          = 0xFFFFFFE0;
	static const ARGB Lime                 = 0xFF00FF00;
	static const ARGB LimeGreen            = 0xFF32CD32;
	static const ARGB Linen                = 0xFFFAF0E6;
	static const ARGB Magenta              = 0xFFFF00FF;
	static const ARGB Maroon               = 0xFF800000;
	static const ARGB MediumAquamarine     = 0xFF66CDAA;
	static const ARGB MediumBlue           = 0xFF0000CD;
	static const ARGB MediumOrchid         = 0xFFBA55D3;
	static const ARGB MediumPurple         = 0xFF9370DB;
	static const ARGB MediumSeaGreen       = 0xFF3CB371;
	static const ARGB MediumSlateBlue      = 0xFF7B68EE;
	static const ARGB MediumSpringGreen    = 0xFF00FA9A;
	static const ARGB MediumTurquoise      = 0xFF48D1CC;
	static const ARGB MediumVioletRed      = 0xFFC71585;
	static const ARGB MidnightBlue         = 0xFF191970;
	static const ARGB MintCream            = 0xFFF5FFFA;
	static const ARGB MistyRose            = 0xFFFFE4E1;
	static const ARGB Moccasin             = 0xFFFFE4B5;
	static const ARGB NavajoWhite          = 0xFFFFDEAD;
	static const ARGB Navy                 = 0xFF000080;
	static const ARGB OldLace              = 0xFFFDF5E6;
	static const ARGB Olive                = 0xFF808000;
	static const ARGB OliveDrab            = 0xFF6B8E23;
	static const ARGB Orange               = 0xFFFFA500;
	static const ARGB OrangeRed            = 0xFFFF4500;
	static const ARGB Orchid               = 0xFFDA70D6;
	static const ARGB PaleGoldenrod        = 0xFFEEE8AA;
	static const ARGB PaleGreen            = 0xFF98FB98;
	static const ARGB PaleTurquoise        = 0xFFAFEEEE;
	static const ARGB PaleVioletRed        = 0xFFDB7093;
	static const ARGB PapayaWhip           = 0xFFFFEFD5;
	static const ARGB PeachPuff            = 0xFFFFDAB9;
	static const ARGB Peru                 = 0xFFCD853F;
	static const ARGB Pink                 = 0xFFFFC0CB;
	static const ARGB Plum                 = 0xFFDDA0DD;
	static const ARGB PowderBlue           = 0xFFB0E0E6;
	static const ARGB Purple               = 0xFF800080;
	static const ARGB Red                  = 0xFFFF0000;
	static const ARGB RosyBrown            = 0xFFBC8F8F;
	static const ARGB RoyalBlue            = 0xFF4169E1;
	static const ARGB SaddleBrown          = 0xFF8B4513;
	static const ARGB Salmon               = 0xFFFA8072;
	static const ARGB SandyBrown           = 0xFFF4A460;
	static const ARGB SeaGreen             = 0xFF2E8B57;
	static const ARGB SeaShell             = 0xFFFFF5EE;
	static const ARGB Sienna               = 0xFFA0522D;
	static const ARGB Silver               = 0xFFC0C0C0;
	static const ARGB SkyBlue              = 0xFF87CEEB;
	static const ARGB SlateBlue            = 0xFF6A5ACD;
	static const ARGB SlateGray            = 0xFF708090;
	static const ARGB Snow                 = 0xFFFFFAFA;
	static const ARGB SpringGreen          = 0xFF00FF7F;
	static const ARGB SteelBlue            = 0xFF4682B4;
	static const ARGB Tan                  = 0xFFD2B48C;
	static const ARGB Teal                 = 0xFF008080;
	static const ARGB Thistle              = 0xFFD8BFD8;
	static const ARGB Tomato               = 0xFFFF6347;
	static const ARGB Transparent          = 0x00FFFFFF;
	static const ARGB Turquoise            = 0xFF40E0D0;
	static const ARGB Violet               = 0xFFEE82EE;
	static const ARGB Wheat                = 0xFFF5DEB3;
	static const ARGB White                = 0xFFFFFFFF;
	static const ARGB WhiteSmoke           = 0xFFF5F5F5;
	static const ARGB Yellow               = 0xFFFFFF00;
	static const ARGB YellowGreen          = 0xFF9ACD32;

	Color(): Value(0xFF000000) {}
	Color(ARGB argb): Value(argb) {}
	Color(BYTE r, BYTE g, BYTE b): Value(MakeARGB(0xFF, r, g, b)) {}
	Color(BYTE a, BYTE r, BYTE g, BYTE b): Value(MakeARGB(a, r, g, b)) {}

	BYTE GetA() const
	{
		return (BYTE) (Value >> 24);
	}
	BYTE GetAlpha() const
	{
		return (BYTE) (Value >> 24);
	}
	BYTE GetB() const
	{
		return (BYTE) Value;
	}
	BYTE GetBlue() const
	{
		return (BYTE) Value;
	}
	BYTE GetG() const
	{
		return (BYTE) (Value >> 8);
	}
	BYTE GetGreen() const
	{
		return (BYTE) (Value >> 8);
	}
	BYTE GetR() const
	{
		return (BYTE) (Value >> 16);
	}
	BYTE GetRed() const
	{
		return (BYTE) (Value >> 16);
	}
	ARGB GetValue() const
	{
		return Value;
	}
	VOID SetFromCOLORREF(COLORREF rgb)
	{
		BYTE r = (BYTE) rgb;
		BYTE g = (BYTE) (rgb >> 8);
		BYTE b = (BYTE) (rgb >> 16);
		Value = MakeARGB(0xFF, r, g, b);
	}
	VOID SetValue(ARGB argb)
	{
		Value = argb;
	}
	COLORREF ToCOLORREF() const
	{
		return RGB(GetRed(), GetGreen(), GetBlue());
	}
	#endif /* __cplusplus */
} Color;

#endif /* __GDIPLUS_COLOR_H */
