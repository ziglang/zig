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

/**
 * @addtogroup ArkUI_NativeModule
 * @{
 *
 * @brief Provides UI capabilities of ArkUI on the native side, such as UI component creation and destruction,
 * tree node operations, attribute setting, and event listening.
 *
 * @since 12
 */

/**
 * @file native_node_napi.h
 *
 * @brief Declares APIs for converting <b>FrameNode</b> objects on the ArkTS side to <b>ArkUI_NodeHandle</b> objects on
 * the native side.
 *
 * @library libace_ndk.z.so
 * @syscap SystemCapability.ArkUI.ArkUI.Full
 * @since 12
 */

#ifndef ARKUI_NATIVE_NODE_NAPI_H
#define ARKUI_NATIVE_NODE_NAPI_H

#include "drawable_descriptor.h"
#include "napi/native_api.h"
#include "native_type.h"

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Obtains a <b>FrameNode</b> object on the ArkTS side and maps it to an <b>ArkUI_NodeHandle</b> object on the
 * native side.
 *
 * @param env Indicates the NAPI environment pointer.
 * @param frameNode Indicates the <b>FrameNode</b> object created on the ArkTS side.
 * @param handle Indicates the pointer to the <b>ArkUI_NodeHandle</b> object.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_GetNodeHandleFromNapiValue(napi_env env, napi_value frameNode, ArkUI_NodeHandle* handle);

/**
 * @brief Obtains a <b>UIContext</b> object on the ArkTS side and maps it to an <b>ArkUI_ContextHandle</b> object on the
 * native side.
 *
 * @param env ndicates the NAPI environment pointer.
 * @param value Indicates the <b>UIContext</b> object created on the ArkTS side.
 * @param context Indicates the pointer to the <b>ArkUI_ContextHandle</b> object.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_GetContextFromNapiValue(napi_env env, napi_value value, ArkUI_ContextHandle* context);


/**
  * @brief Obtains a <b>NodeContent</b> object on the ArkTS side and maps it to an <b>ArkUI_NodeContentHandle</b>
  * object on the native side.
  *
  * @param env ndicates the NAPI environment pointer.
  * @param value Indicates the <b>NodeContent</b> object created on the ArkTS side.
  * @param content Indicates the pointer to the <b>ArkUI_NodeContentHandle</b> object.
  * @return Returns the error code.
  *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
  *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
  * @since 12
  */
int32_t OH_ArkUI_GetNodeContentFromNapiValue(napi_env env, napi_value value, ArkUI_NodeContentHandle* content);

/**
 * @brief Obtains a <b>DrawableDescriptor</b> object on the ArkTS side and maps it to an
 * <b>ArkUI_DrawableDescriptro</b> object on the native side.
 *
 * @param env Indicates the NAPI environment pointer.
 * @param value Indicates the <b>DrawableDescriptor</b> object created on the ArkTS side.
 * @param drawableDescriptor Indicates the pointer to the <b>ArkUI_DrawableDescriptro</b> object.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
*/
int32_t OH_ArkUI_GetDrawableDescriptorFromNapiValue(
    napi_env env, napi_value value, ArkUI_DrawableDescriptor** drawableDescriptor);

/**
 * @brief Obtains a <b>Resource</b> object on the ArkTS side and maps it to an
 * <b>ArkUI_DrawableDescriptro</b> object on the native side.
 *
 * @param env Indicates the NAPI environment pointer.
 * @param value Indicates the <b>Resource</b> object created on the ArkTS side.
 * @param drawableDescriptor Indicates the pointer to the <b>ArkUI_DrawableDescriptro</b> object.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
*/
int32_t OH_ArkUI_GetDrawableDescriptorFromResourceNapiValue(
    napi_env env, napi_value value, ArkUI_DrawableDescriptor** drawableDescriptor);
#ifdef __cplusplus
};
#endif

#endif // ARKUI_NATIVE_NODE_NAPI_H
/** @} */