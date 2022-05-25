'use strict';

/**
 * @typedef {
    | "Type"
    | "Void"
    | "Bool"
    | "NoReturn"
    | "Int"
    | "Float"
    | "Pointer"
    | "Array"
    | "Struct"
    | "ComptimeFloat"
    | "ComptimeInt"
    | "Undefined"
    | "Null"
    | "Optional"
    | "ErrorUnion"
    | "ErrorSet"
    | "Enum"
    | "Union"
    | "Fn"
    | "BoundFn"
    | "Opaque"
    | "Frame"
    | "AnyFrame"
    | "Vector"
    | "EnumLiteral"
    | "ComptimeExpr"
    | "Unanalyzed"
   } TypeKind
*/

/**
 * @typedef {{
     typeRef: Expr?,
     expr: Expr,
   }} WalkResult
*/

/**
 * @typedef {{
     void: {},
     unreachable: {},
     anytype: {},
     type: number,
     comptimeExpr: number,
     call: number,
     int: number,
     float: number,
     bool: boolean,
     undefined: WalkResult,
     null: WalkResult,
     typeOf: WalkResult,
     compileError: string
     string: string,
     struct: Expr[],
     refPath: Expr[],
     declRef: number,
     array: ZigArray,
     enumLiteral: string,
   }} Expr
*/

/**
 * @typedef {{
      kind: number,
      name: string,
      src: number,
      privDecls: number[],
      pubDecls: number[],
      fields: WalkResult[]
}} ContainerType
*/

/**
 * @typedef {{
      kind: number,
      name: string,
      src: number,
      ret: WalkResult,
      params: WalkResult[],
      generic: boolean,
 }} Fn
*/

/**
* @typedef {{
     kind: number,
     name: string,
     fields: { name: string, docs: string }[]
     fn: number | undefined,
}} ErrSetType
*/

/**
* @typedef {{
     kind: number,
     err: WalkResult,
     payload: WalkResult,
}} ErrUnionType
*/

// Type, Void, Bool, NoReturn, Int, Float, ComptimeExpr, ComptimeFloat, ComptimeInt, Undefined, Null, ErrorUnion, BoundFn, Opaque, Frame, AnyFrame, Vector, EnumLiteral
/**
* @typedef {{
     kind: number,
     name: string
}} NumberType
*/

/**
* @typedef {{
     kind: number,
     size: number,
     child: WalkResult
     align: number,
     bitOffsetInHost: number,
     hostIntBytes: number,
     volatile: boolean,
     const: boolean,
}} PointerType
*/

/**
* @typedef {{
     kind: number,
     len: WalkResult
     child: WalkResult
}} ArrayType
*/

/**
* @typedef {{
     kind: number,
     name: string,
     child: Expr,
}} OptionalType
*/

/**
 * @typedef {
    | OptionalType
    | ArrayType
    | PointerType
    | ContainerType
    | Fn
    | ErrSetType
    | ErrUnionType
    | NumberType
   } Type
*/


/**
 * @typedef {{
       func: Expr,
       args: Expr[],
       ret: Expr,
   }} Call
*/

/**
 * @typedef {{
       file: number,
       line: number,
       col: number,
       name?: string,
       docs?: string,
       fields?: number[],
       comptime: boolean,
       noalias: boolean,
       varArgs: boolean,
   }} AstNode
*/

/**
 * @typedef {{
      name: string,
      kind: string,
      src: number,
      value: WalkResult,
      decltest?: number,
      isTest: boolean,
   }} Decl
*/

/**
 * @typedef {{
      name: string,
      file: number,
      main: number,
      table: Record<string, number>,
   }} Package
*/

/**
 * @typedef {{
      typeRef: WalkResult,
      data: WalkResult[],
  }} ZigArray
*/

/**
 * @typedef {{
      code: string,
      typeRef: WalkResult,
   }} ComptimeExpr
*/

/**
 * @typedef {{
       typeKinds: TypeKind[];
       rootPkg: number;
       params: {
           zigId: string;
           zigVersion: string;
           target: string;
           rootName: string;
           builds: { target: string };
       };
       packages: Package[];
       errors: {};
       astNodes: AstNode[];
       calls: Call[];
       files: Record<string, string>;
       types: Type[];
       decls: Decl[];
       comptimeExprs: ComptimeExpr[];
       fns: Fn[];
   }} DocData
*/

/** @type {DocData} */
var zigAnalysis;

