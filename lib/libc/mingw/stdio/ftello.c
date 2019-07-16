#include <stdio.h>

_off_t ftello(FILE * stream){
  return (_off_t) ftello64(stream);
}
