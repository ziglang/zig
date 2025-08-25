/*
 This Software is provided under the Zope Public License (ZPL) Version 2.1.

 Copyright (c) 2009, 2010, 2013 by the mingw-w64 project

 See the AUTHORS file for the list of contributors to the mingw-w64 project.

 This license has been certified as open source. It has also been designated
 as GPL compatible by the Free Software Foundation (FSF).

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

   1. Redistributions in source code must retain the accompanying copyright
      notice, this list of conditions, and the following disclaimer.
   2. Redistributions in binary form must reproduce the accompanying
      copyright notice, this list of conditions, and the following disclaimer
      in the documentation and/or other materials provided with the
      distribution.
   3. Names of the copyright holders must not be used to endorse or promote
      products derived from this software without prior written permission
      from the copyright holders.
   4. The right to distribute this software or to use it for any purpose does
      not give you the right to use Servicemarks (sm) or Trademarks (tm) of
      the copyright holders.  Use of them is covered by separate agreement
      with the copyright holders.
   5. If any files are modified, you must cause the modified files to carry
      prominent notices stating that you changed the files and the date of
      any change.

 Disclaimer

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY EXPRESSED
 OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifndef __WUSB_H__
#define __WUSB_H__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

#include <windows.h>
#include <winusbio.h>   /* for PWINUSB_PIPE_INFORMATION  */
#include <usb100.h>     /* for PUSB_INTERFACE_DESCRIPTOR */

  typedef PVOID WINUSB_INTERFACE_HANDLE,*PWINUSB_INTERFACE_HANDLE;
  typedef PVOID WINUSB_ISOCH_BUFFER_HANDLE,*PWINUSB_ISOCH_BUFFER_HANDLE;

#include "pshpack1.h"
  typedef struct _WINUSB_SETUP_PACKET {
    UCHAR RequestType;
    UCHAR Request;
    USHORT Value;
    USHORT Index;
    USHORT Length;
  } WINUSB_SETUP_PACKET,*PWINUSB_SETUP_PACKET;
