from rpython.jit.backend.zarch import locations as loc

RND_CURMODE = loc.imm(0x0)
RND_BIASED_NEAREST = loc.imm(0x1)
RND_NEARST = loc.imm(0x4)
RND_TOZERO = loc.imm(0x5)
RND_TO_POSINF = loc.imm(0x6)
RND_TO_NEGINF= loc.imm(0x7)
