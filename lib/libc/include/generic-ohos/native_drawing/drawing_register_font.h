/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef C_INCLUDE_DRAWING_REGISTER_FONT_H
#define C_INCLUDE_DRAWING_REGISTER_FONT_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides the 2D drawing capability.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 11
 * @version 1.0
 */

/**
 * @file drawing_register_font.h
 *
 * @brief Declares functions related to <b>FontManager</b> in the drawing module.
 *
 * @since 11
 * @version 1.0
 */

#include "drawing_text_declaration.h"
#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Defines an <b>OH_Drawing_RegisterFont</b>, which is used to register a customized font in the FontManager.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontCollection Indicates the pointer to an <b>OH_Drawing_FontCollection</b> object.
 * @param fontFamily Indicates the family-name of the font which need to register.
 * @param familySrc Indicates the path of the font file which need to register.
 * @return error code.
 * @since 11
 * @version 1.0
 */
uint32_t OH_Drawing_RegisterFont(OH_Drawing_FontCollection*, const char* fontFamily, const char* familySrc);

/**
 * @brief Defines an <b>OH_Drawing_RegisterFontBuffer</b>, which is used to register a customized font in the
 *        FontManager.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_FontCollection Indicates the pointer to an <b>OH_Drawing_FontCollection</b> object.
 * @param fontFamily Indicates the family-name of the font which need to register.
 * @param fontBuffer Indicates the buffer of the font file which need to register.
 * @param length Indicates the length of the font file which need to register.
 * @return error code.
 * @since 11
 * @version 1.0
 */
uint32_t OH_Drawing_RegisterFontBuffer(OH_Drawing_FontCollection*, const char* fontFamily, uint8_t* fontBuffer,
    size_t length);

#ifdef __cplusplus
}
#endif
/** @} */
#endif