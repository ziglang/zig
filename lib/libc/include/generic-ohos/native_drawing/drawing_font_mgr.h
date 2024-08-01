/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef C_INCLUDE_DRAWING_FONT_MGR_H
#define C_INCLUDE_DRAWING_FONT_MGR_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides functions such as 2D graphics rendering, text drawing, and image display.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 12
 * @version 1.0
 */

/**
 * @file drawing_font_mgr.h
 *
 * @brief Declares functions related to the <b>fontmgr</b> object in the drawing module.
 *
 * @library libnative_drawing_ndk.z.so
 * @since 12
 * @version 1.0
 */

#include "drawing_types.h"
#include "drawing_text_typography.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates an <b>OH_Drawing_FontMgr</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_FontMgr</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_FontMgr* OH_Drawing_FontMgrCreate(void);

/**
 * @brief Releases the memory occupied by an <b>OH_Drawing_FontMgr</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontMgr Indicates the pointer to an <b>OH_Drawing_FontMgr</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_FontMgrDestroy(OH_Drawing_FontMgr*);

/**
 * @brief Gets the count of font families.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontMgr Indicates the pointer to an <b>OH_Drawing_FontMgr</b> object.
 * @return Returns the count of font families.
 * @since 12
 * @version 1.0
 */
int OH_Drawing_FontMgrGetFamilyCount(OH_Drawing_FontMgr*);

/**
 * @brief Gets the font family name by the index.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontMgr Indicates the pointer to an <b>OH_Drawing_FontMgr</b> object.
 * @param index Indicates the index to get the font family name.
 * @return Returns the font family name corresponding to the index value.
 * @since 12
 * @version 1.0
 */
char* OH_Drawing_FontMgrGetFamilyName(OH_Drawing_FontMgr*, int index);

/**
 * @brief Releases the memory occupied by font family name.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param familyName Indicates the font family name.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_FontMgrDestroyFamilyName(char* familyName);

/**
 * @brief Creates an <b>OH_Drawing_FontStyleSet</b> object by <b>OH_Drawing_FontMgr</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontMgr Indicates the pointer to an <b>OH_Drawing_FontMgr</b> object.
 * @param index Indicates the index used to get the font style set object from the font manager object.
 * @return Returns the pointer to the <b>OH_Drawing_FontStyleSet</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_FontStyleSet* OH_Drawing_FontMgrCreateFontStyleSet(OH_Drawing_FontMgr*, int index);

/**
 * @brief Releases the memory occupied by an <b>OH_Drawing_FontStyleSet</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontStyleSet Indicates the pointer to an <b>OH_Drawing_FontStyleSet</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_FontMgrDestroyFontStyleSet(OH_Drawing_FontStyleSet*);

/**
 * @brief Get the pointer to an <b>OH_Drawing_FontStyleSet</b> object for the given font style set family name.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontMgr Indicates the pointer to an <b>OH_Drawing_FontMgr</b> object.
 * @param familyName Indicates the family name of a font style set to be matched.
 * @return Returns the pointer to the <b>OH_Drawing_FontStyleSet</b> object matched.
 * @since 12
 * @version 1.0
 */
OH_Drawing_FontStyleSet* OH_Drawing_FontMgrMatchFamily(OH_Drawing_FontMgr*, const char* familyName);

/**
 * @brief Get the pointer to an <b>OH_Drawing_Typeface</b> object based on the given font style and family name.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontMgr Indicates the pointer to an <b>OH_Drawing_FontMgr</b> object.
 * @param familyName Indicates the family name of a font style set to be matched.
 * @param OH_Drawing_FontStyleStruct Indicates an <b>OH_Drawing_FontStyleStruct</b> object.
 * @return Returns the pointer to the <b>OH_Drawing_Typeface</b> object matched.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Typeface* OH_Drawing_FontMgrMatchFamilyStyle(OH_Drawing_FontMgr*,
    const char* familyName, OH_Drawing_FontStyleStruct fontStyle);

/**
 * @brief Get the pointer to an <b>OH_Drawing_Typeface</b> object for the given character.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontMgr Indicates the pointer to an <b>OH_Drawing_FontMgr</b> object.
 * @param familyName Indicates the family name of a font style set to be matched.
 * @param OH_Drawing_FontStyleStruct Indicates an <b>OH_Drawing_FontStyleStruct</b> object.
 * @param bcp47 Indicates an array of languages which indicate the language of character.
 * @param bcp47Count Indicates the array size of bcp47.
 * @param character Indicates a UTF8 value to be matched.
 * @return Returns the pointer to the <b>OH_Drawing_Typeface</b> object matched.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Typeface* OH_Drawing_FontMgrMatchFamilyStyleCharacter(OH_Drawing_FontMgr*, const char* familyName,
    OH_Drawing_FontStyleStruct fontStyle, const char* bcp47[], int bcp47Count, int32_t character);

/**
 * @brief Create a typeface for the given index.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontStyleSet Indicates the pointer to an <b>OH_Drawing_FontStyleSet</b> object.
 * @param index Indicates the index of the typeface in this fontStyleSet.
 * @return If successful, return a pointer to <b>OH_Drawing_Typeface</b> object; if failed, return nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Typeface* OH_Drawing_FontStyleSetCreateTypeface(OH_Drawing_FontStyleSet*, int index);

 /**
 * @brief Get font style for the specified typeface.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontStyleSet Indicates the pointer to an <b>OH_Drawing_FontStyleSet</b> object.
 * @param index Indicates the index of the typeface in this fontStyleSet.
 * @param styleName Indicates the style name returned.
 * @return Return the <b>OH_Drawing_FontStyleStruct<b> structure.
 * @since 12
 * @version 1.0
 */
OH_Drawing_FontStyleStruct OH_Drawing_FontStyleSetGetStyle(OH_Drawing_FontStyleSet*, int32_t index,
    char** styleName);

 /**
 * @brief Releases the memory  styleName string.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param styleName Indicates the pointer to a string type.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_FontStyleSetFreeStyleName(char** styleName);

/**
 * @brief Get the closest matching typeface.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontStyleSet Indicates the pointer to an <b>OH_Drawing_FontStyleSet</b> object.
 * @param fontStyleStruct Indicates the <b>OH_Drawing_FontStyleStruct</b> structure.
 * @return A pointer to matched <b>OH_Drawing_Typeface</b>.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Typeface* OH_Drawing_FontStyleSetMatchStyle(OH_Drawing_FontStyleSet*,
    OH_Drawing_FontStyleStruct fontStyleStruct);

/**
 * @brief Get the count of typeface.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontStyleSet Indicates the pointer to an <b>OH_Drawing_FontStyleSet</b> object.
 * @return The count of typeface in this font style set.
 * @since 12
 * @version 1.0
 */
int OH_Drawing_FontStyleSetCount(OH_Drawing_FontStyleSet*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif