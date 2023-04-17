"use strict";

var zigAnalysis;

const NAV_MODES = {
  API: "#A;",
  API_INTERNAL: "#a;",
  GUIDES: "#G;",
};

(function () {
  const domStatus = document.getElementById("status");
  const domSectNav = document.getElementById("sectNav");
  const domListNav = document.getElementById("listNav");
  const domApiSwitch = document.getElementById("ApiSwitch");
  const domGuideSwitch = document.getElementById("guideSwitch");
  const domGuidesMenu = document.getElementById("guidesMenu");
  const domApiMenu = document.getElementById("apiMenu");
  const domGuidesList = document.getElementById("guidesList");
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
  const domFnSourceLink = document.getElementById("fnSourceLink");
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
  const domGuides = document.getElementById("guides");
  const domListSearchResults = document.getElementById("listSearchResults");
  const domSectSearchNoResults = document.getElementById("sectSearchNoResults");
  const domSectInfo = document.getElementById("sectInfo");
  // const domTdTarget = (document.getElementById("tdTarget"));
  const domPrivDeclsBox = document.getElementById("privDeclsBox");
  const domTdZigVer = document.getElementById("tdZigVer");
  const domHdrName = document.getElementById("hdrName");
  const domHelpModal = document.getElementById("helpModal");
  const domSearchPlaceholder = document.getElementById("searchPlaceholder");
  const sourceFileUrlTemplate = "src/{{file}}.html#L{{line}}"
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
    mode: NAV_MODES.API,
    activeGuide: "",
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
    location.hash = "#A;";
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
    let suffix = " - Zig";
    switch (curNav.mode) {
      case NAV_MODES.API:
      case NAV_MODES.API_INTERNAL:
        let list = curNav.pkgNames.concat(curNav.declNames);
        if (list.length === 0) {
          document.title = zigAnalysis.packages[zigAnalysis.rootPkg].name + suffix;
        } else {
          document.title = list.join(".") + suffix;
        }
        return;
      case NAV_MODES.GUIDES:
        document.title = "[G] " + curNav.activeGuide + suffix;
        return;
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
  function renderGuides() {
    renderTitle();

    // set guide mode
    domGuideSwitch.classList.add("active");
    domApiSwitch.classList.remove("active");
    domDocs.classList.add("hidden");
    domGuides.classList.remove("hidden");
    domApiMenu.classList.add("hidden");

    // sidebar guides list
    const section_list = zigAnalysis.guide_sections;
    resizeDomList(domGuidesList, section_list.length, '<div><h2><span></span></h2><ul class="packages"></ul></div>');
    for (let j = 0; j < section_list.length; j += 1) {
        const section = section_list[j];
        const domSectionName = domGuidesList.children[j].children[0].children[0];
        const domGuides = domGuidesList.children[j].children[1];
        domSectionName.textContent = section.name;
        resizeDomList(domGuides, section.guides.length, '<li><a href="#"></a></li>');
        for (let i = 0; i < section.guides.length; i += 1) {
          const guide = section.guides[i];
          let liDom = domGuides.children[i];
          let aDom = liDom.children[0];
          aDom.textContent = guide.name;
          aDom.setAttribute("href", NAV_MODES.GUIDES + guide.name);
          if (guide.name === curNav.activeGuide) {
            aDom.classList.add("active");
          } else {
            aDom.classList.remove("active");
          }
        }
    }
  
    if (section_list.length > 0) {
      domGuidesMenu.classList.remove("hidden");
    }

    // main content
    let activeGuide = undefined;
    outer: for (let i = 0; i < zigAnalysis.guide_sections.length; i += 1) {
      const section = zigAnalysis.guide_sections[i];
      for (let j = 0; j < section.guides.length; j += 1) {
        const guide = section.guides[j];
        if (guide.name == curNav.activeGuide) {
          activeGuide = guide;
          break outer;
        }
      }
    }        
    
    if (activeGuide == undefined) {
      const root_file_idx = zigAnalysis.packages[zigAnalysis.rootPkg].file;
      const root_file_name = zigAnalysis.files[root_file_idx];
      domGuides.innerHTML = markdown(`
          # Zig Guides
          These autodocs don't contain any guide.

          While the API section is a reference guide autogenerated from Zig source code,
          guides are meant to be handwritten explanations that provide for example:

          - how-to explanations for common use-cases 
          - technical documentation 
          - information about advanced usage patterns
          
          You can add guides by specifying which markdown files to include
          in the top level doc comment of your root file, like so:

          (At the top of \`${root_file_name}\`)
          \`\`\`
          //!zig-autodoc-guide: intro.md
          //!zig-autodoc-guide: quickstart.md
          //!zig-autodoc-section: Advanced topics
          //!zig-autodoc-guide: ../advanced-docs/advanced-stuff.md
          \`\`\`
        
          **Note that this feature is still under heavy development so expect bugs**
          **and missing features!**

          Happy writing!
        `);
    } else {
      domGuides.innerHTML = markdown(activeGuide.body);
    }
  }

  function renderApi() {
    // set Api mode
    domApiSwitch.classList.add("active");
    domGuideSwitch.classList.remove("active");
    domGuides.classList.add("hidden");
    domDocs.classList.remove("hidden");
    domApiMenu.classList.remove("hidden");
    domGuidesMenu.classList.add("hidden");

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

    domPrivDeclsBox.checked = curNav.mode == NAV_MODES.API_INTERNAL;

    if (curNavSearch !== "") {
      return renderSearch();
    }

    let rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
    let pkg = rootPkg;
    curNav.pkgObjs = [pkg];
    for (let i = 1; i < curNav.pkgNames.length; i += 1) {
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



    window.x = currentType;

    renderNav();

    let last = curNav.declObjs[curNav.declObjs.length - 1];
    let lastIsDecl = isDecl(last);
    let lastIsType = isType(last);
    let lastIsContainerType = isContainerType(last);

    if (lastIsDecl) {
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

  function render() {
    switch (curNav.mode) {
      case NAV_MODES.API:
      case NAV_MODES.API_INTERNAL:
        return renderApi();
      case NAV_MODES.GUIDES:
        return renderGuides();
      default:
        throw "?";
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
    return typeObj.field_types.length == 0;
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

    domFnSourceLink.innerHTML = "[<a target=\"_blank\" href=\"" + sourceFileLink(fnDecl) + "\">src</a>]";

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
      domTldDocs.innerHTML = markdown(docsSource, fnDecl);
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
    const rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
    let list = [];
    for (let key in rootPkg.table) {
      let pkgIndex = rootPkg.table[key];
      if (zigAnalysis.packages[pkgIndex] == null) continue;
      if (key == rootPkg.name) continue;
      list.push({
        name: key,
        pkg: pkgIndex,
      });
    }

    {
      let aDom = domSectMainPkg.children[1].children[0].children[0];
      aDom.textContent = rootPkg.name;
      aDom.setAttribute("href", navLinkPkg(zigAnalysis.rootPkg));
      if (rootPkg.name === curNav.pkgNames[0]) {
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
    let base = curNav.mode;

    if (pkgNames.length === 0 && declNames.length === 0) {
      return base;
    } else if (declNames.length === 0 && callName == null) {
      return base + pkgNames.join(".");
    } else if (callName == null) {
      return base + pkgNames.join(".") + ":" + declNames.join(".");
    } else {
      return (
        base + pkgNames.join(".") + ":" + declNames.join(".") + ";" + callName
      );
    }
  }

  function navLinkPkg(pkgIndex) {
    return navLink(canonPkgPaths[pkgIndex], []);
  }

  function navLinkDecl(childName) {
    return navLink(curNav.pkgNames, curNav.declNames.concat([childName]));
  }

  function findDeclNavLink(declName) {
    if (curNav.declObjs.length == 0) return null;
    const curFile = getAstNode(curNav.declObjs[curNav.declObjs.length - 1].src).file;

    for (let i = curNav.declObjs.length - 1; i >= 0; i--) {
      const curDecl = curNav.declObjs[i];
      const curDeclName = curNav.declNames[i - 1];
      if (curDeclName == declName) {
        const declPath = curNav.declNames.slice(0, i);
        return navLink(curNav.pkgNames, declPath);
      }

      if (findSubDecl(curDecl, declName) != null) {
        const declPath = curNav.declNames.slice(0, i).concat([declName]);
        return navLink(curNav.pkgNames, declPath);
      }
    }

    //throw("could not resolve links for '" + declName + "'");
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
        return "&" + exprName(zigAnalysis.exprs[expr["&"]], opts);
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
        let decl = exprName(lhsExpr, opts);
        let start = exprName(startExpr, opts);
        let end = "";
        let sentinel = "";
        if (expr.slice["end"]) {
          const endExpr = zigAnalysis.exprs[expr.slice.end];
          let end_ = exprName(endExpr, opts);
          end += end_;
        }
        if (expr.slice["sentinel"]) {
          const sentinelExpr = zigAnalysis.exprs[expr.slice.sentinel];
          let sentinel_ = exprName(sentinelExpr, opts);
          sentinel += " :" + sentinel_;
        }
        payloadHtml += decl + "[" + start + ".." + end + sentinel + "]";
        return payloadHtml;
      }
      case "sliceIndex": {
        const sliceIndex = zigAnalysis.exprs[expr.sliceIndex];
        return exprName(sliceIndex, opts, opts);
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
      case "fieldRef": {
        const field_idx = expr.fieldRef.index;
        const type = getType(expr.fieldRef.type);
        const field = getAstNode(type.src).fields[field_idx];
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
          case "work_item_id": {
            payloadHtml += "workItemId";
            break;
          }
          case "work_group_size": {
            payloadHtml += "workGroupSize";
            break;
          }
          case "work_group_id": {
            payloadHtml += "workGroupId";
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
          case "max": {
            payloadHtml += "max";
            break;
          }
          case "min": {
            payloadHtml += "min";
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
          case "const_cast": {
            payloadHtml += "constCast";
            break;
          }
          case "volatile_cast": {
            payloadHtml += "volatileCast";
            break;
          }
          case "truncate": {
            payloadHtml += "truncate";
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
        if (opts.wantHtml) {
          return '<span class="tok-null">null</span>';
        } else {
          return "null";
        }
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
        const name = getDecl(expr.declRef).name;

        if (opts.wantHtml) {
          let payloadHtml = "";
          if (opts.wantLink) {
            payloadHtml += '<a href="' + findDeclNavLink(name) + '">';
          }
          payloadHtml +=
            '<span class="tok-kw" style="color:lightblue;">' +
            name +
            "</span>";
          if (opts.wantLink) payloadHtml += "</a>";
          return payloadHtml;
        } else {
          return name;
        }
      }
      case "refPath": {
        let firstComponent = expr.refPath[0];
        let name = exprName(firstComponent, opts);
        let url = undefined;
        if (opts.wantLink && "declRef" in firstComponent) {
          url = findDeclNavLink(getDecl(firstComponent.declRef).name);
        }
        for (let i = 1; i < expr.refPath.length; i++) {
          let component = undefined;
          if ("string" in expr.refPath[i]) {
            component = expr.refPath[i].string;
          } else {
            component = exprName(expr.refPath[i], { ...opts, wantLink: false });
            if (opts.wantLink && "declRef" in expr.refPath[i]) {
              url += "." + getDecl(expr.refPath[i].declRef).name;
              component = '<a href="' + url + '">' +
                component +
                "</a>";
            }
          }
          name += "." + component;
        }
        return name;
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
            let name = "";
            if (opts.wantHtml) {
              if (structObj.is_tuple) {
                name = "<span class='tok-kw'>tuple</span> { ";
              } else {
                name = "<span class='tok-kw'>struct</span> { ";
              }
            } else {
              if (structObj.is_tuple) {
                name = "tuple { ";
              } else {
                name = "struct { ";
              }
            }
            if (structObj.field_types.length > 1 && opts.wantHtml) { name += "</br>"; }
            let indent = "";
            if (structObj.field_types.length > 1 && opts.wantHtml) {
              indent = "&nbsp;&nbsp;&nbsp;&nbsp;"
            }
            if (opts.indent && structObj.field_types.length > 1) {
              indent = opts.indent + indent;
            }
            let structNode = getAstNode(structObj.src);
            let field_end = ",";
            if (structObj.field_types.length > 1 && opts.wantHtml) {
              field_end += "</br>";
            } else {
              field_end += " ";
            }

            for (let i = 0; i < structObj.field_types.length; i += 1) {
              let fieldNode = getAstNode(structNode.fields[i]);
              let fieldName = fieldNode.name;
              let html = indent;
              if (!structObj.is_tuple) {
                html += escapeHtml(fieldName);
              }

              let fieldTypeExpr = structObj.field_types[i];
              if (!structObj.is_tuple) {
                html += ": ";
              }

              html += exprName(fieldTypeExpr, { ...opts, indent: indent });

              if (structObj.field_defaults[i] !== null) {
                html += " = " + exprName(structObj.field_defaults[i], opts);
              }

              html += field_end;

              name += html;
            }
            if (opts.indent && structObj.field_types.length > 1) {
              name += opts.indent;
            }
            name += "}";
            return name;
          }
          case typeKinds.Enum: {
            let enumObj = typeObj;
            let name = "";
            if (opts.wantHtml) {
              name = "<span class='tok-kw'>enum</span>";
            } else {
              name = "enum";
            }
            if (enumObj.tag) {
              name += " (" + exprName(enumObj.tag, opts) + ")";
            }
            name += " { ";
            let enumNode = getAstNode(enumObj.src);
            let fields_len = enumNode.fields.length;
            if (enumObj.nonexhaustive) {
              fields_len += 1;
            }
            if (fields_len > 1 && opts.wantHtml) { name += "</br>"; }
            let indent = "";
            if (fields_len > 1) {
              if (opts.wantHtml) {
                indent = "&nbsp;&nbsp;&nbsp;&nbsp;";
              } else {
                indent = "    ";
              }
            }
            if (opts.indent) {
              indent = opts.indent + indent;
            }
            let field_end = ",";
            if (fields_len > 1 && opts.wantHtml) {
              field_end += "</br>";
            } else {
              field_end += " ";
            }
            for (let i = 0; i < enumNode.fields.length; i += 1) {
              let fieldNode = getAstNode(enumNode.fields[i]);
              let fieldName = fieldNode.name;
              let html = indent + escapeHtml(fieldName);

              if (enumObj.values[i] !== null) {
                html += " = " + exprName(enumObj.values[i], opts);
              }

              html += field_end;

              name += html;
            }
            if (enumObj.nonexhaustive) {
              name += indent + "_" + field_end;
            }
            if (opts.indent) {
              name += opts.indent;
            }
            name += "}";
            return name;
          }
          case typeKinds.Union: {
            let unionObj = typeObj;
            let name = "";
            if (opts.wantHtml) {
              name = "<span class='tok-kw'>union</span>";
            } else {
              name = "union";
            }
            if (unionObj.auto_tag) {
              if (opts.wantHtml) {
                name += " (<span class='tok-kw'>enum</span>";
              } else {
                name += " (enum";
              }
              if (unionObj.tag) {
                name += "(" + exprName(unionObj.tag, opts) + "))";
              } else {
                name += ")";
              }
            } else if (unionObj.tag) {
              name += " (" + exprName(unionObj.tag, opts) + ")";
            }
            name += " { ";
            if (unionObj.fields.length > 1 && opts.wantHtml) {
              name += "</br>";
            }
            let indent = "";
            if (unionObj.fields.length > 1 && opts.wantHtml) {
              indent = "&nbsp;&nbsp;&nbsp;&nbsp;"
            }
            if (opts.indent) {
              indent = opts.indent + indent;
            }
            let unionNode = getAstNode(unionObj.src);
            let field_end = ",";
            if (unionObj.fields.length > 1 && opts.wantHtml) {
              field_end += "</br>";
            } else {
              field_end += " ";
            }
            for (let i = 0; i < unionObj.fields.length; i += 1) {
              let fieldNode = getAstNode(unionNode.fields[i]);
              let fieldName = fieldNode.name;
              let html = indent + escapeHtml(fieldName);

              let fieldTypeExpr = unionObj.fields[i];
              html += ": ";

              html += exprName(fieldTypeExpr, { ...opts, indent: indent });

              html += field_end;

              name += html;
            }
            if (opts.indent) {
              name += opts.indent;
            }
            name += "}";
            return name;
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
            let fnDecl = opts.fnDecl;
            let linkFnNameDecl = opts.linkFnNameDecl;
            opts.fnDecl = null;
            opts.linkFnNameDecl = null;
            let payloadHtml = "";
            if (opts.addParensIfFnSignature && fnObj.src == 0) {
              payloadHtml += "(";
            }
            if (opts.wantHtml) {
              if (fnObj.is_extern) {
                payloadHtml += "pub extern ";
              }
              if (fnObj.has_lib_name) {
                payloadHtml += '"' + fnObj.lib_name + '" ';
              }
              payloadHtml += '<span class="tok-kw">fn </span>';
              if (fnDecl) {
                payloadHtml += '<span class="tok-fn">';
                if (linkFnNameDecl) {
                  payloadHtml +=
                    '<a href="' + linkFnNameDecl + '">' +
                    escapeHtml(fnDecl.name) +
                    "</a>";
                } else {
                  payloadHtml += escapeHtml(fnDecl.name);
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
              if (fnObj.src != 0) {
                let fnNode = getAstNode(fnObj.src);
                fields = fnNode.fields;
                isVarArgs = fnNode.varArgs;
              }

              for (let i = 0; i < fnObj.params.length; i += 1) {
                if (i != 0) {
                  payloadHtml += ", ";
                }

                if (opts.wantHtml) {
                  payloadHtml +=
                    "<span class='argBreaker'><br>&nbsp;&nbsp;&nbsp;&nbsp;</span>";
                }
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
                  payloadHtml += exprName(value, opts);
                } else if ("typeOf" in value) {
                  payloadHtml += exprName(value, opts);
                } else if ("typeOf_peer" in value) {
                  payloadHtml += exprName(value, opts);
                } else if ("declRef" in value) {
                  payloadHtml += exprName(value, opts);
                } else if ("call" in value) {
                  payloadHtml += exprName(value, opts);
                } else if ("refPath" in value) {
                  payloadHtml += exprName(value, opts);
                } else if ("type" in value) {
                  payloadHtml += exprName(value, opts);
                  //payloadHtml += '<span class="tok-kw">' + name + "</span>";
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

            if (opts.wantHtml) {
              payloadHtml += "<span class='argBreaker'>,<br></span>";
            }
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
              payloadHtml += exprName(fnObj.ret, {
                ...opts,
                addParensIfFnSignature: true,
              });
            } else if (opts.wantHtml) {
              payloadHtml += '<span class="tok-kw">anytype</span>';
            } else {
              payloadHtml += "anytype";
            }

            if (opts.addParensIfFnSignature && fnObj.src == 0) {
              payloadHtml += ")";
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
      name = exprName({ type: typeObj }, { wantHtml: false, wantLink: false });
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
      // TODO: it shouldn't just be decl.parent_container, but rather 
      //       the type that the decl holds (if the value is a type)
      domTldDocs.innerHTML = markdown(docs, getType(decl.parent_container));
      
      domTldDocs.classList.remove("hidden");
    }

    domFnProto.classList.remove("hidden");
  }

  function renderVar(decl) {
    let resolvedVar = resolveValue(decl.value);

    if (resolvedVar.expr.fieldRef) {
      const declRef = decl.value.expr.refPath[0].declRef;
      const type = getDecl(declRef);
      domFnProtoCode.innerHTML =
        '<span class="tok-kw">var</span> ' +
        escapeHtml(decl.name) +
        ": " +
        type.name +
        " = " +
        exprName(decl.value.expr, { wantHtml: true, wantLink: true }) +
        ";";
    } else if (
      resolvedVar.expr.string !== undefined ||
      resolvedVar.expr.call !== undefined ||
      resolvedVar.expr.comptimeExpr
    ) {
      domFnProtoCode.innerHTML =
        '<span class="tok-kw">var</span> ' +
        escapeHtml(decl.name) +
        ": " +
        exprName(resolvedVar.expr, { wantHtml: true, wantLink: true }) +
        " = " +
        exprName(decl.value.expr, { wantHtml: true, wantLink: true }) +
        ";";
    } else if (resolvedVar.expr.compileError) {
      domFnProtoCode.innerHTML =
        '<span class="tok-kw">var</span> ' +
        escapeHtml(decl.name) +
        " = " +
        exprName(decl.value.expr, { wantHtml: true, wantLink: true }) +
        ";";
    } else {
      domFnProtoCode.innerHTML =
        '<span class="tok-kw">var</span> ' +
        escapeHtml(decl.name) +
        ": " +
        exprName(resolvedVar.typeRef, { wantHtml: true, wantLink: true }) +
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

  function categorizeDecls(
    decls,
    typesList,
    namespacesList,
    errSetsList,
    fnsList,
    varsList,
    valsList,
    testsList,
    unsList
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

      if (decl.is_uns) {
        unsList.push(decl);
      }
    }
  }

  function sourceFileLink(decl) {
    const srcNode = getAstNode(decl.src);
    return sourceFileUrlTemplate.
      replace("{{file}}", zigAnalysis.files[srcNode.file]).
      replace("{{line}}", srcNode.line + 1);
  }

  function renderContainer(container) {
    let typesList = [];

    let namespacesList = [];

    let errSetsList = [];

    let fnsList = [];

    let varsList = [];

    let valsList = [];

    let testsList = [];

    let unsList = [];

    categorizeDecls(
      container.pubDecls,
      typesList,
      namespacesList,
      errSetsList,
      fnsList,
      varsList,
      valsList,
      testsList,
      unsList
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
        testsList,
        unsList
      );

    while (unsList.length > 0) {
      let uns = unsList.shift();
      let declValue = resolveValue(uns.value);
      if (!("type" in declValue.expr)) continue;
      let uns_container = getType(declValue.expr.type);
      if (!isContainerType(uns_container)) continue;
      categorizeDecls(
        uns_container.pubDecls,
        typesList,
        namespacesList,
        errSetsList,
        fnsList,
        varsList,
        valsList,
        testsList,
        unsList
      );
      if (curNav.showPrivDecls)
        categorizeDecls(
          uns_container.privDecls,
          typesList,
          namespacesList,
          errSetsList,
          fnsList,
          varsList,
          valsList,
          testsList,
          unsList
        );
    }

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
        domTldDocs.innerHTML = markdown(docs, container);
        domTldDocs.classList.remove("hidden");
      }
    }

    if (typesList.length !== 0) {
      resizeDomList(
        domListTypes,
        typesList.length,
        '<li><a href=""></a></li>'
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
        tdFnSrc.innerHTML = "<a style=\"float: right;\" target=\"_blank\" href=\"" +
          sourceFileLink(decl) + "\">[src]</a>";

        let docs = getAstNode(decl.src).docs;
        if (docs != null) {
          docs = docs.trim();
          var short = shortDesc(docs);
          if (short != docs) {
            short = markdown(short, container);
            var long = markdown(docs, container); // TODO: this needs to be the file top lvl struct
            tdDesc.innerHTML =
              "<div class=\"expand\" ><span class=\"button\" onclick=\"toggleExpand(event)\"></span><div class=\"sum-less\">" + short + "</div>" + "<div class=\"sum-more\">" + long + "</div></details>";
          }
          else {
            tdDesc.innerHTML = markdown(short, container);
          }
        } else {
          tdDesc.innerHTML = "<p><i>No documentation provided.</i><p>";
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
          let value = container.values[i];
          if (value !== null) {
            html += " = " + exprName(value, { wantHtml: true, wantLink: true });
          }
        } else {
          let fieldTypeExpr = container.field_types[i];
          if (container.kind !== typeKinds.Struct || !container.is_tuple) {
            html += ": ";
          }
          html += exprName(fieldTypeExpr, { wantHtml: true, wantLink: true });
          let tsn = typeShorthandName(fieldTypeExpr);
          if (tsn) {
            html += "<span> (" + tsn + ")</span>";
          }
          if (container.kind === typeKinds.Struct && !container.is_tuple) {
            let defaultInitExpr = container.field_defaults[i];
            if (defaultInitExpr !== null) {
              html += " = " + exprName(defaultInitExpr, { wantHtml: true, wantLink: true });
            }
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
      mode: NAV_MODES.API,
      pkgNames: [],
      pkgObjs: [],
      declNames: [],
      declObjs: [],
      callName: null,
    };
    curNavSearch = "";

    const mode = location.hash.substring(0, 3);
    let query = location.hash.substring(3);

    const DEFAULT_HASH = NAV_MODES.API + zigAnalysis.packages[zigAnalysis.rootPkg].name;
    switch (mode) {
      case NAV_MODES.API:
      case NAV_MODES.API_INTERNAL:
        // #A;PACKAGE:decl.decl.decl?search-term
        curNav.mode = mode;

        let qpos = query.indexOf("?");
        let nonSearchPart;
        if (qpos === -1) {
          nonSearchPart = query;
        } else {
          nonSearchPart = query.substring(0, qpos);
          curNavSearch = decodeURIComponent(query.substring(qpos + 1));
        }

        let parts = nonSearchPart.split(":");
        if (parts[0] == "") {
          location.hash = DEFAULT_HASH;
        } else {
          curNav.pkgNames = decodeURIComponent(parts[0]).split(".");
        }

        if (parts[1] != null) {
          curNav.declNames = decodeURIComponent(parts[1]).split(".");
        }

        return;
      case NAV_MODES.GUIDES:
        const sections = zigAnalysis.guide_sections;
        if (sections.length != 0 && sections[0].guides.length != 0 && query == "") {
          location.hash = NAV_MODES.GUIDES + sections[0].guides[0].name;
          return;
        }

        curNav.mode = mode;
        curNav.activeGuide = query;

        return;
      default:
        location.hash = DEFAULT_HASH;
        return;
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

  function findSubDecl(parentTypeOrDecl, childName) {
    let parentType = parentTypeOrDecl;
    {
      // Generic functions / resolving decls
      if ("value" in parentType) {
        const rv = resolveValue(parentType.value);
        if ("type" in rv.expr) {
          const t = getType(rv.expr.type);
          parentType = t;
          if (t.kind == typeKinds.Fn && t.generic_ret != null) {
            let resolvedGenericRet = resolveValue({ expr: t.generic_ret });

            if ("call" in resolvedGenericRet.expr) {
              let call = zigAnalysis.calls[resolvedGenericRet.expr.call];
              let resolvedFunc = resolveValue({ expr: call.func });
              if (!("type" in resolvedFunc.expr)) return null;
              let callee = getType(resolvedFunc.expr.type);
              if (!callee.generic_ret) return null;
              resolvedGenericRet = resolveValue({ expr: callee.generic_ret });
            }

            if ("type" in resolvedGenericRet.expr) {
              parentType = getType(resolvedGenericRet.expr.type);
            }
          }
        }
      }
    }

    if (parentType.pubDecls) {
      for (let i = 0; i < parentType.pubDecls.length; i += 1) {
        let declIndex = parentType.pubDecls[i];
        let childDecl = getDecl(declIndex);
        if (childDecl.name === childName) {
          childDecl.find_subdecl_idx = declIndex;
          return childDecl;
        } else if (childDecl.is_uns) {
          let declValue = resolveValue(childDecl.value);
          if (!("type" in declValue.expr)) continue;
          let uns_container = getType(declValue.expr.type);
          let uns_res = findSubDecl(uns_container, childName);
          if (uns_res !== null) return uns_res;
        }
      }
    }

    if (parentType.privDecls) {
      for (let i = 0; i < parentType.privDecls.length; i += 1) {
        let declIndex = parentType.privDecls[i];
        let childDecl = getDecl(declIndex);
        if (childDecl.name === childName) {
          childDecl.find_subdecl_idx = declIndex;
          return childDecl;
        } else if (childDecl.is_uns) {
          let declValue = resolveValue(childDecl.value);
          if (!("type" in declValue.expr)) continue;
          let uns_container = getType(declValue.expr.type);
          let uns_res = findSubDecl(uns_container, childName);
          if (uns_res !== null) return uns_res;
        }
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
            let declIndex = t.pubDecls[declI];
            if (list[declIndex] != null) continue;

            let decl = getDecl(declIndex);
              
            if (decl.is_uns) {
              let unsDeclList = [decl];
              while(unsDeclList.length != 0) {
                let unsDecl = unsDeclList.pop();
                let unsDeclVal = resolveValue(unsDecl.value);
                if (!("type" in unsDeclVal.expr)) continue;
                let unsType = getType(unsDeclVal.expr.type);
                if (!isContainerType(unsType)) continue;
                let unsPubDeclLen = unsType.pubDecls ? unsType.pubDecls.length : 0;
                for (let unsDeclI = 0; unsDeclI < unsPubDeclLen; unsDeclI += 1) {
                  let childDeclIndex = unsType.pubDecls[unsDeclI];
                  let childDecl = getDecl(childDeclIndex);
                  
                  if (childDecl.is_uns) {
                    unsDeclList.push(childDecl);
                  } else {
                    addDeclToSearchResults(childDecl, childDeclIndex, pkgNames, item, list, stack);
                  }
                }
              }
            } else {
              addDeclToSearchResults(decl, declIndex, pkgNames, item, list, stack);
            }
          }
        }
      }
    }
    return list;
  }

function addDeclToSearchResults(decl, declIndex, pkgNames, item, list, stack) {
  let declVal = resolveValue(decl.value);
  let declNames = item.declNames.concat([decl.name]);

  if (list[declIndex] != null) return;
  list[declIndex] = {
    pkgNames: pkgNames,
    declNames: declNames,
  };
  
  if ("type" in declVal.expr) {
    let value = getType(declVal.expr.type);
    if (declCanRepresentTypeKind(value.kind)) {
      canonTypeDecls[declVal.type] = declIndex;
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

  function shortDesc(docs) {
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
    return slice;
  }

  function shortDescMarkdown(docs) {
    return markdown(shortDesc(docs));
  }

  function markdown(input, contextType) {
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
        } else if (line.text.match(/^-[ \t]+.*$/)) {
          // line starts with a hyphen, followed by spaces or tabs
          const match = line.text.match(/^-[ \t]+/);
          line.type = "ul";
          line.text = line.text.substr(match[0].length);
        } else if (line.text.match(/^\d+\.[ \t]+.*$/)) {
          // line starts with {number}{dot}{spaces or tabs}
          const match = line.text.match(/(\d+)\.[ \t]+/);
          line.type = "ol";
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

    function markdownInlines(innerText, contextType) {
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

      // state used to link decl references
      let quote_start = undefined;
      let quote_start_html = undefined;

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

            // find out if this is a decl that should be linked
            const maybe_decl_path = innerText.substr(quote_start, i-quote_start);
            const decl_hash = detectDeclPath(maybe_decl_path, contextType);
            if (decl_hash) {
              const anchor_opening_tag = "<a href='"+ decl_hash +"'>";
              innerHTML = innerHTML.slice(0, quote_start_html) 
                + anchor_opening_tag
                + innerHTML.slice(quote_start_html) + "</a>";
            }
          } else {
            currentRun += innerText[i];
          }
          continue;
        }

        if (innerText[i] == "`") {
          flushRun();
          if (!parsing_code) {
            quote_start = i + 1;
            quote_start_html = innerHTML.length;
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

      if (in_code) {
        in_code = false;
        parsing_code = false;
        innerHTML += "</code>";
        codetag = "";
      }

      while (stack.length > 0) {
        const fmt = stack.pop();
        innerHTML += "</" + fmt.tag + ">";
      }

      return innerHTML;
    }

    function detectDeclPath(text, context) {
      let result = "";
      let separator = ":";
      const components = text.split(".");
      let curDeclOrType = undefined;
      
      let curContext = context;
      let limit = 10000;
      while (curContext) {
        limit -= 1;
        
        if (limit == 0) {
          throw "too many iterations";
        }
        
        curDeclOrType = findSubDecl(curContext, components[0]);
        
        if (!curDeclOrType) {
          if (curContext.parent_container == null) break;
          curContext = getType(curContext.parent_container);
          continue;
        }

        if (curContext == context) {
          separator = '.';
          result = location.hash + separator + components[0];
        } else {
          // We had to go up, which means we need a new path!
          const canonPath = getCanonDeclPath(curDeclOrType.find_subdecl_idx);
          if (!canonPath) return;
          
          let lastPkgName = canonPath.pkgNames[canonPath.pkgNames.length - 1];
          let fullPath = lastPkgName + ":" + canonPath.declNames.join(".");
        
          separator = '.';
          result = "#A;" + fullPath;
        }

        break;
      } 

      if (!curDeclOrType) {
        for (let i = 0; i < zigAnalysis.packages.length; i += 1){
          const p = zigAnalysis.packages[i];
          if (p.name == components[0]) {
            curDeclOrType = getType(p.main);
            result += "#A;" + components[0];
            break;
          }
        }
      }

      if (!curDeclOrType) return null;
      
      for (let i = 1; i < components.length; i += 1) {
        curDeclOrType = findSubDecl(curDeclOrType, components[i]);
        if (!curDeclOrType) return null;
        result += separator + components[i];
        separator = '.';
      }

      return result;
      
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
            markdownInlines(line.text, contextType) +
            "</" +
            line.type +
            ">\n";
          break;

        case "ul":
        case "ol":
          if (
            !previousLineIs(line.type, line_no) ||
            getPreviousLineIndent(line_no) < line.indent
          ) {
            html += "<" + line.type + ">\n";
          }

          html += "<li>" + markdownInlines(line.text, contextType) + "</li>\n";

          if (
            !nextLineIs(line.type, line_no) ||
            getNextLineIndent(line_no) < line.indent
          ) {
            html += "</" + line.type + ">\n";
          }
          break;

        case "p":
          if (!previousLineIs("p", line_no)) {
            html += "<p>\n";
          }
          html += markdownInlines(line.text, contextType) + "\n";
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
      is_uns: decl[5],
      parent_container: decl[6],
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

  function getType(idx) {
    const ty = zigAnalysis.types[idx];
    switch (ty[0]) {
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
        return { kind: ty[0], name: ty[1] };
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
          field_types: ty[5],
          field_defaults: ty[6],
          is_tuple: ty[7],
          line_number: ty[8],
          parent_container: ty[9],
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
          tag: ty[5],
          values: ty[6],
          nonexhaustive: ty[7],
          parent_container: ty[8],
        };
      case 20: // Union
        return {
          kind: ty[0],
          name: ty[1],
          src: ty[2],
          privDecls: ty[3],
          pubDecls: ty[4],
          field_types: ty[5],
          tag: ty[6],
          auto_tag: ty[7],
          parent_container: ty[8],
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
          parent_container: ty[5],
        };
      case 24: // Frame
      case 25: // AnyFrame
      case 26: // Vector
      case 27: // EnumLiteral
        return { kind: ty[0], name: ty[1] };
    }
  }

})();

function toggleExpand(event) {
  const parent = event.target.parentElement;
  parent.toggleAttribute("open");

  if (!parent.open && parent.getBoundingClientRect().top < 0) {
    parent.parentElement.parentElement.scrollIntoView(true);
  }
}
