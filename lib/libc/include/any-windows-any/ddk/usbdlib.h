#pragma once

#ifndef DECLSPEC_EXPORT
#define DECLSPEC_EXPORT __declspec(dllexport)
#endif

typedef struct _USBD_INTERFACE_LIST_ENTRY {
  PUSB_INTERFACE_DESCRIPTOR InterfaceDescriptor;
  PUSBD_INTERFACE_INFORMATION Interface;
} USBD_INTERFACE_LIST_ENTRY, *PUSBD_INTERFACE_LIST_ENTRY;

#define UsbBuildInterruptOrBulkTransferRequest(urb,length, pipeHandle, transferBuffer, transferBufferMDL, transferBufferLength, transferFlags, link) \
{												\
	(urb)->UrbHeader.Function = URB_FUNCTION_BULK_OR_INTERRUPT_TRANSFER;			\
	(urb)->UrbHeader.Length = (length);							\
	(urb)->UrbBulkOrInterruptTransfer.PipeHandle = (pipeHandle);				\
	(urb)->UrbBulkOrInterruptTransfer.TransferBufferLength = (transferBufferLength);	\
	(urb)->UrbBulkOrInterruptTransfer.TransferBufferMDL = (transferBufferMDL);		\
	(urb)->UrbBulkOrInterruptTransfer.TransferBuffer = (transferBuffer);			\
	(urb)->UrbBulkOrInterruptTransfer.TransferFlags = (transferFlags);			\
	(urb)->UrbBulkOrInterruptTransfer.UrbLink = (link);					\
}

#define UsbBuildGetDescriptorRequest(urb, length, descriptorType, descriptorIndex, languageId, transferBuffer, transferBufferMDL, transferBufferLength, link) \
{												\
	(urb)->UrbHeader.Function =  URB_FUNCTION_GET_DESCRIPTOR_FROM_DEVICE;			\
	(urb)->UrbHeader.Length = (length);							\
	(urb)->UrbControlDescriptorRequest.TransferBufferLength = (transferBufferLength);	\
	(urb)->UrbControlDescriptorRequest.TransferBufferMDL = (transferBufferMDL);		\
	(urb)->UrbControlDescriptorRequest.TransferBuffer = (transferBuffer);			\
	(urb)->UrbControlDescriptorRequest.DescriptorType = (descriptorType);			\
	(urb)->UrbControlDescriptorRequest.Index = (descriptorIndex);				\
	(urb)->UrbControlDescriptorRequest.LanguageId = (languageId);				\
	(urb)->UrbControlDescriptorRequest.UrbLink = (link);					\
}

#define UsbBuildGetStatusRequest(urb, op, index, transferBuffer, transferBufferMDL, link)	\
{												\
	(urb)->UrbHeader.Function =  (op);							\
	(urb)->UrbHeader.Length = sizeof(struct _URB_CONTROL_GET_STATUS_REQUEST);		\
	(urb)->UrbControlGetStatusRequest.TransferBufferLength = sizeof(USHORT);		\
	(urb)->UrbControlGetStatusRequest.TransferBufferMDL = (transferBufferMDL);		\
	(urb)->UrbControlGetStatusRequest.TransferBuffer = (transferBuffer);			\
	(urb)->UrbControlGetStatusRequest.Index = (index);					\
	(urb)->UrbControlGetStatusRequest.UrbLink = (link);					\
}

#define UsbBuildFeatureRequest(urb, op, featureSelector, index, link)				\
{												\
	(urb)->UrbHeader.Function =  (op);							\
	(urb)->UrbHeader.Length = sizeof(struct _URB_CONTROL_FEATURE_REQUEST);			\
	(urb)->UrbControlFeatureRequest.FeatureSelector = (featureSelector);			\
	(urb)->UrbControlFeatureRequest.Index = (index);					\
	(urb)->UrbControlFeatureRequest.UrbLink = (link);					\
}

