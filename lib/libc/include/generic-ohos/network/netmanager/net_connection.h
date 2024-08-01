/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef NATIVE_NET_CONN_API_H
#define NATIVE_NET_CONN_API_H

/**
 * @addtogroup NetConnection
 * @{
 *
 * @brief Provide C interface for the data network connection module of network management.
 *
 * @since 11
 * @version 1.0
 */

/**
 * @file net_connection.h
 *
 * @brief Provide C interface for the data network connection module of network management.
 *
 * @kit NetworkKit
 * @syscap SystemCapability.Communication.NetManager.Core
 * @library libnet_connection.so
 * @since 11
 * @version 1.0
 */

#include <netdb.h>

#include "net_connection_type.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Checks whether a default activated data network is available.
 *
 * @param hasDefaultNet Pointer to the result that specifies whether a default activated data network is available.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.GET_NETWORK_INFO
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_HasDefaultNet(int32_t *hasDefaultNet);

/**
 * @brief Obtains the default activated data network.
 *
 * @param netHandle Pointer to the network handle that contains the network ID.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.GET_NETWORK_INFO
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_GetDefaultNet(NetConn_NetHandle *netHandle);

/**
 * @brief Checks whether metering is enabled for the default data network.
 *
 * @param isMetered Pointer to the result that specifies whether metering is enabled.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.GET_NETWORK_INFO
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_IsDefaultNetMetered(int32_t *isMetered);

/**
 * @brief Obtains the connection properties of a data network.
 *
 * @param netHandle Pointer to the network handle that contains the network ID.
 * @param prop Pointer to the connection properties.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.GET_NETWORK_INFO
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_GetConnectionProperties(NetConn_NetHandle *netHandle, NetConn_ConnectionProperties *prop);

/**
 * @brief Obtains the capabilities of a data network.
 *
 * @param netHandle Pointer to the network handle that contains the network ID.
 * @param netCapacities Pointer to the network capabilities.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.GET_NETWORK_INFO
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_GetNetCapabilities(NetConn_NetHandle *netHandle, NetConn_NetCapabilities *netCapabilities);

/**
 * @brief Obtains the default http proxy.
 *
 * @param httpProxy Pointer to the HTTP proxy.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_GetDefaultHttpProxy(NetConn_HttpProxy *httpProxy);

/**
 * @brief Get DNS result with netId.
 *
 * @param host The host name to query.
 * @param serv Service name.
 * @param hint Pointer to the addrinfo structure.
 * @param res Store DNS query results and return them in a linked list format.
 * @param netId DNS query netId, 0 is used for default netid query.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.INTERNET
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_GetAddrInfo(char *host, char *serv, struct addrinfo *hint, struct addrinfo **res, int32_t netId);

/**
 * @brief Free DNS result.
 *
 * @param res DNS query result chain header.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.INTERNET
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_FreeDnsResult(struct addrinfo *res);

/**
 * @brief Queries all activated data networks.
 *
 * @param netHandleList Network handle that stores the network ID list.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.GET_NETWORK_INFO
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OH_NetConn_GetAllNets(NetConn_NetHandleList *netHandleList);

/**
 * @brief Registers a custom DNS resolver.
 *
 * @param resolver Pointer to the custom DNS resolver.
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.INTERNET
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OHOS_NetConn_RegisterDnsResolver(OH_NetConn_CustomDnsResolver resolver);

/**
 * @brief Unregisters a custom DNS resolver.
 *
 * @return 0 - Success. 201 - Missing permissions.
 *         401 - Parameter error. 2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @permission ohos.permission.INTERNET
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 11
 * @version 1.0
 */
int32_t OHOS_NetConn_UnregisterDnsResolver(void);

/**
 * @brief Binds a socket to the specific network.
 *
 * @param socketFd Socket constructed by user.
 * @param netHandle Pointer to the network handle that contains the network ID.
 * @return 0 - Success.
 *         401 - Parameter error.
 *         2100002 - Unable to connect to service.
 *         2100003 - Internal error.
 * @syscap SystemCapability.Communication.NetManager.Core
 * @since 12
 * @version 1.0
 */
int32_t OH_NetConn_BindSocket(int32_t socketFd, NetConn_NetHandle *netHandle);

#ifdef __cplusplus
}
#endif

/** @} */
#endif /* NATIVE_NET_CONN_API_H */