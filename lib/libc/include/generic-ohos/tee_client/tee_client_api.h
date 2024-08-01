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

#ifndef TEE_CLIENT_API_H
#define TEE_CLIENT_API_H
/**
 * @addtogroup TeeClient
 * @{
 *
 * @brief Provides APIs for the client applications (CAs) in the Rich Execution Environment (normal mode) to
 * access the trusted applications (TAs) in a Trusted Execution Environment (TEE).
 *
 * @since 12
 * @version 1.0
 */

/**
 * @file tee_client_api.h
 *
 * @brief Defines APIs for CAs to access TAs.
 *
 * <p> Example:
 * <p>1. Initialize a TEE: Call <b>TEEC_InitializeContext</b> to initialize the TEE.
 * <p>2. Open a session: Call <b>TEEC_OpenSession</b> with the Universal Unique Identifier (UUID) of the TA.
 * <p>3. Send a command: Call <b>TEEC_InvokeCommand</b> to send a command to the TA.
 * <p>4. Close the session: Call <b>TEEC_CloseSession</b> to close the session.
 * <p>5. Close the TEE: Call <b>TEEC_FinalizeContext</b> to close the TEE.
 *
 * @library libteec.so
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <string.h>
#include "tee_client_type.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the values of the parameters transmitted between the REE and TEE.
 *
 * @since 12
 * @version 1.0
 */
#define TEEC_PARAM_TYPES(param0Type, param1Type, param2Type, param3Type) \
    ((param3Type) << 12 | (param2Type) << 8 | (param1Type) << 4 | (param0Type))

/**
 * @brief Defines the value of the parameter specified by <b>paramTypes</b> and <b>index</b>.
 *
 * @since 12
 * @version 1.0
 */
#define TEEC_PARAM_TYPE_GET(paramTypes, index) \
    (((paramTypes) >> (4*(index))) & 0x0F)

/**
 * @brief Initializes a TEE.
 *
 * The TEE must be initialized before a session is open or commands are sent.
 * After the initialization, a connection is set up between the CA and the TEE.
 *
 * @param name [IN] Indicates the pointer to the TEE path.
 * @param context [IN/OUT] Indicates the context pointer, which is the handle of the TEE.
 *
 * @return Returns {@code TEEC_SUCCESS} if the TEE is successfully initialized.
 *         Returns {@code TEEC_ERROR_BAD_PARAMETERS} if <b>name</b> is incorrect or <b>context</b> is null.
 *         Returns {@code TEEC_ERROR_GENERIC} if the available system resources are insufficient.
 *
 * @since 12
 * @version 1.0
 */
TEEC_Result TEEC_InitializeContext(const char *name, TEEC_Context *context);

/**
 * @brief Closes the TEE.
 *
 * After the TEE is closed, the CA is disconnected from the TEE.
 *
 * @param context [IN/OUT] Indicates the pointer to the TEE that is successfully initialized.
 *
 * @since 12
 * @version 1.0
 */
void TEEC_FinalizeContext(TEEC_Context *context);

/**
 * @brief Opens a session.
 *
 * This function is used to set up a connection between the CA and the TA of the specified UUID in the specified TEE
 * context. The data to be transferred is contained in <b>operation</b>.
 * If a session is opened successfully, <b>session</b> is returned providing a description of the connection.
 * If the session fails to open, <b>returnOrigin</b> is returned indicating the cause of the failure.
 *
 * @param context [IN/OUT] Indicates the pointer to the TEE that is successfully initialized.
 * @param session [OUT] Indicates the pointer to the session. The value cannot be null.
 * @param destination [IN] Indicates the pointer to the UUID of the target TA. Each TA has a unique UUID.
 * @param connectionMethod [IN] Indicates the connection method. For details, see {@link TEEC_LoginMethod}.
 * @param connectionData [IN] Indicates the pointer to the connection data, which varies with the connection mode.
 * If the connection mode is {@code TEEC_LOGIN_PUBLIC}, {@code TEEC_LOGIN_USER},
 * {@code TEEC_LOGIN_USER_APPLICATION}, or {@code TEEC_LOGIN_GROUP_APPLICATION}, the connection data must be null.
 * If the connection mode is {@code TEEC_LOGIN_GROUP} or {@code TEEC_LOGIN_GROUP_APPLICATION},
 * the connection data must point to data of the uint32_t type, which indicates the target group user to be connected
 * by the CA.
 * @param operation [IN/OUT] Indicates the pointer to the data to be transmitted between the CA and TA.
 * @param returnOrigin [IN/OUT] Indicates the pointer to the error source.
 * For details, see {@code TEEC_ReturnCodeOrigin}.
 *
 * @return Returns {@code TEEC_SUCCESS} if the session is open successfully.
 *         Returns {@code TEEC_ERROR_BAD_PARAMETERS} if <b>context</b>, <b>session</b>, or <b>destination</b> is null.
 *         Returns {@code TEEC_ERROR_ACCESS_DENIED} if the access request is denied.
 *         Returns {@code TEEC_ERROR_OUT_OF_MEMORY} if the available system resources are insufficient.
 *         Returns {@code TEEC_ERROR_TRUSTED_APP_LOAD_ERROR} if the TA failed to be loaded.
 *         For details about other return values, see {@code TEEC_ReturnCode}.
 *
 * @since 12
 * @version 1.0
 */
TEEC_Result TEEC_OpenSession(TEEC_Context *context, TEEC_Session *session, const TEEC_UUID *destination,
    uint32_t connectionMethod, const void *connectionData, TEEC_Operation *operation, uint32_t *returnOrigin);

/**
 * @brief Closes a session.
 *
 * After the session is closed, the CA is disconnected from the TA.
 *
 * @param session [IN/OUT] Indicates the pointer to the session to close.
 *
 * @since 12
 * @version 1.0
 */
void TEEC_CloseSession(TEEC_Session *session);

/**
 * @brief Sends a command to a TA.
 *
 * The CA sends the command ID to the TA through the specified session.
 *
 * @param session [IN/OUT] Indicates the pointer to the session opened.
 * @param commandID [IN] Indicates the command ID supported by the TA. It is defined by the TA.
 * @param operation [IN/OUT] Indicates the pointer to the data to be sent from the CA to the TA.
 * @param returnOrigin [IN/OUT] Indicates the pointer to the error source.
 * For details, see {@code TEEC_ReturnCodeOrigin}.
 *
 * @return Returns {@code TEEC_SUCCESS} if the command is sent successfully.
 *         Returns {@code TEEC_ERROR_BAD_PARAMETERS} if <b>session</b> is null or
 * <b>operation</b> is in incorrect format.
 *         Returns {@code TEEC_ERROR_ACCESS_DENIED} if the access request is denied.
 *         Returns {@code TEEC_ERROR_OUT_OF_MEMORY} if the available system resources are insufficient.
 *         For details about other return values, see {@code TEEC_ReturnCode}.
 *
 * @since 12
 * @version 1.0
 */
TEEC_Result TEEC_InvokeCommand(TEEC_Session *session, uint32_t commandID,
    TEEC_Operation *operation, uint32_t *returnOrigin);

/**
 * @brief Registers shared memory in the specified TEE context.
 *
 * The registered shared memory can implement zero-copy.
 * The zero-copy function, however, also requires support by the operating system.
 * At present, zero-copy cannot be implemented in this manner.
 *
 * @param context [IN/OUT] Indicates the pointer to the TEE that is successfully initialized.
 * @param sharedMem [IN/OUT] Indicates the pointer to the shared memory.
 * The pointed shared memory cannot be null and the size cannot be 0.
 *
 * @return Returns {@code TEEC_SUCCESS} if the operation is successful.
 *         Returns {@code TEEC_ERROR_BAD_PARAMETERS} if <b>context</b> or <b>sharedMem</b> is null or
 * the pointed memory is empty.
 *
 * @since 12
 * @version 1.0
 */
TEEC_Result TEEC_RegisterSharedMemory(TEEC_Context *context, TEEC_SharedMemory *sharedMem);

/**
 * @brief Requests shared memory in the specified TEE context.
 *
 * The shared memory can be used to implement zero-copy during data transmission between the REE and TEE.
 * The zero-copy function, however, also requires support by the operating system.
 * At present, zero-copy cannot be implemented in this manner.
 *
 * @attention If the <b>size</b> field of the input parameter <b>sharedMem</b> is set to <b>0</b>, <b>TEEC_SUCCESS</b>
 * will be returned but the shared memory cannot be used because this memory has neither an address nor size.
 * @param context [IN/OUT] Indicates the pointer to the TEE that is successfully initialized.
 * @param sharedMem [IN/OUT] Indicates the pointer to the shared memory. The size of the shared memory cannot be 0.
 *
 * @return Returns {@code TEEC_SUCCESS} if the operation is successful.
 *         Returns {@code TEEC_ERROR_BAD_PARAMETERS} if <b>context</b> or <b>sharedMem</b> is null.
 *         Returns {@code TEEC_ERROR_OUT_OF_MEMORY} if the available system resources are insufficient.
 *
 * @since 12
 * @version 1.0
 */
TEEC_Result TEEC_AllocateSharedMemory(TEEC_Context *context, TEEC_SharedMemory *sharedMem);

/**
 * @brief Releases the shared memory registered or acquired.
 *
 * @attention If the shared memory is acquired by using {@code TEEC_AllocateSharedMemory},
 * the memory released will be reclaimed. If the shared memory is acquired by using {@code TEEC_RegisterSharedMemory},
 * the local memory released will not be reclaimed.
 * @param sharedMem [IN/OUT] Indicates the pointer to the shared memory to release.
 *
 * @since 12
 * @version 1.0
 */
void TEEC_ReleaseSharedMemory(TEEC_SharedMemory *sharedMem);

/**
 * @brief Cancels an operation.
 *
 * @attention This operation is only used to send a cancel message. Whether to perform the cancel operation is
 * determined by the TEE or TA.
 * At present, the cancel operation does not take effect.
 * @param operation [IN/OUT] Indicates the pointer to the data to be sent from the CA to the TA.
 *
 * @since 12
 * @version 1.0
 */
void TEEC_RequestCancellation(TEEC_Operation *operation);

#ifdef __cplusplus
}
#endif
/** @} */
#endif