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

#ifndef C_INCLUDE_DRAWING_COLOR_SPACE_H
#define C_INCLUDE_DRAWING_COLOR_SPACE_H

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
 * @file drawing_color_space.h
 *
 * @brief Declares functions related to the <b>colorSpace</b> object in the drawing module.
 *
 * @since 12
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates an <b>OH_Drawing_ColorSpace</b> object that represents the SRGB color space.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_ColorSpace</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ColorSpace* OH_Drawing_ColorSpaceCreateSrgb(void);

/**
 * @brief Creates an <b>OH_Drawing_ColorSpace</b> object with the SRGB primaries, but a linear (1.0) gamma.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_ColorSpace</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ColorSpace* OH_Drawing_ColorSpaceCreateSrgbLinear(void);

/**
 * @brief Destroy an <b>OH_Drawing_ColorSpace</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_ColorSpace Indicates the pointer to an <b>OH_Drawing_ColorSpace</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_ColorSpaceDestroy(OH_Drawing_ColorSpace*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif