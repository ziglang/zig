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
#ifndef DDK_API_H
#define DDK_API_H

/**
 * @addtogroup Ddk
 * @{
 *
 * @brief Provides Base DDK APIs, including creating the shared memory, mapping the shared memory,\n
 * unmapping the shared memory, and destroying the shared memory.
 *
 * @since 12
 */

/**
 * @file ddk_api.h
 *
 * @brief Declares the Base DDK APIs.
 *
 * @library libddk_base.z.so
 * @syscap SystemCapability.Driver.DDK.Extension
 * @since 12
 */

#include <stdint.h>
#include "ddk_types.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * @brief Creates shared memory. To prevent resource leakage, destroy the shared memory that is not required by\n
 * calling <b>OH_DDK_DestroyAshmem</b>.
 *
 * @param name Pointer to the shared memory to create.
 * @param size Size of the buffer corresponding to the shared memory.
 * @param ashmem Pointer to the shared memory created.
 * @return {@link DDK_SUCCESS} the operation is successful.
 *         {@link DDK_INVALID_PARAMETER} name is NULL, size is 0 or ashmem is NULL.
 *         {@link DDK_FAILURE} create the shared memory failed or create structure DDK_Ashmem failed.
 * @since 12
 */
DDK_RetCode OH_DDK_CreateAshmem(const uint8_t *name, uint32_t size, DDK_Ashmem **ashmem);

/**
 * @brief Maps the created shared memory to the user space. Unmap the shared memory that is not required by using\n
 * <b>OH_DDK_UnmapAshmem</b>.
 *
 * @param ashmem Pointer of the shared memory to map.
 * @param ashmemMapType Protection permission value of the shared memory.
 * @return {@link DDK_SUCCESS} the operation is successful.
 *         {@link DDK_NULL_PTR} ashmem is NULL.
 *         {@link DDK_FAILURE} the fd of ashmem is invalid.
 *         {@link DDK_INVALID_OPERATION} use function MapAshmem failed.
 * @since 12
 */
DDK_RetCode OH_DDK_MapAshmem(DDK_Ashmem *ashmem, const uint8_t ashmemMapType);

/**
 * @brief Unmaps shared memory.
 *
 * @param ashmem Pointer of the shared memory to unmap.
 * @return {@link DDK_SUCCESS} the operation is successful.
 *         {@link DDK_NULL_PTR} ashmem is NULL.
 *         {@link DDK_FAILURE} the fd of ashmem is invalid.
 * @since 12
 */
DDK_RetCode OH_DDK_UnmapAshmem(DDK_Ashmem *ashmem);

/**
 * @brief Destroys shared memory.
 *
 * @param ashmem Pointer of the shared memory to destroy.
 * @return {@link DDK_SUCCESS} the operation is successful.
 *         {@link DDK_NULL_PTR} ashmem is NULL.
 *         {@link DDK_FAILURE} the fd of ashmem is invalid.
 * @since 12
 */
DDK_RetCode OH_DDK_DestroyAshmem(DDK_Ashmem *ashmem);
#ifdef __cplusplus
}
/** @} */
#endif /* __cplusplus */
#endif // DDK_APIS_H