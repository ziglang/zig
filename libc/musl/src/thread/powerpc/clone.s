.text
.global __clone
.hidden __clone
.type __clone, %function
__clone:
# int clone(fn, stack, flags, arg, ptid, tls, ctid)
#            a  b       c     d     e    f    g
#            3  4       5     6     7    8    9
# pseudo C code:
# tid = syscall(SYS_clone,c,b,e,f,g);
# if (!tid) syscall(SYS_exit, a(d));
# return tid;

# SYS_clone = 120
# SYS_exit = 1

# store non-volatile regs r30, r31 on stack in order to put our
# start func and its arg there
stwu 30, -16(1)
stw 31, 4(1)

# save r3 (func) into r30, and r6(arg) into r31
mr 30, 3
mr 31, 6

# create initial stack frame for new thread
clrrwi 4, 4, 4
li 0, 0
stwu 0, -16(4)

#move c into first arg
mr 3, 5
#mr 4, 4
mr 5, 7
mr 6, 8
mr 7, 9

# move syscall number into r0    
li 0, 120

sc

# check for syscall error
bns+ 1f # jump to label 1 if no summary overflow.
#else
neg 3, 3 #negate the result (errno)
1:
# compare sc result with 0
cmpwi cr7, 3, 0

# if not 0, jump to end
bne cr7, 2f

#else: we're the child
#call funcptr: move arg (d) into r3
mr 3, 31
#move r30 (funcptr) into CTR reg
mtctr 30
# call CTR reg
bctrl
# mov SYS_exit into r0 (the exit param is already in r3)
li 0, 1
sc

2:

# restore stack
lwz 30, 0(1)
lwz 31, 4(1)
addi 1, 1, 16

blr

