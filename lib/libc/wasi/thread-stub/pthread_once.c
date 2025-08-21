#include "pthread_impl.h"

int __pthread_once(pthread_once_t *control, void (*init)(void))
{
       if (!*control) {
               init();
               *control = 1;
       }
       return 0;
}

weak_alias(__pthread_once, pthread_once);
