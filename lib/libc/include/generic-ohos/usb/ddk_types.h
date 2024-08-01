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
#ifndef DDK_TYPES_H
#define DDK_TYPES_H

/**
 * @addtogroup Ddk
 * @{
 *
 * @brief Provides Base DDK types and declares the macros, enums, and\n
 * data structs used by the Base DDK APIs.
 *
 * @since 12
 */

/**
 * @file ddk_types.h
 *
 * @brief Provides the enums, structs, and macros used in USB Base APIs.
 *
 * @library libddk_base.z.so
 * @syscap SystemCapability.Driver.DDK.Extension
 * @since 12
 */

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * @brief Defines the shared memory created by using <b>OH_DDK_CreateAshmem</b>.\n
 * A buffer for the shared memory provides better performance.
 *
 * @since 12
 */
typedef struct DDK_Ashmem {
    /** File descriptor of the shared memory. */
    int32_t ashmemFd;
    /** Buffer address. */
    const uint8_t *address;
    /** Buffer size. */
    const uint32_t size;
    /** Offset of the used buffer. The default value is 0, which indicates that there is no offset\n
     * and the buffer starts from the specified address.
     */
    uint32_t offset;
    /** Length of the used buffer. By default, the value is equal to the size, which indicates that\n
     * the entire buffer is used.
     */
    uint32_t bufferLength;
    /** Length of the transferred data. */
    uint32_t transferredLength;
} DDK_Ashmem;

/**
 * @brief Enumerates the error codes used in the Base DDK.
 *
 * @since 12
 */
typedef enum {
    /** @error Operation success */
    DDK_SUCCESS = 0,
    /** @error Operation failed */
    DDK_FAILURE = 28600001,
    /** @error Invalid parameter */
    DDK_INVALID_PARAMETER = 28600002,
    /** @error Invalid operation */
    DDK_INVALID_OPERATION = 28600003,
    /** @error Null pointer exception */
    DDK_NULL_PTR = 28600004
} DDK_RetCode;
#ifdef __cplusplus
}
/** @} */
#endif /* __cplusplus */
#endif // DDK_TYPES_H