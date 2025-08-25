/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_FUNCTIONDISCOVERYCATEGORIES
#define _INC_FUNCTIONDISCOVERYCATEGORIES

#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

#define FCTN_CATEGORY_DEVICES /*Not used??*/
#define FCTN_CATEGORY_NETBIOS L"Provider\\Microsoft.Networking.Netbios"
#define FCTN_CATEGORY_NETWORKDEVICES L"Layered\\Microsoft.Networking.Devices"
#define FCTN_CATEGORY_PNP L"Provider\\Microsoft.Base.PnP"
#define FCTN_CATEGORY_PNPXASSOCIATION L"Provider\\Microsoft.PnPX.Association"
#define FCTN_CATEGORY_PUBLICATION L"Provider\\Microsoft.Base.Publication"
#define FCTN_CATEGORY_REGISTRY L"Provider\\Microsoft.Base.Registry"
#define FCTN_CATEGORY_SSDP L"Provider\\Microsoft.Networking.SSDP"
#define FCTN_CATEGORY_WCN L"Provider\\Microsoft.Networking.WCN"
#define FCTN_CATEGORY_WSDISCOVERY L"Provider\\Microsoft.Networking.WSD"

/* Magic Subcatagory defintions - http://msdn.microsoft.com/en-us/library/aa364815%28v=VS.85%29.aspx */
#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_FUNCTIONDISCOVERYCONSTRAINTS*/