#include "poppack.h"

  WINBOOL WINAPI WinUsb_AbortPipe (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR PipeID);
  WINBOOL WINAPI WinUsb_ControlTransfer (WINUSB_INTERFACE_HANDLE InterfaceHandle, WINUSB_SETUP_PACKET SetupPacket, PUCHAR Buffer, ULONG BufferLength, PULONG LengthTransferred, LPOVERLAPPED Overlapped);
  WINBOOL WINAPI WinUsb_FlushPipe (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR PipeID);
  WINBOOL WINAPI WinUsb_Free (WINUSB_INTERFACE_HANDLE InterfaceHandle);
  WINBOOL WINAPI WinUsb_GetAdjustedFrameNumber (PULONG CurrentFrameNumber, LARGE_INTEGER TimeStamp);
  WINBOOL WINAPI WinUsb_GetAssociatedInterface (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR AssociatedInterfaceIndex, PWINUSB_INTERFACE_HANDLE AssociatedInterfaceHandle);
  WINBOOL WINAPI WinUsb_GetCurrentAlternateSetting (WINUSB_INTERFACE_HANDLE InterfaceHandle, PUCHAR SettingNumber);
  WINBOOL WINAPI WinUsb_GetCurrentFrameNumber (WINUSB_INTERFACE_HANDLE InterfaceHandle, PULONG CurrentFrameNumber, LARGE_INTEGER* TimeStamp);
  WINBOOL WINAPI WinUsb_GetDescriptor (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR DescriptorType, UCHAR Index, USHORT LanguageID, PUCHAR Buffer, ULONG BufferLength, PULONG LengthTransferred);
  WINBOOL WINAPI WinUsb_GetOverlappedResult (WINUSB_INTERFACE_HANDLE InterfaceHandle, LPOVERLAPPED lpOverlapped, LPDWORD lpNumberOfBytesTransferred, WINBOOL bWait);
  WINBOOL WINAPI WinUsb_GetPipePolicy (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR PipeID, ULONG PolicyType, PULONG ValueLength, PVOID Value);
  WINBOOL WINAPI WinUsb_GetPowerPolicy (WINUSB_INTERFACE_HANDLE InterfaceHandle, ULONG PolicyType, PULONG ValueLength, PVOID Value);
  WINBOOL WINAPI WinUsb_Initialize (HANDLE DeviceHandle, PWINUSB_INTERFACE_HANDLE InterfaceHandle);
  PUSB_INTERFACE_DESCRIPTOR WINAPI WinUsb_ParseConfigurationDescriptor (PUSB_CONFIGURATION_DESCRIPTOR ConfigurationDescriptor, PVOID StartPosition, LONG InterfaceNumber, LONG AlternateSetting, LONG InterfaceClass, LONG InterfaceSubClass, LONG InterfaceProtocol);
  PUSB_COMMON_DESCRIPTOR WINAPI WinUsb_ParseDescriptors (PVOID DescriptorBuffer, ULONG TotalLength, PVOID StartPosition, LONG DescriptorType);
  WINBOOL WINAPI WinUsb_ReadIsochPipe (WINUSB_ISOCH_BUFFER_HANDLE BufferHandle, ULONG Offset, ULONG Length, PULONG FrameNumber, ULONG NumberOfPackets, PUSBD_ISO_PACKET_DESCRIPTOR IsoPacketDescriptors, LPOVERLAPPED Overlapped);
  WINBOOL WINAPI WinUsb_ReadIsochPipeAsap (WINUSB_ISOCH_BUFFER_HANDLE BufferHandle, ULONG Offset, ULONG Length, BOOL ContinueStream, ULONG NumberOfPackets, PUSBD_ISO_PACKET_DESCRIPTOR IsoPacketDescriptors, LPOVERLAPPED Overlapped);
  WINBOOL WINAPI WinUsb_ReadPipe (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR PipeID, PUCHAR Buffer, ULONG BufferLength, PULONG LengthTransferred, LPOVERLAPPED Overlapped);
  WINBOOL WINAPI WinUsb_RegisterIsochBuffer(WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR PipeID, PUCHAR Buffer, ULONG BufferLength, PWINUSB_ISOCH_BUFFER_HANDLE IsochBufferHandle);
  WINBOOL WINAPI WinUsb_QueryDeviceInformation (WINUSB_INTERFACE_HANDLE InterfaceHandle, ULONG InformationType, PULONG BufferLength, PVOID Buffer);
  WINBOOL WINAPI WinUsb_QueryInterfaceSettings (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR AlternateInterfaceNumber, PUSB_INTERFACE_DESCRIPTOR UsbAltInterfaceDescriptor);
  WINBOOL WINAPI WinUsb_QueryPipe (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR AlternateInterfaceNumber, UCHAR PipeIndex, PWINUSB_PIPE_INFORMATION PipeInformation);
  WINBOOL WINAPI WinUsb_QueryPipeEx (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR AlternateInterfaceNumber, UCHAR PipeIndex, PWINUSB_PIPE_INFORMATION_EX PipeInformationEx);
  WINBOOL WINAPI WinUsb_ResetPipe (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR PipeID);
  WINBOOL WINAPI WinUsb_SetCurrentAlternateSetting (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR SettingNumber);
  WINBOOL WINAPI WinUsb_SetPipePolicy (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR PipeID, ULONG PolicyType, ULONG ValueLength, PVOID Value);
  WINBOOL WINAPI WinUsb_SetPowerPolicy (WINUSB_INTERFACE_HANDLE InterfaceHandle, ULONG PolicyType, ULONG ValueLength, PVOID Value);
  WINBOOL WINAPI WinUsb_UnregisterIsochBuffer(WINUSB_ISOCH_BUFFER_HANDLE IsochBufferHandle);
  WINBOOL WINAPI WinUsb_WriteIsochPipe (WINUSB_ISOCH_BUFFER_HANDLE BufferHandle, ULONG Offset, ULONG Length, PULONG FrameNumber, LPOVERLAPPED Overlapped);
  WINBOOL WINAPI WinUsb_WriteIsochPipeAsap (WINUSB_ISOCH_BUFFER_HANDLE BufferHandle, ULONG Offset, ULONG Length, BOOL ContinueStream, LPOVERLAPPED Overlapped);
  WINBOOL WINAPI WinUsb_WritePipe (WINUSB_INTERFACE_HANDLE InterfaceHandle, UCHAR PipeID, PUCHAR Buffer, ULONG BufferLength, PULONG LengthTransferred, LPOVERLAPPED Overlapped);

#ifdef __cplusplus
}
#endif

#endif

#endif
