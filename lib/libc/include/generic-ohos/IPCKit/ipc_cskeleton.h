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

#ifndef CAPI_INCLUDE_IPC_CSKELETON_H
#define CAPI_INCLUDE_IPC_CSKELETON_H

/**
 * @addtogroup OHIPCSkeleton
 * @{
 *
 * @brief Provides C interfaces for managing the token IDs, credentials, process IDs (PIDs),
 * user IDs (UIDs), and thread pool in the IPC framework.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @since 12
 */

/**
 * @file ipc_cskeleton.h
 *
 * @brief Defines C interfaces for managing the token IDs, credentials, PIDs, UIDs, and thread
 * pool in the IPC framework.
 *
 * @library libipc_capi.so
 * @kit IPCKit
 * @syscap SystemCapability.Communication.IPC.Core
 * @since 12
 */

#include <stdint.h>

#include "ipc_cparcel.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Joints this thread to the IPC worker thread pool.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @since 12
 */
void OH_IPCSkeleton_JoinWorkThread(void);

/**
 * @brief Stops this thread.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @since 12
 */
void OH_IPCSkeleton_StopWorkThread(void);

/**
 * @brief Obtains the token ID of the caller. This function must be called in the IPC context.
 * Otherwise, the local token ID is returned.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @return Returns the token ID of the caller.
 * @since 12
 */
uint64_t OH_IPCSkeleton_GetCallingTokenId(void);

/**
 * @brief Obtains the token ID of the first caller.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @return Returns the token ID obtained.
 * @since 12
 */
uint64_t OH_IPCSkeleton_GetFirstTokenId(void);

/**
 * @brief Obtains the local token ID.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @return Returns the token ID obtained.
 * @since 12
 */
uint64_t OH_IPCSkeleton_GetSelfTokenId(void);

/**
 * @brief Obtains the process ID of the caller. This function must be called in the IPC context.
 * Otherwise, the current process ID is returned.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @return Returns the process ID of the caller.
 * @since 12
 */
uint64_t OH_IPCSkeleton_GetCallingPid(void);

/**
 * @brief Obtains the UID of the caller. This function must be called in the IPC context.
 * Otherwise, the current UID is returned.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @return Returns the UID of the caller.
 * @since 12
 */
uint64_t OH_IPCSkeleton_GetCallingUid(void);

/**
 * @brief Checks whether a local calling is being made.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @return Returns <b>1</b> if a local calling is in progress; returns <b>0</b> otherwise.
 * @since 12
 */
int OH_IPCSkeleton_IsLocalCalling(void);

/**
 * @brief Sets the maximum number of worker threads.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param maxThreadNum Maximum number of worker threads to set. The default value is <b>16</b>.
 * The value range is [1, 32].
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if incorrect parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_INNER_ERROR} in other cases.
 * @since 12
 */
int OH_IPCSkeleton_SetMaxWorkThreadNum(const int maxThreadNum);

/**
 * @brief Resets the caller identity credential (including the token ID, UID, and PID) to that of this process and
 * returns the caller credential information.
 * The identity information is used in <b>OH_IPCSkeleton_SetCallingIdentity</b>.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param identity Pointer to the address of the memory for holding the caller identity information.
 * The memory is allocated by the allocator provided by the user and needs to be released. This pointer cannot be NULL.
 * @param len Pointer to the length of the identity information. It cannot be NULL.
 * @param allocator Memory allocator specified by the user for allocating memory for <b>identity</b>. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if incorrect parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_MEM_ALLOCATOR_ERROR} if memory allocation fails. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_INNER_ERROR} in other cases.
 * @since 12
 */
int OH_IPCSkeleton_ResetCallingIdentity(char **identity, int32_t *len, OH_IPC_MemAllocator allocator);

/**
 * @brief Sets the caller credential information to the IPC context.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param identity Pointer to the caller identity, which cannot be NULL.
 * The value is returned by <b>OH_IPCSkeleton_ResetCallingIdentity</b>.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if incorrect parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_INNER_ERROR} in other cases.
 * @since 12
 */
int OH_IPCSkeleton_SetCallingIdentity(const char *identity);

/**
 * @brief Checks whether an IPC request is being handled.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @return Returns <b>1</b> if an IPC request is being handled; returns <b>0</b> otherwise.
 * @since 12
 */
int OH_IPCSkeleton_IsHandlingTransaction(void);

#ifdef __cplusplus
}
#endif

/** @} */
#endif