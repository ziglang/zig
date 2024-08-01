/*
 * Copyright (c) 2023-2024 Huawei Device Co., Ltd.
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

#ifndef C_INCLUDE_DRAWING_MEMORY_STREAM_H
#define C_INCLUDE_DRAWING_MEMORY_STREAM_H

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
 * @file drawing_memory_stream.h
 *
 * @brief Declares functions related to the <b>memoryStream</b> object in the drawing module.
 *
 * @since 12
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates a <b>OH_Drawing_MemoryStream</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_MemoryStream</b> object created.
 * @param data  file path.
 * @param length  Data length.
 * @param copyData  Copy data or not.
 * @since 12
 * @version 1.0
 */
OH_Drawing_MemoryStream* OH_Drawing_MemoryStreamCreate(const void* data, size_t length, bool copyData);

/**
 * @brief Destroys an <b>OH_Drawing_MemoryStream</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_MemoryStream Indicates the pointer to an <b>OH_Drawing_MemoryStream</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_MemoryStreamDestroy(OH_Drawing_MemoryStream*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif