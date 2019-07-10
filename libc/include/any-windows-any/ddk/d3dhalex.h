
#ifndef _D3DHALEX_H
#define _D3DHALEX_H

#define D3DGDI_IS_GDI2(pData)               ((((DD_GETDRIVERINFO2DATA*)(pData->lpvData))->dwMagic)  == D3DGDI2_MAGIC)
#define D3DGDI_IS_STEREOMODE(pData)         ((((DD_STEREOMODE*)        (pData->lpvData))->dwHeight) != D3DGDI2_MAGIC)
#define D3DGDI_GET_GDI2_DATA(pData)         (D3DGDI_IS_GDI2(pData) ? (((DD_GETDRIVERINFO2DATA*)(pData->lpvData))) : NULL)
#define D3DGDI_GET_STEREOMODE_DATA(pData)   (D3DGDI_IS_STEREOMODE(pData) ? (((DD_STEREOMODE*)(pData->lpvData)))   : NULL)

#endif /* _D3DHALEX_H */
