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
 * @addtogroup Web
 * @{
 *
 * @brief Provide the definition of the C interface for the native ArkWeb.
 * @since 12
 */
/**
 * @file arkweb_type.h
 *
 * @brief Defines the common types for the native ArkWeb.
 * @library libohweb.so
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */

#ifndef ARKWEB_TYPE_H
#define ARKWEB_TYPE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the javascript bridge data type.
 *
 * @since 12
 */
typedef struct {
    /** A buffer that contains data. */
    const uint8_t* buffer;
    /** The size of the buffer. */
    size_t size;
} ArkWeb_JavaScriptBridgeData;

/**
 * @brief Defines the javascript callback of the native ArkWeb.
 *
 * @since 12
 */
typedef void (*ArkWeb_OnJavaScriptCallback)(
    const char* webTag, const ArkWeb_JavaScriptBridgeData* data, void* userData);

/**
 * @brief Defines the javascript proxy callback of the native ArkWeb.
 *
 * @since 12
 */
typedef void (*ArkWeb_OnJavaScriptProxyCallback)(
    const char* webTag, const ArkWeb_JavaScriptBridgeData* dataArray, size_t arraySize, void* userData);

/**
 * @brief Defines the component callback of the native ArkWeb.
 *
 * @since 12
 */
typedef void (*ArkWeb_OnComponentCallback)(const char* webTag, void* userData);

/**
 * @brief Defines the javascript object.
 *
 * @since 12
 */
typedef struct {
    /** A piece of javascript code. */
    const uint8_t* buffer;
    /** The size of the javascript code. */
    size_t size;
    /** Callbacks execute JavaScript script results. */
    ArkWeb_OnJavaScriptCallback callback;
    /** The user data to set. */
    void* userData;
} ArkWeb_JavaScriptObject;

/**
 * @brief Defines the javascript proxy registered method object.
 *
 * @since 12
 */
typedef struct {
    /** The method of the application side JavaScript object participating in the registration. */
    const char* methodName;
    /** The callback function registered by developer is called back when HTML side uses. */
    ArkWeb_OnJavaScriptProxyCallback callback;
    /** The user data to set. */
    void* userData;
} ArkWeb_ProxyMethod;

/**
 * @brief Defines the javascript proxy registered object.
 *
 * @since 12
 */
typedef struct {
    /** The name of the registered object. */
    const char* objName;
    /** The javascript proxy registered method object list */
    const ArkWeb_ProxyMethod* methodList;
    /** The size of the methodList. */
    size_t size;
} ArkWeb_ProxyObject;

/**
 * @brief Defines the controller API for native ArkWeb.
 *
 * @since 12
 */
typedef struct {
    /** The ArkWeb_ControllerAPI struct size. */
    size_t size;
    /** Load a piece of code and execute JS code in the context of the currently displayed page. */
    void (*runJavaScript)(const char* webTag, const ArkWeb_JavaScriptObject* javascriptObject);
    /** Register the JavaScript object and method list. */
    void (*registerJavaScriptProxy)(const char* webTag, const ArkWeb_ProxyObject* proxyObject);
    /** Deletes the registered object which th given name. */
    void (*deleteJavaScriptRegister)(const char* webTag, const char* objName);
    /** Refresh the current web page. */
    void (*refresh)(const char* webTag);
    /** Register the JavaScript object and async method list. */
    void (*registerAsyncJavaScriptProxy)(const char* webTag, const ArkWeb_ProxyObject* proxyObject);
} ArkWeb_ControllerAPI;

/**
 * @brief Defines the component API for native ArkWeb.
 *
 * @since 12
 */
typedef struct {
    /** The ArkWeb_ComponentAPI struct size. */
    size_t size;
    /** Register the OnControllerAttached callback. */
    void (*onControllerAttached)(const char* webTag, ArkWeb_OnComponentCallback callback, void* userData);
    /** Register the OnPageBegin callback. */
    void (*onPageBegin)(const char* webTag, ArkWeb_OnComponentCallback callback, void* userData);
    /** Register the OnPageEnd callback. */
    void (*onPageEnd)(const char* webTag, ArkWeb_OnComponentCallback callback, void* userData);
    /** Register the OnDestroy callback. */
    void (*onDestroy)(const char* webTag, ArkWeb_OnComponentCallback callback, void* userData);
} ArkWeb_ComponentAPI;

/**
 * @brief Check whether the member variables of the current struct exist.
 *
 * @since 12
 */
#define ARKWEB_MEMBER_EXISTS(s, f) \
    ((intptr_t) & ((s)->f) - (intptr_t)(s) + sizeof((s)->f) <= *reinterpret_cast<size_t*>(s))

/**
 * @brief Return false if the struct member does not exist, otherwise true.
 *
 * @since 12
 */
#define ARKWEB_MEMBER_MISSING(s, f) (!ARKWEB_MEMBER_EXISTS(s, f) || !((s)->f))

#ifdef __cplusplus
};
#endif
#endif // ARKWEB_TYPE_H