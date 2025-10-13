const namespace = struct {
    const S = struct {};
    const E = enum {};
    const U = union {};
    const O = opaque {};
};
export fn declarationValue() void {
    @compileLog(@typeName(namespace.S));
    @compileLog(@typeName(namespace.E));
    @compileLog(@typeName(namespace.U));
    @compileLog(@typeName(namespace.O));
}

export fn localVarValue() void {
    const S = struct {};
    const E = enum {};
    const U = union {};
    const O = opaque {};
    @compileLog(@typeName(S));
    @compileLog(@typeName(E));
    @compileLog(@typeName(U));
    @compileLog(@typeName(O));
}

fn MakeS() type {
    return struct {};
}
fn MakeE() type {
    return enum {};
}
fn MakeU() type {
    return union {};
}
fn MakeO() type {
    return opaque {};
}

export fn returnValue() void {
    @compileLog(@typeName(MakeS()));
    @compileLog(@typeName(MakeE()));
    @compileLog(@typeName(MakeU()));
    @compileLog(@typeName(MakeO()));
}

const StructInStruct = struct { a: struct { b: u8 } };
const UnionInStruct = struct { a: union { b: u8 } };
const StructInUnion = union { a: struct { b: u8 } };
const UnionInUnion = union { a: union { b: u8 } };
const InnerStruct = struct { b: u8 };
const StructInTuple = struct { a: InnerStruct };
const InnerUnion = union { b: u8 };
const UnionInTuple = struct { a: InnerUnion };

export fn nestedTypes() void {
    @compileLog(@typeName(StructInStruct));
    @compileLog(@typeName(UnionInStruct));
    @compileLog(@typeName(StructInUnion));
    @compileLog(@typeName(UnionInUnion));
    @compileLog(@typeName(StructInTuple));
    @compileLog(@typeName(UnionInTuple));
}

// error
//
// :8:5: error: found compile log statement
// :19:5: note: also here
// :39:5: note: also here
// :55:5: note: also here
//
//Compile Log Output:
//@as(*const [15:0]u8, "tmp.namespace.S")
//@as(*const [15:0]u8, "tmp.namespace.E")
//@as(*const [15:0]u8, "tmp.namespace.U")
//@as(*const [15:0]u8, "tmp.namespace.O")
//@as(*const [19:0]u8, "tmp.localVarValue.S")
//@as(*const [19:0]u8, "tmp.localVarValue.E")
//@as(*const [19:0]u8, "tmp.localVarValue.U")
//@as(*const [19:0]u8, "tmp.localVarValue.O")
//@as(*const [11:0]u8, "tmp.MakeS()")
//@as(*const [11:0]u8, "tmp.MakeE()")
//@as(*const [11:0]u8, "tmp.MakeU()")
//@as(*const [11:0]u8, "tmp.MakeO()")
//@as(*const [18:0]u8, "tmp.StructInStruct")
//@as(*const [17:0]u8, "tmp.UnionInStruct")
//@as(*const [17:0]u8, "tmp.StructInUnion")
//@as(*const [16:0]u8, "tmp.UnionInUnion")
//@as(*const [17:0]u8, "tmp.StructInTuple")
//@as(*const [16:0]u8, "tmp.UnionInTuple")
