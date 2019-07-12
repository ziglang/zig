#pragma once

#define __NET_PNP__

typedef enum _NET_DEVICE_POWER_STATE {
  NetDeviceStateUnspecified = 0,
  NetDeviceStateD0,
  NetDeviceStateD1,
  NetDeviceStateD2,
  NetDeviceStateD3,
  NetDeviceStateMaximum
} NET_DEVICE_POWER_STATE, *PNET_DEVICE_POWER_STATE;

typedef enum _NET_PNP_EVENT_CODE {
  NetEventSetPower,
  NetEventQueryPower,
  NetEventQueryRemoveDevice,
  NetEventCancelRemoveDevice,
  NetEventReconfigure,
  NetEventBindList,
  NetEventBindsComplete,
  NetEventPnPCapabilities,
  NetEventPause,
  NetEventRestart,
  NetEventPortActivation,
  NetEventPortDeactivation,
  NetEventIMReEnableDevice,
  NetEventMaximum
} NET_PNP_EVENT_CODE, *PNET_PNP_EVENT_CODE;

typedef struct _NET_PNP_EVENT {
  NET_PNP_EVENT_CODE NetEvent;
  PVOID Buffer;
  ULONG BufferLength;
  ULONG_PTR NdisReserved[4];
  ULONG_PTR TransportReserved[4];
  ULONG_PTR TdiReserved[4];
  ULONG_PTR TdiClientReserved[4];
} NET_PNP_EVENT, *PNET_PNP_EVENT;

/* FIXME : This belongs to ndis.h */
typedef enum _NDIS_DEVICE_PNP_EVENT {
  NdisDevicePnPEventSurpriseRemoved,
  NdisDevicePnPEventPowerProfileChanged,
  NdisDevicePnPEventMaximum
} NDIS_DEVICE_PNP_EVENT, *PNDIS_DEVICE_PNP_EVENT;
