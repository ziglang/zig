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

#ifndef CAPI_INCLUDE_IPC_ERROR_CODE_H
#define CAPI_INCLUDE_IPC_ERROR_CODE_H

/**
 * @addtogroup OHIPCErrorCode
 * @{
 *
 * @brief Provides IPC error codes.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @since 12
 */

/**
 * @file ipc_error_code.h
 *
 * @brief Defines IPC error codes.
 *
 * @library libipc_capi.so
 * @kit IPCKit
 * @syscap SystemCapability.Communication.IPC.Core
 * @since 12
 */

/**
* @brief Enumerates IPC error codes.
*
* @since 12
*/
typedef enum {
    /** @error Execution successful. */
    OH_IPC_SUCCESS = 0,
    /** @error Start error code. */
    OH_IPC_ERROR_CODE_BASE = 1901000,
    /** @error Invalid parameters. */
    OH_IPC_CHECK_PARAM_ERROR = OH_IPC_ERROR_CODE_BASE,
    /** @error Failed to write data to the serialized object. */
    OH_IPC_PARCEL_WRITE_ERROR = OH_IPC_ERROR_CODE_BASE + 1,
    /** @error Failed to read data from the serialized object. */
    OH_IPC_PARCEL_READ_ERROR = OH_IPC_ERROR_CODE_BASE + 2,
    /** @error Failed to allocate memory. */
    OH_IPC_MEM_ALLOCATOR_ERROR = OH_IPC_ERROR_CODE_BASE + 3,
    /** @error The command word is out of the value range [0x01,0x00ffffff]. */
    OH_IPC_CODE_OUT_OF_RANGE = OH_IPC_ERROR_CODE_BASE + 4,
    /** @error The remote object is dead. */
    OH_IPC_DEAD_REMOTE_OBJECT = OH_IPC_ERROR_CODE_BASE + 5,
    /** @error The custom error code is out of range [1900001, 1999999]. */
    OH_IPC_INVALID_USER_ERROR_CODE = OH_IPC_ERROR_CODE_BASE + 6,
    /** @error IPC internal error. */
    OH_IPC_INNER_ERROR = OH_IPC_ERROR_CODE_BASE + 7,
    /** @error Maximum error code. */
    OH_IPC_ERROR_CODE_MAX = OH_IPC_ERROR_CODE_BASE + 1000,
    /** @error Minimum value for a custom error code. */
    OH_IPC_USER_ERROR_CODE_MIN = 1909000,
    /** @error Maximum value for a custom error code. */
    OH_IPC_USER_ERROR_CODE_MAX = 1909999,
} OH_IPC_ErrorCode;

/** @} */
#endif