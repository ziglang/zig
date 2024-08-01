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

#ifndef OS_ACCOUNT_H
#define OS_ACCOUNT_H

/**
 * @addtogroup OsAccount
 * @{
 *
 * @brief Provide the definition of the C interface for the native OsAccount.
 * @since 12
 */
/**
 * @file os_account.h
 *
 * @brief Declares the APIs for accessing and managing the OS account information.
 * @library libos_account_ndk.so
 * @kit BasicServicesKit
 * @syscap SystemCapability.Account.OsAccount
 * @since 12
 */

#include <stddef.h>
#include "os_account_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Gets the name of the OS account to which the caller process belongs.
 *
 * @param buffer The name character array which should have space for the name and the terminating character ('\0').
 * @param buffer_size The size of the name character array.
 * @return {@link OS_ACCOUNT_ERR_OK} Indicates successful;<br>
 *         {@link OS_ACCOUNT_ERR_INTERNAL_ERROR} Indicates the internal error.<br>
 *         {@link OS_ACCOUNT_ERR_INVALID_PARAMETER} Indicates the <i>buffer</i> is NULL pointer or the size of the name,
 *         including the terminating character ('\0'), is larger than <i>buffer_size</i>;
 * @syscap SystemCapability.Account.OsAccount
 * @since 12
 */
OsAccount_ErrCode OH_OsAccount_GetName(char *buffer, size_t buffer_size);

#ifdef __cplusplus
}
#endif

/** @} */

#endif // OS_ACCOUNT_H