#if   defined(__MINGW32__)
#include "switch_x86_gcc.h" /* gcc on X86 */
#elif defined(_M_IX86)
#include "switch_x86_msvc.h" /* MS Visual Studio on X86 */
#elif defined(_M_X64)
#include "switch_x64_msvc.h" /* MS Visual Studio on X64 */
#elif defined(__GNUC__) && defined(__amd64__)
#include "switch_x86_64_gcc.h" /* gcc on amd64 */
#elif defined(__GNUC__) && defined(__i386__)
#include "switch_x86_gcc.h" /* gcc on X86 */
#elif defined(__GNUC__) && defined(__arm__)
#include "switch_arm_gcc.h" /* gcc on arm */
#elif defined(__GNUC__) && defined(__aarch64__)
#include "switch_aarch64_gcc.h" /* gcc on aarch64 */
#elif defined(__GNUC__) && defined(__PPC64__)
#include "switch_ppc64_gcc.h" /* gcc on ppc64 */
#elif defined(__GNUC__) && defined(__mips__) && defined(_ABI64)
#include "switch_mips64_gcc.h" /* gcc on mips64 */
#elif defined(__GNUC__) && defined(__s390x__)
#include "switch_s390x_gcc.h"
#else
#error "Unsupported platform!"
#endif
