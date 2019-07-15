/*
 * gdiplusstringformat.h
 *
 * GDI+ StringFormat class
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

#ifndef __GDIPLUS_STRINGFORMAT_H
#define __GDIPLUS_STRINGFORMAT_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdiplusstringformat.h."
#endif

class StringFormat: public GdiplusBase
{
	friend class Graphics;
	friend class GraphicsPath;

public:
	static const StringFormat* GenericDefault();
	static const StringFormat* GenericTypographic();

	StringFormat(INT formatFlags = 0, LANGID language = LANG_NEUTRAL):
			nativeStringFormat(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreateStringFormat(
				formatFlags, language, &nativeStringFormat);
	}
	StringFormat(const StringFormat *format):
			nativeStringFormat(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCloneStringFormat(
				format ? format->nativeStringFormat : NULL,
				&nativeStringFormat);
	}
	~StringFormat()
	{
		DllExports::GdipDeleteStringFormat(nativeStringFormat);
	}
	StringFormat* Clone() const
	{
		GpStringFormat *cloneStringFormat = NULL;
		Status status = updateStatus(DllExports::GdipCloneStringFormat(
				nativeStringFormat, &cloneStringFormat));
		if (status == Ok) {
			StringFormat *result = new StringFormat(
					cloneStringFormat, lastStatus);
			if (!result) {
				DllExports::GdipDeleteStringFormat(cloneStringFormat);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	StringAlignment GetAlignment() const
	{
		StringAlignment result = StringAlignmentNear;
		updateStatus(DllExports::GdipGetStringFormatAlign(
				nativeStringFormat, &result));
		return result;
	}
	LANGID GetDigitSubstitutionLanguage() const
	{
		LANGID result = 0;
		StringDigitSubstitute method;
		updateStatus(DllExports::GdipGetStringFormatDigitSubstitution(
				nativeStringFormat, &result, &method));
		return result;
	}
	StringDigitSubstitute GetDigitSubstitutionMethod() const
	{
		LANGID language;
		StringDigitSubstitute result = StringDigitSubstituteUser;
		updateStatus(DllExports::GdipGetStringFormatDigitSubstitution(
				nativeStringFormat, &language, &result));
		return result;
	}
	INT GetFormatFlags() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetStringFormatFlags(
				nativeStringFormat, &result));
		return result;
	}
	HotkeyPrefix GetHotkeyPrefix() const
	{
		HotkeyPrefix result = HotkeyPrefixNone;
		updateStatus(DllExports::GdipGetStringFormatHotkeyPrefix(
				nativeStringFormat, (INT*) &result));
		return result;
	}
	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}
	StringAlignment GetLineAlignment() const
	{
		StringAlignment result = StringAlignmentNear;
		updateStatus(DllExports::GdipGetStringFormatLineAlign(
				nativeStringFormat, &result));
		return result;
	}
	INT GetMeasurableCharacterRangeCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetStringFormatMeasurableCharacterRangeCount(
				nativeStringFormat, &result));
		return result;
	}
	INT GetTabStopCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetStringFormatTabStopCount(
				nativeStringFormat, &result));
		return result;
	}
	Status GetTabStops(INT count, REAL *firstTabOffset, REAL *tabStops)
	{
		return updateStatus(DllExports::GdipGetStringFormatTabStops(
				nativeStringFormat, count,
				firstTabOffset, tabStops));
	}
	StringTrimming GetTrimming() const
	{
		StringTrimming result = StringTrimmingNone;
		updateStatus(DllExports::GdipGetStringFormatTrimming(
				nativeStringFormat, &result));
		return result;
	}
	Status SetAlignment(StringAlignment align)
	{
		return updateStatus(DllExports::GdipSetStringFormatAlign(
				nativeStringFormat, align));
	}
	Status SetDigitSubstitution(LANGID language,
			StringDigitSubstitute substitute)
	{
		return updateStatus(DllExports::GdipSetStringFormatDigitSubstitution(
				nativeStringFormat, language, substitute));
	}
	Status SetFormatFlags(INT flags)
	{
		return updateStatus(DllExports::GdipSetStringFormatFlags(
				nativeStringFormat, flags));
	}
	Status SetHotkeyPrefix(HotkeyPrefix hotkeyPrefix)
	{
		return updateStatus(DllExports::GdipSetStringFormatHotkeyPrefix(
				nativeStringFormat, (INT) hotkeyPrefix));
	}
	Status SetLineAlignment(StringAlignment align)
	{
		return updateStatus(DllExports::GdipSetStringFormatLineAlign(
				nativeStringFormat, align));
	}
	Status SetMeasurableCharacterRanges(INT rangeCount,
			const CharacterRange *ranges)
	{
		return updateStatus(DllExports::GdipSetStringFormatMeasurableCharacterRanges(
				nativeStringFormat, rangeCount, ranges));
	}
	Status SetTabStops(REAL firstTabOffset, INT count, const REAL *tabStops)
	{
		return updateStatus(DllExports::GdipSetStringFormatTabStops(
				nativeStringFormat, firstTabOffset,
				count, tabStops));
	}
	Status SetTrimming(StringTrimming trimming)
	{
		return updateStatus(DllExports::GdipSetStringFormatTrimming(
				nativeStringFormat, trimming));
	}

private:
	StringFormat(GpStringFormat *stringFormat, Status status):
		nativeStringFormat(stringFormat), lastStatus(status) {}
	StringFormat(const StringFormat&);
	StringFormat& operator=(const StringFormat&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpStringFormat *nativeStringFormat;
	mutable Status lastStatus;
};


// FIXME: do StringFormat::GenericDefault() et al. need to be thread safe?
// FIXME: maybe put this in gdiplus.c?

extern "C" void *_GdipStringFormatCachedGenericDefault;
extern "C" void *_GdipStringFormatCachedGenericTypographic;

__inline__ const StringFormat* StringFormat::GenericDefault()
{
	if (!_GdipStringFormatCachedGenericDefault) {
		GpStringFormat *nativeStringFormat = 0;
		Status status = DllExports::GdipStringFormatGetGenericDefault(
				&nativeStringFormat);
		if (status == Ok && nativeStringFormat) {
			_GdipStringFormatCachedGenericDefault = (void*)
				new StringFormat(nativeStringFormat, Ok);
		}
	}
	return (StringFormat*) _GdipStringFormatCachedGenericDefault;
}

__inline__ const StringFormat* StringFormat::GenericTypographic()
{
	if (!_GdipStringFormatCachedGenericTypographic) {
		GpStringFormat *nativeStringFormat = 0;
		Status status = DllExports::GdipStringFormatGetGenericTypographic(
				&nativeStringFormat);
		if (status == Ok && nativeStringFormat) {
			_GdipStringFormatCachedGenericTypographic = (void*)
				new StringFormat(nativeStringFormat, Ok);
		}
	}
	return (StringFormat*) _GdipStringFormatCachedGenericTypographic;
}



#endif /* __GDIPLUS_STRINGFORMAT_H */
