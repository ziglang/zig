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
 * @file native_interface.h
 *
 * @brief Provides a unified entry for the native module APIs.
 *
 * @library libace_ndk.z.so
 * @syscap SystemCapability.ArkUI.ArkUI.Full
 * @since 12
 */

#ifndef ARKUI_NATIVE_INTERFACE_H
#define ARKUI_NATIVE_INTERFACE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the native API types.
 *
 * @since 12
 */
typedef enum {
    /** API related to UI components. For details, see the struct definition in <arkui/native_node.h>. */
    ARKUI_NATIVE_NODE,
    /** API related to dialog boxes. For details, see the struct definition in <arkui/native_dialog.h>. */
    ARKUI_NATIVE_DIALOG,
    /** API related to gestures. For details, see the struct definition in <arkui/native_gesture.h>. */
    ARKUI_NATIVE_GESTURE,
    /** API related to animations. For details, see the struct definition in <arkui/native_animate.h>.*/
    ARKUI_NATIVE_ANIMATE,
} ArkUI_NativeAPIVariantKind;

/**
 * @brief Obtains the native API set of a specified type.
 *
 * @param type Indicates the type of the native API set provided by ArkUI, for example, <b>ARKUI_NATIVE_NODE</b>
 * and <b>ARKUI_NATIVE_GESTURE</b>.
 * @param sturctName Indicates the name of a native struct defined in the corresponding header file, for example,
 * <b>ArkUI_NativeNodeAPI_1</b> in <arkui/native_node.h>.
 * @return Returns the pointer to the abstract native API, which can be used after being converted into a specific type.
 * @code {.cpp}
 * #include<arkui/native_interface.h>
 * #include<arkui/native_node.h>
 * #include<arkui/native_gesture.h>
 *
 * auto* anyNativeAPI = OH_ArkUI_QueryModuleInterfaceByName(ARKUI_NATIVE_NODE, "ArkUI_NativeNodeAPI_1");
 * if (anyNativeAPI) {
 *     auto nativeNodeApi = reinterpret_cast<ArkUI_NativeNodeAPI_1*>(anyNativeAPI);
 * }
 * auto anyGestureAPI = OH_ArkUI_QueryModuleInterface(ARKUI_NATIVE_GESTURE, "ArkUI_NativeGestureAPI_1");
 * if (anyNativeAPI) {
 *     auto basicGestureApi = reinterpret_cast<ArkUI_NativeGestureAPI_1*>(anyGestureAPI);
 * }
 * @endcode
 *
 * @since 12
 */
void* OH_ArkUI_QueryModuleInterfaceByName(ArkUI_NativeAPIVariantKind type, const char* structName);

/**
 * @brief Obtains the macro function corresponding to a struct pointer based on the struct type.
 *
 * @code {.cpp}
 * #include<arkui/native_interface.h>
 * #include<arkui/native_node.h>
 *
 * ArkUI_NativeNodeAPI_1* nativeNodeApi = nullptr;
 * OH_ArkUI_GetModuleInterface(ARKUI_NATIVE_NODE, ArkUI_NativeNodeAPI_1, nativeNodeApi);
 * @endcode
 *
 * @since 12
 */
#define OH_ArkUI_GetModuleInterface(nativeAPIVariantKind, structType, structPtr)                     \
    do {                                                                                             \
        void* anyNativeAPI = OH_ArkUI_QueryModuleInterfaceByName(nativeAPIVariantKind, #structType); \
        if (anyNativeAPI) {                                                                          \
            structPtr = (structType*)(anyNativeAPI);                                                 \
        }                                                                                            \
    } while (0)

#ifdef __cplusplus
};
#endif

#endif // ARKUI_NATIVE_INTERFACE_H
/** @} */