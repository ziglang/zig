main:
LOAD 0 => r1
LOAD 1 => r2
@add
ADD r2 r1 => r1
JUMP_IF_ABOVE r0 r1 @add
RETURN r1
