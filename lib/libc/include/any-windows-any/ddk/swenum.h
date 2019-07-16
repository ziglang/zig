#ifndef _SWENUM_
#define _SWENUM_

#define IOCTL_SWENUM_INSTALL_INTERFACE CTL_CODE(FILE_DEVICE_BUS_EXTENDER, 0x000, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_SWENUM_REMOVE_INTERFACE CTL_CODE(FILE_DEVICE_BUS_EXTENDER, 0x001, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_SWENUM_GET_BUS_ID CTL_CODE(FILE_DEVICE_BUS_EXTENDER, 0x002, METHOD_NEITHER, FILE_READ_ACCESS)

typedef struct _SWENUM_INSTALL_INTERFACE {
  GUID   DeviceId;
  GUID   InterfaceId;
  WCHAR  ReferenceString[1];
} SWENUM_INSTALL_INTERFACE, *PSWENUM_INSTALL_INTERFACE;

#if defined(_KS_)
#define STATIC_BUSID_SoftwareDeviceEnumerator STATIC_KSMEDIUMSETID_Standard
#define BUSID_SoftwareDeviceEnumerator KSMEDIUMSETID_Standard
#else
#define STATIC_BUSID_SoftwareDeviceEnumerator \
    0x4747B320L, 0x62CE, 0x11CF, 0xA5, 0xD6, 0x28, 0xDB, 0x04, 0xC1, 0x00, 0x00
#endif /* _KS_ */

#if defined(_NTDDK_)

#if !defined(_KS_)
typedef VOID (NTAPI *PFNREFERENCEDEVICEOBJECT)(PVOID Context);
typedef VOID (NTAPI *PFNDEREFERENCEDEVICEOBJECT)(PVOID Context);
typedef NTSTATUS (NTAPI *PFNQUERYREFERENCESTRING)(PVOID Context, PWCHAR *String);
#endif /* _KS_ */

#define BUS_INTERFACE_SWENUM_VERSION    0x100

typedef struct _BUS_INTERFACE_SWENUM {
  INTERFACE Interface;
  PFNREFERENCEDEVICEOBJECT ReferenceDeviceObject;
  PFNDEREFERENCEDEVICEOBJECT DereferenceDeviceObject;
  PFNQUERYREFERENCESTRING QueryReferenceString;
} BUS_INTERFACE_SWENUM, *PBUS_INTERFACE_SWENUM;

#if defined(__cplusplus)
extern "C" {
#endif

#if defined(_KS_)

KSDDKAPI
NTSTATUS
NTAPI
KsQuerySoftwareBusInterface(
    IN PDEVICE_OBJECT PnpDeviceObject,
    OUT PBUS_INTERFACE_SWENUM BusInterface
);

KSDDKAPI
NTSTATUS
NTAPI
KsReferenceSoftwareBusObject(
    IN KSDEVICE_HEADER Header
);

KSDDKAPI
VOID
NTAPI
KsDereferenceSoftwareBusObject(
    IN KSDEVICE_HEADER  Header
);

KSDDKAPI
NTSTATUS
NTAPI
KsCreateBusEnumObject(
    IN PWSTR BusIdentifier,
    IN PDEVICE_OBJECT BusDeviceObject,
    IN PDEVICE_OBJECT PhysicalDeviceObject,
    IN PDEVICE_OBJECT PnpDeviceObject,
    IN REFGUID InterfaceGuid,
    IN PWSTR ServiceRelativePath
);

KSDDKAPI
NTSTATUS
NTAPI
KsGetBusEnumIdentifier(
    IN OUT PIRP Irp
);

KSDDKAPI
NTSTATUS
NTAPI
KsGetBusEnumPnpDeviceObject(
    IN PDEVICE_OBJECT DeviceObject,
    OUT PDEVICE_OBJECT *PnpDeviceObject
);

KSDDKAPI
NTSTATUS
NTAPI
KsInstallBusEnumInterface(
    IN PIRP Irp
);

KSDDKAPI
NTSTATUS
NTAPI
KsIsBusEnumChildDevice(
    IN PDEVICE_OBJECT DeviceObject,
    OUT PBOOLEAN ChildDevice
);


KSDDKAPI
NTSTATUS
NTAPI
KsRemoveBusEnumInterface(
    IN PIRP Irp
);

KSDDKAPI
NTSTATUS
NTAPI
KsServiceBusEnumPnpRequest(
    IN PDEVICE_OBJECT DeviceObject,
    IN OUT PIRP Irp
);

KSDDKAPI
NTSTATUS
NTAPI
KsServiceBusEnumCreateRequest(
    IN PDEVICE_OBJECT DeviceObject,
    IN OUT PIRP Irp
);

KSDDKAPI
NTSTATUS
NTAPI
KsGetBusEnumParentFDOFromChildPDO(
    IN PDEVICE_OBJECT DeviceObject,
    OUT PDEVICE_OBJECT *FunctionalDeviceObject
);

#endif /* _KS_ */

#if defined(__cplusplus)
}
#endif

#endif /* _NTDDK_ */

#endif /* _SWENUM_ */