(function() {
    let domStatus = /** @type HTMLElement */(document.getElementById("status"));
    let domSectNav = /** @type HTMLElement */(document.getElementById("sectNav"));
    let domListNav = /** @type HTMLElement */(document.getElementById("listNav"));
    let domSectMainPkg = /** @type HTMLElement */(document.getElementById("sectMainPkg"));
    let domSectPkgs = /** @type HTMLElement */(document.getElementById("sectPkgs"));
    let domListPkgs = /** @type HTMLElement */(document.getElementById("listPkgs"));
    let domSectTypes = /** @type HTMLElement */(document.getElementById("sectTypes"));
    let domListTypes = /** @type HTMLElement */(document.getElementById("listTypes"));
    let domSectTests = /** @type HTMLElement */(document.getElementById("sectTests"));
    let domListTests = /** @type HTMLElement */(document.getElementById("listTests"));
    let domSectNamespaces = /** @type HTMLElement */(document.getElementById("sectNamespaces"));
    let domListNamespaces = /** @type HTMLElement */(document.getElementById("listNamespaces"));
    let domSectErrSets = /** @type HTMLElement */(document.getElementById("sectErrSets"));
    let domListErrSets = /** @type HTMLElement */(document.getElementById("listErrSets"));
    let domSectFns = /** @type HTMLElement */(document.getElementById("sectFns"));
    let domListFns = /** @type HTMLElement */(document.getElementById("listFns"));
    let domSectFields = /** @type HTMLElement */(document.getElementById("sectFields"));
    let domListFields = /** @type HTMLElement */(document.getElementById("listFields"));
    let domSectGlobalVars = /** @type HTMLElement */(document.getElementById("sectGlobalVars"));
    let domListGlobalVars = /** @type HTMLElement */(document.getElementById("listGlobalVars"));
    let domSectValues = /** @type HTMLElement */(document.getElementById("sectValues"));
    let domListValues = /** @type HTMLElement */(document.getElementById("listValues"));
    let domFnProto = /** @type HTMLElement */(document.getElementById("fnProto"));
    let domFnProtoCode = /** @type HTMLElement */(document.getElementById("fnProtoCode"));
    let domSectParams = /** @type HTMLElement */(document.getElementById("sectParams"));
    let domListParams = /** @type HTMLElement */(document.getElementById("listParams"));
    let domTldDocs = /** @type HTMLElement */(document.getElementById("tldDocs"));
    let domSectFnErrors = /** @type HTMLElement */(document.getElementById("sectFnErrors"));
    let domListFnErrors = /** @type HTMLElement */(document.getElementById("listFnErrors"));
    let domTableFnErrors =/** @type HTMLElement */(document.getElementById("tableFnErrors"));
    let domFnErrorsAnyError = /** @type HTMLElement */(document.getElementById("fnErrorsAnyError"));
    let domFnExamples = /** @type HTMLElement */(document.getElementById("fnExamples"));
    // let domListFnExamples = /** @type HTMLElement */(document.getElementById("listFnExamples"));
    let domFnNoExamples = /** @type HTMLElement */(document.getElementById("fnNoExamples"));
    let domDeclNoRef = /** @type HTMLElement */(document.getElementById("declNoRef"));
    let domSearch = /** @type HTMLInputElement */(document.getElementById("search"));
    let domSectSearchResults = /** @type HTMLElement */(document.getElementById("sectSearchResults"));

    let domListSearchResults = /** @type HTMLElement */(document.getElementById("listSearchResults"));
    let domSectSearchNoResults = /** @type HTMLElement */(document.getElementById("sectSearchNoResults"));
    let domSectInfo = /** @type HTMLElement */(document.getElementById("sectInfo"));
    // let domTdTarget = /** @type HTMLElement */(document.getElementById("tdTarget"));
    let domPrivDeclsBox = /** @type HTMLInputElement */(document.getElementById("privDeclsBox"));
    let domTdZigVer = /** @type HTMLElement */(document.getElementById("tdZigVer"));
    let domHdrName = /** @type HTMLElement */(document.getElementById("hdrName"));
    let domHelpModal = /** @type HTMLElement */(document.getElementById("helpDialog"));

    /** @type number | null */
    let searchTimer = null;

    /** @type Object<string, string> */
    let escapeHtmlReplacements = { "&": "&amp;", '"': "&quot;", "<": "&lt;", ">": "&gt;" };

    let typeKinds = /** @type {Record<string, number>} */(indexTypeKinds());
    let typeTypeId = /** @type {number} */ (findTypeTypeId());
    let pointerSizeEnum = { One: 0, Many: 1, Slice: 2, C: 3 };

    // for each package, is an array with packages to get to this one
    let canonPkgPaths = computeCanonicalPackagePaths();

    /** @typedef {{declNames: string[], pkgNames: string[]}} CanonDecl */

    // for each decl, is an array with {declNames, pkgNames} to get to this one
    /** @type CanonDecl[] | null */
    let canonDeclPaths = null; // lazy; use getCanonDeclPath

    // for each type, is an array with {declNames, pkgNames} to get to this one
    /** @type  number[] | null */
    let canonTypeDecls = null; // lazy; use getCanonTypeDecl

    /** @typedef {{
    *       showPrivDecls: boolean,
    *       pkgNames: string[],
    *       pkgObjs: Package[],
    *       declNames: string[],
    *       declObjs: (Decl | Type)[],
    *       callName: any,
    *   }} CurNav
    */

    /** @type {CurNav} */
    let curNav = {
        showPrivDecls: false,
        // each element is a package name, e.g. @import("a") then within there @import("b")
        // starting implicitly from root package
        pkgNames: [],
        // same as above except actual packages, not names
        pkgObjs: [],
        // Each element is a decl name, `a.b.c`, a is 0, b is 1, c is 2, etc.
        // empty array means refers to the package itself
        declNames: [],
        // these will be all types, except the last one may be a type or a decl
        declObjs: [],

        // (a, b, c, d) comptime call; result is the value the docs refer to
        callName: null,
    };

    let curNavSearch = "";
    let curSearchIndex = -1;
    let imFeelingLucky = false;

    let rootIsStd = detectRootIsStd();

    // map of decl index to list of non-generic fn indexes
    // let nodesToFnsMap = indexNodesToFns();
    // map of decl index to list of comptime fn calls
    // let nodesToCallsMap = indexNodesToCalls();

    domSearch.addEventListener('keydown', onSearchKeyDown, false);
    domPrivDeclsBox.addEventListener('change', function() {
        if (this.checked != curNav.showPrivDecls) {
            if (this.checked && location.hash.length > 1 && location.hash[1] != '*'){
                location.hash = "#*" + location.hash.substring(1);
                return;
            }
            if (!this.checked && location.hash.length > 1 && location.hash[1] == '*') {
                location.hash = "#" + location.hash.substring(2);
                return;
            }
        }
    }, false);
    window.addEventListener('hashchange', onHashChange, false);
    window.addEventListener('keydown', onWindowKeyDown, false);
    onHashChange();

    function renderTitle() {
        let list = curNav.pkgNames.concat(curNav.declNames);
        let suffix = " - Zig";
        if (list.length === 0) {
            if (rootIsStd) {
                document.title = "std" + suffix;
            } else {
                document.title = zigAnalysis.params.rootName + suffix;
            }
        } else {
            document.title = list.join('.') + suffix;
        }
    }

    /** @param {Type | Decl} x */
    function isDecl(x) {
        return "value" in x;
    }

    /** @param {Type | Decl} x */
    function isType(x) {
        return "kind" in x && !("value" in x);
    }

    /** @param {Type | Decl} x */
    function isContainerType(x) {
        return isType(x) && typeKindIsContainer(/** @type {Type} */(x).kind) ;
    }

    /** @param {Expr} expr */
    function typeShorthandName(expr) {
        let resolvedExpr = resolveValue({expr: expr});
        if (!("type" in resolvedExpr)) {
            return null;
        }
        let type = /** @type {Type} */(zigAnalysis.types[resolvedExpr.type]);

        outer: for (let i = 0; i < 10000; i += 1) {
            switch (type.kind) {
                case typeKinds.Optional:
                case typeKinds.Pointer:
                    let child = /** @type {PointerType | OptionalType} */(type).child;
                    let resolvedChild = resolveValue(child);
                    if ("type" in resolvedChild) {
                        type = zigAnalysis.types[resolvedChild.type];
                        continue;
                    } else {
                        return null;
                    }
                default:
                    break outer;
            }

            if (i == 9999) throw "Exhausted typeShorthandName quota";
        }



        let name = undefined;
        if (type.kind === typeKinds.Struct) {
            name = "struct";
        } else if (type.kind === typeKinds.Enum) {
            name = "enum";
        } else if (type.kind === typeKinds.Union) {
            name = "union";
        } else {
            console.log("TODO: unhalndled case in typeShortName");
            return null;
        }

        return escapeHtml(name);
    }

    /** @param {number} typeKind */
    function typeKindIsContainer(typeKind) {
        return typeKind === typeKinds.Struct ||
            typeKind === typeKinds.Union ||
            typeKind === typeKinds.Enum;
    }

    /** @param {number} typeKind */
    function declCanRepresentTypeKind(typeKind) {
        return typeKind === typeKinds.ErrorSet || typeKindIsContainer(typeKind);
    }

    // /**
    //     * @param {WalkResult[]} path
    //     * @return {WalkResult | null}
    // */
    // function findCteInRefPath(path) {
    //     for (let i = path.length - 1; i >= 0; i -= 1) {
    //         const ref = path[i];
    //         if ("string" in ref) continue;
    //         if ("comptimeExpr" in ref) return ref;
    //         if ("refPath" in ref) return findCteInRefPath(ref.refPath);
    //         return null;
    //     }

    //     return null;
    // }

    /**
        * @param {WalkResult} value
        * @return {WalkResult}
    */
    function resolveValue(value) {
        let i = 0;
        while(i < 1000) {
            i += 1;

            if ("refPath" in value.expr) {
                value = {expr: value.expr.refPath[value.expr.refPath.length -1]};
                continue;
            }

            if ("declRef" in value.expr) {
                value = zigAnalysis.decls[value.expr.declRef].value;
                continue;
            }

//            if ("as" in value.expr) {
//                value = {
//                  typeRef: zigAnalysis.exprs[value.expr.as.typeRefArg],
//                  expr: zigAnalysis.exprs[value.expr.as.exprArg],
//                };
//                continue;
//            }

            return value;

        }
        console.assert(false);
        return /** @type {WalkResult} */({});
    }

    /**
        * @param {Decl} decl
        * @return {WalkResult}
    */
//    function typeOfDecl(decl){
//        return decl.value.typeRef;
//
//        let i = 0;
//        while(i < 1000) {
//            i += 1;
//            console.assert(isDecl(decl));
//            if ("type" in decl.value) {
//                return /** @type {WalkResult} */({ type: typeTypeId });
//            }
//
////            if ("string" in decl.value) {
////                return /** @type {WalkResult} */({ type: {
////                  kind: typeKinds.Pointer,
////                  size: pointerSizeEnum.One,
////                  child: });
////            }
//
//            if ("refPath" in decl.value) {
//                decl =  /** @type {Decl} */({
//                  value: decl.value.refPath[decl.value.refPath.length -1]
//                });
//                continue;
//            }
//
//            if ("declRef" in decl.value) {
//                decl = zigAnalysis.decls[decl.value.declRef];
//                continue;
//            }
//
//            if ("int" in decl.value) {
//                return decl.value.int.typeRef;
//            }
//
//            if ("float" in decl.value) {
//                return decl.value.float.typeRef;
//            }
//
//            if ("array" in decl.value) {
//                return decl.value.array.typeRef;
//            }
//
//            if ("struct" in decl.value) {
//                return decl.value.struct.typeRef;
//            }
//
//            if ("comptimeExpr" in decl.value) {
//                const cte = zigAnalysis.comptimeExprs[decl.value.comptimeExpr];
//                return cte.typeRef;
//            }
//
//            if ("call" in decl.value) {
//                const fn_call = zigAnalysis.calls[decl.value.call];
//                let fn_decl = undefined;
//                if ("declRef" in fn_call.func) {
//                    fn_decl = zigAnalysis.decls[fn_call.func.declRef];
//                } else if ("refPath" in fn_call.func) {
//                    console.assert("declRef" in fn_call.func.refPath[fn_call.func.refPath.length -1]);
//                    fn_decl = zigAnalysis.decls[fn_call.func.refPath[fn_call.func.refPath.length -1].declRef];
//                } else throw {};
//
//                const fn_decl_value = resolveValue(fn_decl.value);
//                console.assert("type" in fn_decl_value); //TODO handle comptimeExpr
//                const fn_type = /** @type {Fn} */(zigAnalysis.types[fn_decl_value.type]);
//                console.assert(fn_type.kind === typeKinds.Fn);
//                return fn_type.ret;
//            }
//
//            if ("void" in decl.value) {
//                return /** @type {WalkResult} */({ type: typeTypeId });
//            }
//
//            if ("bool" in decl.value) {
//                return /** @type {WalkResult} */({ type: typeKinds.Bool });
//            }
//
//            console.log("TODO: handle in `typeOfDecl` more cases: ", decl);
//            console.assert(false);
//            throw {};
//        }
//        console.assert(false);
//        return /** @type {WalkResult} */({});
//    }

    function render() {
        domStatus.classList.add("hidden");
        domFnProto.classList.add("hidden");
        domSectParams.classList.add("hidden");
        domTldDocs.classList.add("hidden");
        domSectMainPkg.classList.add("hidden");
        domSectPkgs.classList.add("hidden");
        domSectTypes.classList.add("hidden");
        domSectTests.classList.add("hidden");
        domSectNamespaces.classList.add("hidden");
        domSectErrSets.classList.add("hidden");
        domSectFns.classList.add("hidden");
        domSectFields.classList.add("hidden");
        domSectSearchResults.classList.add("hidden");
        domSectSearchNoResults.classList.add("hidden");
        domSectInfo.classList.add("hidden");
        domHdrName.classList.add("hidden");
        domSectNav.classList.add("hidden");
        domSectFnErrors.classList.add("hidden");
        domFnExamples.classList.add("hidden");
        domFnNoExamples.classList.add("hidden");
        domDeclNoRef.classList.add("hidden");
        domFnErrorsAnyError.classList.add("hidden");
        domTableFnErrors.classList.add("hidden");
        domSectGlobalVars.classList.add("hidden");
        domSectValues.classList.add("hidden");

        renderTitle();
        renderInfo();
        renderPkgList();

        domPrivDeclsBox.checked = curNav.showPrivDecls;

        if (curNavSearch !== "") {
            return renderSearch();
        }

        let rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        let pkg = rootPkg;
        curNav.pkgObjs = [pkg];
        for (let i = 0; i < curNav.pkgNames.length; i += 1) {
            let childPkg = zigAnalysis.packages[pkg.table[curNav.pkgNames[i]]];
            if (childPkg == null) {
                return render404();
            }
            pkg = childPkg;
            curNav.pkgObjs.push(pkg);
        }

        /** @type {Decl | Type} */
        let currentType = zigAnalysis.types[pkg.main];
        curNav.declObjs = [currentType];
        for (let i = 0; i < curNav.declNames.length; i += 1) {

            /** @type {Decl | Type | null} */
            let childDecl = findSubDecl(/** @type {ContainerType} */(currentType), curNav.declNames[i]);
            if (childDecl == null) {
                return render404();
            }

            let childDeclValue = resolveValue(/** @type {Decl} */(childDecl).value).expr;
            if ("type" in childDeclValue) {

                const t = zigAnalysis.types[childDeclValue.type];
                if (t.kind != typeKinds.Fn) {
                    childDecl = t;
                }
            }

            currentType = /** @type {Decl | Type} */(childDecl);
            curNav.declObjs.push(currentType);
        }

        renderNav();

        let last = curNav.declObjs[curNav.declObjs.length - 1];
        let lastIsDecl = isDecl(last);
        let lastIsType = isType(last);
        let lastIsContainerType = isContainerType(last);

        if (lastIsContainerType) {
            return renderContainer(/** @type {ContainerType} */(last));
        }

        if (!lastIsDecl && !lastIsType) {
            return renderUnknownDecl(/** @type {Decl} */(last));
        }

        if (lastIsType) {
            return renderType(/** @type {Type} */(last));
        }

        if (lastIsDecl && last.kind === 'var') {
            return renderVar(/** @type {Decl} */(last));
        }

        if (lastIsDecl && last.kind === 'const') {
            let typeObj = zigAnalysis.types[resolveValue(/** @type {Decl} */(last).value).expr.type];
            if (typeObj && typeObj.kind === typeKinds.Fn) {
                return renderFn(/** @type {Decl} */(last));
            }

            return renderValue(/** @type {Decl} */(last));
        }
    }

    /** @param {Decl} decl */
    function renderUnknownDecl(decl) {
        domDeclNoRef.classList.remove("hidden");

        let docs = zigAnalysis.astNodes[decl.src].docs;
        if (docs != null) {
            domTldDocs.innerHTML = markdown(docs);
        } else {
            domTldDocs.innerHTML = '<p>There are no doc comments for this declaration.</p>';
        }
        domTldDocs.classList.remove("hidden");
    }

    /** @param {number} typeIndex */
    function typeIsErrSet(typeIndex) {
        let typeObj = zigAnalysis.types[typeIndex];
        return typeObj.kind === typeKinds.ErrorSet;
    }

    /** @param {number} typeIndex */
    function typeIsStructWithNoFields(typeIndex) {
        let typeObj = zigAnalysis.types[typeIndex];
        if (typeObj.kind !== typeKinds.Struct)
            return false;
        return /** @type {ContainerType} */(typeObj).fields.length == 0;
    }

    /** @param {number} typeIndex */
    function typeIsGenericFn(typeIndex) {
        let typeObj = zigAnalysis.types[typeIndex];
        if (typeObj.kind !== typeKinds.Fn) {
            return false;
        }
        return  /** @type {Fn} */(typeObj).generic;
    }

    /** @param {Decl} fnDecl */
    function renderFn(fnDecl) {
        if ("refPath" in fnDecl.value.expr) {
            let last = fnDecl.value.expr.refPath.length - 1;
            let lastExpr = fnDecl.value.expr.refPath[last];
            console.assert("declRef" in lastExpr);
            fnDecl = zigAnalysis.decls[lastExpr.declRef];
        }

        let value = resolveValue(fnDecl.value);
        console.assert("type" in value.expr);
        let typeObj = /** @type {Fn} */(zigAnalysis.types[value.expr.type]);

        domFnProtoCode.innerHTML = exprName(value.expr, {
          wantHtml: true,
          wantLink: true,
          fnDecl,
        });

        let docsSource = null;
        let srcNode = zigAnalysis.astNodes[fnDecl.src];
        if (srcNode.docs != null) {
            docsSource = srcNode.docs;
        }

        renderFnParamDocs(fnDecl, typeObj);

        let retExpr = resolveValue({expr:typeObj.ret}).expr;
        if ("type" in retExpr) {
            let retIndex = retExpr.type;
            let errSetTypeIndex = /** @type {number | null} */(null);
            let retType = zigAnalysis.types[retIndex];
            if (retType.kind === typeKinds.ErrorSet) {
                errSetTypeIndex = retIndex;
            } else if (retType.kind === typeKinds.ErrorUnion) {
                errSetTypeIndex = /** @type {ErrUnionType} */(retType).err.type;
            }
            if (errSetTypeIndex != null) {
                let errSetType = /** @type {ErrSetType} */(zigAnalysis.types[errSetTypeIndex]);
                renderErrorSet(errSetType);
            }
        }

        let protoSrcIndex = fnDecl.src;
        if (typeIsGenericFn(value.expr.type)) {
            throw "TODO";
            // let instantiations = nodesToFnsMap[protoSrcIndex];
            // let calls = nodesToCallsMap[protoSrcIndex];
            // if (instantiations == null && calls == null) {
            //     domFnNoExamples.classList.remove("hidden");
            // } else if (calls != null) {
            //     // if (fnObj.combined === undefined) fnObj.combined = allCompTimeFnCallsResult(calls);
            //     if (fnObj.combined != null) renderContainer(fnObj.combined);

            //     resizeDomList(domListFnExamples, calls.length, '<li></li>');

            //     for (let callI = 0; callI < calls.length; callI += 1) {
            //         let liDom = domListFnExamples.children[callI];
            //         liDom.innerHTML = getCallHtml(fnDecl, calls[callI]);
            //     }

            //     domFnExamples.classList.remove("hidden");
            // } else if (instantiations != null) {
            //     // TODO
            // }
        } else {

            domFnExamples.classList.add("hidden");
            domFnNoExamples.classList.add("hidden");
        }

        let protoSrcNode = zigAnalysis.astNodes[protoSrcIndex];
        if (docsSource == null && protoSrcNode != null && protoSrcNode.docs != null) {
            docsSource = protoSrcNode.docs;
        }
        if (docsSource != null) {
            domTldDocs.innerHTML = markdown(docsSource);
            domTldDocs.classList.remove("hidden");
        }
        domFnProto.classList.remove("hidden");
    }

    /**
    * @param {Decl} fnDecl
    * @param {Fn} typeObj
    */
    function renderFnParamDocs(fnDecl, typeObj) {
        let docCount = 0;

        let fnNode = zigAnalysis.astNodes[fnDecl.src];
        let fields = /** @type {number[]} */(fnNode.fields);
        let isVarArgs = fnNode.varArgs;

        for (let i = 0; i < fields.length; i += 1) {
            let field = fields[i];
            let fieldNode = zigAnalysis.astNodes[field];
            if (fieldNode.docs != null) {
                docCount += 1;
            }
        }
        if (docCount == 0) {
            return;
        }

        resizeDomList(domListParams, docCount, '<div></div>');
        let domIndex = 0;

        for (let i = 0; i < fields.length; i += 1) {
            let field = fields[i];
            let fieldNode = zigAnalysis.astNodes[field];
            if (fieldNode.docs == null) {
                continue;
            }
            let divDom = domListParams.children[domIndex];
            domIndex += 1;


            let value = typeObj.params[i];
            let html = '<pre>' + escapeHtml(/** @type {string} */(fieldNode.name)) + ": ";
            if (isVarArgs && i === typeObj.params.length - 1) {
                html += '...';
            } else {
                let name = exprName(value, {wantHtml: false, wantLink: false});
                html += '<span class="tok-kw">' + name + '</span>';
            }

            html += ',</pre>';

            let docs = fieldNode.docs;
            if (docs != null) {
                html += markdown(docs);
            }
            divDom.innerHTML = html;
        }
        domSectParams.classList.remove("hidden");
    }

    function renderNav() {
        let len = curNav.pkgNames.length + curNav.declNames.length;
        resizeDomList(domListNav, len, '<li><a href="#"></a></li>');
        let list = [];
        let hrefPkgNames = [];
        let hrefDeclNames = /** @type {string[]} */([]);
        for (let i = 0; i < curNav.pkgNames.length; i += 1) {
            hrefPkgNames.push(curNav.pkgNames[i]);
            list.push({
                name: curNav.pkgNames[i],
                link: navLink(hrefPkgNames, hrefDeclNames),
            });
        }
        for (let i = 0; i < curNav.declNames.length; i += 1) {
            hrefDeclNames.push(curNav.declNames[i]);
            list.push({
                name: curNav.declNames[i],
                link: navLink(hrefPkgNames, hrefDeclNames),
            });
        }

        for (let i = 0; i < list.length; i += 1) {
            let liDom = domListNav.children[i];
            let aDom = liDom.children[0];
            aDom.textContent = list[i].name;
            aDom.setAttribute('href', list[i].link);
            if (i + 1 == list.length) {
                aDom.classList.add("active");
            } else {
                aDom.classList.remove("active");
            }
        }

        domSectNav.classList.remove("hidden");
    }

    function renderInfo() {
        domTdZigVer.textContent = zigAnalysis.params.zigVersion;
        //domTdTarget.textContent = zigAnalysis.params.builds[0].target;

        domSectInfo.classList.remove("hidden");
    }

    function render404() {
        domStatus.textContent = "404 Not Found";
        domStatus.classList.remove("hidden");
    }

    function renderPkgList() {
        let rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        let list = [];
        for (let key in rootPkg.table) {
            let pkgIndex = rootPkg.table[key];
            if (zigAnalysis.packages[pkgIndex] == null) continue;
            list.push({
                name: key,
                pkg: pkgIndex,
            });
        }

        {
            let aDom = domSectMainPkg.children[1].children[0].children[0];
            aDom.textContent = zigAnalysis.params.rootName;
            aDom.setAttribute('href', navLinkPkg(zigAnalysis.rootPkg));
            if (zigAnalysis.params.rootName === curNav.pkgNames[0]) {
                aDom.classList.add("active");
            } else {
                aDom.classList.remove("active");
            }
            domSectMainPkg.classList.remove("hidden");
        }

        list.sort(function(a, b) {
            return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
        });

        if (list.length !== 0) {
            resizeDomList(domListPkgs, list.length, '<li><a href="#"></a></li>');
            for (let i = 0; i < list.length; i += 1) {
                let liDom = domListPkgs.children[i];
                let aDom = liDom.children[0];
                aDom.textContent = list[i].name;
                aDom.setAttribute('href', navLinkPkg(list[i].pkg));
                if (list[i].name === curNav.pkgNames[0]) {
                    aDom.classList.add("active");
                } else {
                    aDom.classList.remove("active");
                }
            }

            domSectPkgs.classList.remove("hidden");
        }
    }

    /**
    * @param {string[]} pkgNames
    * @param {string[]} declNames
    * @param {string} [callName]
    */

    function navLink(pkgNames, declNames, callName) {
        let base = '#';
        if (curNav.showPrivDecls) {
            base += "*";
        }

        if (pkgNames.length === 0 && declNames.length === 0) {
            return base;
        } else if (declNames.length === 0 && callName == null) {
            return base + pkgNames.join('.');
        } else if (callName == null) {
            return base + pkgNames.join('.') + ';' + declNames.join('.');
        } else {
            return base + pkgNames.join('.') + ';' + declNames.join('.') + ';' + callName;
        }
    }

    /** @param {number} pkgIndex */
    function navLinkPkg(pkgIndex) {
        return navLink(canonPkgPaths[pkgIndex], []);
    }

    /** @param {string} childName */
    function navLinkDecl(childName) {
        return navLink(curNav.pkgNames, curNav.declNames.concat([childName]));
    }

   //  /** @param {Call} callObj */
   //  function navLinkCall(callObj) {
   //      let declNamesCopy = curNav.declNames.concat([]);
   //      let callName = /** @type {string} */(declNamesCopy.pop());

   //      callName += '(';
   //          for (let arg_i = 0; arg_i < callObj.args.length; arg_i += 1) {
   //              if (arg_i !== 0) callName += ',';
   //              let argObj = callObj.args[arg_i];
   //              callName += getValueText(argObj, argObj, false, false);
   //          }
   //          callName += ')';

   //      declNamesCopy.push(callName);
   //      return navLink(curNav.pkgNames, declNamesCopy);
   //  }

    /**
    * @param {any} dlDom
    * @param {number} desiredLen
    */
    function resizeDomListDl(dlDom, desiredLen) {
        // add the missing dom entries
        for (let i = dlDom.childElementCount / 2; i < desiredLen; i += 1) {
            dlDom.insertAdjacentHTML('beforeend', '<dt></dt><dd></dd>');
        }
        // remove extra dom entries
        while (desiredLen < dlDom.childElementCount / 2) {
            dlDom.removeChild(dlDom.lastChild);
            dlDom.removeChild(dlDom.lastChild);
        }
    }

    /**
    * @param {any} listDom
    * @param {number} desiredLen
    * @param {string} templateHtml
    */
    function resizeDomList(listDom, desiredLen, templateHtml) {
        // add the missing dom entries
        for (let i = listDom.childElementCount; i < desiredLen; i += 1) {
            listDom.insertAdjacentHTML('beforeend', templateHtml);
        }
        // remove extra dom entries
        while (desiredLen < listDom.childElementCount) {
            listDom.removeChild(listDom.lastChild);
        }
    }
     /**
      * @param {WalkResult} wr,
      * @return {Expr}
    */
    function walkResultTypeRef(wr) {
      if (wr.typeRef) return wr.typeRef;
      let resolved = resolveValue(wr);
      if (wr === resolved) {
        return {type: 0};
      }
      return walkResultTypeRef(resolved);
    }
     /**
      * @typedef {{
          wantHtml: boolean,
      }} RenderWrOptions
      * @param {Expr} expr,
      * @param {RenderWrOptions} opts,
      * @return {string}
    */
    function exprName(expr, opts) {
        switch (Object.keys(expr)[0]) {
          default: throw "oh no";
          case "struct": {
            const struct_name = zigAnalysis.decls[expr.struct[0].val.typeRef.refPath[0].declRef].name;
            let struct_body = "";
            struct_body += struct_name + "{ ";
            for (let i = 0; i < expr.struct.length; i++) {
              const val = expr.struct[i].name
              const exprArg = zigAnalysis.exprs[expr.struct[i].val.expr.as.exprArg];
              let value_field = exprArg[Object.keys(exprArg)[0]];
              if (value_field instanceof Object) {
                value_field = zigAnalysis.decls[value_field[0].val.typeRef.refPath[0].declRef].name;
              };
              struct_body += "." + val + " = " + value_field;
              if (i !== expr.struct.length - 1) {
                struct_body += ", ";
              }  else {
                struct_body += " ";
              }
            }
              struct_body += "}";
            return struct_body;
          }
          case "null": {
            return "null";
          }
          case "array": {
            let payloadHtml = ".{";
            for (let i = 0; i < expr.array.length; i++) {
                if (i != 0) payloadHtml += ", ";
                let elem = zigAnalysis.exprs[expr.array[i]];
                payloadHtml += exprName(elem);
            }
            return payloadHtml + "}";
          }
          case "comptimeExpr": {
              return zigAnalysis.comptimeExprs[expr.comptimeExpr].code;
          }
          case "call": {
              let call = zigAnalysis.calls[expr.call];
              let payloadHtml = "";


              switch(Object.keys(call.func)[0]){
                default: throw "TODO";
                case "declRef":
                case "refPath": {
                    payloadHtml += exprName(call.func);
                    break;
                }
              }
              payloadHtml += "(";

              for (let i = 0; i < call.args.length; i++) {
                  if (i != 0) payloadHtml += ", ";
                  payloadHtml += exprName(call.args[i]);
              }

              payloadHtml += ")";
              return payloadHtml;
          }
          case "as": {
              const typeRefArg = zigAnalysis.exprs[expr.as.typeRefArg];
              const exprArg = zigAnalysis.exprs[expr.as.exprArg];
              return "@as(" + exprName(typeRefArg, opts) +
                ", " + exprName(exprArg, opts) + ")";
          }
          case "declRef": {
            return zigAnalysis.decls[expr.declRef].name;
          }
          case "refPath": {
            return expr.refPath.map(x => exprName(x, opts)).join(".");
          }
          case "int": {
              return "" + expr.int;
          }
          case "string": {
            return "\"" + escapeHtml(expr.string) + "\"";
          }

          case "anytype": {
            return "anytype";
          }

          case "this":{
            return "this";
          }

          case "type": {
              let name = "";

              let typeObj = expr.type;
              if (typeof typeObj === 'number') typeObj = zigAnalysis.types[typeObj];

              switch (typeObj.kind) {
                  default: throw "TODO";
                  case typeKinds.ComptimeExpr:
                  {
                      return "[ComptimeExpr]";
                  }
                  case typeKinds.Array:
                  {
                    let arrayObj = /** @type {ArrayType} */ (typeObj);
                    let name = "[";
                    let lenName = exprName(arrayObj.len, opts);
                    let sentinel = arrayObj.sentinel ? ":"+exprName(arrayObj.sentinel, opts) : "";
                    let is_mutable = arrayObj.is_multable ? "const " : "";

                    if (opts.wantHtml) {
                      name +=
                        '<span class="tok-number">' + lenName + sentinel + "</span>";
                    } else {
                      name += lenName + sentinel;
                    }
                    name += "]";
                    name += is_mutable;
                    name += exprName(arrayObj.child, opts);
                    return name;
                  }
                  case typeKinds.Optional:
                      return "?" + exprName(/**@type {OptionalType} */(typeObj).child, opts);
                  case typeKinds.Pointer:
                  {
                      let ptrObj = /** @type {PointerType} */(typeObj);
                    let sentinel = ptrObj.sentinel ? ":"+exprName(ptrObj.sentinel, opts) : "";
                      let is_mutable = !ptrObj.is_mutable ? "const " : "";
                      let name = "";
                      switch (ptrObj.size) {
                          default:
                              console.log("TODO: implement unhandled pointer size case");
                          case pointerSizeEnum.One:
                              name += "*";
                              name += is_mutable;
                              break;
                          case pointerSizeEnum.Many:
                              name += "[*";
                              name += sentinel;
                              name += "]";
                              name += is_mutable;
                              break;
                          case pointerSizeEnum.Slice:
                              name += "[";
                              name += sentinel;
                              name += "]";
                              name += is_mutable;
                              break;
                          case pointerSizeEnum.C:
                              name += "[*c";
                              name += sentinel;
                              name += "]";
                              name += is_mutable;
                              break;
                      }
                      if (ptrObj['const']) {
                          if (opts.wantHtml) {
                              name += '<span class="tok-kw">const</span> ';
                          } else {
                              name += "const ";
                          }
                      }
                      if (ptrObj['volatile']) {
                          if (opts.wantHtml) {
                              name += '<span class="tok-kw">volatile</span> ';
                          } else {
                              name += "volatile ";
                          }
                      }
                      if (ptrObj.align != null) {
                          if (opts.wantHtml) {
                              name += '<span class="tok-kw">align</span>(';
                          } else {
                              name += "align(";
                          }
                          if (opts.wantHtml) {
                              name += '<span class="tok-number">' + ptrObj.align + '</span>';
                          } else {
                              name += ptrObj.align;
                          }
                          if (ptrObj.hostIntBytes != null) {
                              name += ":";
                              if (opts.wantHtml) {
                                  name += '<span class="tok-number">' + ptrObj.bitOffsetInHost + '</span>';
                              } else {
                                  name += ptrObj.bitOffsetInHost;
                              }
                              name += ":";
                              if (opts.wantHtml) {
                                  name += '<span class="tok-number">' + ptrObj.hostIntBytes + '</span>';
                              } else {
                                  name += ptrObj.hostIntBytes;
                              }
                          }
                          name += ") ";
                      }
                      //name += typeValueName(ptrObj.child, wantHtml, wantSubLink, null);
                      name += exprName(ptrObj.child, opts);
                      return name;
                  }
                  case typeKinds.Float:
                  {
                      let floatObj = /** @type {NumberType} */ (typeObj);

                      if (opts.wantHtml) {
                          return '<span class="tok-type">' + floatObj.name + '</span>';
                      } else {
                          return floatObj.name;
                      }
                  }
                  case typeKinds.Int:
                  {
                      let intObj = /** @type {NumberType} */(typeObj);
                      let name = intObj.name;
                      if (opts.wantHtml) {
                          return '<span class="tok-type">' + name + '</span>';
                      } else {
                          return name;
                      }
                  }
                  case typeKinds.ComptimeInt:
                      if (opts.wantHtml) {
                          return '<span class="tok-type">comptime_int</span>';
                      } else {
                          return "comptime_int";
                      }
                  case typeKinds.ComptimeFloat:
                      if (opts.wantHtml) {
                          return '<span class="tok-type">comptime_float</span>';
                      } else {
                          return "comptime_float";
                      }
                  case typeKinds.Type:
                      if (opts.wantHtml) {
                          return '<span class="tok-type">type</span>';
                      } else {
                          return "type";
                      }
                  case typeKinds.Bool:
                      if (opts.wantHtml) {
                          return '<span class="tok-type">bool</span>';
                      } else {
                          return "bool";
                      }
                  case typeKinds.Void:
                      if (opts.wantHtml) {
                          return '<span class="tok-type">void</span>';
                      } else {
                          return "void";
                      }
                  case typeKinds.EnumLiteral:
                      if (opts.wantHtml) {
                          return '<span class="tok-type">(enum literal)</span>';
                      } else {
                          return "(enum literal)";
                      }
                  case typeKinds.NoReturn:
                      if (opts.wantHtml) {
                          return '<span class="tok-type">noreturn</span>';
                      } else {
                          return "noreturn";
                      }
                  case typeKinds.ErrorSet:
                  {
                      let errSetObj = /** @type {ErrSetType} */(typeObj);
                      if (errSetObj.fields == null) {
                          if (wantHtml) {
                              return '<span class="tok-type">anyerror</span>';
                          } else {
                              return "anyerror";
                          }
                      } else {
                          throw "TODO";
                          // if (wantHtml) {
                          //     return escapeHtml(typeObj.name);
                          // } else {
                          //     return typeObj.name;
                          // }
                      }
                  }
                  case typeKinds.ErrorUnion:
                  {
                      throw "TODO";
                      // TODO: implement error union printing assuming that both
                      // payload and error union are walk results!
                      // let errUnionObj = /** @type {ErrUnionType} */(typeObj);
                      // let errSetTypeObj = /** @type {ErrSetType} */ (zigAnalysis.types[errUnionObj.err]);
                      // let payloadHtml = typeValueName(errUnionObj.payload, wantHtml, wantSubLink, null);
                      // if (fnDecl != null && errSetTypeObj.fn === fnDecl.value.type) {
                      //     // function index parameter supplied and this is the inferred error set of it
                      //     return "!" + payloadHtml;
                      // } else {
                      //     return typeValueName(errUnionObj.err, wantHtml, wantSubLink, null) + "!" + payloadHtml;
                      // }
                  }
                  case typeKinds.Fn:
                  {
                      let fnObj = /** @type {Fn} */(typeObj);
                      let payloadHtml = "";
                      if (opts.wantHtml) {
                          payloadHtml += '<span class="tok-kw">fn</span>';
                          if (opts.fnDecl) {
                              payloadHtml += ' <span class="tok-fn">';
                              if (opts.linkFnNameDecl) {
                                  payloadHtml += '<a href="' + opts.linkFnNameDecl + '">' +
                                      escapeHtml(opts.fnDecl.name) + '</a>';
                              } else {
                                  payloadHtml += escapeHtml(opts.fnDecl.name);
                              }
                              payloadHtml += '</span>';
                          }
                      } else {
                          payloadHtml += 'fn ';
                      }
                      payloadHtml += '(';
                          if (fnObj.params) {
                              let fields = null;
                              let isVarArgs = false;
                              let fnNode = zigAnalysis.astNodes[fnObj.src];
                              fields = fnNode.fields;
                              isVarArgs = fnNode.varArgs;

                              for (let i = 0; i < fnObj.params.length; i += 1) {
                                  if (i != 0) {
                                      payloadHtml += ', ';
                                  }

                                  let value = fnObj.params[i];
                                  let paramValue = resolveValue({expr: value});

                                  if (fields != null) {
                                      let paramNode = zigAnalysis.astNodes[fields[i]];

                                      if (paramNode.varArgs) {
                                          payloadHtml += '...';
                                          continue;
                                      }

                                      if (paramNode.noalias) {
                                          if (opts.wantHtml) {
                                              payloadHtml += '<span class="tok-kw">noalias</span> ';
                                          } else {
                                              payloadHtml += 'noalias ';
                                          }
                                      }

                                      if (paramNode.comptime) {
                                          if (opts.wantHtml) {
                                              payloadHtml += '<span class="tok-kw">comptime</span> ';
                                          } else {
                                              payloadHtml += 'comptime ';
                                          }
                                      }

                                      let paramName = paramNode.name;
                                      if (paramName != null) {
                                          // skip if it matches the type name
                                          if (!shouldSkipParamName(paramValue, paramName)) {
                                              payloadHtml += paramName + ': ';
                                          }
                                      }
                                  }

                                  if (isVarArgs && i === fnObj.params.length - 1) {
                                      payloadHtml += '...';
                                  } else if ("refPath" in value) {
                                      if (opts.wantHtml) {
                                          payloadHtml += '<a href="">';
                                          payloadHtml +=
                                            '<span class="tok-kw" style="color:lightblue;">'
                                              + exprName(value, opts) + '</span>';
                                          payloadHtml += '</a>';
                                      } else {
                                          payloadHtml += exprName(value, opts);
                                      }

                                  } else if ("type" in value) {
                                      let name = exprName(value, {
                                        wantHtml: false,
                                        wantLink: false,
                                        fnDecl: opts.fnDecl,
                                        linkFnNameDecl: opts.linkFnNameDecl,
                                      });
                                      payloadHtml += '<span class="tok-kw">' + escapeHtml(name) + '</span>';
                                  } else if ("comptimeExpr" in value) {
                                      if (opts.wantHtml) {
                                        payloadHtml += '<span class="tok-kw">[ComptimeExpr]</span>';
                                      } else {
                                        payloadHtml += "[ComptimeExpr]";
                                      }
                                  } else if (opts.wantHtml) {
                                      payloadHtml += '<span class="tok-kw">anytype</span>';
                                  } else {
                                      payloadHtml += 'anytype';
                                  }
                              }
                          }

                      payloadHtml += ') ';
                      if (fnObj.ret != null) {
                          payloadHtml += exprName(fnObj.ret, opts);
                      } else if (opts.wantHtml) {
                          payloadHtml += '<span class="tok-kw">anytype</span>';
                      } else {
                          payloadHtml += 'anytype';
                      }
                      return payloadHtml;
                  }
                      // if (wantHtml) {
                      //     return escapeHtml(typeObj.name);
                      // } else {
                      //     return typeObj.name;
                      // }
              }
        }

        }
    }


    /**
    * @param {Expr} typeRef
    * @param {string} paramName
    */
    function shouldSkipParamName(typeRef, paramName) {
        let resolvedTypeRef = resolveValue({expr: typeRef});
        if ("type" in resolvedTypeRef) {
            let typeObj = zigAnalysis.types[resolvedTypeRef.type];
            if (typeObj.kind === typeKinds.Pointer){
                let ptrObj = /** @type {PointerType} */(typeObj);
                if (getPtrSize(ptrObj) === pointerSizeEnum.One) {
                    const value = resolveValue(ptrObj.child);
                    return typeValueName(value, false, true).toLowerCase() === paramName;
                }
            }
        }
        return false;
    }

    /** @param {PointerType} typeObj */
    function getPtrSize(typeObj) {
        return (typeObj.size == null) ? pointerSizeEnum.One : typeObj.size;
    }

    /** @param {Type} typeObj */
    function renderType(typeObj) {
        let name;
        if (rootIsStd && typeObj === zigAnalysis.types[zigAnalysis.packages[zigAnalysis.rootPkg].main]) {
            name = "std";
        } else {
            name = exprName({type:typeObj}, false, false);
        }
        if (name != null && name != "") {
            domHdrName.innerText = name + " (" + zigAnalysis.typeKinds[typeObj.kind] + ")";
            domHdrName.classList.remove("hidden");
        }
        if (typeObj.kind == typeKinds.ErrorSet) {
            renderErrorSet(/** @type {ErrSetType} */(typeObj));
        }
    }

    /** @param {ErrSetType} errSetType */
    function renderErrorSet(errSetType) {
        if (errSetType.fields == null) {
            domFnErrorsAnyError.classList.remove("hidden");
        } else {
            let errorList = [];
            for (let i = 0; i < errSetType.fields.length; i += 1) {
                let errObj = errSetType.fields[i];
                //let srcObj = zigAnalysis.astNodes[errObj.src];
                errorList.push(errObj);
            }
            errorList.sort(function(a, b) {
                return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
            });

            resizeDomListDl(domListFnErrors, errorList.length);
            for (let i = 0; i < errorList.length; i += 1) {
                let nameTdDom = domListFnErrors.children[i * 2 + 0];
                let descTdDom = domListFnErrors.children[i * 2 + 1];
                nameTdDom.textContent = errorList[i].name;
                let docs = errorList[i].docs;
                if (docs != null) {
                    descTdDom.innerHTML = markdown(docs);
                } else {
                    descTdDom.textContent = "";
                }
            }
            domTableFnErrors.classList.remove("hidden");
        }
        domSectFnErrors.classList.remove("hidden");
    }

//     function allCompTimeFnCallsHaveTypeResult(typeIndex, value) {
//         let srcIndex = zigAnalysis.fns[value].src;
//         let calls = nodesToCallsMap[srcIndex];
//         if (calls == null) return false;
//         for (let i = 0; i < calls.length; i += 1) {
//             let call = zigAnalysis.calls[calls[i]];
//             if (call.result.type !== typeTypeId) return false;
//         }
//         return true;
//     }
//
//     function allCompTimeFnCallsResult(calls) {
//         let firstTypeObj = null;
//         let containerObj = {
//             privDecls: [],
//         };
//         for (let callI = 0; callI < calls.length; callI += 1) {
//             let call = zigAnalysis.calls[calls[callI]];
//             if (call.result.type !== typeTypeId) return null;
//             let typeObj = zigAnalysis.types[call.result.value];
//             if (!typeKindIsContainer(typeObj.kind)) return null;
//             if (firstTypeObj == null) {
//                 firstTypeObj = typeObj;
//                 containerObj.src = typeObj.src;
//             } else if (firstTypeObj.src !== typeObj.src) {
//                 return null;
//             }
//
//             if (containerObj.fields == null) {
//                 containerObj.fields = (typeObj.fields || []).concat([]);
//             } else for (let fieldI = 0; fieldI < typeObj.fields.length; fieldI += 1) {
//                 let prev = containerObj.fields[fieldI];
//                 let next = typeObj.fields[fieldI];
//                 if (prev === next) continue;
//                 if (typeof(prev) === 'object') {
//                     if (prev[next] == null) prev[next] = typeObj;
//                 } else {
//                     containerObj.fields[fieldI] = {};
//                     containerObj.fields[fieldI][prev] = firstTypeObj;
//                     containerObj.fields[fieldI][next] = typeObj;
//                 }
//             }
//
//             if (containerObj.pubDecls == null) {
//                 containerObj.pubDecls = (typeObj.pubDecls || []).concat([]);
//             } else for (let declI = 0; declI < typeObj.pubDecls.length; declI += 1) {
//                 let prev = containerObj.pubDecls[declI];
//                 let next = typeObj.pubDecls[declI];
//                 if (prev === next) continue;
//                 // TODO instead of showing "examples" as the public declarations,
//                     // do logic like this:
//                 //if (typeof(prev) !== 'object') {
//                     //    let newDeclId = zigAnalysis.decls.length;
//                     //    prev = clone(zigAnalysis.decls[prev]);
//                     //    prev.id = newDeclId;
//                     //    zigAnalysis.decls.push(prev);
//                     //    containerObj.pubDecls[declI] = prev;
//                     //}
//                 //mergeDecls(prev, next, firstTypeObj, typeObj);
//             }
//         }
//         for (let declI = 0; declI < containerObj.pubDecls.length; declI += 1) {
//             let decl = containerObj.pubDecls[declI];
//             if (typeof(decl) === 'object') {
//                 containerObj.pubDecls[declI] = containerObj.pubDecls[declI].id;
//             }
//         }
//         return containerObj;
//     }



    /** @param {Decl} decl */
    function renderValue(decl) {
        let resolvedValue = resolveValue(decl.value)

        domFnProtoCode.innerHTML = '<span class="tok-kw">const</span> ' +
            escapeHtml(decl.name) + ': ' + exprName(resolvedValue.typeRef, {wantHtml: true, wantLink:true}) +
            " = " + exprName(decl.value.expr, {wantHtml: true, wantLink:true}) + ";";

        let docs = zigAnalysis.astNodes[decl.src].docs;
        if (docs != null) {
            domTldDocs.innerHTML = markdown(docs);
            domTldDocs.classList.remove("hidden");
        }

        domFnProto.classList.remove("hidden");
    }

    /** @param {Decl} decl */
    function renderVar(decl) {
        let declTypeRef = typeOfDecl(decl);
        domFnProtoCode.innerHTML = '<span class="tok-kw">var</span> ' +
            escapeHtml(decl.name) + ': ' + typeValueName(declTypeRef, true, true);

        let docs = zigAnalysis.astNodes[decl.src].docs;
        if (docs != null) {
            domTldDocs.innerHTML = markdown(docs);
            domTldDocs.classList.remove("hidden");
        }

        domFnProto.classList.remove("hidden");
    }


    /**
    * @param {number[]} decls
    * @param {Decl[]} typesList
    * @param {Decl[]} namespacesList,
    * @param {Decl[]} errSetsList,
    * @param {Decl[]} fnsList,
    * @param {Decl[]} varsList,
    * @param {Decl[]} valsList,
    * @param {Decl[]} testsList
    */
    function categorizeDecls(decls,
        typesList, namespacesList, errSetsList,
        fnsList, varsList, valsList, testsList) {

        for (let i = 0; i < decls.length; i += 1) {
            let decl = zigAnalysis.decls[decls[i]];
            let declValue = resolveValue(decl.value);

            if (decl.isTest) {
                testsList.push(decl);
                continue;
            }

            if (decl.kind === 'var') {
                varsList.push(decl);
                continue;
            }

            if (decl.kind === 'const') {
                if ("type" in declValue.expr) {
                    // We have the actual type expression at hand.
                    const typeExpr = zigAnalysis.types[declValue.expr.type];
                    if (typeExpr.kind == typeKinds.Fn) {
                        const funcRetExpr = resolveValue({
                            expr: /** @type {Fn} */(typeExpr).ret
                        });
                        if ("type" in funcRetExpr.expr && funcRetExpr.expr.type == typeTypeId) {
                            if (typeIsErrSet(declValue.expr.type)) {
                                errSetsList.push(decl);
                            } else if (typeIsStructWithNoFields(declValue.expr.type)) {
                                namespacesList.push(decl);
                            } else {
                                typesList.push(decl);
                            }
                        } else {
                            fnsList.push(decl);
                        }
                    } else {
                        if (typeIsErrSet(declValue.expr.type)) {
                            errSetsList.push(decl);
                        } else if (typeIsStructWithNoFields(declValue.expr.type)) {
                            namespacesList.push(decl);
                        } else {
                            typesList.push(decl);
                        }
                    }
                 } else if ("typeRef" in declValue) {
                      if ("type" in declValue.typeRef && declValue.typeRef == typeTypeId) {
                          // We don't know what the type expression is, but we know it's a type.
                          typesList.push(decl);
                      } else {
                          valsList.push(decl);
                      }
                } else {
                    valsList.push(decl);
                }
            }
        }
    }

    /**
     * @param {ContainerType} container
     */
    function renderContainer(container) {
        /** @type {Decl[]} */
        let typesList = [];
        /** @type {Decl[]} */
        let namespacesList = [];
        /** @type {Decl[]} */
        let errSetsList = [];
        /** @type {Decl[]} */
        let fnsList = [];
        /** @type {Decl[]} */
        let varsList = [];
        /** @type {Decl[]} */
        let valsList = [];
        /** @type {Decl[]} */
        let testsList = [];

        categorizeDecls(container.pubDecls,
            typesList, namespacesList, errSetsList,
            fnsList, varsList, valsList, testsList);
        if (curNav.showPrivDecls) categorizeDecls(container.privDecls,
            typesList, namespacesList, errSetsList,
            fnsList, varsList, valsList, testsList);


        typesList.sort(byNameProperty);
        namespacesList.sort(byNameProperty);
        errSetsList.sort(byNameProperty);
        fnsList.sort(byNameProperty);
        varsList.sort(byNameProperty);
        valsList.sort(byNameProperty);
        testsList.sort(byNameProperty);

        if (container.src != null) {
            let docs = zigAnalysis.astNodes[container.src].docs;
            if (docs != null) {
                domTldDocs.innerHTML = markdown(docs);
                domTldDocs.classList.remove("hidden");
            }
        }

        if (typesList.length !== 0) {
            resizeDomList(domListTypes, typesList.length, '<li><a href="#"></a></li>');
            for (let i = 0; i < typesList.length; i += 1) {
                let liDom = domListTypes.children[i];
                let aDom = liDom.children[0];
                let decl = typesList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domSectTypes.classList.remove("hidden");
        }
        if (namespacesList.length !== 0) {
            resizeDomList(domListNamespaces, namespacesList.length, '<li><a href="#"></a></li>');
            for (let i = 0; i < namespacesList.length; i += 1) {
                let liDom = domListNamespaces.children[i];
                let aDom = liDom.children[0];
                let decl = namespacesList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domSectNamespaces.classList.remove("hidden");
        }

        if (errSetsList.length !== 0) {
            resizeDomList(domListErrSets, errSetsList.length, '<li><a href="#"></a></li>');
            for (let i = 0; i < errSetsList.length; i += 1) {
                let liDom = domListErrSets.children[i];
                let aDom = liDom.children[0];
                let decl = errSetsList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domSectErrSets.classList.remove("hidden");
        }

        if (fnsList.length !== 0) {
            resizeDomList(domListFns, fnsList.length, '<tr><td></td><td></td></tr>');
            for (let i = 0; i < fnsList.length; i += 1) {
                let decl = fnsList[i];
                let trDom = domListFns.children[i];

                let tdFnCode = trDom.children[0];
                let tdDesc = trDom.children[1];

                let declType = resolveValue(decl.value);
                console.assert("type" in declType.expr);

                tdFnCode.innerHTML = exprName(declType.expr,{
                  wantHtml: true,
                  wantLink: true,
                  fnDecl: decl,
                  linkFnNameDecl: navLinkDecl(decl.name),
                });

                let docs = zigAnalysis.astNodes[decl.src].docs;
                if (docs != null) {
                    tdDesc.innerHTML = shortDescMarkdown(docs);
                } else {
                    tdDesc.textContent = "";
                }
            }
            domSectFns.classList.remove("hidden");
        }

        let containerNode = zigAnalysis.astNodes[container.src];
        if (containerNode.fields && containerNode.fields.length > 0) {
            resizeDomList(domListFields, containerNode.fields.length, '<div></div>');

            for (let i = 0; i < containerNode.fields.length; i += 1) {
                let fieldNode = zigAnalysis.astNodes[containerNode.fields[i]];
                let divDom = domListFields.children[i];
                let fieldName = /** @type {string} */(fieldNode.name);

                let html = '<div class="mobile-scroll-container"><pre class="scroll-item">' + escapeHtml(fieldName);

                if (container.kind === typeKinds.Enum) {
                    html += ' = <span class="tok-number">' + fieldName + '</span>';
                } else {
                    let fieldTypeExpr = container.fields[i];
                    html += ": ";
                    let name = exprName(fieldTypeExpr, false, false);
                    html += '<span class="tok-kw">'+ name +'</span>';
                    let tsn = typeShorthandName(fieldTypeExpr);
                    if (tsn) {
                        html += '<span> ('+ tsn +')</span>';

                    }
                }

                html += ',</pre></div>';

                let docs = fieldNode.docs;
                if (docs != null) {
                    html += markdown(docs);
                }
                divDom.innerHTML = html;
            }
            domSectFields.classList.remove("hidden");
        }

        if (varsList.length !== 0) {
            resizeDomList(domListGlobalVars, varsList.length,
                '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
            for (let i = 0; i < varsList.length; i += 1) {
                let decl = varsList[i];
                let trDom = domListGlobalVars.children[i];

                let tdName = trDom.children[0];
                let tdNameA = tdName.children[0];
                let tdType = trDom.children[1];
                let tdDesc = trDom.children[2];

                tdNameA.setAttribute('href', navLinkDecl(decl.name));
                tdNameA.textContent = decl.name;

                tdType.innerHTML = typeValueName(typeOfDecl(decl), true, true);

                let docs = zigAnalysis.astNodes[decl.src].docs;
                if (docs != null) {
                    tdDesc.innerHTML = shortDescMarkdown(docs);
                } else {
                    tdDesc.textContent = "";
                }
            }
            domSectGlobalVars.classList.remove("hidden");
        }

        if (valsList.length !== 0) {
            resizeDomList(domListValues, valsList.length,
                '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
            for (let i = 0; i < valsList.length; i += 1) {
                let decl = valsList[i];
                let trDom = domListValues.children[i];

                let tdName = trDom.children[0];
                let tdNameA = tdName.children[0];
                let tdType = trDom.children[1];
                let tdDesc = trDom.children[2];

                tdNameA.setAttribute('href', navLinkDecl(decl.name));
                tdNameA.textContent = decl.name;

                tdType.innerHTML = exprName(walkResultTypeRef(decl.value),
                  {wantHtml:true, wantLink:true});

                let docs = zigAnalysis.astNodes[decl.src].docs;
                if (docs != null) {
                    tdDesc.innerHTML = shortDescMarkdown(docs);
                } else {
                    tdDesc.textContent = "";
                }
            }
            domSectValues.classList.remove("hidden");
        }

        if (testsList.length !== 0) {
            resizeDomList(domListTests, testsList.length,
                '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
            for (let i = 0; i < testsList.length; i += 1) {
                let decl = testsList[i];
                let trDom = domListTests.children[i];

                let tdName = trDom.children[0];
                let tdNameA = tdName.children[0];
                let tdType = trDom.children[1];
                let tdDesc = trDom.children[2];

                tdNameA.setAttribute('href', navLinkDecl(decl.name));
                tdNameA.textContent = decl.name;

                tdType.innerHTML = exprName(walkResultTypeRef(decl.value),
                  {wantHtml:true, wantLink:true});

                let docs = zigAnalysis.astNodes[decl.src].docs;
                if (docs != null) {
                    tdDesc.innerHTML = shortDescMarkdown(docs);
                } else {
                    tdDesc.textContent = "";
                }
            }
            domSectTests.classList.remove("hidden");
        }
    }


    /**
    * @param {string | number} a
    * @param {string | number} b
    */
    function operatorCompare(a, b) {
        if (a === b) {
            return 0;
        } else if (a < b) {
            return -1;
        } else {
            return 1;
        }
    }

    function detectRootIsStd() {
        let rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        if (rootPkg.table["std"] == null) {
            // no std mapped into the root package
            return false;
        }
        let stdPkg = zigAnalysis.packages[rootPkg.table["std"]];
        if (stdPkg == null) return false;
        return rootPkg.file === stdPkg.file;
    }

    function indexTypeKinds() {
        let map = /** @type {Record<string, number>} */({});
        for (let i = 0; i < zigAnalysis.typeKinds.length; i += 1) {
            map[zigAnalysis.typeKinds[i]] = i;
        }
        // This is just for debugging purposes, not needed to function
        let assertList = ["Type","Void","Bool","NoReturn","Int","Float","Pointer","Array","Struct",
            "ComptimeFloat","ComptimeInt","Undefined","Null","Optional","ErrorUnion","ErrorSet","Enum",
            "Union","Fn","BoundFn","Opaque","Frame","AnyFrame","Vector","EnumLiteral"];
        for (let i = 0; i < assertList.length; i += 1) {
            if (map[assertList[i]] == null) throw new Error("No type kind '" + assertList[i] + "' found");
        }
        return map;
    }

    function findTypeTypeId() {
        for (let i = 0; i < zigAnalysis.types.length; i += 1) {
            if (zigAnalysis.types[i].kind == typeKinds.Type) {
                return i;
            }
        }
        throw new Error("No type 'type' found");
    }

    function updateCurNav() {

        curNav = {
            showPrivDecls: false,
            pkgNames: [],
            pkgObjs: [],
            declNames: [],
            declObjs: [],
            callName: null,
        };
        curNavSearch = "";

        if (location.hash[0] === '#' && location.hash.length > 1) {
            let query = location.hash.substring(1);
            if (query[0] === '*') {
              curNav.showPrivDecls = true;
              query = query.substring(1);
            }

            let qpos = query.indexOf("?");
            let nonSearchPart;
            if (qpos === -1) {
                nonSearchPart = query;
            } else {
                nonSearchPart = query.substring(0, qpos);
                curNavSearch = decodeURIComponent(query.substring(qpos + 1));
            }

            let parts = nonSearchPart.split(";");
            curNav.pkgNames = decodeURIComponent(parts[0]).split(".");
            if (parts[1] != null) {
                curNav.declNames = decodeURIComponent(parts[1]).split(".");
            }
        }

        if (curNav.pkgNames.length === 0 && rootIsStd) {
            curNav.pkgNames = ["std"];
        }
    }

    function onHashChange() {
        updateCurNav();
        if (domSearch.value !== curNavSearch) {
            domSearch.value = curNavSearch;
        }
        render();
        if (imFeelingLucky) {
            imFeelingLucky = false;
            activateSelectedResult();
        }
    }

    /**
    * @param {ContainerType} parentType
    * @param {string} childName
    */
    function findSubDecl(parentType, childName) {
        if (!parentType.pubDecls) return null;
        for (let i = 0; i < parentType.pubDecls.length; i += 1) {
            let declIndex = parentType.pubDecls[i];
            let childDecl = zigAnalysis.decls[declIndex];
            if (childDecl.name === childName) {
                return childDecl;
            }
        }
        if (!parentType.privDecls) return null;
        for (let i = 0; i < parentType.privDecls.length; i += 1) {
            let declIndex = parentType.privDecls[i];
            let childDecl = zigAnalysis.decls[declIndex];
            if (childDecl.name === childName) {
                return childDecl;
            }
        }
        return null;
    }




    function computeCanonicalPackagePaths() {
        let list = new Array(zigAnalysis.packages.length);
        // Now we try to find all the packages from root.
            let rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        // Breadth-first to keep the path shortest possible.
            let stack = [{
                path: /** @type {string[]} */([]),
                pkg: rootPkg,
            }];
        while (stack.length !== 0) {
            let item = /** @type {{path: string[], pkg: Package}} */(stack.shift());
            for (let key in item.pkg.table) {
                let childPkgIndex = item.pkg.table[key];
                if (list[childPkgIndex] != null) continue;
                let childPkg = zigAnalysis.packages[childPkgIndex];
                if (childPkg == null) continue;

                let newPath = item.path.concat([key])
                list[childPkgIndex] = newPath;
                stack.push({
                    path: newPath,
                    pkg: childPkg,
                });
            }
        }
        return list;
    }


    /** @return {CanonDecl[]} */
    function computeCanonDeclPaths() {
        let list = new Array(zigAnalysis.decls.length);
        canonTypeDecls = new Array(zigAnalysis.types.length);

        for (let pkgI = 0; pkgI < zigAnalysis.packages.length; pkgI += 1) {
            if (pkgI === zigAnalysis.rootPkg && rootIsStd) continue;
            let pkg = zigAnalysis.packages[pkgI];
            let pkgNames = canonPkgPaths[pkgI];
            let stack = [{
                declNames: /** @type {string[]} */([]),
                type: zigAnalysis.types[pkg.main],
            }];
            while (stack.length !== 0) {
                let item = /** @type {{declNames: string[], type: Type}} */(stack.shift());

                if (isContainerType(item.type)) {
                    let t = /** @type {ContainerType} */(item.type);

                    let len = t.pubDecls ? t.pubDecls.length : 0;
                    for (let declI = 0; declI < len; declI += 1) {
                        let mainDeclIndex = t.pubDecls[declI];
                        if (list[mainDeclIndex] != null) continue;

                        let decl = zigAnalysis.decls[mainDeclIndex];
                        let declVal =  decl.value; //resolveValue(decl.value);
                        let declNames = item.declNames.concat([decl.name]);
                        list[mainDeclIndex] = {
                            pkgNames: pkgNames,
                            declNames: declNames,
                        };
                        if ("type" in declVal.expr) {
                            let value = zigAnalysis.types[declVal.expr.type];
                            if (declCanRepresentTypeKind(value.kind))
                            {
                                canonTypeDecls[declVal.type] = mainDeclIndex;
                            }

                            if (isContainerType(value)) {
                                stack.push({
                                    declNames: declNames,
                                    type:value,
                                });
                            }
                        }
                    }
                }
            }
        }
        return list;
    }

    /** @param {number} index */
    function getCanonDeclPath(index) {
        if (canonDeclPaths == null) {
            canonDeclPaths = computeCanonDeclPaths();
        }
        //let cd = /** @type {CanonDecl[]}*/(canonDeclPaths);
        return canonDeclPaths[index];
    }

    /** @param {number} index */
    function getCanonTypeDecl(index) {
        getCanonDeclPath(0);
        //let ct = /** @type {number[]}*/(canonTypeDecls);
        return canonTypeDecls[index];
    }

    /** @param {string} text */
    function escapeHtml(text) {
        return text.replace(/[&"<>]/g, function (m) {
            return escapeHtmlReplacements[m];
        });
    }

    /** @param {string} docs */
    function shortDescMarkdown(docs) {
        let parts = docs.trim().split("\n");
        let firstLine = parts[0];
        return markdown(firstLine);
    }

    /** @param {string} input */
    function markdown(input) {
        const raw_lines = input.split('\n'); // zig allows no '\r', so we don't need to split on CR
        /**
        * @type Array<{
        *   indent: number,
        *   raw_text: string,
        *   text: string,
        *   type: string,
        *   ordered_number: number,
        * }>
        */
        const lines = [];

        // PHASE 1:
        // Dissect lines and determine the type for each line.
            // Also computes indentation level and removes unnecessary whitespace

        let is_reading_code = false;
        let code_indent = 0;
        for (let line_no = 0; line_no < raw_lines.length; line_no++) {
            const raw_line = raw_lines[line_no];

            const line = {
                indent: 0,
                raw_text: raw_line,
                text: raw_line.trim(),
                type: "p", // p, h1 … h6, code, ul, ol, blockquote, skip, empty
                ordered_number: -1, // NOTE: hack to make the type checker happy
            };

            if (!is_reading_code) {
                while ((line.indent < line.raw_text.length) && line.raw_text[line.indent] == ' ') {
                    line.indent += 1;
                }

                if (line.text.startsWith("######")) {
                    line.type = "h6";
                    line.text = line.text.substr(6);
                }
                else if (line.text.startsWith("#####")) {
                    line.type = "h5";
                    line.text = line.text.substr(5);
                }
                else if (line.text.startsWith("####")) {
                    line.type = "h4";
                    line.text = line.text.substr(4);
                }
                else if (line.text.startsWith("###")) {
                    line.type = "h3";
                    line.text = line.text.substr(3);
                }
                else if (line.text.startsWith("##")) {
                    line.type = "h2";
                    line.text = line.text.substr(2);
                }
                else if (line.text.startsWith("#")) {
                    line.type = "h1";
                    line.text = line.text.substr(1);
                }
                else if (line.text.startsWith("-")) {
                    line.type = "ul";
                    line.text = line.text.substr(1);
                }
                else if (line.text.match(/^\d+\..*$/)) { // if line starts with {number}{dot}
                    const match = /** @type {RegExpMatchArray} */(line.text.match(/(\d+)\./));
                    line.type = "ul";
                    line.text = line.text.substr(match[0].length);
                    line.ordered_number = Number(match[1].length);
                }
                else if (line.text == "```") {
                    line.type = "skip";
                    is_reading_code = true;
                    code_indent = line.indent;
                }
                else if (line.text == "") {
                    line.type = "empty";
                }
            }
            else {
                if (line.text == "```") {
                    is_reading_code = false;
                    line.type = "skip";
                } else {
                    line.type = "code";
                    line.text = line.raw_text.substr(code_indent); // remove the indent of the ``` from all the code block
                }
            }

            if (line.type != "skip") {
                lines.push(line);
            }
        }

        // PHASE 2:
        // Render HTML from markdown lines.
            // Look at each line and emit fitting HTML code

        /**
        * @param {string } innerText
        */
        function markdownInlines(innerText) {

            // inline types:
            // **{INLINE}**       : <strong>
                // __{INLINE}__       : <u>
                // ~~{INLINE}~~       : <s>
                //  *{INLINE}*        : <emph>
                //  _{INLINE}_        : <emph>
                //  `{TEXT}`          : <code>
                //  [{INLINE}]({URL}) : <a>
                // ![{TEXT}]({URL})   : <img>
                // [[std;format.fmt]] : <a> (inner link)

            /** @typedef {{marker: string, tag: string}} Fmt*/
            /** @type {Array<Fmt>} */
            const formats = [
                {
                    marker: "**",
                    tag: "strong",
                },
                {
                    marker: "~~",
                    tag: "s",
                },
                {
                    marker: "__",
                    tag: "u",
                },
                {
                    marker: "*",
                    tag: "em",
                }
            ];

            /** @type {Array<Fmt>} */
            const stack = [];

            let innerHTML = "";
            let currentRun = "";

            function flushRun() {
                if (currentRun != "") {
                    innerHTML += escapeHtml(currentRun);
                }
                currentRun = "";
            }

            let parsing_code = false;
            let codetag = "";
            let in_code = false;

            for (let i = 0; i < innerText.length; i++) {

                if (parsing_code && in_code) {
                    if (innerText.substr(i, codetag.length) == codetag) {
                        // remove leading and trailing whitespace if string both starts and ends with one.
                            if (currentRun[0] == " " && currentRun[currentRun.length - 1] == " ") {
                                currentRun = currentRun.substr(1, currentRun.length - 2);
                            }
                        flushRun();
                        i += codetag.length - 1;
                        in_code = false;
                        parsing_code = false;
                        innerHTML += "</code>";
                        codetag = "";
                    } else {
                        currentRun += innerText[i];
                    }
                    continue;
                }

                if (innerText[i] == "`") {
                    flushRun();
                    if (!parsing_code) {
                        innerHTML += "<code>";
                    }
                    parsing_code = true;
                    codetag += "`";
                    continue;
                }

                if (parsing_code) {
                    currentRun += innerText[i];
                    in_code = true;
                } else {
                    let any = false;
                    for (let idx = /** @type {number} */(stack.length > 0 ? -1 : 0); idx < formats.length; idx++) {
                        const fmt = idx >= 0 ? formats[idx] : stack[stack.length - 1];
                        if (innerText.substr(i, fmt.marker.length) == fmt.marker) {
                            flushRun();
                            if (stack[stack.length - 1] == fmt) {
                                stack.pop();
                                innerHTML += "</" + fmt.tag + ">";
                            } else {
                                stack.push(fmt);
                                innerHTML += "<" + fmt.tag + ">";
                            }
                            i += fmt.marker.length - 1;
                            any = true;
                            break;
                        }
                    }
                    if (!any) {
                        currentRun += innerText[i];
                    }
                }
            }
            flushRun();

            while (stack.length > 0) {
                const fmt = /** @type {Fmt} */(stack.pop());
                innerHTML += "</" + fmt.tag + ">";
            }

            return innerHTML;
        }

        /**
        * @param {string} type
        * @param {number} line_no
        */
        function previousLineIs(type, line_no) {
            if (line_no > 0) {
                return (lines[line_no - 1].type == type);
            } else {
                return false;
            }
        }

        /**
        * @param {string} type
        * @param {number} line_no
        */
        function nextLineIs(type, line_no) {
            if (line_no < (lines.length - 1)) {
                return (lines[line_no + 1].type == type);
            } else {
                return false;
            }
        }

        /** @param {number} line_no */
        function getPreviousLineIndent(line_no) {
            if (line_no > 0) {
                return lines[line_no - 1].indent;
            } else {
                return 0;
            }
        }

        /** @param {number} line_no */
        function getNextLineIndent(line_no) {
            if (line_no < (lines.length - 1)) {
                return lines[line_no + 1].indent;
            } else {
                return 0;
            }
        }

        let html = "";
        for (let line_no = 0; line_no < lines.length; line_no++) {
            const line = lines[line_no];



            switch (line.type) {
                case "h1":
                case "h2":
                case "h3":
                case "h4":
                case "h5":
                case "h6":
                    html += "<" + line.type + ">" + markdownInlines(line.text) + "</" + line.type + ">\n";
                    break;

                case "ul":
                case "ol":
                    if (!previousLineIs("ul", line_no) || getPreviousLineIndent(line_no) < line.indent) {
                        html += "<" + line.type + ">\n";
                    }

                    html += "<li>" + markdownInlines(line.text) + "</li>\n";

                    if (!nextLineIs("ul", line_no) || getNextLineIndent(line_no) < line.indent) {
                        html += "</" + line.type + ">\n";
                    }
                    break;

                case "p":
                    if (!previousLineIs("p", line_no)) {
                        html += "<p>\n";
                    }
                    html += markdownInlines(line.text) + "\n";
                    if (!nextLineIs("p", line_no)) {
                        html += "</p>\n";
                    }
                    break;

                case "code":
                    if (!previousLineIs("code", line_no)) {
                        html += "<pre><code>";
                    }
                    html += escapeHtml(line.text) + "\n";
                    if (!nextLineIs("code", line_no)) {
                        html += "</code></pre>\n";
                    }
                    break;
            }
        }

        return html;
    }

    function activateSelectedResult() {
        if (domSectSearchResults.classList.contains("hidden")) {
            return;
        }

        let liDom = domListSearchResults.children[curSearchIndex];
        if (liDom == null && domListSearchResults.children.length !== 0) {
            liDom = domListSearchResults.children[0];
        }
        if (liDom != null) {
            let aDom = liDom.children[0];
            location.href = /** @type {string} */(aDom.getAttribute("href"));
            curSearchIndex = -1;
        }
        domSearch.blur();
    }

    /** @param {KeyboardEvent} ev */
    function onSearchKeyDown(ev) {
        switch (getKeyString(ev)) {
            case "Enter":
                // detect if this search changes anything
                let terms1 = getSearchTerms();
                startSearch();
                updateCurNav();
                let terms2 = getSearchTerms();
                // we might have to wait for onHashChange to trigger
                imFeelingLucky = (terms1.join(' ') !== terms2.join(' '));
                if (!imFeelingLucky) activateSelectedResult();

                ev.preventDefault();
                ev.stopPropagation();
                return;
            case "Esc":
                domSearch.value = "";
                domSearch.blur();
                curSearchIndex = -1;
                ev.preventDefault();
                ev.stopPropagation();
                startSearch();
                return;
            case "Up":
                moveSearchCursor(-1);
                ev.preventDefault();
                ev.stopPropagation();
                return;
            case "Down":
                moveSearchCursor(1);
                ev.preventDefault();
                ev.stopPropagation();
                return;
            default:
                if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;

                curSearchIndex = -1;
                ev.stopPropagation();
                startAsyncSearch();
                return;
        }
    }


    /** @param {number} dir */
    function moveSearchCursor(dir) {
        if (curSearchIndex < 0 || curSearchIndex >= domListSearchResults.children.length) {
            if (dir > 0) {
                curSearchIndex = -1 + dir;
            } else if (dir < 0) {
                curSearchIndex = domListSearchResults.children.length + dir;
            }
        } else {
            curSearchIndex += dir;
        }
        if (curSearchIndex < 0) {
            curSearchIndex = 0;
        }
        if (curSearchIndex >= domListSearchResults.children.length) {
            curSearchIndex = domListSearchResults.children.length - 1;
        }
        renderSearchCursor();
    }

    /** @param {KeyboardEvent} ev */
    function getKeyString(ev) {
        let name;
        let ignoreShift = false;
        switch (ev.which) {
            case 13:
                name = "Enter";
                break;
            case 27:
                name = "Esc";
                break;
            case 38:
                name = "Up";
                break;
            case 40:
                name = "Down";
                break;
            default:
                ignoreShift = true;
                name = (ev.key != null) ? ev.key : String.fromCharCode(ev.charCode || ev.keyCode);
        }
        if (!ignoreShift && ev.shiftKey) name = "Shift+" + name;
        if (ev.altKey) name = "Alt+" + name;
        if (ev.ctrlKey) name = "Ctrl+" + name;
        return name;
    }

    /** @param {KeyboardEvent} ev */
    function onWindowKeyDown(ev) {
        switch (getKeyString(ev)) {
            case "Esc":
                if (!domHelpModal.classList.contains("hidden")) {
                    domHelpModal.classList.add("hidden");
                    ev.preventDefault();
                    ev.stopPropagation();
                }
                break;
            case "s":
                domSearch.focus();
                domSearch.select();
                ev.preventDefault();
                ev.stopPropagation();
                startAsyncSearch();
                break;
            case "?":
                    ev.preventDefault();
                ev.stopPropagation();
                showHelpModal();
                break;
        }
    }

function showHelpModal() {
    domHelpModal.classList.remove("hidden");
    domHelpModal.style.left = (window.innerWidth / 2 - domHelpModal.clientWidth / 2) + "px";
    domHelpModal.style.top = (window.innerHeight / 2 - domHelpModal.clientHeight / 2) + "px";
    domHelpModal.focus();
}

function clearAsyncSearch() {
    if (searchTimer != null) {
        clearTimeout(searchTimer);
        searchTimer = null;
    }
}

function startAsyncSearch() {
    clearAsyncSearch();
    searchTimer = setTimeout(startSearch, 100);
}
function startSearch() {
    clearAsyncSearch();
    let oldHash = location.hash;
    let parts = oldHash.split("?");
    let newPart2 = (domSearch.value === "") ? "" : ("?" + domSearch.value);
    location.hash = (parts.length === 1) ? (oldHash + newPart2) : (parts[0] + newPart2);
}
function getSearchTerms() {
    let list = curNavSearch.trim().split(/[ \r\n\t]+/);
    list.sort();
    return list;
}
function renderSearch() {
    let matchedItems = [];
    let ignoreCase = (curNavSearch.toLowerCase() === curNavSearch);
    let terms = getSearchTerms();

    decl_loop: for (let declIndex = 0; declIndex < zigAnalysis.decls.length; declIndex += 1) {
        let canonPath = getCanonDeclPath(declIndex);
        if (canonPath == null) continue;

        let decl = zigAnalysis.decls[declIndex];
        let lastPkgName = canonPath.pkgNames[canonPath.pkgNames.length - 1];
        let fullPathSearchText = lastPkgName + "." + canonPath.declNames.join('.');
        let astNode = zigAnalysis.astNodes[decl.src];
        let fileAndDocs = "" //zigAnalysis.files[astNode.file];
        // TODO: understand what this piece of code is trying to achieve
        //       also right now `files` are expressed as a hashmap.
        if (astNode.docs != null) {
            fileAndDocs += "\n" + astNode.docs;
        }
        let fullPathSearchTextLower = fullPathSearchText;
        if (ignoreCase) {
            fullPathSearchTextLower = fullPathSearchTextLower.toLowerCase();
            fileAndDocs = fileAndDocs.toLowerCase();
        }

        let points = 0;
        for (let termIndex = 0; termIndex < terms.length; termIndex += 1) {
            let term = terms[termIndex];

            // exact, case sensitive match of full decl path
            if (fullPathSearchText === term) {
                points += 4;
                continue;
            }
            // exact, case sensitive match of just decl name
            if (decl.name == term) {
                points += 3;
                continue;
            }
            // substring, case insensitive match of full decl path
            if (fullPathSearchTextLower.indexOf(term) >= 0) {
                points += 2;
                continue;
            }
            if (fileAndDocs.indexOf(term) >= 0) {
                points += 1;
                continue;
            }

            continue decl_loop;
        }

        matchedItems.push({
            decl: decl,
            path: canonPath,
            points: points,
        });
    }

    if (matchedItems.length !== 0) {
        resizeDomList(domListSearchResults, matchedItems.length, '<li><a href="#"></a></li>');

        matchedItems.sort(function(a, b) {
            let cmp = operatorCompare(b.points, a.points);
            if (cmp != 0) return cmp;
            return operatorCompare(a.decl.name, b.decl.name);
        });

        for (let i = 0; i < matchedItems.length; i += 1) {
            let liDom = domListSearchResults.children[i];
            let aDom = liDom.children[0];
            let match = matchedItems[i];
            let lastPkgName = match.path.pkgNames[match.path.pkgNames.length - 1];
            aDom.textContent = lastPkgName + "." + match.path.declNames.join('.');
            aDom.setAttribute('href', navLink(match.path.pkgNames, match.path.declNames));
        }
        renderSearchCursor();

        domSectSearchResults.classList.remove("hidden");
    } else {
        domSectSearchNoResults.classList.remove("hidden");
    }
}

function renderSearchCursor() {
    for (let i = 0; i < domListSearchResults.children.length; i += 1) {
        let liDom = /** @type HTMLElement */(domListSearchResults.children[i]);
        if (curSearchIndex === i) {
            liDom.classList.add("selected");
        } else {
            liDom.classList.remove("selected");
        }
    }
}



// function indexNodesToCalls() {
//     let map = {};
//     for (let i = 0; i < zigAnalysis.calls.length; i += 1) {
//         let call = zigAnalysis.calls[i];
//         let fn = zigAnalysis.fns[call.fn];
//         if (map[fn.src] == null) {
//             map[fn.src] = [i];
//         } else {
//             map[fn.src].push(i);
//         }
//     }
//     return map;
// }


/**
* @param {{ name: string }} a
* @param {{ name: string }} b
*/
function byNameProperty(a, b) {
    return operatorCompare(a.name, b.name);
}



})();
