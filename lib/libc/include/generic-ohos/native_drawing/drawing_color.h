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

#ifndef C_INCLUDE_DRAWING_COLOR_H
#define C_INCLUDE_DRAWING_COLOR_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides functions such as 2D graphics rendering, text drawing, and image display.
 * 
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 8
 * @version 1.0
 */

/**
 * @file drawing_color.h
 *
 * @brief Declares functions related to the <b>color</b> object in the drawing module.
 *
 * @since 8
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Converts four variables (alpha, red, green, and blue) into a 32-bit (ARGB) variable that describes a color.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param alpha Indicates a variable that describes alpha. The value ranges from 0x00 to 0xFF.
 * @param red Indicates a variable that describes red. The value ranges from 0x00 to 0xFF.
 * @param green Indicates a variable that describes green. The value ranges from 0x00 to 0xFF.
 * @param blue Indicates a variable that describes blue. The value ranges from 0x00 to 0xFF.
 * @return Returns a 32-bit (ARGB) variable that describes the color.
 * @since 8
 * @version 1.0
 */
uint32_t OH_Drawing_ColorSetArgb(uint32_t alpha, uint32_t red, uint32_t green, uint32_t blue);

#ifdef __cplusplus
}
#endif
/** @} */
#endif