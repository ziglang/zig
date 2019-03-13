#include <features.h>

/* These functions will not work, but suffice for targets where the
 * kernel sigaction structure does not actually use sa_restorer. */

hidden void __restore()
{
}

hidden void __restore_rt()
{
}
