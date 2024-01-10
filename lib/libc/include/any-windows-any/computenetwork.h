/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef HCN_CLIENT_H
#define HCN_CLIENT_H

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum HCN_NOTIFICATIONS {
  HcnNotificationInvalid = 0x00000000,
  HcnNotificationNetworkPreCreate = 0x00000001,
  HcnNotificationNetworkCreate = 0x00000002,
  HcnNotificationNetworkPreDelete = 0x00000003,
  HcnNotificationNetworkDelete = 0x00000004,
  HcnNotificationNamespaceCreate = 0x00000005,
  HcnNotificationNamespaceDelete = 0x00000006,
  HcnNotificationGuestNetworkServiceCreate = 0x00000007,
  HcnNotificationGuestNetworkServiceDelete = 0x00000008,
  HcnNotificationNetworkEndpointAttached = 0x00000009,
  HcnNotificationNetworkEndpointDetached = 0x00000010,
  HcnNotificationGuestNetworkServiceStateChanged = 0x00000011,
  HcnNotificationGuestNetworkServiceInterfaceStateChanged = 0x00000012,
  HcnNotificationServiceDisconnect = 0x01000000,
  HcnNotificationFlagsReserved = 0xF0000000
} HCN_NOTIFICATIONS;

typedef void* HCN_CALLBACK;

typedef void (CALLBACK *HCN_NOTIFICATION_CALLBACK)(DWORD NotificationType, void *Context, HRESULT NotificationStatus, PCWSTR NotificationData);

typedef void* HCN_NETWORK;
typedef HCN_NETWORK* PHCN_NETWORK;

HRESULT WINAPI HcnEnumerateNetworks (PCWSTR Query, PWSTR *Networks, PWSTR *ErrorRecord);
HRESULT WINAPI HcnCreateNetwork (REFGUID Id, PCWSTR Settings, PHCN_NETWORK Network, PWSTR *ErrorRecord);
HRESULT WINAPI HcnOpenNetwork (REFGUID Id, PHCN_NETWORK Network, PWSTR *ErrorRecord);
HRESULT WINAPI HcnModifyNetwork (HCN_NETWORK Network, PCWSTR Settings, PWSTR *ErrorRecord);
HRESULT WINAPI HcnQueryNetworkProperties (HCN_NETWORK Network, PCWSTR Query, PWSTR *Properties, PWSTR *ErrorRecord);
HRESULT WINAPI HcnDeleteNetwork (REFGUID Id, PWSTR *ErrorRecord);
HRESULT WINAPI HcnCloseNetwork (HCN_NETWORK Network);

typedef void* HCN_NAMESPACE;
typedef HCN_NAMESPACE* PHCN_NAMESPACE;

HRESULT WINAPI HcnEnumerateNamespaces (PCWSTR Query, PWSTR *Namespaces, PWSTR *ErrorRecord);
HRESULT WINAPI HcnCreateNamespace (REFGUID Id, PCWSTR Settings, PHCN_NAMESPACE Namespace, PWSTR *ErrorRecord);
HRESULT WINAPI HcnOpenNamespace (REFGUID Id, PHCN_NAMESPACE Namespace, PWSTR *ErrorRecord);
HRESULT WINAPI HcnModifyNamespace (HCN_NAMESPACE Namespace, PCWSTR Settings, PWSTR *ErrorRecord);
HRESULT WINAPI HcnQueryNamespaceProperties (HCN_NAMESPACE Namespace, PCWSTR Query, PWSTR *Properties, PWSTR *ErrorRecord);
HRESULT WINAPI HcnDeleteNamespace (REFGUID Id, PWSTR *ErrorRecord);
HRESULT WINAPI HcnCloseNamespace (HCN_NAMESPACE Namespace);

typedef void* HCN_ENDPOINT;
typedef HCN_ENDPOINT* PHCN_ENDPOINT;

HRESULT WINAPI HcnEnumerateEndpoints (PCWSTR Query, PWSTR *Endpoints, PWSTR *ErrorRecord);
HRESULT WINAPI HcnCreateEndpoint (HCN_NETWORK Network, REFGUID Id, PCWSTR Settings, PHCN_ENDPOINT Endpoint, PWSTR *ErrorRecord);
HRESULT WINAPI HcnOpenEndpoint (REFGUID Id, PHCN_ENDPOINT Endpoint, PWSTR *ErrorRecord);
HRESULT WINAPI HcnModifyEndpoint (HCN_ENDPOINT Endpoint, PCWSTR Settings, PWSTR *ErrorRecord);
HRESULT WINAPI HcnQueryEndpointProperties (HCN_ENDPOINT Endpoint, PCWSTR Query, PWSTR *Properties, PWSTR *ErrorRecord);
HRESULT WINAPI HcnDeleteEndpoint (REFGUID Id, PWSTR *ErrorRecord);
HRESULT WINAPI HcnCloseEndpoint (HCN_ENDPOINT Endpoint);

typedef void* HCN_LOADBALANCER;
typedef HCN_LOADBALANCER* PHCN_LOADBALANCER;

