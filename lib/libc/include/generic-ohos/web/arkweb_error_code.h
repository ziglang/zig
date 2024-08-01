/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

/**
 * @addtogroup Web
 * @{
 *
 * @brief Provides APIs for the ArkWeb errors.
 * @since 12
 */
/**
 * @file arkweb_error_code.h
 *
 * @brief Declares the APIs for the ArkWeb errors.
 * @library libohweb.so
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
#ifndef ARKWEB_ERROR_CODE_H
#define ARKWEB_ERROR_CODE_H

typedef enum ArkWeb_ErrorCode {
/** @error Unknown error. */
ARKWEB_ERROR_UNKNOWN = 17100100,

/** @error Invalid param. */
ARKWEB_INVALID_PARAM = 17100101,

/** @error Register custom schemes should be called before create any ArkWeb. */
ARKWEB_SCHEME_REGISTER_FAILED = 17100102,
} ArkWeb_ErrorCode;

#endif // ARKWEB_ERROR_CODE_H