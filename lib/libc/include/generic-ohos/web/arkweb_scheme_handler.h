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
 * @brief Provides APIs to intercept the request from ArkWeb.
 * @since 12
 */
/**
 * @file arkweb_scheme_handler.h
 *
 * @brief Declares the APIs to intercept the request from ArkWeb.
 * @library libohweb.so
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
#ifndef ARKWEB_SCHEME_HANDLER_H
#define ARKWEB_SCHEME_HANDLER_H

#include "stdint.h"

#include "arkweb_error_code.h"
#include "arkweb_net_error_list.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Configuration information for custom schemes.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef enum ArkWeb_CustomSchemeOption {
    OH_ARKWEB_SCHEME_OPTION_NONE = 0,

    /** If ARKWEB_SCHEME_OPTION_STANDARD is set, the scheme will be handled as a standard scheme. The standard
     *  schemes need to comply with the URL normalization and parsing rules defined in Section 3.1 of RFC 1738,
     *  which can be found in the http://www.ietf.org/rfc/rfc1738.txt.
     */
    ARKWEB_SCHEME_OPTION_STANDARD = 1 << 0,

    /** If ARKWEB_SCHEME_OPTION_LOCAL is set, the same security rules as those applied to the "file" URL will be
     *  used to handle the scheme.
     */
    ARKWEB_SCHEME_OPTION_LOCAL = 1 << 1,

    /** If ARKWEB_SCHEME_OPTION_DISPLAY_ISOLATED is set, then the scheme can only be displayed from other content
     *  hosted using the same scheme.
     */
    ARKWEB_SCHEME_OPTION_DISPLAY_ISOLATED = 1 << 2,

    /** If ARKWEB_SCHEME_OPTION_SECURE is set, the same security rules as those applied to the "https" URL will be
     *  used to handle the scheme.
     */
    ARKWEB_SCHEME_OPTION_SECURE = 1 << 3,

    /** If ARKWEB_SCHEME_OPTION_CORS_ENABLED is set, then the scheme can be sent CORS requests. In most cases this
     *  value should be set when ARKWEB_SCHEME_OPTION_STANDARD is set.
     */
    ARKWEB_SCHEME_OPTION_CORS_ENABLED = 1 << 4,

    /** If ARKWEB_SCHEME_OPTION_CSP_BYPASSING is set, then this scheme can bypass Content Security Policy (CSP)
     *  checks. In most cases, this value should not be set when ARKWEB_SCHEME_OPTION_STANDARD is set.
     */
    ARKWEB_SCHEME_OPTION_CSP_BYPASSING = 1 << 5,

    /** If ARKWEB_SCHEME_OPTION_FETCH_ENABLED is set, then this scheme can perform FETCH API requests. */
    ARKWEB_SCHEME_OPTION_FETCH_ENABLED = 1 << 6,

    /** If ARKWEB_SCHEME_OPTION_CODE_CACHE_ENABLED is set, then the js of this scheme can generate code cache. */
    ARKWEB_SCHEME_OPTION_CODE_CACHE_ENABLED = 1 << 7,
} ArkWeb_CustomSchemeOption;

/**
 * @brief Resource type for a request.
 *
 * These constants match their equivalents in Chromium's ResourceType and should not be renumbered.\n
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef enum ArkWeb_ResourceType {
    /** Top level page. */
    MAIN_FRAME = 0,

    /** Frame or Iframe. */
    SUB_FRAME = 1,

    /** CSS stylesheet. */
    STYLE_SHEET = 2,

    /** External script. */
    SCRIPT = 3,

    /** Image(jpg/gif/png/etc). */
    IMAGE = 4,

    /** Font. */
    FONT_RESOURCE = 5,

    /** Some other subresource. This is the default type if the actual type is unknown. */
    SUB_RESOURCE = 6,

    /** Object (or embed) tag for a plugin, or a resource that a plugin requested. */
    OBJECT = 7,

    /** Media resource. */
    MEDIA = 8,

    /** Main resource of a dedicated worker. */
    WORKER = 9,

    /** Main resource of a shared worker. */
    SHARED_WORKER = 10,

    /** Explicitly requested prefetch. */
    PREFETCH = 11,

    /** Favicon. */
    FAVICON = 12,

    /** XMLHttpRequest. */
    XHR = 13,

    /** Ping request for <a ping>/sendBeacon. */
    PING = 14,

    /** The main resource of a service worker. */
    SERVICE_WORKER = 15,

    /** Report of Content Security Policy violations. */
    CSP_REPORT = 16,

    /** Resource that a plugin requested. */
    PLUGIN_RESOURCE = 17,

    /** A main-frame service worker navigation preload request. */
    NAVIGATION_PRELOAD_MAIN_FRAME = 19,

    /** A sub-frame service worker navigation preload request. */
    NAVIGATION_PRELOAD_SUB_FRAME = 20,
} ArkWeb_ResourceType;

