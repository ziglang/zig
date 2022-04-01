#include "bridge.h"

#ifdef RPYTHON_LL2CTYPES

_HPyBridge *hpy_get_bridge(void) {
    static _HPyBridge bridge;
    return &bridge;
}

#endif
