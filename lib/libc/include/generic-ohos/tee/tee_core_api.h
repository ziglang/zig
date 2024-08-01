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

#ifndef __TEE_CORE_API_H
#define __TEE_CORE_API_H

/**
 * @addtogroup TeeTrusted
 * @{
 *
 * @brief TEE(Trusted Excution Environment) API.
 * Provides security capability APIs such as trusted storage, encryption and decryption,
 * and trusted time for trusted application development.
 *
 * @since 12
 * @version 1.0
 */

 /**
 * @file tee_core_api.h
 *
 * @brief Provides APIs for managing trusted application (TA) sessions.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include "tee_defines.h"

#ifdef __cplusplus
extern "C" {
#endif
#ifndef _TEE_TA_SESSION_HANDLE
#define _TEE_TA_SESSION_HANDLE
/**
 * @brief Defines the handle of TA session.
 *
 * @since 12
 */
typedef uint32_t TEE_TASessionHandle;
#endif

/**
 * @brief Raises a panic in the TA instance.
 *
 * @param panicCode Indicates an informative panic code defined by the TA.
 *
 * @since 12
 * @version 1.0
 */
void TEE_Panic(TEE_Result panicCode);

/**
 * @brief Opens a new session with a TA.
 *
 * @param destination Indicates the pointer to the <b>TEE_UUID</b> structure that contains
 * the Universal Unique Identifier (UUID) of the target TA.
 * @param cancellationRequestTimeout Indicates the timeout period in milliseconds or a special value
 * if there is no timeout.
 * @param paramTypes Indicates the types of all parameters passed in the operation.
 * @param params Indicates the parameters passed in the operation.
 * @param session Indicates the pointer to the variable that will receive the client session handle.
 * @param returnOrigin Indicates the pointer to the variable that holds the return origin.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the session is opened.
 *         Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the TA cannot be found in the Trusted Execution Environment (TEE).
 *         Returns <b>TEE_ERROR_ACCESS_DENIED</b> if the access request to the TA is denied.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_OpenTASession(const TEE_UUID *destination, uint32_t cancellationRequestTimeout, uint32_t paramTypes,
                             TEE_Param params[TEE_PARAMS_NUM], TEE_TASessionHandle *session, uint32_t *returnOrigin);

/**
 * @brief Closes a client session.
 *
 * @param session Indicates the handle of the session to close.
 *
 * @since 12
 * @version 1.0
 */
void TEE_CloseTASession(TEE_TASessionHandle session);

/**
 * @brief Invokes a command in a session opened between this client TA instance and a target TA instance.
 *
 * @param session Indicates the handle of the opened session.
 * @param cancellationRequestTimeout Indicates the timeout period in milliseconds or a special value
 * if there is no timeout.
 * @param commandID Indicates the identifier of the command to invoke.
 * @param paramTypes Indicates the types of all parameters passed in the operation.
 * @param params Indicates the parameters passed in the operation.
 * @param returnOrigin Indicates the pointer to the variable that holds the return origin.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_ACCESS_DENIED</b> if the command fails to be invoked.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_InvokeTACommand(TEE_TASessionHandle session, uint32_t cancellationRequestTimeout, uint32_t commandID,
                               uint32_t paramTypes, TEE_Param params[TEE_PARAMS_NUM], uint32_t *returnOrigin);

#ifdef __cplusplus
}
#endif
/** @} */
#endif