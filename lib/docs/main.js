"use strict";

var zigAnalysis;

(function () {
  const domStatus = document.getElementById("status");
  const domSectNav = document.getElementById("sectNav");
  const domListNav = document.getElementById("listNav");
  const domSectMainPkg = document.getElementById("sectMainPkg");
  const domSectPkgs = document.getElementById("sectPkgs");
  const domListPkgs = document.getElementById("listPkgs");
  const domSectTypes = document.getElementById("sectTypes");
  const domListTypes = document.getElementById("listTypes");
  const domSectTests = document.getElementById("sectTests");
  const domListTests = document.getElementById("listTests");
  const domSectDocTests = document.getElementById("sectDocTests");
  const domDocTestsCode = document.getElementById("docTestsCode");
  const domSectNamespaces = document.getElementById("sectNamespaces");
  const domListNamespaces = document.getElementById("listNamespaces");
  const domSectErrSets = document.getElementById("sectErrSets");
  const domListErrSets = document.getElementById("listErrSets");
  const domSectFns = document.getElementById("sectFns");
  const domListFns = document.getElementById("listFns");
  const domSectFields = document.getElementById("sectFields");
  const domListFields = document.getElementById("listFields");
  const domSectGlobalVars = document.getElementById("sectGlobalVars");
  const domListGlobalVars = document.getElementById("listGlobalVars");
  const domSectValues = document.getElementById("sectValues");
  const domListValues = document.getElementById("listValues");
  const domFnProto = document.getElementById("fnProto");
  const domFnProtoCode = document.getElementById("fnProtoCode");
  const domSectParams = document.getElementById("sectParams");
  const domListParams = document.getElementById("listParams");
  const domTldDocs = document.getElementById("tldDocs");
  const domSectFnErrors = document.getElementById("sectFnErrors");
  const domListFnErrors = document.getElementById("listFnErrors");
  const domTableFnErrors = document.getElementById("tableFnErrors");
  const domFnErrorsAnyError = document.getElementById("fnErrorsAnyError");
  const domFnExamples = document.getElementById("fnExamples");
  // const domListFnExamples = (document.getElementById("listFnExamples"));
  const domFnNoExamples = document.getElementById("fnNoExamples");
  const domDeclNoRef = document.getElementById("declNoRef");
  const domSearch = document.getElementById("search");
  const domSectSearchResults = document.getElementById("sectSearchResults");
  const domSectSearchAllResultsLink = document.getElementById("sectSearchAllResultsLink");
  const domDocs = document.getElementById("docs");
  const domListSearchResults = document.getElementById("listSearchResults");
  const domSectSearchNoResults = document.getElementById("sectSearchNoResults");
  const domSectInfo = document.getElementById("sectInfo");
  // const domTdTarget = (document.getElementById("tdTarget"));
  const domPrivDeclsBox = document.getElementById("privDeclsBox");
  const domTdZigVer = document.getElementById("tdZigVer");
  const domHdrName = document.getElementById("hdrName");
  const domHelpModal = document.getElementById("helpModal");
  const domSearchPlaceholder = document.getElementById("searchPlaceholder");
  const sourceFileUrlTemplate = "src/{{file}}#L{{line}}"
  const domLangRefLink = document.getElementById("langRefLink");

  let searchTimer = null;
  let searchTrimResults = true;

  let escapeHtmlReplacements = {
    "&": "&amp;",
    '"': "&quot;",
    "<": "&lt;",
    ">": "&gt;",
  };

  let typeKinds = indexTypeKinds();
  let typeTypeId = findTypeTypeId();
  let pointerSizeEnum = { One: 0, Many: 1, Slice: 2, C: 3 };

  // for each package, is an array with packages to get to this one
  let canonPkgPaths = computeCanonicalPackagePaths();

  // for each decl, is an array with {declNames, pkgNames} to get to this one

  let canonDeclPaths = null; // lazy; use getCanonDeclPath

  // for each type, is an array with {declNames, pkgNames} to get to this one

  let canonTypeDecls = null; // lazy; use getCanonTypeDecl

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

  domSearch.disabled = false;
  domSearch.addEventListener("keydown", onSearchKeyDown, false);
  domSearch.addEventListener("focus", ev => {
    domSearchPlaceholder.classList.add("hidden");
  });
  domSearch.addEventListener("blur", ev => {
    if (domSearch.value.length == 0)
      domSearchPlaceholder.classList.remove("hidden");
  });
  domSectSearchAllResultsLink.addEventListener('click', onClickSearchShowAllResults, false);
  function onClickSearchShowAllResults(ev) {
    ev.preventDefault();
    ev.stopPropagation();
    searchTrimResults = false;
    onHashChange();
  }

  domPrivDeclsBox.addEventListener(
    "change",
    function () {
      if (this.checked != curNav.showPrivDecls) {
        if (
          this.checked &&
          location.hash.length > 1 &&
          location.hash[1] != "*"
        ) {
          location.hash = "#*" + location.hash.substring(1);
          return;
        }
        if (
          !this.checked &&
          location.hash.length > 1 &&
          location.hash[1] == "*"
        ) {
          location.hash = "#" + location.hash.substring(2);
          return;
        }
      }
    },
    false
  );

  if (location.hash == "") {
    location.hash = "#root";
  }

  // make the modal disappear if you click outside it
  domHelpModal.addEventListener("click", ev => {
    if (ev.target.className == "help-modal")
      domHelpModal.classList.add("hidden");
  });

  window.addEventListener("hashchange", onHashChange, false);
  window.addEventListener("keydown", onWindowKeyDown, false);
  onHashChange();

  let langRefVersion = zigAnalysis.params.zigVersion;
  if (!/^\d+\.\d+\.\d+$/.test(langRefVersion)) {
    // the version is probably not released yet
    langRefVersion = "master";
  }
  domLangRefLink.href = `https://ziglang.org/documentation/${langRefVersion}/`;

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
      document.title = list.join(".") + suffix;
    }
  }

  function isDecl(x) {
    return "value" in x;
  }

  function isType(x) {
    return "kind" in x && !("value" in x);
  }

  function isContainerType(x) {
    return isType(x) && typeKindIsContainer(x.kind);
  }

  function typeShorthandName(expr) {
    let resolvedExpr = resolveValue({ expr: expr });
    if (!("type" in resolvedExpr)) {
      return null;
    }
    let type = getType(resolvedExpr.type);

    outer: for (let i = 0; i < 10000; i += 1) {
      switch (type.kind) {
        case typeKinds.Optional:
        case typeKinds.Pointer:
          let child = type.child;
          let resolvedChild = resolveValue(child);
          if ("type" in resolvedChild) {
            type = getType(resolvedChild.type);
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

  function typeKindIsContainer(typeKind) {
    return (
      typeKind === typeKinds.Struct ||
      typeKind === typeKinds.Union ||
      typeKind === typeKinds.Enum ||
      typeKind === typeKinds.Opaque
    );
  }

  function declCanRepresentTypeKind(typeKind) {
    return typeKind === typeKinds.ErrorSet || typeKindIsContainer(typeKind);
  }

  //
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

  function resolveValue(value) {
    let i = 0;
    while (i < 1000) {
      i += 1;

      if ("refPath" in value.expr) {
        value = { expr: value.expr.refPath[value.expr.refPath.length - 1] };
        continue;
      }

      if ("declRef" in value.expr) {
        value = getDecl(value.expr.declRef).value;
        continue;
      }

      if ("as" in value.expr) {
        value = {
          typeRef: zigAnalysis.exprs[value.expr.as.typeRefArg],
          expr: zigAnalysis.exprs[value.expr.as.exprArg],
        };
        continue;
      }

      return value;
    }
    console.assert(false);
    return {};
  }

  //    function typeOfDecl(decl){
  //        return decl.value.typeRef;
  //
  //        let i = 0;
  //        while(i < 1000) {
  //            i += 1;
  //            console.assert(isDecl(decl));
  //            if ("type" in decl.value) {
  //                return ({ type: typeTypeId });
  //            }
  //
  ////            if ("string" in decl.value) {
  ////                return ({ type: {
  ////                  kind: typeKinds.Pointer,
  ////                  size: pointerSizeEnum.One,
  ////                  child: });
  ////            }
  //
  //            if ("refPath" in decl.value) {
  //                decl =  ({
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
  //                const fn_type = (zigAnalysis.types[fn_decl_value.type]);
  //                console.assert(fn_type.kind === typeKinds.Fn);
  //                return fn_type.ret;
  //            }
  //
  //            if ("void" in decl.value) {
  //                return ({ type: typeTypeId });
  //            }
  //
  //            if ("bool" in decl.value) {
  //                return ({ type: typeKinds.Bool });
  //            }
  //
  //            console.log("TODO: handle in `typeOfDecl` more cases: ", decl);
  //            console.assert(false);
  //            throw {};
  //        }
  //        console.assert(false);
  //        return ({});
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
    domSectDocTests.classList.add("hidden");
    domSectNamespaces.classList.add("hidden");
    domSectErrSets.classList.add("hidden");
    domSectFns.classList.add("hidden");
    domSectFields.classList.add("hidden");
    domSectSearchResults.classList.add("hidden");
    domSectSearchAllResultsLink.classList.add("hidden");
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

    let currentType = getType(pkg.main);
    curNav.declObjs = [currentType];
    for (let i = 0; i < curNav.declNames.length; i += 1) {
      let childDecl = findSubDecl(currentType, curNav.declNames[i]);
      if (childDecl == null) {
        return render404();
      }

      let childDeclValue = resolveValue(childDecl.value).expr;
      if ("type" in childDeclValue) {
        const t = getType(childDeclValue.type);
        if (t.kind != typeKinds.Fn) {
          childDecl = t;
        }
      }

      currentType = childDecl;
      curNav.declObjs.push(currentType);
    }

    renderNav();

    let last = curNav.declObjs[curNav.declObjs.length - 1];
    let lastIsDecl = isDecl(last);
    let lastIsType = isType(last);
    let lastIsContainerType = isContainerType(last);
      
    if (lastIsDecl){
       renderDocTest(last);  
    }

    if (lastIsContainerType) {
      return renderContainer(last);
    }

    if (!lastIsDecl && !lastIsType) {
      return renderUnknownDecl(last);
    }

    if (lastIsType) {
      return renderType(last);
    }

    if (lastIsDecl && last.kind === "var") {
      return renderVar(last);
    }

    if (lastIsDecl && last.kind === "const") {
      const value = resolveValue(last.value);
      if ("type" in value.expr) {
        let typeObj = getType(value.expr.type);
        if (typeObj.kind === typeKinds.Fn) {
          return renderFn(last);
        }
      }
      return renderValue(last);
    }
    
  }
    
  function renderDocTest(decl) {
    if (!decl.decltest) return;
    const astNode = getAstNode(decl.decltest);
    domSectDocTests.classList.remove("hidden");
    domDocTestsCode.innerHTML = astNode.code;
  }

  function renderUnknownDecl(decl) {
    domDeclNoRef.classList.remove("hidden");

    let docs = getAstNode(decl.src).docs;
    if (docs != null) {
      domTldDocs.innerHTML = markdown(docs);
    } else {
      domTldDocs.innerHTML =
        "<p>There are no doc comments for this declaration.</p>";
    }
    domTldDocs.classList.remove("hidden");
  }

  function typeIsErrSet(typeIndex) {
    let typeObj = getType(typeIndex);
    return typeObj.kind === typeKinds.ErrorSet;
  }

  function typeIsStructWithNoFields(typeIndex) {
    let typeObj = getType(typeIndex);
    if (typeObj.kind !== typeKinds.Struct) return false;
    return typeObj.fields.length == 0;
  }

  function typeIsGenericFn(typeIndex) {
    let typeObj = getType(typeIndex);
    if (typeObj.kind !== typeKinds.Fn) {
      return false;
    }
    return typeObj.generic_ret != null;
  }

  function renderFn(fnDecl) {
    if ("refPath" in fnDecl.value.expr) {
      let last = fnDecl.value.expr.refPath.length - 1;
      let lastExpr = fnDecl.value.expr.refPath[last];
      console.assert("declRef" in lastExpr);
      fnDecl = getDecl(lastExpr.declRef);
    }

    let value = resolveValue(fnDecl.value);
    console.assert("type" in value.expr);
    let typeObj = getType(value.expr.type);

    domFnProtoCode.innerHTML = exprName(value.expr, {
      wantHtml: true,
      wantLink: true,
      fnDecl,
    });

    let docsSource = null;
    let srcNode = getAstNode(fnDecl.src);
    if (srcNode.docs != null) {
      docsSource = srcNode.docs;
    }

    renderFnParamDocs(fnDecl, typeObj);

    let retExpr = resolveValue({ expr: typeObj.ret }).expr;
    if ("type" in retExpr) {
      let retIndex = retExpr.type;
      let errSetTypeIndex = null;
      let retType = getType(retIndex);
      if (retType.kind === typeKinds.ErrorSet) {
        errSetTypeIndex = retIndex;
      } else if (retType.kind === typeKinds.ErrorUnion) {
        errSetTypeIndex = retType.err.type;
      }
      if (errSetTypeIndex != null) {
        let errSetType = getType(errSetTypeIndex);
        renderErrorSet(errSetType);
      }
    }

    let protoSrcIndex = fnDecl.src;
    if (typeIsGenericFn(value.expr.type)) {
      // does the generic_ret contain a container?
      var resolvedGenericRet = resolveValue({ expr: typeObj.generic_ret });

      if ("call" in resolvedGenericRet.expr) {
        let call = zigAnalysis.calls[resolvedGenericRet.expr.call];
        let resolvedFunc = resolveValue({ expr: call.func });
        if (!("type" in resolvedFunc.expr)) return;
        let callee = getType(resolvedFunc.expr.type);
        if (!callee.generic_ret) return;
        resolvedGenericRet = resolveValue({ expr: callee.generic_ret });
      }

      // TODO: see if unwrapping the `as` here is a good idea or not.
      if ("as" in resolvedGenericRet.expr) {
        resolvedGenericRet = {
          expr: zigAnalysis.exprs[resolvedGenericRet.expr.as.exprArg],
        };
      }

      if (!("type" in resolvedGenericRet.expr)) return;
      const genericType = getType(resolvedGenericRet.expr.type);
      if (isContainerType(genericType)) {
        renderContainer(genericType);
      }

      // old code
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

    let protoSrcNode = getAstNode(protoSrcIndex);
    if (
      docsSource == null &&
      protoSrcNode != null &&
      protoSrcNode.docs != null
    ) {
      docsSource = protoSrcNode.docs;
    }
    if (docsSource != null) {
      domTldDocs.innerHTML = markdown(docsSource);
      domTldDocs.classList.remove("hidden");
    }
    domFnProto.classList.remove("hidden");
  }

  function renderFnParamDocs(fnDecl, typeObj) {
    let docCount = 0;

    let fnNode = getAstNode(fnDecl.src);
    let fields = fnNode.fields;
    let isVarArgs = fnNode.varArgs;

    for (let i = 0; i < fields.length; i += 1) {
      let field = fields[i];
      let fieldNode = getAstNode(field);
      if (fieldNode.docs != null) {
        docCount += 1;
      }
    }
    if (docCount == 0) {
      return;
    }

    resizeDomList(domListParams, docCount, "<div></div>");
    let domIndex = 0;

    for (let i = 0; i < fields.length; i += 1) {
      let field = fields[i];
      let fieldNode = getAstNode(field);
      let docs = fieldNode.docs;
      if (fieldNode.docs == null) {
        continue;
      }
      let docsNonEmpty = docs !== "";
      let divDom = domListParams.children[domIndex];
      domIndex += 1;

      let value = typeObj.params[i];
      let preClass = docsNonEmpty ? ' class="fieldHasDocs"' : "";
      let html = "<pre" + preClass + ">" + escapeHtml(fieldNode.name) + ": ";
      if (isVarArgs && i === typeObj.params.length - 1) {
        html += "...";
      } else {
        let name = exprName(value, { wantHtml: false, wantLink: false });
        html += '<span class="tok-kw">' + name + "</span>";
      }

      html += ",</pre>";

      if (docsNonEmpty) {
        html += '<div class="fieldDocs">' + markdown(docs) + "</div>";
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
    let hrefDeclNames = [];
    for (let i = 0; i < curNav.pkgNames.length; i += 1) {
      hrefPkgNames.push(curNav.pkgNames[i]);
      let name = curNav.pkgNames[i];
      if (name == "root") name = zigAnalysis.rootPkgName;
      list.push({
        name: name,
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
      aDom.setAttribute("href", list[i].link);
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
      if (key == zigAnalysis.params.rootName) continue;
      list.push({
        name: key,
        pkg: pkgIndex,
      });
    }

    {
      let aDom = domSectMainPkg.children[1].children[0].children[0];
      aDom.textContent = zigAnalysis.rootPkgName;
      aDom.setAttribute("href", navLinkPkg(zigAnalysis.rootPkg));
      if (zigAnalysis.params.rootName === curNav.pkgNames[0]) {
        aDom.classList.add("active");
      } else {
        aDom.classList.remove("active");
      }
      domSectMainPkg.classList.remove("hidden");
    }

    list.sort(function (a, b) {
      return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
    });

    if (list.length !== 0) {
      resizeDomList(domListPkgs, list.length, '<li><a href="#"></a></li>');
      for (let i = 0; i < list.length; i += 1) {
        let liDom = domListPkgs.children[i];
        let aDom = liDom.children[0];
        aDom.textContent = list[i].name;
        aDom.setAttribute("href", navLinkPkg(list[i].pkg));
        if (list[i].name === curNav.pkgNames[0]) {
          aDom.classList.add("active");
        } else {
          aDom.classList.remove("active");
        }
      }

      domSectPkgs.classList.remove("hidden");
    }
  }

  function navLink(pkgNames, declNames, callName) {
    let base = "#";
    if (curNav.showPrivDecls) {
      base += "*";
    }

    if (pkgNames.length === 0 && declNames.length === 0) {
      return base;
    } else if (declNames.length === 0 && callName == null) {
      return base + pkgNames.join(".");
    } else if (callName == null) {
      return base + pkgNames.join(".") + ";" + declNames.join(".");
    } else {
      return (
        base + pkgNames.join(".") + ";" + declNames.join(".") + ";" + callName
      );
    }
  }

  function navLinkPkg(pkgIndex) {
    return navLink(canonPkgPaths[pkgIndex], []);
  }

  function navLinkDecl(childName) {
    return navLink(curNav.pkgNames, curNav.declNames.concat([childName]));
  }

  //
  //  function navLinkCall(callObj) {
  //      let declNamesCopy = curNav.declNames.concat([]);
  //      let callName = (declNamesCopy.pop());

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

  function resizeDomListDl(dlDom, desiredLen) {
    // add the missing dom entries
    for (let i = dlDom.childElementCount / 2; i < desiredLen; i += 1) {
      dlDom.insertAdjacentHTML("beforeend", "<dt></dt><dd></dd>");
    }
    // remove extra dom entries
    while (desiredLen < dlDom.childElementCount / 2) {
      dlDom.removeChild(dlDom.lastChild);
      dlDom.removeChild(dlDom.lastChild);
    }
  }

  function resizeDomList(listDom, desiredLen, templateHtml) {
    // add the missing dom entries
    for (let i = listDom.childElementCount; i < desiredLen; i += 1) {
      listDom.insertAdjacentHTML("beforeend", templateHtml);
    }
    // remove extra dom entries
    while (desiredLen < listDom.childElementCount) {
      listDom.removeChild(listDom.lastChild);
    }
  }

  function walkResultTypeRef(wr) {
    if (wr.typeRef) return wr.typeRef;
    let resolved = resolveValue(wr);
    if (wr === resolved) {
      return { type: 0 };
    }
    return walkResultTypeRef(resolved);
  }

  function exprName(expr, opts) {
    switch (Object.keys(expr)[0]) {
      default:
        throw "this expression is not implemented yet";
      case "bool": {
        if (expr.bool) {
          return "true";
        }
        return "false";
      }
      case "&": {
        return "&" + exprName(zigAnalysis.exprs[expr["&"]]);
      }
      case "compileError": {
        let compileError = expr.compileError;
        return "@compileError(" + exprName(zigAnalysis.exprs[compileError], opts) + ")";
      }
      case "enumLiteral": {
        let literal = expr.enumLiteral;
        return "." + literal;
      }
      case "void": {
        return "void";
      }
      case "slice": {
        let payloadHtml = "";
        const lhsExpr = zigAnalysis.exprs[expr.slice.lhs];
        const startExpr = zigAnalysis.exprs[expr.slice.start];
        let decl = exprName(lhsExpr);
        let start = exprName(startExpr);
        let end = "";
        let sentinel = "";
        if (expr.slice["end"]) {
          const endExpr = zigAnalysis.exprs[expr.slice.end];
          let end_ = exprName(endExpr);
          end += end_;
        }
        if (expr.slice["sentinel"]) {
          const sentinelExpr = zigAnalysis.exprs[expr.slice.sentinel];
          let sentinel_ = exprName(sentinelExpr);
          sentinel += " :" + sentinel_;
        }
        payloadHtml += decl + "[" + start + ".." + end + sentinel + "]";
        return payloadHtml;
      }
      case "sliceIndex": {
        const sliceIndex = zigAnalysis.exprs[expr.sliceIndex];
        return exprName(sliceIndex, opts);
      }
      case "cmpxchg": {
        const typeIndex = zigAnalysis.exprs[expr.cmpxchg.type];
        const ptrIndex = zigAnalysis.exprs[expr.cmpxchg.ptr];
        const expectedValueIndex =
          zigAnalysis.exprs[expr.cmpxchg.expected_value];
        const newValueIndex = zigAnalysis.exprs[expr.cmpxchg.new_value];
        const successOrderIndex = zigAnalysis.exprs[expr.cmpxchg.success_order];
        const failureOrderIndex = zigAnalysis.exprs[expr.cmpxchg.failure_order];

        const type = exprName(typeIndex, opts);
        const ptr = exprName(ptrIndex, opts);
        const expectedValue = exprName(expectedValueIndex, opts);
        const newValue = exprName(newValueIndex, opts);
        const successOrder = exprName(successOrderIndex, opts);
        const failureOrder = exprName(failureOrderIndex, opts);

        let fnName = "@";

        switch (expr.cmpxchg.name) {
          case "cmpxchg_strong": {
            fnName += "cmpxchgStrong";
            break;
          }
          case "cmpxchg_weak": {
            fnName += "cmpxchgWeak";
            break;
          }
          default: {
            console.log("There's only cmpxchg_strong and cmpxchg_weak");
          }
        }

        return (
          fnName +
          "(" +
          type +
          ", " +
          ptr +
          ", " +
          expectedValue +
          ", " +
          newValue +
          ", " +
          "." +
          successOrder +
          ", " +
          "." +
          failureOrder +
          ")"
        );
      }
      case "cmpxchgIndex": {
        const cmpxchgIndex = zigAnalysis.exprs[expr.cmpxchgIndex];
        return exprName(cmpxchgIndex, opts);
      }
      case "switchOp": {
        let condExpr = zigAnalysis.exprs[expr.switchOp.cond_index];
        let ast = getAstNode(expr.switchOp.src);
        let file_name = expr.switchOp.file_name;
        let outer_decl_index = expr.switchOp.outer_decl;
        let outer_decl = getType(outer_decl_index);
        let line = 0;
        // console.log(expr.switchOp)
        // console.log(outer_decl)
        while (outer_decl_index !== 0 && outer_decl.line_number > 0) {
          line += outer_decl.line_number;
          outer_decl_index = outer_decl.outer_decl;
          outer_decl = getType(outer_decl_index);
          // console.log(outer_decl)
        }
        line += ast.line + 1;
        let payloadHtml = "";
        let cond = exprName(condExpr, opts);

        payloadHtml +=
          "</br>" +
          "node_name: " +
          ast.name +
          "</br>" +
          "file: " +
          file_name +
          "</br>" +
          "line: " +
          line +
          "</br>";
        payloadHtml +=
          "switch(" +
          cond +
          ") {" +
          '<a href="/src/' +
          file_name +
          "#L" +
          line +
          '">' +
          "..." +
          "</a>}";
        return payloadHtml;
      }
      case "switchIndex": {
        const switchIndex = zigAnalysis.exprs[expr.switchIndex];
        return exprName(switchIndex, opts);
      }
      case "refPath": {
        let name = exprName(expr.refPath[0]);
        for (let i = 1; i < expr.refPath.length; i++) {
          let component = undefined;
          if ("string" in expr.refPath[i]) {
            component = expr.refPath[i].string;
          } else {
            component = exprName(expr.refPath[i]);
          }
          name += "." + component;
        }
        return name;
      }
      case "fieldRef": {
        const enumObj = exprName({ type: expr.fieldRef.type }, opts);
        const field =
          getAstNode(enumObj.src).fields[expr.fieldRef.index];
        const name = getAstNode(field).name;
        return name;
      }
      case "enumToInt": {
        const enumToInt = zigAnalysis.exprs[expr.enumToInt];
        return "@enumToInt(" + exprName(enumToInt, opts) + ")";
      }
      case "bitSizeOf": {
        const bitSizeOf = zigAnalysis.exprs[expr.bitSizeOf];
        return "@bitSizeOf(" + exprName(bitSizeOf, opts) + ")";
      }
      case "sizeOf": {
        const sizeOf = zigAnalysis.exprs[expr.sizeOf];
        return "@sizeOf(" + exprName(sizeOf, opts) + ")";
      }
      case "builtinIndex": {
        const builtinIndex = zigAnalysis.exprs[expr.builtinIndex];
        return exprName(builtinIndex, opts);
      }
      case "builtin": {
        const param_expr = zigAnalysis.exprs[expr.builtin.param];
        let param = exprName(param_expr, opts);

        let payloadHtml = "@";
        switch (expr.builtin.name) {
          case "align_of": {
            payloadHtml += "alignOf";
            break;
          }
          case "bool_to_int": {
            payloadHtml += "boolToInt";
            break;
          }
          case "embed_file": {
            payloadHtml += "embedFile";
            break;
          }
          case "error_name": {
            payloadHtml += "errorName";
            break;
          }
          case "panic": {
            payloadHtml += "panic";
            break;
          }
          case "set_cold": {
            payloadHtml += "setCold";
            break;
          }
          case "set_runtime_safety": {
            payloadHtml += "setRuntimeSafety";
            break;
          }
          case "sqrt": {
            payloadHtml += "sqrt";
            break;
          }
          case "sin": {
            payloadHtml += "sin";
            break;
          }
          case "cos": {
            payloadHtml += "cos";
            break;
          }
          case "tan": {
            payloadHtml += "tan";
            break;
          }
          case "exp": {
            payloadHtml += "exp";
            break;
          }
          case "exp2": {
            payloadHtml += "exp2";
            break;
          }
          case "log": {
            payloadHtml += "log";
            break;
          }
          case "log2": {
            payloadHtml += "log2";
            break;
          }
          case "log10": {
            payloadHtml += "log10";
            break;
          }
          case "fabs": {
            payloadHtml += "fabs";
            break;
          }
          case "floor": {
            payloadHtml += "floor";
            break;
          }
          case "ceil": {
            payloadHtml += "ceil";
            break;
          }
          case "trunc": {
            payloadHtml += "trunc";
            break;
          }
          case "round": {
            payloadHtml += "round";
            break;
          }
          case "tag_name": {
            payloadHtml += "tagName";
            break;
          }
          case "reify": {
            payloadHtml += "Type";
            break;
          }
          case "type_name": {
            payloadHtml += "typeName";
            break;
          }
          case "frame_type": {
            payloadHtml += "Frame";
            break;
          }
          case "frame_size": {
            payloadHtml += "frameSize";
            break;
          }
          case "ptr_to_int": {
            payloadHtml += "ptrToInt";
            break;
          }
          case "error_to_int": {
            payloadHtml += "errorToInt";
            break;
          }
          case "int_to_error": {
            payloadHtml += "intToError";
            break;
          }
          case "maximum": {
            payloadHtml += "maximum";
            break;
          }
          case "minimum": {
            payloadHtml += "minimum";
            break;
          }
          case "bit_not": {
            return "~" + param;
          }
          case "clz": {
            return "@clz(T" + ", " + param + ")";
          }
          case "ctz": {
            return "@ctz(T" + ", " + param + ")";
          }
          case "pop_count": {
            return "@popCount(T" + ", " + param + ")";
          }
          case "byte_swap": {
            return "@byteSwap(T" + ", " + param + ")";
          }
          case "bit_reverse": {
            return "@bitReverse(T" + ", " + param + ")";
          }
          default:
            console.log("builtin function not handled yet or doesn't exist!");
        }
        return payloadHtml + "(" + param + ")";
      }
      case "builtinBinIndex": {
        const builtinBinIndex = zigAnalysis.exprs[expr.builtinBinIndex];
        return exprName(builtinBinIndex, opts);
      }
      case "builtinBin": {
        const lhsOp = zigAnalysis.exprs[expr.builtinBin.lhs];
        const rhsOp = zigAnalysis.exprs[expr.builtinBin.rhs];
        let lhs = exprName(lhsOp, opts);
        let rhs = exprName(rhsOp, opts);

        let payloadHtml = "@";
        switch (expr.builtinBin.name) {
          case "float_to_int": {
            payloadHtml += "floatToInt";
            break;
          }
          case "int_to_float": {
            payloadHtml += "intToFloat";
            break;
          }
          case "int_to_ptr": {
            payloadHtml += "intToPtr";
            break;
          }
          case "int_to_enum": {
            payloadHtml += "intToEnum";
            break;
          }
          case "float_cast": {
            payloadHtml += "floatCast";
            break;
          }
          case "int_cast": {
            payloadHtml += "intCast";
            break;
          }
          case "ptr_cast": {
            payloadHtml += "ptrCast";
            break;
          }
          case "truncate": {
            payloadHtml += "truncate";
            break;
          }
          case "align_cast": {
            payloadHtml += "alignCast";
            break;
          }
          case "has_decl": {
            payloadHtml += "hasDecl";
            break;
          }
          case "has_field": {
            payloadHtml += "hasField";
            break;
          }
          case "bit_reverse": {
            payloadHtml += "bitReverse";
            break;
          }
          case "div_exact": {
            payloadHtml += "divExact";
            break;
          }
          case "div_floor": {
            payloadHtml += "divFloor";
            break;
          }
          case "div_trunc": {
            payloadHtml += "divTrunc";
            break;
          }
          case "mod": {
            payloadHtml += "mod";
            break;
          }
          case "rem": {
            payloadHtml += "rem";
            break;
          }
          case "mod_rem": {
            payloadHtml += "rem";
            break;
          }
          case "shl_exact": {
            payloadHtml += "shlExact";
            break;
          }
          case "shr_exact": {
            payloadHtml += "shrExact";
            break;
          }
          case "bitcast": {
            payloadHtml += "bitCast";
            break;
          }
          case "align_cast": {
            payloadHtml += "alignCast";
            break;
          }
          case "vector_type": {
            payloadHtml += "Vector";
            break;
          }
          case "reduce": {
            payloadHtml += "reduce";
            break;
          }
          case "splat": {
            payloadHtml += "splat";
            break;
          }
          case "offset_of": {
            payloadHtml += "offsetOf";
            break;
          }
          case "bit_offset_of": {
            payloadHtml += "bitOffsetOf";
            break;
          }
          default:
            console.log("builtin function not handled yet or doesn't exist!");
        }
        return payloadHtml + "(" + lhs + ", " + rhs + ")";
      }
      case "binOpIndex": {
        const binOpIndex = zigAnalysis.exprs[expr.binOpIndex];
        return exprName(binOpIndex, opts);
      }
      case "binOp": {
        const lhsOp = zigAnalysis.exprs[expr.binOp.lhs];
        const rhsOp = zigAnalysis.exprs[expr.binOp.rhs];
        let lhs = exprName(lhsOp, opts);
        let rhs = exprName(rhsOp, opts);

        let print_lhs = "";
        let print_rhs = "";

        if (lhsOp["binOpIndex"]) {
          print_lhs = "(" + lhs + ")";
        } else {
          print_lhs = lhs;
        }
        if (rhsOp["binOpIndex"]) {
          print_rhs = "(" + rhs + ")";
        } else {
          print_rhs = rhs;
        }

        let operator = "";

        switch (expr.binOp.name) {
          case "add": {
            operator += "+";
            break;
          }
          case "addwrap": {
            operator += "+%";
            break;
          }
          case "add_sat": {
            operator += "+|";
            break;
          }
          case "sub": {
            operator += "-";
            break;
          }
          case "subwrap": {
            operator += "-%";
            break;
          }
          case "sub_sat": {
            operator += "-|";
            break;
          }
          case "mul": {
            operator += "*";
            break;
          }
          case "mulwrap": {
            operator += "*%";
            break;
          }
          case "mul_sat": {
            operator += "*|";
            break;
          }
          case "div": {
            operator += "/";
            break;
          }
          case "shl": {
            operator += "<<";
            break;
          }
          case "shl_sat": {
            operator += "<<|";
            break;
          }
          case "shr": {
            operator += ">>";
            break;
          }
          case "bit_or": {
            operator += "|";
            break;
          }
          case "bit_and": {
            operator += "&";
            break;
          }
          case "array_cat": {
            operator += "++";
            break;
          }
          case "array_mul": {
            operator += "**";
            break;
          }
          case "cmp_eq": {
            operator += "==";
            break;
          }
          case "cmp_neq": {
            operator += "!=";
            break;
          }
          case "cmp_gt": {
            operator += ">";
            break;
          }
          case "cmp_gte": {
            operator += ">=";
            break;
          }
          case "cmp_lt": {
            operator += "<";
            break;
          }
          case "cmp_lte": {
            operator += "<=";
            break;
          }
          default:
            console.log("operator not handled yet or doesn't exist!");
        }

        return print_lhs + " " + operator + " " + print_rhs;
      }
      case "errorSets": {
        const errUnionObj = getType(expr.errorSets);
        let lhs = exprName(errUnionObj.lhs, opts);
        let rhs = exprName(errUnionObj.rhs, opts);
        return lhs + " || " + rhs;
      }
      case "errorUnion": {
        const errUnionObj = getType(expr.errorUnion);
        let lhs = exprName(errUnionObj.lhs, opts);
        let rhs = exprName(errUnionObj.rhs, opts);
        return lhs + "!" + rhs;
      }
      case "struct": {
        // const struct_name =
        //   zigAnalysis.decls[expr.struct[0].val.typeRef.refPath[0].declRef].name;
        const struct_name = ".";
        let struct_body = "";
        struct_body += struct_name + "{ ";
        for (let i = 0; i < expr.struct.length; i++) {
          const fv = expr.struct[i];
          const field_name = fv.name;
          const field_value = exprName(fv.val.expr, opts);
          // TODO: commented out because it seems not needed. if it deals
          //       with a corner case, please add a comment when re-enabling it.
          // let field_value = exprArg[Object.keys(exprArg)[0]];
          // if (field_value instanceof Object) {
          //   value_field = exprName(value_field)
          //     zigAnalysis.decls[value_field[0].val.typeRef.refPath[0].declRef]
          //       .name;
          // }
          struct_body += "." + field_name + " = " + field_value;
          if (i !== expr.struct.length - 1) {
            struct_body += ", ";
          } else {
            struct_body += " ";
          }
        }
        struct_body += "}";
        return struct_body;
      }
      case "typeOf_peer": {
        let payloadHtml = "@TypeOf(";
        for (let i = 0; i < expr.typeOf_peer.length; i++) {
          let elem = zigAnalysis.exprs[expr.typeOf_peer[i]];
          payloadHtml += exprName(elem, { wantHtml: true, wantLink: true });
          if (i !== expr.typeOf_peer.length - 1) {
            payloadHtml += ", ";
          }
        }
        payloadHtml += ")";
        return payloadHtml;
      }
      case "alignOf": {
        const alignRefArg = zigAnalysis.exprs[expr.alignOf];
        let payloadHtml =
          "@alignOf(" +
          exprName(alignRefArg, { wantHtml: true, wantLink: true }) +
          ")";
        return payloadHtml;
      }
      case "typeOf": {
        const typeRefArg = zigAnalysis.exprs[expr.typeOf];
        let payloadHtml =
          "@TypeOf(" +
          exprName(typeRefArg, { wantHtml: true, wantLink: true }) +
          ")";
        return payloadHtml;
      }
      case "typeInfo": {
        const typeRefArg = zigAnalysis.exprs[expr.typeInfo];
        let payloadHtml =
          "@typeInfo(" +
          exprName(typeRefArg, { wantHtml: true, wantLink: true }) +
          ")";
        return payloadHtml;
      }
      case "null": {
        return "null";
      }
      case "array": {
        let payloadHtml = ".{";
        for (let i = 0; i < expr.array.length; i++) {
          if (i != 0) payloadHtml += ", ";
          let elem = zigAnalysis.exprs[expr.array[i]];
          payloadHtml += exprName(elem, opts);
        }
        return payloadHtml + "}";
      }
      case "comptimeExpr": {
        return zigAnalysis.comptimeExprs[expr.comptimeExpr].code;
      }
      case "call": {
        let call = zigAnalysis.calls[expr.call];
        let payloadHtml = "";

        switch (Object.keys(call.func)[0]) {
          default:
            throw "TODO";
          case "declRef":
          case "refPath": {
            payloadHtml += exprName(call.func, opts);
            break;
          }
        }
        payloadHtml += "(";

        for (let i = 0; i < call.args.length; i++) {
          if (i != 0) payloadHtml += ", ";
          payloadHtml += exprName(call.args[i], opts);
        }

        payloadHtml += ")";
        return payloadHtml;
      }
      case "as": {
        // @Check : this should be done in backend because there are legit @as() calls
        // const typeRefArg = zigAnalysis.exprs[expr.as.typeRefArg];
        const exprArg = zigAnalysis.exprs[expr.as.exprArg];
        // return "@as(" + exprName(typeRefArg, opts) +
        //   ", " + exprName(exprArg, opts) + ")";
        return exprName(exprArg, opts);
      }
      case "declRef": {
        return getDecl(expr.declRef).name;
      }
      case "refPath": {
        return expr.refPath.map((x) => exprName(x, opts)).join(".");
      }
      case "int": {
        return "" + expr.int;
      }
      case "float": {
        return "" + expr.float.toFixed(2);
      }
      case "float128": {
        return "" + expr.float128.toFixed(2);
      }
      case "undefined": {
        return "undefined";
      }
      case "string": {
        return '"' + escapeHtml(expr.string) + '"';
      }

      case "int_big": {
        return (expr.int_big.negated ? "-" : "") + expr.int_big.value;
      }

      case "anytype": {
        return "anytype";
      }

      case "this": {
        return "@This()";
      }

      case "type": {
        let name = "";

        let typeObj = expr.type;
        if (typeof typeObj === "number") typeObj = getType(typeObj);
        switch (typeObj.kind) {
          default:
            throw "TODO";
          case typeKinds.Struct: {
            let structObj = typeObj;
            return structObj;
          }
          case typeKinds.Enum: {
            let enumObj = typeObj;
            return enumObj;
          }
          case typeKinds.Opaque: {
            let opaqueObj = typeObj;
            return opaqueObj;
          }
          case typeKinds.ComptimeExpr: {
            return "anyopaque";
          }
          case typeKinds.Array: {
            let arrayObj = typeObj;
            let name = "[";
            let lenName = exprName(arrayObj.len, opts);
            let sentinel = arrayObj.sentinel
              ? ":" + exprName(arrayObj.sentinel, opts)
              : "";
            // let is_mutable = arrayObj.is_multable ? "const " : "";

            if (opts.wantHtml) {
              name +=
                '<span class="tok-number">' + lenName + sentinel + "</span>";
            } else {
              name += lenName + sentinel;
            }
            name += "]";
            // name += is_mutable;
            name += exprName(arrayObj.child, opts);
            return name;
          }
          case typeKinds.Optional:
            return "?" + exprName(typeObj.child, opts);
          case typeKinds.Pointer: {
            let ptrObj = typeObj;
            let sentinel = ptrObj.sentinel
              ? ":" + exprName(ptrObj.sentinel, opts)
              : "";
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
                if (ptrObj.is_ref) {
                  name += "*";
                }
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
            // @check: after the major changes in arrays the consts are came from switch above
            // if (!ptrObj.is_mutable) {
            //     if (opts.wantHtml) {
            //         name += '<span class="tok-kw">const</span> ';
            //     } else {
            //         name += "const ";
            //     }
            // }
            if (ptrObj.is_allowzero) {
              name += "allowzero ";
            }
            if (ptrObj.is_volatile) {
              name += "volatile ";
            }
            if (ptrObj.has_addrspace) {
              name += "addrspace(";
              name += "." + "";
              name += ") ";
            }
            if (ptrObj.has_align) {
              let align = exprName(ptrObj.align, opts);
              if (opts.wantHtml) {
                name += '<span class="tok-kw">align</span>(';
              } else {
                name += "align(";
              }
              if (opts.wantHtml) {
                name += '<span class="tok-number">' + align + "</span>";
              } else {
                name += align;
              }
              if (ptrObj.hostIntBytes != null) {
                name += ":";
                if (opts.wantHtml) {
                  name +=
                    '<span class="tok-number">' +
                    ptrObj.bitOffsetInHost +
                    "</span>";
                } else {
                  name += ptrObj.bitOffsetInHost;
                }
                name += ":";
                if (opts.wantHtml) {
                  name +=
                    '<span class="tok-number">' +
                    ptrObj.hostIntBytes +
                    "</span>";
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
          case typeKinds.Float: {
            let floatObj = typeObj;

            if (opts.wantHtml) {
              return '<span class="tok-type">' + floatObj.name + "</span>";
            } else {
              return floatObj.name;
            }
          }
          case typeKinds.Int: {
            let intObj = typeObj;
            let name = intObj.name;
            if (opts.wantHtml) {
              return '<span class="tok-type">' + name + "</span>";
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
          case typeKinds.ErrorSet: {
            let errSetObj = typeObj;
            if (errSetObj.fields == null) {
              return '<span class="tok-type">anyerror</span>';
            } else if (errSetObj.fields.length == 0) {
              return "error{}";
            } else if (errSetObj.fields.length == 1) {
              return "error{" + errSetObj.fields[0].name + "}";
            } else {
              // throw "TODO";
              let html = "error{ " + errSetObj.fields[0].name;
              for (let i = 1; i < errSetObj.fields.length; i++) html += ", " + errSetObj.fields[i].name;
              html += " }";
              return html;
            }
          }

          case typeKinds.ErrorUnion: {
            let errUnionObj = typeObj;
            let lhs = exprName(errUnionObj.lhs, opts);
            let rhs = exprName(errUnionObj.rhs, opts);
            return lhs + "!" + rhs;
          }
          case typeKinds.InferredErrorUnion: {
            let errUnionObj = typeObj;
            let payload = exprName(errUnionObj.payload, opts);
            return "!" + payload;
          }
          case typeKinds.Fn: {
            let fnObj = typeObj;
            let payloadHtml = "";
            if (opts.wantHtml) {
              if (fnObj.is_extern) {
                payloadHtml += "pub extern ";
              }
              if (fnObj.has_lib_name) {
                payloadHtml += '"' + fnObj.lib_name + '" ';
              }
              payloadHtml += '<span class="tok-kw">fn</span>';
              if (opts.fnDecl) {
                payloadHtml += ' <span class="tok-fn">';
                if (opts.linkFnNameDecl) {
                  payloadHtml +=
                    '<a href="' +
                    opts.linkFnNameDecl +
                    '">' +
                    escapeHtml(opts.fnDecl.name) +
                    "</a>";
                } else {
                  payloadHtml += escapeHtml(opts.fnDecl.name);
                }
                payloadHtml += "</span>";
              }
            } else {
              payloadHtml += "fn ";
            }
            payloadHtml += "(";
            if (fnObj.params) {
              let fields = null;
              let isVarArgs = false;
              let fnNode = getAstNode(fnObj.src);
              fields = fnNode.fields;
              isVarArgs = fnNode.varArgs;

              for (let i = 0; i < fnObj.params.length; i += 1) {
                if (i != 0) {
                  payloadHtml += ", ";
                }

                payloadHtml +=
                  "<span class='argBreaker'><br>&nbsp;&nbsp;&nbsp;&nbsp;</span>";
                let value = fnObj.params[i];
                let paramValue = resolveValue({ expr: value });

                if (fields != null) {
                  let paramNode = getAstNode(fields[i]);

                  if (paramNode.varArgs) {
                    payloadHtml += "...";
                    continue;
                  }

                  if (paramNode.noalias) {
                    if (opts.wantHtml) {
                      payloadHtml += '<span class="tok-kw">noalias</span> ';
                    } else {
                      payloadHtml += "noalias ";
                    }
                  }

                  if (paramNode.comptime) {
                    if (opts.wantHtml) {
                      payloadHtml += '<span class="tok-kw">comptime</span> ';
                    } else {
                      payloadHtml += "comptime ";
                    }
                  }

                  let paramName = paramNode.name;
                  if (paramName != null) {
                    // skip if it matches the type name
                    if (!shouldSkipParamName(paramValue, paramName)) {
                      payloadHtml += paramName + ": ";
                    }
                  }
                }

                if (isVarArgs && i === fnObj.params.length - 1) {
                  payloadHtml += "...";
                } else if ("alignOf" in value) {
                  if (opts.wantHtml) {
                    payloadHtml += '<a href="">';
                    payloadHtml +=
                      '<span class="tok-kw" style="color:lightblue;">' +
                      exprName(value, opts) +
                      "</span>";
                    payloadHtml += "</a>";
                  } else {
                    payloadHtml += exprName(value, opts);
                  }
                } else if ("typeOf" in value) {
                  if (opts.wantHtml) {
                    payloadHtml += '<a href="">';
                    payloadHtml +=
                      '<span class="tok-kw" style="color:lightblue;">' +
                      exprName(value, opts) +
                      "</span>";
                    payloadHtml += "</a>";
                  } else {
                    payloadHtml += exprName(value, opts);
                  }
                } else if ("typeOf_peer" in value) {
                  if (opts.wantHtml) {
                    payloadHtml += '<a href="">';
                    payloadHtml +=
                      '<span class="tok-kw" style="color:lightblue;">' +
                      exprName(value, opts) +
                      "</span>";
                    payloadHtml += "</a>";
                  } else {
                    payloadHtml += exprName(value, opts);
                  }
                } else if ("declRef" in value) {
                  if (opts.wantHtml) {
                    payloadHtml += '<a href="">';
                    payloadHtml +=
                      '<span class="tok-kw" style="color:lightblue;">' +
                      exprName(value, opts) +
                      "</span>";
                    payloadHtml += "</a>";
                  } else {
                    payloadHtml += exprName(value, opts);
                  }
                } else if ("call" in value) {
                  if (opts.wantHtml) {
                    payloadHtml += '<a href="">';
                    payloadHtml +=
                      '<span class="tok-kw" style="color:lightblue;">' +
                      exprName(value, opts) +
                      "</span>";
                    payloadHtml += "</a>";
                  } else {
                    payloadHtml += exprName(value, opts);
                  }
                } else if ("refPath" in value) {
                  if (opts.wantHtml) {
                    payloadHtml += '<a href="">';
                    payloadHtml +=
                      '<span class="tok-kw" style="color:lightblue;">' +
                      exprName(value, opts) +
                      "</span>";
                    payloadHtml += "</a>";
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
                  payloadHtml += '<span class="tok-kw">' + name + "</span>";
                } else if ("binOpIndex" in value) {
                  payloadHtml += exprName(value, opts);
                } else if ("comptimeExpr" in value) {
                  let comptimeExpr =
                    zigAnalysis.comptimeExprs[value.comptimeExpr].code;
                  if (opts.wantHtml) {
                    payloadHtml +=
                      '<span class="tok-kw">' + comptimeExpr + "</span>";
                  } else {
                    payloadHtml += comptimeExpr;
                  }
                } else if (opts.wantHtml) {
                  payloadHtml += '<span class="tok-kw">anytype</span>';
                } else {
                  payloadHtml += "anytype";
                }
              }
            }

            payloadHtml += "<span class='argBreaker'>,<br></span>";
            payloadHtml += ") ";

            if (fnObj.has_align) {
              let align = zigAnalysis.exprs[fnObj.align];
              payloadHtml += "align(" + exprName(align, opts) + ") ";
            }
            if (fnObj.has_cc) {
              let cc = zigAnalysis.exprs[fnObj.cc];
              if (cc) {
                payloadHtml += "callconv(." + cc.enumLiteral + ") ";
              }
            }

            if (fnObj.is_inferred_error) {
              payloadHtml += "!";
            }
            if (fnObj.ret != null) {
              payloadHtml += exprName(fnObj.ret, opts);
            } else if (opts.wantHtml) {
              payloadHtml += '<span class="tok-kw">anytype</span>';
            } else {
              payloadHtml += "anytype";
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

  function shouldSkipParamName(typeRef, paramName) {
    let resolvedTypeRef = resolveValue({ expr: typeRef });
    if ("type" in resolvedTypeRef) {
      let typeObj = getType(resolvedTypeRef.type);
      if (typeObj.kind === typeKinds.Pointer) {
        let ptrObj = typeObj;
        if (getPtrSize(ptrObj) === pointerSizeEnum.One) {
          const value = resolveValue(ptrObj.child);
          return typeValueName(value, false, true).toLowerCase() === paramName;
        }
      }
    }
    return false;
  }

  function getPtrSize(typeObj) {
    return typeObj.size == null ? pointerSizeEnum.One : typeObj.size;
  }

  function renderType(typeObj) {
    let name;
    if (
      rootIsStd &&
      typeObj ===
        getType(zigAnalysis.packages[zigAnalysis.rootPkg].main)
    ) {
      name = "std";
    } else {
      name = exprName({ type: typeObj }, false, false);
    }
    if (name != null && name != "") {
      domHdrName.innerText =
        name + " (" + zigAnalysis.typeKinds[typeObj.kind] + ")";
      domHdrName.classList.remove("hidden");
    }
    if (typeObj.kind == typeKinds.ErrorSet) {
      renderErrorSet(typeObj);
    }
  }

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
      errorList.sort(function (a, b) {
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

  function renderValue(decl) {
    let resolvedValue = resolveValue(decl.value);

    if (resolvedValue.expr.fieldRef) {
      const declRef = decl.value.expr.refPath[0].declRef;
      const type = getDecl(declRef);
      domFnProtoCode.innerHTML =
        '<span class="tok-kw">const</span> ' +
        escapeHtml(decl.name) +
        ": " +
        type.name +
        " = " +
        exprName(decl.value.expr, { wantHtml: true, wantLink: true }) +
        ";";
    } else if (
      resolvedValue.expr.string !== undefined ||
      resolvedValue.expr.call !== undefined ||
      resolvedValue.expr.comptimeExpr
    ) {
      domFnProtoCode.innerHTML =
        '<span class="tok-kw">const</span> ' +
        escapeHtml(decl.name) +
        ": " +
        exprName(resolvedValue.expr, { wantHtml: true, wantLink: true }) +
        " = " +
        exprName(decl.value.expr, { wantHtml: true, wantLink: true }) +
        ";";
    } else if (resolvedValue.expr.compileError) {
      domFnProtoCode.innerHTML =
        '<span class="tok-kw">const</span> ' +
        escapeHtml(decl.name) +
        " = " +
        exprName(decl.value.expr, { wantHtml: true, wantLink: true }) +
        ";";
    } else {
      domFnProtoCode.innerHTML =
        '<span class="tok-kw">const</span> ' +
        escapeHtml(decl.name) +
        ": " +
        exprName(resolvedValue.typeRef, { wantHtml: true, wantLink: true }) +
        " = " +
        exprName(decl.value.expr, { wantHtml: true, wantLink: true }) +
        ";";
    }

    let docs = getAstNode(decl.src).docs;
    if (docs != null) {
      domTldDocs.innerHTML = markdown(docs);
      domTldDocs.classList.remove("hidden");
    }

    domFnProto.classList.remove("hidden");
  }

  function renderVar(decl) {
    let declTypeRef = typeOfDecl(decl);
    domFnProtoCode.innerHTML =
      '<span class="tok-kw">var</span> ' +
      escapeHtml(decl.name) +
      ": " +
      typeValueName(declTypeRef, true, true);

    let docs = getAstNode(decl.src).docs;
    if (docs != null) {
      domTldDocs.innerHTML = markdown(docs);
      domTldDocs.classList.remove("hidden");
    }

    domFnProto.classList.remove("hidden");
  }

  function categorizeDecls(
    decls,
    typesList,
    namespacesList,
    errSetsList,
    fnsList,
    varsList,
    valsList,
    testsList
  ) {
    for (let i = 0; i < decls.length; i += 1) {
      let decl = getDecl(decls[i]);
      let declValue = resolveValue(decl.value);

      // if (decl.isTest) {
      //   testsList.push(decl);
      //   continue;
      // }

      if (decl.kind === "var") {
        varsList.push(decl);
        continue;
      }

      if (decl.kind === "const") {
        if ("type" in declValue.expr) {
          // We have the actual type expression at hand.
          const typeExpr = getType(declValue.expr.type);
          if (typeExpr.kind == typeKinds.Fn) {
            const funcRetExpr = resolveValue({
              expr: typeExpr.ret,
            });
            if (
              "type" in funcRetExpr.expr &&
              funcRetExpr.expr.type == typeTypeId
            ) {
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
        } else if (declValue.typeRef) {
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
  function renderSourceFileLink(decl) {
    let srcNode = getAstNode(decl.src);

    return  "<a style=\"float: right;\" href=\"" +
      sourceFileUrlTemplate.replace("{{file}}",
        zigAnalysis.files[srcNode.file]).replace("{{line}}", srcNode.line + 1) + "\">[src]</a>";
  }

  function renderContainer(container) {
    let typesList = [];

    let namespacesList = [];

    let errSetsList = [];

    let fnsList = [];

    let varsList = [];

    let valsList = [];

    let testsList = [];

    categorizeDecls(
      container.pubDecls,
      typesList,
      namespacesList,
      errSetsList,
      fnsList,
      varsList,
      valsList,
      testsList
    );
    if (curNav.showPrivDecls)
      categorizeDecls(
        container.privDecls,
        typesList,
        namespacesList,
        errSetsList,
        fnsList,
        varsList,
        valsList,
        testsList
      );

    typesList.sort(byNameProperty);
    namespacesList.sort(byNameProperty);
    errSetsList.sort(byNameProperty);
    fnsList.sort(byNameProperty);
    varsList.sort(byNameProperty);
    valsList.sort(byNameProperty);
    testsList.sort(byNameProperty);

    if (container.src != null) {
      let docs = getAstNode(container.src).docs;
      if (docs != null) {
        domTldDocs.innerHTML = markdown(docs);
        domTldDocs.classList.remove("hidden");
      }
    }

    if (typesList.length !== 0) {
      window.x = typesList;
      resizeDomList(
        domListTypes,
        typesList.length,
        '<li><a href="#"></a></li>'
      );
      for (let i = 0; i < typesList.length; i += 1) {
        let liDom = domListTypes.children[i];
        let aDom = liDom.children[0];
        let decl = typesList[i];
        aDom.textContent = decl.name;
        aDom.setAttribute("href", navLinkDecl(decl.name));
      }
      domSectTypes.classList.remove("hidden");
    }
    if (namespacesList.length !== 0) {
      resizeDomList(
        domListNamespaces,
        namespacesList.length,
        '<li><a href="#"></a></li>'
      );
      for (let i = 0; i < namespacesList.length; i += 1) {
        let liDom = domListNamespaces.children[i];
        let aDom = liDom.children[0];
        let decl = namespacesList[i];
        aDom.textContent = decl.name;
        aDom.setAttribute("href", navLinkDecl(decl.name));
      }
      domSectNamespaces.classList.remove("hidden");
    }

    if (errSetsList.length !== 0) {
      resizeDomList(
        domListErrSets,
        errSetsList.length,
        '<li><a href="#"></a></li>'
      );
      for (let i = 0; i < errSetsList.length; i += 1) {
        let liDom = domListErrSets.children[i];
        let aDom = liDom.children[0];
        let decl = errSetsList[i];
        aDom.textContent = decl.name;
        aDom.setAttribute("href", navLinkDecl(decl.name));
      }
      domSectErrSets.classList.remove("hidden");
    }

    if (fnsList.length !== 0) {
      resizeDomList(
        domListFns,
        fnsList.length,
        "<div><dt><div class=\"fnSignature\"></div><div></div></dt><dd></dd></div>"
      );

      for (let i = 0; i < fnsList.length; i += 1) {
        let decl = fnsList[i];
        let trDom = domListFns.children[i];

        let tdFnSignature = trDom.children[0].children[0];
        let tdFnSrc = trDom.children[0].children[1];
        let tdDesc = trDom.children[1];

        let declType = resolveValue(decl.value);
        console.assert("type" in declType.expr);
        tdFnSignature.innerHTML = exprName(declType.expr, {
          wantHtml: true,
          wantLink: true,
          fnDecl: decl,
          linkFnNameDecl: navLinkDecl(decl.name),
        });
        tdFnSrc.innerHTML = renderSourceFileLink(decl);

        let docs = getAstNode(decl.src).docs;
        if (docs != null) {
          tdDesc.innerHTML = shortDescMarkdown(docs);
        } else {
          tdDesc.textContent = "";
        }
      }
      domSectFns.classList.remove("hidden");
    }

    let containerNode = getAstNode(container.src);
    if (containerNode.fields && containerNode.fields.length > 0) {
      resizeDomList(domListFields, containerNode.fields.length, "<div></div>");

      for (let i = 0; i < containerNode.fields.length; i += 1) {
        let fieldNode = getAstNode(containerNode.fields[i]);
        let divDom = domListFields.children[i];
        let fieldName = fieldNode.name;
        let docs = fieldNode.docs;
        let docsNonEmpty = docs != null && docs !== "";
        let extraPreClass = docsNonEmpty ? " fieldHasDocs" : "";

        let html =
          '<div class="mobile-scroll-container"><pre class="scroll-item' +
          extraPreClass +
          '">' +
          escapeHtml(fieldName);

        if (container.kind === typeKinds.Enum) {
          html += ' = <span class="tok-number">' + fieldName + "</span>";
        } else {
          let fieldTypeExpr = container.fields[i];
          html += ": ";
          let name = exprName(fieldTypeExpr, false, false);
          html += '<span class="tok-kw">' + name + "</span>";
          let tsn = typeShorthandName(fieldTypeExpr);
          if (tsn) {
            html += "<span> (" + tsn + ")</span>";
          }
        }

        html += ",</pre></div>";

        if (docsNonEmpty) {
          html += '<div class="fieldDocs">' + markdown(docs) + "</div>";
        }
        divDom.innerHTML = html;
      }
      domSectFields.classList.remove("hidden");
    }

    if (varsList.length !== 0) {
      resizeDomList(
        domListGlobalVars,
        varsList.length,
        '<tr><td><a href="#"></a></td><td></td><td></td></tr>'
      );
      for (let i = 0; i < varsList.length; i += 1) {
        let decl = varsList[i];
        let trDom = domListGlobalVars.children[i];

        let tdName = trDom.children[0];
        let tdNameA = tdName.children[0];
        let tdType = trDom.children[1];
        let tdDesc = trDom.children[2];

        tdNameA.setAttribute("href", navLinkDecl(decl.name));
        tdNameA.textContent = decl.name;

        tdType.innerHTML = typeValueName(typeOfDecl(decl), true, true);

        let docs = getAstNode(decl.src).docs;
        if (docs != null) {
          tdDesc.innerHTML = shortDescMarkdown(docs);
        } else {
          tdDesc.textContent = "";
        }
      }
      domSectGlobalVars.classList.remove("hidden");
    }

    if (valsList.length !== 0) {
      resizeDomList(
        domListValues,
        valsList.length,
        '<tr><td><a href="#"></a></td><td></td><td></td></tr>'
      );
      for (let i = 0; i < valsList.length; i += 1) {
        let decl = valsList[i];
        let trDom = domListValues.children[i];

        let tdName = trDom.children[0];
        let tdNameA = tdName.children[0];
        let tdType = trDom.children[1];
        let tdDesc = trDom.children[2];

        tdNameA.setAttribute("href", navLinkDecl(decl.name));
        tdNameA.textContent = decl.name;

        tdType.innerHTML = exprName(walkResultTypeRef(decl.value), {
          wantHtml: true,
          wantLink: true,
        });

        let docs = getAstNode(decl.src).docs;
        if (docs != null) {
          tdDesc.innerHTML = shortDescMarkdown(docs);
        } else {
          tdDesc.textContent = "";
        }
      }
      domSectValues.classList.remove("hidden");
    }

    if (testsList.length !== 0) {
      resizeDomList(
        domListTests,
        testsList.length,
        '<tr><td><a href="#"></a></td><td></td><td></td></tr>'
      );
      for (let i = 0; i < testsList.length; i += 1) {
        let decl = testsList[i];
        let trDom = domListTests.children[i];

        let tdName = trDom.children[0];
        let tdNameA = tdName.children[0];
        let tdType = trDom.children[1];
        let tdDesc = trDom.children[2];

        tdNameA.setAttribute("href", navLinkDecl(decl.name));
        tdNameA.textContent = decl.name;

        tdType.innerHTML = exprName(walkResultTypeRef(decl.value), {
          wantHtml: true,
          wantLink: true,
        });

        let docs = getAstNode(decl.src).docs;
        if (docs != null) {
          tdDesc.innerHTML = shortDescMarkdown(docs);
        } else {
          tdDesc.textContent = "";
        }
      }
      domSectTests.classList.remove("hidden");
    }
  }

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
    let map = {};
    for (let i = 0; i < zigAnalysis.typeKinds.length; i += 1) {
      map[zigAnalysis.typeKinds[i]] = i;
    }
    // This is just for debugging purposes, not needed to function
    let assertList = [
      "Type",
      "Void",
      "Bool",
      "NoReturn",
      "Int",
      "Float",
      "Pointer",
      "Array",
      "Struct",
      "ComptimeFloat",
      "ComptimeInt",
      "Undefined",
      "Null",
      "Optional",
      "ErrorUnion",
      "ErrorSet",
      "Enum",
      "Union",
      "Fn",
      "BoundFn",
      "Opaque",
      "Frame",
      "AnyFrame",
      "Vector",
      "EnumLiteral",
    ];
    for (let i = 0; i < assertList.length; i += 1) {
      if (map[assertList[i]] == null)
        throw new Error("No type kind '" + assertList[i] + "' found");
    }
    return map;
  }

  function findTypeTypeId() {
    for (let i = 0; i < zigAnalysis.types.length; i += 1) {
      if (getType(i).kind == typeKinds.Type) {
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

    if (location.hash[0] === "#" && location.hash.length > 1) {
      let query = location.hash.substring(1);
      if (query[0] === "*") {
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
  }

  function onHashChange() {
    updateCurNav();
    if (domSearch.value !== curNavSearch) {
      domSearch.value = curNavSearch;
      if (domSearch.value.length == 0)
        domSearchPlaceholder.classList.remove("hidden");
      else
        domSearchPlaceholder.classList.add("hidden");
    }
    render();
    if (imFeelingLucky) {
      imFeelingLucky = false;
      activateSelectedResult();
    }
  }

  function findSubDecl(parentType, childName) {
    {
      // Generic functions
      if ("value" in parentType) {
        const rv = resolveValue(parentType.value);
        if ("type" in rv.expr) {
          const t = getType(rv.expr.type);
          if (t.kind == typeKinds.Fn && t.generic_ret != null) {
            const rgr = resolveValue({ expr: t.generic_ret });
            if ("type" in rgr.expr) {
              parentType = getType(rgr.expr.type);
            }
          }
        }
      }
    }

    if (!parentType.pubDecls) return null;
    for (let i = 0; i < parentType.pubDecls.length; i += 1) {
      let declIndex = parentType.pubDecls[i];
      let childDecl = getDecl(declIndex);
      if (childDecl.name === childName) {
        return childDecl;
      }
    }
    if (!parentType.privDecls) return null;
    for (let i = 0; i < parentType.privDecls.length; i += 1) {
      let declIndex = parentType.privDecls[i];
      let childDecl = getDecl(declIndex);
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
    let stack = [
      {
        path: [],
        pkg: rootPkg,
      },
    ];
    while (stack.length !== 0) {
      let item = stack.shift();
      for (let key in item.pkg.table) {
        let childPkgIndex = item.pkg.table[key];
        if (list[childPkgIndex] != null) continue;
        let childPkg = zigAnalysis.packages[childPkgIndex];
        if (childPkg == null) continue;

        let newPath = item.path.concat([key]);
        list[childPkgIndex] = newPath;
        stack.push({
          path: newPath,
          pkg: childPkg,
        });
      }
    }
    return list;
  }

  function computeCanonDeclPaths() {
    let list = new Array(zigAnalysis.decls.length);
    canonTypeDecls = new Array(zigAnalysis.types.length);

    for (let pkgI = 0; pkgI < zigAnalysis.packages.length; pkgI += 1) {
      if (pkgI === zigAnalysis.rootPkg && rootIsStd) continue;
      let pkg = zigAnalysis.packages[pkgI];
      let pkgNames = canonPkgPaths[pkgI];
      if (pkgNames === undefined) continue;

      let stack = [
        {
          declNames: [],
          type: getType(pkg.main),
        },
      ];
      while (stack.length !== 0) {
        let item = stack.shift();

        if (isContainerType(item.type)) {
          let t = item.type;

          let len = t.pubDecls ? t.pubDecls.length : 0;
          for (let declI = 0; declI < len; declI += 1) {
            let mainDeclIndex = t.pubDecls[declI];
            if (list[mainDeclIndex] != null) continue;

            let decl = getDecl(mainDeclIndex);
            let declVal = resolveValue(decl.value);
            let declNames = item.declNames.concat([decl.name]);
            list[mainDeclIndex] = {
              pkgNames: pkgNames,
              declNames: declNames,
            };
            if ("type" in declVal.expr) {
              let value = getType(declVal.expr.type);
              if (declCanRepresentTypeKind(value.kind)) {
                canonTypeDecls[declVal.type] = mainDeclIndex;
              }

              if (isContainerType(value)) {
                stack.push({
                  declNames: declNames,
                  type: value,
                });
              }

              // Generic function
              if (value.kind == typeKinds.Fn && value.generic_ret != null) {
                let resolvedVal = resolveValue({ expr: value.generic_ret });
                if ("type" in resolvedVal.expr) {
                  let generic_type = getType(resolvedVal.expr.type);
                  if (isContainerType(generic_type)) {
                    stack.push({
                      declNames: declNames,
                      type: generic_type,
                    });
                  }
                }
              }
            }
          }
        }
      }
    }
    return list;
  }

  function getCanonDeclPath(index) {
    if (canonDeclPaths == null) {
      canonDeclPaths = computeCanonDeclPaths();
    }
    //let cd = (canonDeclPaths);
    return canonDeclPaths[index];
  }

  function getCanonTypeDecl(index) {
    getCanonDeclPath(0);
    //let ct = (canonTypeDecls);
    return canonTypeDecls[index];
  }

  function escapeHtml(text) {
    return text.replace(/[&"<>]/g, function (m) {
      return escapeHtmlReplacements[m];
    });
  }

  function shortDescMarkdown(docs) {
    const trimmed_docs = docs.trim();
    let index = trimmed_docs.indexOf("\n\n");
    let cut = false;

    if (index < 0 || index > 80) {
        if (trimmed_docs.length > 80) {
            index = 80;
            cut = true;
        } else {
            index = trimmed_docs.length;
        }
    }

    let slice = trimmed_docs.slice(0, index);
    if (cut) slice += "...";
    return markdown(slice);
  }

  function markdown(input) {
    const raw_lines = input.split("\n"); // zig allows no '\r', so we don't need to split on CR

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
        while (
          line.indent < line.raw_text.length &&
          line.raw_text[line.indent] == " "
        ) {
          line.indent += 1;
        }

        if (line.text.startsWith("######")) {
          line.type = "h6";
          line.text = line.text.substr(6);
        } else if (line.text.startsWith("#####")) {
          line.type = "h5";
          line.text = line.text.substr(5);
        } else if (line.text.startsWith("####")) {
          line.type = "h4";
          line.text = line.text.substr(4);
        } else if (line.text.startsWith("###")) {
          line.type = "h3";
          line.text = line.text.substr(3);
        } else if (line.text.startsWith("##")) {
          line.type = "h2";
          line.text = line.text.substr(2);
        } else if (line.text.startsWith("#")) {
          line.type = "h1";
          line.text = line.text.substr(1);
        } else if (line.text.startsWith("-")) {
          line.type = "ul";
          line.text = line.text.substr(1);
        } else if (line.text.match(/^\d+\..*$/)) {
          // if line starts with {number}{dot}
          const match = line.text.match(/(\d+)\./);
          line.type = "ul";
          line.text = line.text.substr(match[0].length);
          line.ordered_number = Number(match[1].length);
        } else if (line.text == "```") {
          line.type = "skip";
          is_reading_code = true;
          code_indent = line.indent;
        } else if (line.text == "") {
          line.type = "empty";
        }
      } else {
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
        },
      ];

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
            if (
              currentRun[0] == " " &&
              currentRun[currentRun.length - 1] == " "
            ) {
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
          for (
            let idx = stack.length > 0 ? -1 : 0;
            idx < formats.length;
            idx++
          ) {
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
        const fmt = stack.pop();
        innerHTML += "</" + fmt.tag + ">";
      }

      return innerHTML;
    }

    function previousLineIs(type, line_no) {
      if (line_no > 0) {
        return lines[line_no - 1].type == type;
      } else {
        return false;
      }
    }

    function nextLineIs(type, line_no) {
      if (line_no < lines.length - 1) {
        return lines[line_no + 1].type == type;
      } else {
        return false;
      }
    }

    function getPreviousLineIndent(line_no) {
      if (line_no > 0) {
        return lines[line_no - 1].indent;
      } else {
        return 0;
      }
    }

    function getNextLineIndent(line_no) {
      if (line_no < lines.length - 1) {
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
          html +=
            "<" +
            line.type +
            ">" +
            markdownInlines(line.text) +
            "</" +
            line.type +
            ">\n";
          break;

        case "ul":
        case "ol":
          if (
            !previousLineIs("ul", line_no) ||
            getPreviousLineIndent(line_no) < line.indent
          ) {
            html += "<" + line.type + ">\n";
          }

          html += "<li>" + markdownInlines(line.text) + "</li>\n";

          if (
            !nextLineIs("ul", line_no) ||
            getNextLineIndent(line_no) < line.indent
          ) {
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
      location.href = aDom.getAttribute("href");
      curSearchIndex = -1;
    }
    domSearch.blur();
  }

  // hide the modal if it's visible or return to the previous result page and unfocus the search
  function onEscape(ev) {
    if (!domHelpModal.classList.contains("hidden")) {
      domHelpModal.classList.add("hidden");
      ev.preventDefault();
      ev.stopPropagation();
    } else {
      domSearch.value = "";
      domSearch.blur();
      domSearchPlaceholder.classList.remove("hidden");
      curSearchIndex = -1;
      ev.preventDefault();
      ev.stopPropagation();
      startSearch();
    }
  }

  function onSearchKeyDown(ev) {
    switch (getKeyString(ev)) {
      case "Enter":
        // detect if this search changes anything
        let terms1 = getSearchTerms();
        startSearch();
        updateCurNav();
        let terms2 = getSearchTerms();
        // we might have to wait for onHashChange to trigger
        imFeelingLucky = terms1.join(" ") !== terms2.join(" ");
        if (!imFeelingLucky) activateSelectedResult();

        ev.preventDefault();
        ev.stopPropagation();
        return;
      case "Esc":
        onEscape(ev);
        return
      case "Up":
        moveSearchCursor(-1);
        ev.preventDefault();
        ev.stopPropagation();
        return;
      case "Down":
        // TODO: make the page scroll down if the search cursor is out of the screen
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

  function moveSearchCursor(dir) {
    if (
      curSearchIndex < 0 ||
      curSearchIndex >= domListSearchResults.children.length
    ) {
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
        name =
          ev.key != null
            ? ev.key
            : String.fromCharCode(ev.charCode || ev.keyCode);
    }
    if (!ignoreShift && ev.shiftKey) name = "Shift+" + name;
    if (ev.altKey) name = "Alt+" + name;
    if (ev.ctrlKey) name = "Ctrl+" + name;
    return name;
  }

  function onWindowKeyDown(ev) {
    switch (getKeyString(ev)) {
      case "Esc":
        onEscape(ev);
        break;
      case "s":
        if (domHelpModal.classList.contains("hidden")) {
          if (ev.target == domSearch) break;

          domSearch.focus();
          domSearch.select();
          domDocs.scrollTo(0, 0);
          ev.preventDefault();
          ev.stopPropagation();
          startAsyncSearch();
        }
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
    domHelpModal.style.left =
      window.innerWidth / 2 - domHelpModal.clientWidth / 2 + "px";
    domHelpModal.style.top =
      window.innerHeight / 2 - domHelpModal.clientHeight / 2 + "px";
    domHelpModal.focus();
    domSearch.blur();
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
    let newPart2 = domSearch.value === "" ? "" : "?" + domSearch.value;
    location.replace(parts.length === 1 ? oldHash + newPart2 : parts[0] + newPart2);
  }
  function getSearchTerms() {
    let list = curNavSearch.trim().split(/[ \r\n\t]+/);
    list.sort();
    return list;
  }

  function renderSearch() {
    let matchedItems = [];
    let ignoreCase = curNavSearch.toLowerCase() === curNavSearch;
    let terms = getSearchTerms();

    decl_loop: for (
      let declIndex = 0;
      declIndex < zigAnalysis.decls.length;
      declIndex += 1
    ) {
      let canonPath = getCanonDeclPath(declIndex);
      if (canonPath == null) continue;

      let decl = getDecl(declIndex);
      let lastPkgName = canonPath.pkgNames[canonPath.pkgNames.length - 1];
      let fullPathSearchText =
        lastPkgName + "." + canonPath.declNames.join(".");
      let astNode = getAstNode(decl.src);
      let fileAndDocs = ""; //zigAnalysis.files[astNode.file];
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
      matchedItems.sort(function (a, b) {
        let cmp = operatorCompare(b.points, a.points);
        if (cmp != 0) return cmp;
        return operatorCompare(a.decl.name, b.decl.name);
      });

      let searchTrimmed = false;
      const searchTrimResultsMaxItems = 200;
      if (searchTrimResults && matchedItems.length > searchTrimResultsMaxItems) {
        matchedItems = matchedItems.slice(0, searchTrimResultsMaxItems);
        searchTrimmed = true;
      }

      // Build up the list of search results
      let matchedItemsHTML = "";

      for (let i = 0; i < matchedItems.length; i += 1) {
        const match = matchedItems[i];
        const lastPkgName = match.path.pkgNames[match.path.pkgNames.length - 1];

        const text = lastPkgName + "." + match.path.declNames.join(".");
        const href = navLink(match.path.pkgNames, match.path.declNames);

        matchedItemsHTML += "<li><a href=\"" + href + "\">" + text + "</a></li>";
      }

      // Replace the search results using our newly constructed HTML string
      domListSearchResults.innerHTML = matchedItemsHTML;
      if (searchTrimmed) {
        domSectSearchAllResultsLink.classList.remove("hidden");
      }
      renderSearchCursor();

      domSectSearchResults.classList.remove("hidden");
    } else {
      domSectSearchNoResults.classList.remove("hidden");
    }
  }

  function renderSearchCursor() {
    for (let i = 0; i < domListSearchResults.children.length; i += 1) {
      let liDom = domListSearchResults.children[i];
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

  function byNameProperty(a, b) {
    return operatorCompare(a.name, b.name);
  }


  function getDecl(idx) {
    const decl = zigAnalysis.decls[idx];
    return {
      name: decl[0],
      kind: decl[1],
      src: decl[2],
      value: decl[3],
      decltest: decl[4],
    };
  }
  
  function getAstNode(idx) {
    const ast = zigAnalysis.astNodes[idx];
    return {
      file: ast[0],
      line: ast[1],
      col: ast[2],
      name: ast[3],
      code: ast[4],
      docs: ast[5],
      fields: ast[6],
      comptime: ast[7],
    };
  }
  
  function getType(idx){
    const ty = zigAnalysis.types[idx];
    switch(ty[0]) {
    default: 
      throw "unhandled type kind!";
    case 0: // Unanalyzed
      throw "unanalyzed type!";
    case 1: // Type
    case 2: // Void 
    case 3: //  Bool
    case 4: //  NoReturn
    case 5: //  Int
    case 6: //  Float
      return { kind: ty[0], name: ty[1]};
    case 7: // Pointer
      return {
        kind: ty[0],
        size: ty[1],
        child: ty[2],
        sentinel: ty[3],
        align: ty[4],
        address_space: ty[5],
        bit_start: ty[6],
        host_size: ty[7],
        is_ref: ty[8],
        is_allowzero: ty[9],
        is_mutable: ty[10],
        is_volatile: ty[11],
        has_sentinel: ty[12],
        has_align: ty[13],
        has_addrspace: ty[14],
        has_bit_range: ty[15],
      };
    case 8: // Array
      return {
        kind: ty[0],
        len: ty[1],
        child: ty[2],
        sentinel: ty[3],
      };
    case 9: // Struct
      return {
        kind: ty[0],
        name: ty[1],
        src: ty[2],
        privDecls: ty[3],
        pubDecls: ty[4],
        fields: ty[5],
        line_number: ty[6],
        outer_decl: ty[7],
      };
    case 10: // ComptimeExpr
    case 11: // ComptimeFloat
    case 12: // ComptimeInt
    case 13: // Undefined
    case 14: // Null
      return { kind: ty[0], name: ty[1] };
    case 15: // Optional
      return {
        kind: ty[0],
        name: ty[1],
        child: ty[2],
      };
    case 16: // ErrorUnion
      return {
        kind: ty[0],
        lhs: ty[1],
        rhs: ty[2],
      };
    case 17: // InferredErrorUnion
      return {
        kind: ty[0],
        payload: ty[1],
      };
    case 18: // ErrorSet
      return {
        kind: ty[0],
        name: ty[1],
        fields: ty[2],
      };
    case 19: // Enum
      return {
        kind: ty[0],
        name: ty[1],
        src: ty[2],
        privDecls: ty[3],
        pubDecls: ty[4],
      };
    case 20: // Union
      return {
        kind: ty[0],
        name: ty[1],
        src: ty[2],
        privDecls: ty[3],
        pubDecls: ty[4],
        fields: ty[5],
      };    
    case 21: // Fn
      return {
        kind: ty[0],
        name: ty[1],
        src: ty[2],
        ret: ty[3],
        generic_ret: ty[4],
        params: ty[5],
        lib_name: ty[6],
        is_var_args: ty[7],
        is_inferred_error: ty[8],
        has_lib_name: ty[9],
        has_cc: ty[10],
        cc: ty[11],
        align: ty[12],
        has_align: ty[13],
        is_test: ty[14],
        is_extern: ty[15],
      };
    case 22: // BoundFn
      return { kind: ty[0], name: ty[1] };
    case 23: // Opaque
      return {
        kind: ty[0],
        name: ty[1],
        src: ty[2],
        privDecls: ty[3],
        pubDecls: ty[4],
      };
    case 24: // Frame
    case 25: // AnyFrame
    case 26: // Vector
    case 27: // EnumLiteral
      return { kind: ty[0], name: ty[1] };
    }
  }
  
})();



