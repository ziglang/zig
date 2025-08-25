#include "wdm.h"

#ifdef EXPORT
#undef EXPORT
#endif
#define EXPORT  __cdecl


typedef VOID (EXPORT *PACPI_OP_REGION_CALLBACK)();

typedef
NTSTATUS
(EXPORT *PACPI_OP_REGION_HANDLER) (ULONG AccessType,
                                   PVOID OperationRegionObject,
                                   ULONG Address,
                                   ULONG Size,
                                   PULONG Data,
                                   ULONG_PTR Context,
                                   PACPI_OP_REGION_CALLBACK CompletionHandler,
                                   PVOID CompletionContext);

NTSTATUS
RegisterOpRegionHandler (IN PDEVICE_OBJECT DeviceObject,
                         IN ULONG AccessType,
                         IN ULONG RegionSpace,
                         IN PACPI_OP_REGION_HANDLER Handler,
                         IN PVOID Context, IN ULONG Flags,
                         IN OUT PVOID *OperationRegionObject);

NTSTATUS
DeRegisterOpRegionHandler (IN PDEVICE_OBJECT DeviceObject,
                           IN PVOID OperationRegionObject);

#define ACPI_OPREGION_ACCESS_AS_RAW            0x1
#define ACPI_OPREGION_ACCESS_AS_COOKED         0x2
#define ACPI_OPREGION_REGION_SPACE_MEMORY      0x0
#define ACPI_OPREGION_REGION_SPACE_IO          0x1
#define ACPI_OPREGION_REGION_SPACE_PCI_CONFIG  0x2
#define ACPI_OPREGION_REGION_SPACE_EC          0x3
#define ACPI_OPREGION_REGION_SPACE_SMB         0x4
#define ACPI_OPREGION_READ                     0x0
#define ACPI_OPREGION_WRITE                    0x1
#define ACPI_OPREGION_ACCESS_AT_HIGH_LEVEL     0x1

