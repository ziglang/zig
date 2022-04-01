Represent function sets smaller than this option's value as an integer instead
of a function pointer. A call is then done via a switch on that integer, which
allows inlining etc. Small numbers for this can speed up PyPy (try 5).
