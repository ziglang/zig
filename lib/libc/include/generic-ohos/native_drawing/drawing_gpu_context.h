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

#ifndef C_INCLUDE_DRAWING_GPU_CONTEXT_H
#define C_INCLUDE_DRAWING_GPU_CONTEXT_H

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
 * @file drawing_gpu_context.h
 *
 * @brief Declares functions related to the <b>OH_Drawing_GpuContext</b> object in the drawing module.
 *
 * @since 12
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the options about GPU context.
 *
 * @since 12
 * @version 1.0
 */
typedef struct {
    /** If true this allows path mask textures to be cached */
    bool allowPathMaskCaching;
} OH_Drawing_GpuContextOptions;

/**
 * @brief Creates an <b>OH_Drawing_GpuContext</b> object, whose GPU backend context is GL.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_GpuContextOptions Indicates the GPU context options.
 * @return Returns the pointer to the <b>OH_Drawing_GpuContext</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_GpuContext* OH_Drawing_GpuContextCreateFromGL(OH_Drawing_GpuContextOptions);

/**
 * @brief Destroys an <b>OH_Drawing_GpuContext</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_GpuContext Indicates the pointer to an <b>OH_Drawing_GpuContext</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_GpuContextDestroy(OH_Drawing_GpuContext*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif