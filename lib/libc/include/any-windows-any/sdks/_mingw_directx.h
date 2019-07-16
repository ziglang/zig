#if 1

#define __MINGW_HAS_DXSDK 1

#ifndef MINGW_HAS_DDRAW_H
#define MINGW_HAS_DDRAW_H 1
#define MINGW_DDRAW_VERSION	7
#endif

#else

#undef __MINGW_HAS_DXSDK
#undef MINGW_HAS_DDRAW_H
#undef MINGW_DDRAW_VERSION

#endif
