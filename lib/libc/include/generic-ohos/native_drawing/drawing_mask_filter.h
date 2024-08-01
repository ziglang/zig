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

#ifndef C_INCLUDE_DRAWING_MASK_FILTER_H
#define C_INCLUDE_DRAWING_MASK_FILTER_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides functions such as 2D graphics rendering, text drawing, and image display.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 11
 * @version 1.0
 */

/**
 * @file drawing_mask_filter.h
 *
 * @brief Declares functions related to the <b>maskFilter</b> object in the drawing module.
 *
 * @since 11
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates blur type.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /**
     * Fuzzy inside and outside.
     */
    NORMAL,
    /**
     * Solid inside, fuzzy outside.
     */
    SOLID,
    /**
     * Nothing inside, fuzzy outside.
     */
    OUTER,
    /**
     * Fuzzy inside, nothing outside.
     */
    INNER,
} OH_Drawing_BlurType;

/**
 * @brief Creates an <b>OH_Drawing_MaskFilter</b> with a blur effect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param blurType Indicates the blur type.
 * @param sigma Indicates the standard deviation of the Gaussian blur to apply. Must be > 0.
 * @param respectCTM Indicates the blur's sigma is modified by the CTM, default is true.
 * @return Returns the pointer to the <b>OH_Drawing_MaskFilter</b> object created.
 * @since 11
 * @version 1.0
 */
OH_Drawing_MaskFilter* OH_Drawing_MaskFilterCreateBlur(OH_Drawing_BlurType blurType, float sigma, bool respectCTM);

/**
 * @brief Destroys an <b>OH_Drawing_MaskFilter</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_MaskFilter Indicates the pointer to an <b>OH_Drawing_MaskFilter</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_MaskFilterDestroy(OH_Drawing_MaskFilter*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif