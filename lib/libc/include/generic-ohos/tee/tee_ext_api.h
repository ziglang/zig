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

#ifndef TEE_EXT_API_H
#define TEE_EXT_API_H

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
 * @file tee_ext_api.h
 *
 * @brief Provides extended interfaces.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include "tee_defines.h"
#include "tee_hw_ext_api.h"

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif /* __cpluscplus */
#endif /* __cpluscplus */

/**
 * @brief Defines the value of invalid user ID.
 *
 * @since 12
 */
#define INVALID_USERID 0xFFFFFFFU

/**
 * @brief Defines the SMC from user mode.
 *
 * @since 12
 */
#define TEE_SMC_FROM_USR 0

/**
 * @brief Defines the SMC from kernel mode.
 *
 * @since 12
 */
#define TEE_SMC_FROM_KERNEL 1

/**
 * @brief Defines the szie of reserved buffer.
 *
 * @since 12
 */
#define RESERVED_BUF_SIZE 32

/**
 * @brief Defines the caller information.
 *
 * @since 12
 */
typedef struct ta_caller_info {
    uint32_t session_type;
    union {
        struct {
            TEE_UUID caller_uuid;
            uint32_t group_id;
        };
        uint8_t ca_info[RESERVED_BUF_SIZE];
    } caller_identity;
    uint8_t smc_from_kernel_mode;
    uint8_t reserved[RESERVED_BUF_SIZE - 1];
} caller_info;

/**
 * @brief Get caller info of current session, refer caller_info struct for more details.
 *
 * @param ca_name Indicates the process name of the caller of the CA.
 * @param ca_uid Indicates the UID of the caller.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other information otherwise.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_get_caller_info(caller_info *caller_info_data, uint32_t length);

/**
 * @brief Get user ID of current TA.
 *
 * @param user_id Indicates the user ID to be returned.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other information otherwise.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_get_caller_userid(uint32_t *user_id);

/**
 * @brief Adds information about a caller that can invoke this TA.
 * This API applies to the client applications (CAs) in the binary executable file format.
 *
 * @param ca_name Indicates the process name of the caller of the CA.
 * @param ca_uid Indicates the UID of the caller.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other information otherwise.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result AddCaller_CA_exec(const char *ca_name, uint32_t ca_uid);

/**
 * @brief Adds information about a caller that can invoke this TA.
 * This API applies to the client applications (CAs) in the native CA and HAP format.
 *
 * @param cainfo_hash Indicates the hash value of the CA caller information.
 * @param length Indicates the length of the hash value.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other information otherwise.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result AddCaller_CA(const uint8_t *cainfo_hash, uint32_t length);

/**
 * @brief TA call this API allow others TA open session with itself.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns other information otherwise.
  *
 * @since 12
 * @version 1.0
 */
TEE_Result AddCaller_TA_all(void);

/**
 * @brief Defines the session caller from CA.
 *
 * @since 12
 */
#define SESSION_FROM_CA   0

/**
 * @brief Defines the session caller from TA.
 *
 * @since 12
 */
#define SESSION_FROM_TA   1

/**
 * @brief Defines the TA task is not found, for example, from TA sub thread.
 *
 * @since 12
 */
#define SESSION_FROM_NOT_SUPPORTED   0xFE

/**
 * @brief Defines the TA caller is not found.
 *
 * @since 12
 */
#define SESSION_FROM_UNKNOWN   0xFF

/**
 * @brief Obtains the session type.
 *
 * @return Returns the session type obtained.
  *
 * @since 12
 * @version 1.0
 */
uint32_t tee_get_session_type(void);

#ifdef __cplusplus
#if __cplusplus
}
#endif /* __cpluscplus */
#endif /* __cpluscplus */

#endif