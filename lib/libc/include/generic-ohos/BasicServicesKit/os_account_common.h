/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
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

#ifndef OS_ACCOUNT_COMMON_H
#define OS_ACCOUNT_COMMON_H

/**
 * @addtogroup OsAccount
 * @{
 *
 * @brief Provide the definition of the C interface for the native OsAccount.
 * @since 12
 */
/**
 * @file os_account_common.h
 *
 * @brief Declare the common types for the native OsAccount.
 * @library libos_account.so
 * @syscap SystemCapability.Account.OsAccount
 * @since 12
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates the error codes.
 *
 * @since 12
 */
typedef enum OsAccount_ErrCode {
    /** @error Operation is successful.*/
    OS_ACCOUNT_ERR_OK = 0,

    /** @error Internal error.*/
    OS_ACCOUNT_ERR_INTERNAL_ERROR = 12300001,

    /** @error Invalid parameter.*/
    OS_ACCOUNT_ERR_INVALID_PARAMETER = 12300002
} OsAccount_ErrCode;

#ifdef __cplusplus
}
#endif

/** @} */

#endif // OS_ACCOUNT_COMMON_H