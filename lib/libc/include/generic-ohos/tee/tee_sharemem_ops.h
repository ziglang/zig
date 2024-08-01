/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef TEE_SHAREMEM_OPS_H
#define TEE_SHAREMEM_OPS_H

/**
 * @addtogroup TeeTrusted
 * @{
 *
 * @brief TEE(Trusted Excution Environment) API.
 * Provides security capability APIs such as trusted storage, encryption and decryption,
 * and trusted time for trusted application development.
 *
 * @since 12
 */

/**
 * @file tee_sharemem_ops.h
 *
 * @brief Provides  APIs for developers to apply for shared memory.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <stdint.h>
#include <tee_defines.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Alloc shared memory in TEE.
 *
 * @param uuid Indicates the UUID of TA.
 * @param size Indicates the size of the requested shared memory.
 *
 * @return Returns a pointer to the newly allocated space if the operation is successful.
 *         Returns a <b>NULL</b> pointer if the allocation fails.
 *
 * @since 12
 * @version 1.0
 */
void *tee_alloc_sharemem_aux(const struct tee_uuid *uuid, uint32_t size);

/**
 * @brief Alloc continuous shared memory in TEE.
 *
 * @param uuid Indicates the UUID of TA.
 * @param size Indicates the size of the requested shared memory.
 *
 * @return Returns a pointer to the newly allocated space if the operation is successful.
 *         Returns a <b>NULL</b> pointer if the allocation fails.
 *
 * @since 12
 * @version 1.0
 */
void *tee_alloc_coherent_sharemem_aux(const struct tee_uuid *uuid, uint32_t size);

/**
 * @brief Free the shared memory in TEE.
 *
 * @param addr Indicates the shared memory address that will be freed.
 * @param size Indicates the size of the shared memory.
 *
 * @return Returns <b>0</b> if the operation is successful.
 *         Returns others if the operation is failed.
 *
 * @since 12
 * @version 1.0
 */
uint32_t tee_free_sharemem(void *addr, uint32_t size);

/**
 * @brief Copy shared memory from source task.
 *
 * @param src_task Indicates the pid of the source task.
 * @param src Indicates the address of the source buffer.
 * @param src_size Indicates the size of the source buffer.
 * @param dst Indicates the address of the destination buffer.
 * @param dst_size Indicates the size of the destination buffer.
 *
 * @return Returns <b>0</b> if the operation is successful.
 *         Returns <b>-1</b> if the operation is failed.
 *
 * @since 12
 * @version 1.0
 */
int32_t copy_from_sharemem(uint32_t src_task, uint64_t src, uint32_t src_size, uintptr_t dst, uint32_t dst_size);

/**
 * @brief Copy shared memory to destination task.
 *
 * @param src Indicates the address of the source buffer.
 * @param src_size Indicates the size of the source buffer.
 * @param dst_task Indicates the pid of the destination task.
 * @param dst Indicates the address of the destination buffer.
 * @param dst_size Indicates the size of the destination buffer.
 *
 * @return Returns <b>0</b> if the operation is successful.
 *         Returns <b>-1</b> if the operation is failed.
 *
 * @since 12
 * @version 1.0
 */
int32_t copy_to_sharemem(uintptr_t src, uint32_t src_size, uint32_t dst_task, uint64_t dst, uint32_t dst_size);
#ifdef __cplusplus
}
#endif
/** @} */
#endif