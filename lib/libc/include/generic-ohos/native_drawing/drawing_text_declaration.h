/*
 * Copyright (c) 2021-2022 Huawei Device Co., Ltd.
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

#ifndef C_INCLUDE_DRAWING_TEXT_DECLARATION_H
#define C_INCLUDE_DRAWING_TEXT_DECLARATION_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides the 2D drawing capability.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 8
 * @version 1.0
 */

/**
 * @file drawing_text_declaration.h
 *
 * @brief Declares the data structure related to text in 2D drawing.
 *
 * @since 8
 * @version 1.0
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines an <b>OH_Drawing_FontCollection</b>, which is used to load fonts.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_FontCollection OH_Drawing_FontCollection;

/**
 * @brief Defines an <b>OH_Drawing_Typography</b>, which is used to manage the typography layout and display.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_Typography OH_Drawing_Typography;

/**
 * @brief Defines an <b>OH_Drawing_TextStyle</b>, which is used to manage text colors and decorations.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_TextStyle OH_Drawing_TextStyle;

/**
 * @brief Defines an <b>OH_Drawing_TypographyStyle</b>, which is used to manage the typography style,
 * such as the text direction.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_TypographyStyle OH_Drawing_TypographyStyle;

/**
 * @brief Defines an <b>OH_Drawing_TypographyCreate</b>, which is used to create an <b>OH_Drawing_Typography</b> object.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_TypographyCreate OH_Drawing_TypographyCreate;

/**
 * @brief Defines an <b>OH_Drawing_TextBox</b>, which is used to create an <b>OH_Drawing_TextBox</b> object.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_TextBox OH_Drawing_TextBox;

/**
 * @brief Defines an <b>OH_Drawing_PositionAndAffinity</b>,
 * which is used to create an <b>OH_Drawing_PositionAndAffinity</b> object.
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_PositionAndAffinity OH_Drawing_PositionAndAffinity;

/**
 * @brief Defines an <b>OH_Drawing_Range</b>, which is used to create an <b>OH_Drawing_Range</b> object.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_Range OH_Drawing_Range;

/**
 * @brief Defines an <b>OH_Drawing_FontParser</b>, which is used to parse system font files.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_FontParser OH_Drawing_FontParser;

/**
 * @brief Defines an <b>OH_Drawing_TextShadow</b>, which is used to manage text shadow.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_TextShadow OH_Drawing_TextShadow;

#ifdef __cplusplus
}
#endif
/** @} */
#endif