#define UsbBuildSelectConfigurationRequest(urb, length, configurationDescriptor)		\
{												\
	(urb)->UrbHeader.Function =  URB_FUNCTION_SELECT_CONFIGURATION;				\
	(urb)->UrbHeader.Length = (length);							\
	(urb)->UrbSelectConfiguration.ConfigurationDescriptor = (configurationDescriptor);	\
}

#define UsbBuildSelectInterfaceRequest(urb, length, configurationHandle, interfaceNumber, alternateSetting) \
{												\
	(urb)->UrbHeader.Function =  URB_FUNCTION_SELECT_INTERFACE;				\
	(urb)->UrbHeader.Length = (length);							\
	(urb)->UrbSelectInterface.Interface.AlternateSetting = (alternateSetting);		\
	(urb)->UrbSelectInterface.Interface.InterfaceNumber = (interfaceNumber);		\
	(urb)->UrbSelectInterface.Interface.Length =						\
		(length - sizeof(struct _URB_HEADER) - sizeof(USBD_CONFIGURATION_HANDLE));	\
	(urb)->UrbSelectInterface.ConfigurationHandle = (configurationHandle);			\
}

#define UsbBuildVendorRequest(urb, cmd, length, transferFlags, reservedbits, request, value, index, transferBuffer, transferBufferMDL, transferBufferLength, link) \
{												\
	(urb)->UrbHeader.Function =  cmd;							\
	(urb)->UrbHeader.Length = (length);							\
	(urb)->UrbControlVendorClassRequest.TransferBufferLength = (transferBufferLength);	\
	(urb)->UrbControlVendorClassRequest.TransferBufferMDL = (transferBufferMDL);		\
	(urb)->UrbControlVendorClassRequest.TransferBuffer = (transferBuffer);			\
	(urb)->UrbControlVendorClassRequest.RequestTypeReservedBits = (reservedbits);		\
	(urb)->UrbControlVendorClassRequest.Request = (request);				\
	(urb)->UrbControlVendorClassRequest.Value = (value);					\
	(urb)->UrbControlVendorClassRequest.Index = (index);					\
	(urb)->UrbControlVendorClassRequest.TransferFlags = (transferFlags);			\
	(urb)->UrbControlVendorClassRequest.UrbLink = (link);					\
}

#if (NTDDI_VERSION >= NTDDI_WINXP)

#define UsbBuildOsFeatureDescriptorRequest(urb, length, interface, index, transferBuffer, transferBufferMDL, transferBufferLength, link)  \
{												\
	(urb)->UrbHeader.Function = URB_FUNCTION_GET_MS_FEATURE_DESCRIPTOR;			\
	(urb)->UrbHeader.Length = (length);							\
	(urb)->UrbOSFeatureDescriptorRequest.TransferBufferLength = (transferBufferLength);	\
	(urb)->UrbOSFeatureDescriptorRequest.TransferBufferMDL = (transferBufferMDL);		\
	(urb)->UrbOSFeatureDescriptorRequest.TransferBuffer = (transferBuffer);			\
	(urb)->UrbOSFeatureDescriptorRequest.InterfaceNumber = (interface);			\
	(urb)->UrbOSFeatureDescriptorRequest.MS_FeatureDescriptorIndex = (index);		\
	(urb)->UrbOSFeatureDescriptorRequest.UrbLink = (link);					\
}

#endif	/* NTDDI_VERSION >= NTDDI_WINXP */

#define URB_STATUS(urb)					((urb)->UrbHeader.Status)

#define GET_SELECT_CONFIGURATION_REQUEST_SIZE(totalInterfaces, totalPipes)			\
	(sizeof(struct _URB_SELECT_CONFIGURATION) +						\
	  ((totalInterfaces-1) * sizeof(USBD_INTERFACE_INFORMATION)) +				\
	  ((totalPipes-totalInterfaces)*sizeof(USBD_PIPE_INFORMATION)))

#define GET_SELECT_INTERFACE_REQUEST_SIZE(totalPipes)						\
	(sizeof(struct _URB_SELECT_INTERFACE) +							\
	  ((totalPipes-1)*sizeof(USBD_PIPE_INFORMATION)))

