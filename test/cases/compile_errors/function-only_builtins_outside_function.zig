comptime {
    @setAlignStack(1);
}

comptime {
    @setCold(true);
}

comptime {
    @src();
}

comptime {
    @returnAddress();
}

comptime {
    @frameAddress();
}

comptime {
    @breakpoint();
}

comptime {
    @cVaArg(1, 2);
}

comptime {
    @cVaCopy(1);
}

comptime {
    @cVaEnd(1);
}

comptime {
    @cVaStart();
}

comptime {
    @workItemId(42);
}

comptime {
    @workGroupSize(42);
}

comptime {
    @workGroupId(42);
}

// error
// backend=stage2
// target=native
//
// :2:5: error: '@setAlignStack' outside function scope
// :6:5: error: '@setCold' outside function scope
// :10:5: error: '@src' outside function scope
// :14:5: error: '@returnAddress' outside function scope
// :18:5: error: '@frameAddress' outside function scope
// :22:5: error: '@breakpoint' outside function scope
// :26:5: error: '@cVaArg' outside function scope
// :30:5: error: '@cVaCopy' outside function scope
// :34:5: error: '@cVaEnd' outside function scope
// :38:5: error: '@cVaStart' outside function scope
// :42:5: error: '@workItemId' outside function scope
// :46:5: error: '@workGroupSize' outside function scope
// :50:5: error: '@workGroupId' outside function scope