HRESULT WINAPI HcnEnumerateLoadBalancers (PCWSTR Query, PWSTR *LoadBalancer, PWSTR *ErrorRecord);
HRESULT WINAPI HcnCreateLoadBalancer (REFGUID Id, PCWSTR Settings, PHCN_LOADBALANCER LoadBalancer, PWSTR *ErrorRecord);
HRESULT WINAPI HcnOpenLoadBalancer (REFGUID Id, PHCN_LOADBALANCER LoadBalancer, PWSTR *ErrorRecord);
HRESULT WINAPI HcnModifyLoadBalancer (HCN_LOADBALANCER LoadBalancer, PCWSTR Settings, PWSTR *ErrorRecord);
HRESULT WINAPI HcnQueryLoadBalancerProperties (HCN_LOADBALANCER LoadBalancer, PCWSTR Query, PWSTR *Properties, PWSTR *ErrorRecord);
HRESULT WINAPI HcnDeleteLoadBalancer (REFGUID Id, PWSTR *ErrorRecord);
HRESULT WINAPI HcnCloseLoadBalancer (HCN_LOADBALANCER LoadBalancer);

typedef void* HCN_SERVICE;
typedef HCN_SERVICE* PHCN_SERVICE;

HRESULT WINAPI HcnRegisterServiceCallback (HCN_NOTIFICATION_CALLBACK Callback, void *Context, HCN_CALLBACK *CallbackHandle);
HRESULT WINAPI HcnUnregisterServiceCallback (HCN_CALLBACK CallbackHandle);

typedef void* HCN_GUESTNETWORKSERVICE;
typedef HCN_GUESTNETWORKSERVICE* PHCN_GUESTNETWORKSERVICE;

HRESULT WINAPI HcnRegisterGuestNetworkServiceCallback (HCN_GUESTNETWORKSERVICE GuestNetworkService, HCN_NOTIFICATION_CALLBACK Callback, void* Context, HCN_CALLBACK* CallbackHandle);
HRESULT WINAPI HcnUnregisterGuestNetworkServiceCallback (HCN_CALLBACK CallbackHandle);
HRESULT WINAPI HcnCreateGuestNetworkService (REFGUID Id, PCWSTR Settings, PHCN_GUESTNETWORKSERVICE GuestNetworkService, PWSTR* ErrorRecord);
HRESULT WINAPI HcnCloseGuestNetworkService (HCN_GUESTNETWORKSERVICE GuestNetworkService);
HRESULT WINAPI HcnModifyGuestNetworkService (HCN_GUESTNETWORKSERVICE GuestNetworkService, PCWSTR Settings, PWSTR* ErrorRecord);
HRESULT WINAPI HcnDeleteGuestNetworkService (REFGUID Id, PWSTR* ErrorRecord);

typedef enum tagHCN_PORT_PROTOCOL {
  HCN_PORT_PROTOCOL_TCP = 0x01,
  HCN_PORT_PROTOCOL_UDP = 0x02,
  HCN_PORT_PROTOCOL_BOTH = 0x03
} HCN_PORT_PROTOCOL;

typedef enum tagHCN_PORT_ACCESS {
  HCN_PORT_ACCESS_EXCLUSIVE = 0x01,
  HCN_PORT_ACCESS_SHARED = 0x02
} HCN_PORT_ACCESS;

typedef struct tagHCN_PORT_RANGE_RESERVATION {
  USHORT startingPort;
  USHORT endingPort;
} HCN_PORT_RANGE_RESERVATION;

typedef struct tagHCN_PORT_RANGE_ENTRY {
  GUID OwningPartitionId;
  GUID TargetPartitionId;
  HCN_PORT_PROTOCOL Protocol;
  UINT64 Priority;
  UINT32 ReservationType;
  UINT32 SharingFlags;
  UINT32 DeliveryMode;
  UINT16 StartingPort;
  UINT16 EndingPort;
} HCN_PORT_RANGE_ENTRY, *PHCN_PORT_RANGE_ENTRY;

HRESULT WINAPI HcnReserveGuestNetworkServicePort (HCN_GUESTNETWORKSERVICE GuestNetworkService, HCN_PORT_PROTOCOL Protocol, HCN_PORT_ACCESS Access, USHORT Port, HANDLE* PortReservationHandle);
HRESULT WINAPI HcnReserveGuestNetworkServicePortRange (HCN_GUESTNETWORKSERVICE GuestNetworkService, USHORT PortCount, HCN_PORT_RANGE_RESERVATION* PortRangeReservation, HANDLE* PortReservationHandle);
HRESULT WINAPI HcnReleaseGuestNetworkServicePortReservationHandle (HANDLE PortReservationHandle);
HRESULT WINAPI HcnEnumerateGuestNetworkPortReservations (ULONG* ReturnCount, HCN_PORT_RANGE_ENTRY** PortEntries);
VOID WINAPI HcnFreeGuestNetworkPortReservations (HCN_PORT_RANGE_ENTRY* PortEntries);
HRESULT WINAPI HcnQueryEndpointStats (HCN_ENDPOINT Endpoint, PCWSTR Query, PWSTR *Stats, PWSTR *ErrorRecord);
HRESULT WINAPI HcnQueryEndpointAddresses (HCN_ENDPOINT Endpoint, PCWSTR Query, PWSTR *Addresses, PWSTR *ErrorRecord);

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_PARTITION_DESKTOP */

#endif /* HCN_CLIENT_H */
