/*
 * ntddtdi.h
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef _NTDDTDI_
#define _NTDDTDI_

#ifdef __cplusplus
extern "C" {
#endif

#define DD_TDI_DEVICE_NAME "\\Device\\UNKNOWN"
#define _TDI_CONTROL_CODE(request,method)   CTL_CODE(FILE_DEVICE_TRANSPORT, request, method, FILE_ANY_ACCESS)
#define IOCTL_TDI_ACCEPT                    _TDI_CONTROL_CODE( 0, METHOD_BUFFERED )
#define IOCTL_TDI_CONNECT                   _TDI_CONTROL_CODE( 1, METHOD_BUFFERED )
#define IOCTL_TDI_DISCONNECT                _TDI_CONTROL_CODE( 2, METHOD_BUFFERED )
#define IOCTL_TDI_LISTEN                    _TDI_CONTROL_CODE( 3, METHOD_BUFFERED )
#define IOCTL_TDI_QUERY_INFORMATION         _TDI_CONTROL_CODE( 4, METHOD_OUT_DIRECT )
#define IOCTL_TDI_RECEIVE                   _TDI_CONTROL_CODE( 5, METHOD_OUT_DIRECT )
#define IOCTL_TDI_RECEIVE_DATAGRAM          _TDI_CONTROL_CODE( 6, METHOD_OUT_DIRECT )
#define IOCTL_TDI_SEND                      _TDI_CONTROL_CODE( 7, METHOD_IN_DIRECT )
#define IOCTL_TDI_SEND_DATAGRAM             _TDI_CONTROL_CODE( 8, METHOD_IN_DIRECT )
#define IOCTL_TDI_SET_EVENT_HANDLER         _TDI_CONTROL_CODE( 9, METHOD_BUFFERED )
#define IOCTL_TDI_SET_INFORMATION           _TDI_CONTROL_CODE( 10, METHOD_IN_DIRECT )
#define IOCTL_TDI_ASSOCIATE_ADDRESS         _TDI_CONTROL_CODE( 11, METHOD_BUFFERED )
#define IOCTL_TDI_DISASSOCIATE_ADDRESS      _TDI_CONTROL_CODE( 12, METHOD_BUFFERED )
#define IOCTL_TDI_ACTION                    _TDI_CONTROL_CODE( 13, METHOD_OUT_DIRECT )

#ifdef __cplusplus
}
#endif

#endif /* _NTDDTDI_ */