#define GET_USBD_INTERFACE_SIZE(numEndpoints) (sizeof(USBD_INTERFACE_INFORMATION) +		\
	(sizeof(USBD_PIPE_INFORMATION)*(numEndpoints))						\
	  - sizeof(USBD_PIPE_INFORMATION))

#define  GET_ISO_URB_SIZE(n) (sizeof(struct _URB_ISOCH_TRANSFER)+				\
			      sizeof(USBD_ISO_PACKET_DESCRIPTOR)*n)

#ifndef _USBD_

DECLSPEC_IMPORT
VOID
NTAPI
USBD_GetUSBDIVersion(
  OUT PUSBD_VERSION_INFORMATION VersionInformation);

DECLSPEC_IMPORT
PUSB_INTERFACE_DESCRIPTOR
NTAPI
USBD_ParseConfigurationDescriptor(
  IN PUSB_CONFIGURATION_DESCRIPTOR ConfigurationDescriptor,
  IN UCHAR InterfaceNumber,
  IN UCHAR AlternateSetting);

DECLSPEC_IMPORT
PURB
NTAPI
USBD_CreateConfigurationRequest(
  IN  PUSB_CONFIGURATION_DESCRIPTOR ConfigurationDescriptor,
  OUT PUSHORT Siz);

DECLSPEC_IMPORT
PUSB_COMMON_DESCRIPTOR
NTAPI
USBD_ParseDescriptors(
  IN PVOID DescriptorBuffer,
  IN ULONG TotalLength,
  IN PVOID StartPosition,
  IN LONG DescriptorType);

DECLSPEC_IMPORT
PUSB_INTERFACE_DESCRIPTOR
NTAPI
USBD_ParseConfigurationDescriptorEx(
  IN PUSB_CONFIGURATION_DESCRIPTOR ConfigurationDescriptor,
  IN PVOID StartPosition,
  IN LONG InterfaceNumber,
  IN LONG AlternateSetting,
  IN LONG InterfaceClass,
  IN LONG InterfaceSubClass,
  IN LONG InterfaceProtocol);

DECLSPEC_IMPORT
PURB
NTAPI
USBD_CreateConfigurationRequestEx(
  IN PUSB_CONFIGURATION_DESCRIPTOR ConfigurationDescriptor,
  IN PUSBD_INTERFACE_LIST_ENTRY InterfaceList);

DECLSPEC_EXPORT
ULONG
NTAPI
USBD_GetInterfaceLength(
  IN PUSB_INTERFACE_DESCRIPTOR InterfaceDescriptor,
  IN PUCHAR BufferEnd);

DECLSPEC_EXPORT
VOID
NTAPI
USBD_RegisterHcFilter(
  IN PDEVICE_OBJECT DeviceObject,
  IN PDEVICE_OBJECT FilterDeviceObject);

DECLSPEC_EXPORT
NTSTATUS
NTAPI
USBD_GetPdoRegistryParameter(
  IN PDEVICE_OBJECT PhysicalDeviceObject,
  IN OUT PVOID Parameter,
  IN ULONG ParameterLength,
  IN PWSTR KeyName,
  IN ULONG KeyNameLength);

DECLSPEC_EXPORT
NTSTATUS
NTAPI
USBD_QueryBusTime(
  IN PDEVICE_OBJECT RootHubPdo,
  OUT PULONG CurrentFrame);

#if (NTDDI_VERSION >= NTDDI_WINXP)

DECLSPEC_IMPORT
ULONG
NTAPI
USBD_CalculateUsbBandwidth(
  IN ULONG MaxPacketSize,
  IN UCHAR EndpointType,
  IN BOOLEAN LowSpeed);

#endif

#if (NTDDI_VERSION >= NTDDI_VISTA)

DECLSPEC_IMPORT
USBD_STATUS
NTAPI
USBD_ValidateConfigurationDescriptor(
  IN PUSB_CONFIGURATION_DESCRIPTOR ConfigDesc,
  IN ULONG BufferLength,
  IN USHORT Level,
  OUT PUCHAR *Offset,
  IN ULONG Tag OPTIONAL);

#endif

#endif /* ! _USBD_ */

