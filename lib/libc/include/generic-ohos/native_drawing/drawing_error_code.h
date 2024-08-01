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

#ifndef C_INCLUDE_DRAWING_ERROR_CODE_H
#define C_INCLUDE_DRAWING_ERROR_CODE_H

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
 * @file drawing_error_code.h
 *
 * @brief Declares functions related to the error code in the drawing module.
 *
 * @library libnative_drawing.so
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @since 12
 * @version 1.0
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates error codes of drawing.
 * @since 12
 */
typedef enum {
    /**
     * @error Operation completed successfully.
     */
    OH_DRAWING_SUCCESS = 0,
    /**
     * @error Permission verification failed.
     */
    OH_DRAWING_ERROR_NO_PERMISSION = 201,
    /**
     * @error Invalid input parameter. For example, the pointer in the parameter is a nullptr.
     */
    OH_DRAWING_ERROR_INVALID_PARAMETER = 401,
    /**
     * @error The parameter is not in the valid range.
     */
    OH_DRAWING_ERROR_PARAMETER_OUT_OF_RANGE = 26200001,
} OH_Drawing_ErrorCode;

/**
 * @brief Obtains the error code of the drawing module.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the error code.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ErrorCode OH_Drawing_ErrorCodeGet();

#ifdef __cplusplus
}
#endif
/** @} */
#endif