/**
 * @brief This class is used to intercept requests for a specified scheme.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef struct ArkWeb_SchemeHandler_ ArkWeb_SchemeHandler;

/**
 * @brief Used to intercept url requests.
 *
 * Response headers and body can be sent through ArkWeb_ResourceHandler.\n
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef struct ArkWeb_ResourceHandler_ ArkWeb_ResourceHandler;

/**
 * @brief The response of the intercepted request.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef struct ArkWeb_Response_ ArkWeb_Response;

/**
 * @brief The info of the request.
 *
 * You can obtain the requested URL, method, post data, and other information through OH_ArkWeb_ResourceRequest.\n
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef struct ArkWeb_ResourceRequest_ ArkWeb_ResourceRequest;

/**
 * @brief The request headers of the request.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef struct ArkWeb_RequestHeaderList_ ArkWeb_RequestHeaderList;

/**
 * @brief The http body of the request.
 *
 * Use OH_ArkWebHttpBodyStream_* interface to read the body.\n
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef struct ArkWeb_HttpBodyStream_ ArkWeb_HttpBodyStream;


/**
 * @brief Callback for handling the request.
 *
 * This will be called on the IO thread.\n
 *
 * @param schemeHandler The ArkWeb_SchemeHandler.
 * @param resourceRequest Obtain request's information through this.
 * @param resourceHandler The ArkWeb_ResourceHandler for the request. It should not be used if intercept is set to
 *                        false.
 * @param intercept If true will intercept the request, if false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef void (*ArkWeb_OnRequestStart)(const ArkWeb_SchemeHandler* schemeHandler,
                                      ArkWeb_ResourceRequest* resourceRequest,
                                      const ArkWeb_ResourceHandler* resourceHandler,
                                      bool* intercept);

/**
 * @brief Callback when the request is completed.
 *
 * This will be called on the IO thread.\n
 * Should destory the resourceRequest by ArkWeb_ResourceRequest_Destroy and use ArkWeb_ResourceHandler_Destroy\n
 * destroy the ArkWeb_ResourceHandler received in ArkWeb_OnRequestStart.\n
 *
 * @param schemeHandler The ArkWeb_SchemeHandler.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef void (*ArkWeb_OnRequestStop)(const ArkWeb_SchemeHandler* schemeHandler,
                                     const ArkWeb_ResourceRequest* resourceRequest);

/**
 * @brief Callback when the read operation done.
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @param buffer The buffer to receive data.
 * @param bytesRead Callback after OH_ArkWebHttpBodyStream_Read. bytesRead greater than 0 means that the buffer is
 *                  filled with data of bytesRead size. Caller can read from the buffer, and if
 *                  OH_ArkWebHttpBodyStream_IsEOF is false, caller can continue to read the remaining data.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef void (*ArkWeb_HttpBodyStreamReadCallback)(const ArkWeb_HttpBodyStream* httpBodyStream,
                                                  uint8_t* buffer,
                                                  int bytesRead);

/**
 * @brief  Callback when the init operation done.
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @param result {@link ARKWEB_NET_OK} on success otherwise refer to arkweb_net_error_list.h.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
typedef void (*ArkWeb_HttpBodyStreamInitCallback)(const ArkWeb_HttpBodyStream* httpBodyStream, ArkWeb_NetError result);

/**
 * @brief Destroy the ArkWeb_RequestHeaderList.
 * @param requestHeaderList The ArkWeb_RequestHeaderList to be destroyed.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebRequestHeaderList_Destroy(ArkWeb_RequestHeaderList* requestHeaderList);

/**
 * @brief Get the request headers size.
 * @param requestHeaderList The list of request header.
 * @return The size of request headers. -1 if requestHeaderList is invalid.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebRequestHeaderList_GetSize(const ArkWeb_RequestHeaderList* requestHeaderList);

/**
 * @brief Get the specified request header.
 * @param requestHeaderList The list of request header.
 * @param index The index of request header.
 * @param key The header key. Caller must release the string by OH_ArkWeb_ReleaseString.
 * @param value The header value. Caller must release the string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebRequestHeaderList_GetHeader(const ArkWeb_RequestHeaderList* requestHeaderList,
                                          int32_t index,
                                          char** key,
                                          char** value);

/**
 * @brief Set a user data to ArkWeb_ResourceRequest.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @param userData The user data to set.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResourceRequest_SetUserData(ArkWeb_ResourceRequest* resourceRequest, void* userData);

/**
 * @brief Get the user data from ArkWeb_ResourceRequest.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @return The set user data.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void* OH_ArkWebResourceRequest_GetUserData(const ArkWeb_ResourceRequest* resourceRequest);

/**
 * @brief Get the method of request.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @param method The request's http method. This function will allocate memory for the method string and caller must
 *               release the string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResourceRequest_GetMethod(const ArkWeb_ResourceRequest* resourceRequest, char** method);

/**
 * @brief Get the url of request.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @param url The request's url. This function will allocate memory for the url string and caller must release the
 *            string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResourceRequest_GetUrl(const ArkWeb_ResourceRequest* resourceRequest, char** url);

/**
 * @brief Create a ArkWeb_HttpBodyStream which used to read the http body.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @param httpBodyStream The request's http body. This function will allocate memory for the http body stream and
 *                       caller must release the httpBodyStream by OH_ArkWebResourceRequest_DestroyHttpBodyStream.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResourceRequest_GetHttpBodyStream(const ArkWeb_ResourceRequest* resourceRequest,
                                                ArkWeb_HttpBodyStream** httpBodyStream);

/**
 * @brief Destroy the http body stream.
 * @param httpBodyStream The httpBodyStream to be destroyed.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResourceRequest_DestroyHttpBodyStream(ArkWeb_HttpBodyStream* httpBodyStream);

/**
 * @brief Get the resource type of request.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @return The resource type of request. -1 if resourceRequest is invalid.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResourceRequest_GetResourceType(const ArkWeb_ResourceRequest* resourceRequest);

/**
 * @brief Get the url of frame which trigger this request.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @param frameUrl The url of frame which trigger this request. This function will allocate memory for the url string
 *            and caller must release the string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResourceRequest_GetFrameUrl(const ArkWeb_ResourceRequest* resourceRequest, char** frameUrl);

/**
 * @brief Set a user data to ArkWeb_HttpBodyStream.
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @param userData The user data to set.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebHttpBodyStream_SetUserData(ArkWeb_HttpBodyStream* httpBodyStream, void* userData);

/**
 * @brief Get the user data from ArkWeb_HttpBodyStream.
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @return The set user data.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void* OH_ArkWebHttpBodyStream_GetUserData(const ArkWeb_HttpBodyStream* httpBodyStream);

/**
 * @brief Set the callback for OH_ArkWebHttpBodyStream_Read.
 *
 * The result of OH_ArkWebHttpBodyStream_Read will be notified to caller through the readCallback.\n
 * The callback will run in the same thread as OH_ArkWebHttpBodyStream_Read.\n
 *
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @param readCallback The callback of read function.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebHttpBodyStream_SetReadCallback(ArkWeb_HttpBodyStream* httpBodyStream,
                                                ArkWeb_HttpBodyStreamReadCallback readCallback);

/**
 * @brief Init the http body stream.
 *
 * This function must be called before calling any other functions.\n
 *
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @param initCallback The callback of init.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebHttpBodyStream_Init(ArkWeb_HttpBodyStream* httpBodyStream,
                                     ArkWeb_HttpBodyStreamInitCallback initCallback);

/**
 * @brief Read the http body to the buffer.
 *
 * The buffer must be larger than the bufLen. We will be reading data from a worker thread to the buffer,\n
 * so should not use the buffer in other threads before the callback to avoid concurrency issues.\n
 *
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @param buffer The buffer to receive data.
 * @param bufLen The size of bytes to read.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebHttpBodyStream_Read(const ArkWeb_HttpBodyStream* httpBodyStream, uint8_t* buffer, int bufLen);

/**
 * @brief Get the total size of the data stream.
 *
 * When data is chunked or httpBodyStream is invalid, always return zero.\n
 *
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @return The size of data stream.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
uint64_t OH_ArkWebHttpBodyStream_GetSize(const ArkWeb_HttpBodyStream* httpBodyStream);

/**
 * @brief Get the current position of the data stream.
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @return The current position of data stream. 0 if httpBodyStream is invalid.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
uint64_t OH_ArkWebHttpBodyStream_GetPosition(const ArkWeb_HttpBodyStream* httpBodyStream);

/**
 * @brief Get if the data stream is chunked.
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @return True if is chunked; false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
bool OH_ArkWebHttpBodyStream_IsChunked(const ArkWeb_HttpBodyStream* httpBodyStream);


/**
 * @brief Returns true if all data has been consumed from this upload data stream.
 *
 * For chunked uploads, returns false until the first read attempt.\n
 *
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @return True if all data has been consumed; false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
bool OH_ArkWebHttpBodyStream_IsEof(const ArkWeb_HttpBodyStream* httpBodyStream);

/**
 * @brief Returns true if the upload data in the stream is entirely in memory,
 *        and all read requests will succeed synchronously.
 *
 * Expected to return false for chunked requests.\n
 *
 * @param httpBodyStream The ArkWeb_HttpBodyStream.
 * @return True if the upload data is in memory; false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
bool OH_ArkWebHttpBodyStream_IsInMemory(const ArkWeb_HttpBodyStream* httpBodyStream);

/**
 * @brief Destroy the ArkWeb_ResourceRequest.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResourceRequest_Destroy(const ArkWeb_ResourceRequest* resourceRequest);

/**
 * @brief Get the referrer of request.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @param referrer The request's referrer. This function will allocate memory for the post data string and caller
 *                 must release the string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResourceRequest_GetReferrer(const ArkWeb_ResourceRequest* resourceRequest, char** referrer);

/**
 * @brief Get the OH_ArkWeb_RequestHeaderList of the request.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @param requestHeaderList The RequestHeaderList of request.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResourceRequest_GetRequestHeaders(const ArkWeb_ResourceRequest* resourceRequest,
                                                ArkWeb_RequestHeaderList** requestHeaderList);

/**
 * @brief Get if this is a redirect request.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @return True if this is a redirect; false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
bool OH_ArkWebResourceRequest_IsRedirect(const ArkWeb_ResourceRequest* resourceRequest);

/**
 * @brief Get if this is a request from main frame.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @return True if this is from main frame; false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
bool OH_ArkWebResourceRequest_IsMainFrame(const ArkWeb_ResourceRequest* resourceRequest);

/**
 * @brief Get if this is a request is triggered by user gesutre.
 * @param resourceRequest The ArkWeb_ResourceRequest.
 * @return True if this is triggered by user gesture; false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
bool OH_ArkWebResourceRequest_HasGesture(const ArkWeb_ResourceRequest* resourceRequest);

/**
 * @brief Register custom scheme to the ArkWeb.
 *
 * Should not be called for built-in HTTP, HTTPS, FILE, FTP, ABOUT and DATA schemes.\n
 * This function should be called on main thread.\n
 *
 * @param scheme The scheme to regist.
 * @param option The configuration of the scheme.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_ERROR_UNKNOWN} 17100100 - Unknown error.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *         {@link ARKWEB_SCHEME_REGISTER_FAILED} 17100102 - Register custom schemes should be called
 *                                                          before create any ArkWeb.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWeb_RegisterCustomSchemes(const char* scheme, int32_t option);

/**
 * @brief Set a ArkWeb_SchemeHandler for a specific scheme to intercept requests of that scheme type.
 *
 * SchemeHandler should be set after the BrowserContext created.\n
 * Use WebviewController.initializeWebEngine to initialize the BrowserContext without create a ArkWeb.\n
 *
 * @param scheme Scheme that need to be intercepted.
 * @param schemeHandler The SchemeHandler for the scheme. Only requests triggered by ServiceWorker will be notified
 *                      through this handler.
 * @return Return true if set SchemeHandler for specific scheme successful, return false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
bool OH_ArkWebServiceWorker_SetSchemeHandler(const char* scheme, ArkWeb_SchemeHandler* schemeHandler);

/**
 * @brief Set a ArkWeb_SchemeHandler for a specific scheme to intercept requests of that scheme type.
 *
 * SchemeHandler should be set after the BrowserContext created.\n
 * Use WebviewController.initializeWebEngine to initialize the BrowserContext without create a ArkWeb.\n
 *
 * @param scheme Scheme that need to be intercepted.
 * @param webTag The name of the web component.
 * @param schemeHandler The SchemeHandler for the scheme. Only requests triggered from the specified web will be
 *                      notified through this handler.
 * @return Return true if set SchemeHandler for specific scheme successful, return false otherwise.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
bool OH_ArkWeb_SetSchemeHandler(const char* scheme, const char* webTag, ArkWeb_SchemeHandler* schemeHandler);

/**
 * @brief Clear the handler registered on the specified web for service worker.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebServiceWorker_ClearSchemeHandlers();

/**
 * @brief Clear the handler registered on the specified web.
 * @param webTag The name of the web component.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWeb_ClearSchemeHandlers(const char* webTag);

/**
 * @brief Create a SchemeHandler.
 * @param schemeHandler Return the created SchemeHandler. Use OH_ArkWeb_DestroySchemeHandler destroy it when donn't
 *                      need it.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWeb_CreateSchemeHandler(ArkWeb_SchemeHandler** schemeHandler);

/**
 * @brief Destroy a SchemeHandler.
 * @param The ArkWeb_SchemeHandler to be destroy.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWeb_DestroySchemeHandler(ArkWeb_SchemeHandler* schemeHandler);

/**
 * @brief Set a user data to ArkWeb_SchemeHandler.
 * @param schemeHandler The ArkWeb_SchemeHandler.
 * @param userData The user data to set.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebSchemeHandler_SetUserData(ArkWeb_SchemeHandler* schemeHandler, void* userData);

/**
 * @brief Get the user data from ArkWeb_SchemeHandler.
 * @param schemeHandler The ArkWeb_SchemeHandler.
 * @return The set user data.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void* OH_ArkWebSchemeHandler_GetUserData(const ArkWeb_SchemeHandler* schemeHandler);

/**
 * @brief Set the OnRequestStart callback for SchemeHandler.
 * @param schemeHandler The SchemeHandler for the scheme.
 * @param onRequestStart The OnRequestStart callback.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebSchemeHandler_SetOnRequestStart(ArkWeb_SchemeHandler* schemeHandler,
                                                 ArkWeb_OnRequestStart onRequestStart);

/**
 * @brief Set the OnRequestStop callback for SchemeHandler.
 * @param schemeHandler The SchemeHandler for the scheme.
 * @param onRequestStop The OnRequestStop callback.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebSchemeHandler_SetOnRequestStop(ArkWeb_SchemeHandler* schemeHandler,
                                                ArkWeb_OnRequestStop onRequestStop);

/**
 * @brief Create a Response for a request.
 * @param response The created Response. Use OH_ArkWeb_DestroyResponse to destroy when donn't need it.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWeb_CreateResponse(ArkWeb_Response** response);

/**
 * @brief Destroy the Reponse.
 * @param response The Response needs destroy.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWeb_DestroyResponse(ArkWeb_Response* response);

/**
 * @brief Set the resolved URL after redirects or changed as a result of HSTS.
 * @param response The ArkWeb_Response.
 * @param url The resolved URL.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResponse_SetUrl(ArkWeb_Response* response, const char* url);

/**
 * @brief Get the resolved URL after redirects or changed as a result of HSTS.
 * @param response The ArkWeb_Response.
 * @param url The resolved URL.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResponse_GetUrl(const ArkWeb_Response* response, char** url);

/**
 * @brief Set a error code to ArkWeb_Response.
 * @param response The ArkWeb_Response.
 * @param errorCode The error code for the failed request.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResponse_SetError(ArkWeb_Response* response, ArkWeb_NetError errorCode);

/**
 * @brief Get the response's error code.
 * @param response The ArkWeb_Response.
 * @return The response's error code.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
ArkWeb_NetError OH_ArkWebResponse_GetError(const ArkWeb_Response* response);

/**
 * @brief Set a status code to ArkWebResponse.
 * @param response The ArkWeb_Response.
 * @param status The http status code for the request.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResponse_SetStatus(ArkWeb_Response* response, int status);

/**
 * @brief Get the response's status code.
 * @param response The ArkWeb_Response.
 * @return The response's http status code. -1 if response is invalid.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int OH_ArkWebResponse_GetStatus(const ArkWeb_Response* response);

/**
 * @brief Set a status text to ArkWebResponse.
 * @param response The ArkWeb_Response.
 * @param statusText The status text for the request.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResponse_SetStatusText(ArkWeb_Response* response, const char* statusText);

/**
 * @brief Get the response's status text.
 * @param response The ArkWeb_Response.
 * @param statusText Return the response's statusText. This function will allocate memory for the statusText string and
 *                   caller must release the string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResponse_GetStatusText(const ArkWeb_Response* response, char** statusText);

/**
 * @brief Set mime type to ArkWebResponse.
 * @param response The ArkWeb_Response.
 * @param mimeType The mime type for the request.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResponse_SetMimeType(ArkWeb_Response* response, const char* mimeType);

/**
 * @brief Get the response's mime type.
 * @param response The ArkWeb_Response.
 * @param mimeType Return the response's mime type. This function will allocate memory for the mime type string and
 *                 caller must release the string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResponse_GetMimeType(const ArkWeb_Response* response, char** mimeType);

/**
 * @brief Set charset to ArkWeb_Response.
 * @param response The ArkWeb_Response.
 * @param charset The charset for the request.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResponse_SetCharset(ArkWeb_Response* response, const char* charset);

/**
 * @brief Get the response's charset.
 * @param response The ArkWeb_Response.
 * @param charset Return the response's charset. This function will allocate memory for the charset string and caller
 *                must release the string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResponse_GetCharset(const ArkWeb_Response* response, char** charset);

/**
 * @brief Set a header to ArkWeb_Response.
 * @param response The ArkWeb_Response.
 * @param name The name of the header.
 * @param value The value of the header.
 * @param overwirte If true will overwrite the exsits header, if false otherwise.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResponse_SetHeaderByName(ArkWeb_Response* response,
                                          const char* name,
                                          const char* value,
                                          bool overwrite);

/**
 * @brief Get the header from the response.
 * @param response The ArkWeb_Response.
 * @param name The name of the header.
 * @param value Return the header's value. This function will allocate memory for the value string and caller must
 *              release the string by OH_ArkWeb_ReleaseString.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWebResponse_GetHeaderByName(const ArkWeb_Response* response, const char* name, char** value);

/**
 * @brief Destroy the ArkWeb_ResourceHandler.
 * @param resourceHandler The ArkWeb_ResourceHandler.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResourceHandler_Destroy(const ArkWeb_ResourceHandler* resourceHandler);

/**
 * @brief Pass response headers to intercepted requests.
 * @param resourceHandler The ArkWeb_ResourceHandler for the request.
 * @param response The ArkWeb_Response for the intercepting requests.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResourceHandler_DidReceiveResponse(const ArkWeb_ResourceHandler* resourceHandler,
                                                    const ArkWeb_Response* response);

/**
 * @brief Pass response body data to intercepted requests.
 * @param resourceHandler The ArkWeb_ResourceHandler for the request.
 * @param buffer Buffer data to send.
 * @param bufLen The size of buffer.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResourceHandler_DidReceiveData(const ArkWeb_ResourceHandler* resourceHandler,
                                                const uint8_t* buffer,
                                                int64_t bufLen);

/**
 * @brief Notify the ArkWeb that this request should be finished and there is no more data available.
 * @param resourceHandler The ArkWeb_ResourceHandler for the request.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResourceHandler_DidFinish(const ArkWeb_ResourceHandler* resourceHandler);

/**
 * @brief Notify the ArkWeb that this request should be failed.
 * @param resourceHandler The ArkWeb_ResourceHandler for the request.
 * @param errorCode The error code for this request. Refer to arkweb_net_error_list.h.
 * @return {@link ARKWEB_NET_OK} 0 - Success.
 *         {@link ARKWEB_INVALID_PARAM} 17100101 - Invalid param.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
int32_t OH_ArkWebResourceHandler_DidFailWithError(const ArkWeb_ResourceHandler* resourceHandler,
                                                  ArkWeb_NetError errorCode);

/**
 * @brief Release the string acquired by native function.
 * @param string The string to be released.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWeb_ReleaseString(char* string);

/**
 * @brief Release the byte array acquired by native function.
 * @param byteArray The byte array to be released.
 *
 * @syscap SystemCapability.Web.Webview.Core
 * @since 12
 */
void OH_ArkWeb_ReleaseByteArray(uint8_t* byteArray);


#ifdef __cplusplus
};
#endif
#endif // ARKWEB_SCHEME_HANDLER_H