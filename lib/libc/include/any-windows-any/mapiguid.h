/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef MAPIGUID_H
#ifdef INITGUID
#define MAPIGUID_H
#endif

#if !defined(INITGUID) || defined(USES_IID_IMAPISession)
DEFINE_OLEGUID(IID_IMAPISession,0x00020300,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPITable)
DEFINE_OLEGUID(IID_IMAPITable,0x00020301,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIAdviseSink)
DEFINE_OLEGUID(IID_IMAPIAdviseSink,0x00020302,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIControl)
DEFINE_OLEGUID(IID_IMAPIControl,0x0002031B,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IProfAdmin)
DEFINE_OLEGUID(IID_IProfAdmin,0x0002031C,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMsgServiceAdmin)
DEFINE_OLEGUID(IID_IMsgServiceAdmin,0x0002031D,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IProviderAdmin)
DEFINE_OLEGUID(IID_IProviderAdmin,0x00020325,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIProgress)
DEFINE_OLEGUID(IID_IMAPIProgress,0x0002031F,0,0);
#endif

#if !defined(INITGUID) || defined(USES_IID_IMAPIProp)
DEFINE_OLEGUID(IID_IMAPIProp,0x00020303,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IProfSect)
DEFINE_OLEGUID(IID_IProfSect,0x00020304,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIStatus)
DEFINE_OLEGUID(IID_IMAPIStatus,0x00020305,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMsgStore)
DEFINE_OLEGUID(IID_IMsgStore,0x00020306,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMessage)
DEFINE_OLEGUID(IID_IMessage,0x00020307,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IAttachment)
DEFINE_OLEGUID(IID_IAttachment,0x00020308,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IAddrBook)
DEFINE_OLEGUID(IID_IAddrBook,0x00020309,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMailUser)
DEFINE_OLEGUID(IID_IMailUser,0x0002030A,0,0);
#endif

#if !defined(INITGUID) || defined(USES_IID_IMAPIContainer)
DEFINE_OLEGUID(IID_IMAPIContainer,0x0002030B,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIFolder)
DEFINE_OLEGUID(IID_IMAPIFolder,0x0002030C,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IABContainer)
DEFINE_OLEGUID(IID_IABContainer,0x0002030D,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IDistList)
DEFINE_OLEGUID(IID_IDistList,0x0002030E,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPISup)
DEFINE_OLEGUID(IID_IMAPISup,0x0002030F,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMSProvider)
DEFINE_OLEGUID(IID_IMSProvider,0x00020310,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IABProvider)
DEFINE_OLEGUID(IID_IABProvider,0x00020311,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IXPProvider)
DEFINE_OLEGUID(IID_IXPProvider,0x00020312,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMSLogon)
DEFINE_OLEGUID(IID_IMSLogon,0x00020313,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IABLogon)
DEFINE_OLEGUID(IID_IABLogon,0x00020314,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IXPLogon)
DEFINE_OLEGUID(IID_IXPLogon,0x00020315,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPITableData)
DEFINE_OLEGUID(IID_IMAPITableData,0x00020316,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPISpoolerInit)
DEFINE_OLEGUID(IID_IMAPISpoolerInit,0x00020317,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPISpoolerSession)
DEFINE_OLEGUID(IID_IMAPISpoolerSession,0x00020318,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_ITNEF)
DEFINE_OLEGUID(IID_ITNEF,0x00020319,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIPropData)
DEFINE_OLEGUID(IID_IMAPIPropData,0x0002031A,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_ISpoolerHook)
DEFINE_OLEGUID(IID_ISpoolerHook,0x00020320,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPISpoolerService)
DEFINE_OLEGUID(IID_IMAPISpoolerService,0x0002031E,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIViewContext)
DEFINE_OLEGUID(IID_IMAPIViewContext,0x00020321,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIFormMgr)
DEFINE_OLEGUID(IID_IMAPIFormMgr,0x00020322,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IEnumMAPIFormProp)
DEFINE_OLEGUID(IID_IEnumMAPIFormProp,0x00020323,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIFormInfo)
DEFINE_OLEGUID(IID_IMAPIFormInfo,0x00020324,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIForm)
DEFINE_OLEGUID(IID_IMAPIForm,0x00020327,0,0);
#endif
#if !defined(INITGUID) || defined(USES_PS_MAPI)
DEFINE_OLEGUID(PS_MAPI,0x00020328,0,0);
#endif
#if !defined(INITGUID) || defined(USES_PS_PUBLIC_STRINGS)
DEFINE_OLEGUID(PS_PUBLIC_STRINGS,0x00020329,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IPersistMessage)
DEFINE_OLEGUID(IID_IPersistMessage,0x0002032A,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIViewAdviseSink)
DEFINE_OLEGUID(IID_IMAPIViewAdviseSink,0x0002032B,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IStreamDocfile)
DEFINE_OLEGUID(IID_IStreamDocfile,0x0002032C,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIFormProp)
DEFINE_OLEGUID(IID_IMAPIFormProp,0x0002032D,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIFormContainer)
DEFINE_OLEGUID(IID_IMAPIFormContainer,0x0002032E,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIFormAdviseSink)
DEFINE_OLEGUID(IID_IMAPIFormAdviseSink,0x0002032F,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IStreamTnef)
DEFINE_OLEGUID(IID_IStreamTnef,0x00020330,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIFormFactory)
DEFINE_OLEGUID(IID_IMAPIFormFactory,0x00020350,0,0);
#endif
#if !defined(INITGUID) || defined(USES_IID_IMAPIMessageSite)
DEFINE_OLEGUID(IID_IMAPIMessageSite,0x00020370,0,0);
#endif
#if !defined(INITGUID) || defined(USES_PS_ROUTING_EMAIL_ADDRESSES)
DEFINE_OLEGUID(PS_ROUTING_EMAIL_ADDRESSES,0x00020380,0,0);
#endif
#if !defined(INITGUID) || defined(USES_PS_ROUTING_ADDRTYPE)
DEFINE_OLEGUID(PS_ROUTING_ADDRTYPE,0x00020381,0,0);
#endif
#if !defined(INITGUID) || defined(USES_PS_ROUTING_DISPLAY_NAME)
DEFINE_OLEGUID(PS_ROUTING_DISPLAY_NAME,0x00020382,0,0);
#endif
#if !defined(INITGUID) || defined(USES_PS_ROUTING_ENTRYID)
DEFINE_OLEGUID(PS_ROUTING_ENTRYID,0x00020383,0,0);
#endif
#if !defined(INITGUID) || defined(USES_PS_ROUTING_SEARCH_KEY)
DEFINE_OLEGUID(PS_ROUTING_SEARCH_KEY,0x00020384,0,0);
#endif

#if !defined(INITGUID) || defined(USES_MUID_PROFILE_INSTANCE)
DEFINE_OLEGUID(MUID_PROFILE_INSTANCE,0x00020385,0,0);
#endif
#endif
