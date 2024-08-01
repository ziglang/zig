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

/**
 * @addtogroup ArkUI_NativeModule
 * @{
 *
 * @brief Provides ArkUI UI capabilities on the Native side, such as UI component creation and destruction,
 * tree node operation, property setting, event monitoring, and so on.
 *
 * @since 12
 */

/**
 * @file styled_string.h
 *
 * @brief Provides ArkUI with property string capabilities on the Native side.
 *
 * @library libace_ndk.z.so
 * @syscap SystemCapability.ArkUI.ArkUI.Full
 * @since 12
 */

#ifndef ARKUI_NATIVE_STYLED_STRING_H
#define ARKUI_NATIVE_STYLED_STRING_H

#include "native_drawing/drawing_text_declaration.h"
#include "native_drawing/drawing_text_typography.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines formatted string data objects supported by the text component.
 *
 * @since 12
 */
typedef struct ArkUI_StyledString ArkUI_StyledString;

/**
 * @brief Creates a pointer to the ArkUI_StyledString object.
 *
 * @param style A pointer to OH_Drawing_TypographyStyle, obtained by {@link OH_Drawing_CreateTypographyStyle}.
 * @param collection A pointer to OH_Drawing_FontCollection, obtained by {@link OH_Drawing_CreateFontCollection}.
 * @return Creates a pointer to the ArkUI_StyledString object. If the object returns a null pointer,
 *         the creation failed, either because the address space was full,
 *         or because the style, collection parameter was an exception such as a null pointer.
 * @since 12
 */
ArkUI_StyledString* OH_ArkUI_StyledString_Create(
    OH_Drawing_TypographyStyle* style, OH_Drawing_FontCollection* collection);

/**
 * @brief Free the memory occupied by the ArkUI_StyledString object.
 *
 * @param handle A pointer to the ArkUI_StyledString object.
 * @since 12
 */
void OH_ArkUI_StyledString_Destroy(ArkUI_StyledString* handle);

/**
 * @brief Sets the new layout style to the top of the current format string style stack.
 *
 * @param handle A pointer to the ArkUI_StyledString object.
 * @param style A pointer to the OH_Drawing_TextStyle object.
 * @since 12
 */
void OH_ArkUI_StyledString_PushTextStyle(ArkUI_StyledString* handle, OH_Drawing_TextStyle* style);

/**
 * @brief Sets the corresponding text content based on the current format string style.
 *
 * @param handle A pointer to the ArkUI_StyledString object.
 * @param content A pointer to the text content.
 * @since 12
 */
void OH_ArkUI_StyledString_AddText(ArkUI_StyledString* handle, const char* content);

/**
 * @brief Removes the top style from the stack in the current format string object.
 *
 * @param handle A pointer to the ArkUI_StyledString object.
 * @since 12
 */
void OH_ArkUI_StyledString_PopTextStyle(ArkUI_StyledString* handle);

/**
 * @brief Creates a pointer to an OH_Drawing_Typography object based on a format string object
 * for advanced text estimation and typography.
 *
 * @param handle A pointer to the ArkUI_StyledString object.
 * @return A pointer to the OH_Drawing_Typography object. If the object returns a null pointer,
 *         the creation fails because the handle parameter is abnormal, such as a null pointer.
 * @since 12
 */
OH_Drawing_Typography* OH_ArkUI_StyledString_CreateTypography(ArkUI_StyledString* handle);

/**
 * @brief Set the placeholder.
 *
 * @param handle A pointer to the ArkUI_StyledString object.
 * @param placeholder A pointer to the OH_Drawing_PlaceholderSpan object.
 * @since 12
 */
void OH_ArkUI_StyledString_AddPlaceholder(ArkUI_StyledString* handle, OH_Drawing_PlaceholderSpan* placeholder);

#ifdef __cplusplus
};
#endif

#endif // ARKUI_NATIVE_STYLED_STRING_H
/** @} */