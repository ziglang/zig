Enable "small longs", an additional implementation of the Python
type "long", implemented with a C long long.  It is mostly useful
on 32-bit; on 64-bit, a C long long is the same as a C long, so
its usefulness is limited to Python objects of type "long" that
would anyway fit in an "int".
