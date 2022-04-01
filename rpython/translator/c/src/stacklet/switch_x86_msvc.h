/* The actual stack saving function, which just stores the stack,
 * this declared in an .asm file
 */
extern void *slp_switch_raw(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra);

#undef STATIC_NOINLINE
#define STATIC_NOINLINE   static __declspec(noinline)

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

/* Store any other runtime information on the local stack */
#pragma optimize("", off) /* so that autos are stored on the stack */
#pragma warning(disable:4733) /* disable warning about modifying FS[0] */

static void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra)
{
    /* store the structured exception state for this stack */
    DWORD seh_state = __readfsdword(FIELD_OFFSET(NT_TIB, ExceptionList));
    void * result = slp_switch_raw(save_state, restore_state, extra);
    __writefsdword(FIELD_OFFSET(NT_TIB, ExceptionList), seh_state);
    return result;
}
#pragma warning(default:4733) /* disable warning about modifying FS[0] */
#pragma optimize("", on)
