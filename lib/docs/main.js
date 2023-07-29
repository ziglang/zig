"use strict";

var zigAnalysis;

const NAV_MODES = {
  API: "#A;",
  GUIDES: "#G;",
};

(function() {
  const domBanner = document.getElementById("banner");
  const domMain = document.getElementById("main");
  const domStatus = document.getElementById("status");
  const domSectNav = document.getElementById("sectNav");
  const domListNav = document.getElementById("listNav");
  const domApiSwitch = document.getElementById("ApiSwitch");
  const domGuideSwitch = document.getElementById("guideSwitch");
  const domGuidesMenu = document.getElementById("guidesMenu");
  const domApiMenu = document.getElementById("apiMenu");
  const domGuidesList = document.getElementById("guidesList");
  const domSectMainMod = document.getElementById("sectMainMod");
  const domSectMods = document.getElementById("sectMods");
  const domListMods = document.getElementById("listMods");
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
  const domSearchHelpSummary = document.getElementById("searchHelpSummary");
  const domSectSearchResults = document.getElementById("sectSearchResults");
  const domSectSearchAllResultsLink = document.getElementById("sectSearchAllResultsLink");
  const domDocs = document.getElementById("docs");
  const domGuidesSection = document.getElementById("guides");
  const domActiveGuide = document.getElementById("activeGuide");

  const domListSearchResults = document.getElementById("listSearchResults");
  const domSectSearchNoResults = document.getElementById("sectSearchNoResults");
  const domSectInfo = document.getElementById("sectInfo");
  // const domTdTarget = (document.getElementById("tdTarget"));
  const domTdZigVer = document.getElementById("tdZigVer");
  const domHdrName = document.getElementById("hdrName");
  const domHelpModal = document.getElementById("helpModal");
  const domSearchKeys = document.getElementById("searchKeys");
  const domPrefsModal = document.getElementById("prefsModal");
  const domSearchPlaceholder = document.getElementById("searchPlaceholder");
  const sourceFileUrlTemplate = "src/{{mod}}/{{file}}.html#L{{line}}"
  const domLangRefLink = document.getElementById("langRefLink");

  const domPrefSlashSearch = document.getElementById("prefSlashSearch");
  const prefs = getLocalStorage();
  loadPrefs();

  domPrefSlashSearch.addEventListener("change", () => setPrefSlashSearch(domPrefSlashSearch.checked));

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

  let declSearchIndex = new RadixTree();
  window.search = declSearchIndex;

  // for each module, is an array with modules to get to this one
  let canonModPaths = computeCanonicalModulePaths();

  // for each decl, is an array with {declNames, modNames} to get to this one
  let canonDeclPaths = null; // lazy; use getCanonDeclPath

  // for each type, is an array with {declNames, modNames} to get to this one
  let canonTypeDecls = null; // lazy; use getCanonTypeDecl

  let curNav = {
    mode: NAV_MODES.API,
    activeGuide: "",
    // each element is a module name, e.g. @import("a") then within there @import("b")
    // starting implicitly from root module
    modNames: [],
    // same as above except actual modules, not names
    modObjs: [],
    // Each element is a decl name, `a.b.c`, a is 0, b is 1, c is 2, etc.
    // empty array means refers to the module itself
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

  let guidesSearchIndex = {};
  window.guideSearch = guidesSearchIndex;
  parseGuides();

  // identifiers can contain modal trigger characters so we want to allow typing
  // such characters when the search is focused instead of toggling the modal
  let canToggleModal = true;

  domSearch.disabled = false;
  domSearch.addEventListener("keydown", onSearchKeyDown, false);
  domSearch.addEventListener("input", onSearchInput, false);
  domSearch.addEventListener("focus", ev => {
    domSearchPlaceholder.classList.add("hidden");
    canToggleModal = false;
  });
  domSearch.addEventListener("blur", ev => {
    if (domSearch.value.length == 0)
      domSearchPlaceholder.classList.remove("hidden");
    canToggleModal = true;
  });
  domSectSearchAllResultsLink.addEventListener('click', onClickSearchShowAllResults, false);
  function onClickSearchShowAllResults(ev) {
    ev.preventDefault();
    ev.stopPropagation();
    searchTrimResults = false;
    onHashChange();
  }

  if (location.hash == "") {
    location.hash = "#A;";
  }

  // make the modal disappear if you click outside it
  function handleModalClick(ev) {
    if (ev.target.classList.contains("modal-container")) {
      hideModal(this);
    }
  }
  domHelpModal.addEventListener("click", handleModalClick);
  domPrefsModal.addEventListener("click", handleModalClick);

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
        let list = curNav.modNames.concat(curNav.declNames);
        if (list.length === 0) {
          document.title = zigAnalysis.modules[zigAnalysis.rootMod].name + suffix;
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
      console.log("TODO: unhandled case in typeShortName");
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

  function resolveValue(value, trackDecls) {
    let seenDecls = [];
    let i = 0;
    while (true) {
      i += 1;
      if (i >= 10000) {
        throw "resolveValue quota exceeded"
      }

      if ("refPath" in value.expr) {
        value = { expr: value.expr.refPath[value.expr.refPath.length - 1] };
        continue;
      }

      if ("declRef" in value.expr) {
        seenDecls.push(value.expr.declRef);
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

      if (trackDecls) return { value, seenDecls };
      return value;
    }
  }

  function resolveGenericRet(genericFunc) {
    if (genericFunc.generic_ret == null) return null;
    let result = resolveValue({ expr: genericFunc.generic_ret });

    let i = 0;
    while (true) {
      i += 1;
      if (i >= 10000) {
        throw "resolveGenericRet quota exceeded"
      }

      if ("call" in result.expr) {
        let call = zigAnalysis.calls[result.expr.call];
        let resolvedFunc = resolveValue({ expr: call.func });
        if (!("type" in resolvedFunc.expr)) return null;
        let callee = getType(resolvedFunc.expr.type);
        if (!callee.generic_ret) return null;
        result = resolveValue({ expr: callee.generic_ret });
        continue;
      }

      return result;
    }
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
    domGuidesSection.classList.remove("hidden");
    domActiveGuide.classList.add("hidden");
    domApiMenu.classList.add("hidden");
    domSectSearchResults.classList.add("hidden");
    domSectSearchAllResultsLink.classList.add("hidden");
    domSectSearchNoResults.classList.add("hidden");

    // sidebar guides list
    const section_list = zigAnalysis.guide_sections;
    resizeDomList(domGuidesList, section_list.length, '<div><h2><span></span></h2><ul class="modules"></ul></div>');
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
        aDom.textContent = guide.title;
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


    if (curNavSearch !== "") {
      return renderSearchGuides();
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
      const root_file_idx = zigAnalysis.modules[zigAnalysis.rootMod].file;
      const root_file_name = getFile(root_file_idx).name;
      domActiveGuide.innerHTML = markdown(`
# Zig Guides
These autodocs don't contain any guide.

While the API section is a reference guide autogenerated from Zig source code,
guides are meant to be handwritten explanations that provide for example:

- how-to explanations for common use-cases 
- technical documentation 
- information about advanced usage patterns

You can add guides by specifying which markdown files to include
in the top level doc comment of your root file, like so:

(At the top of *${root_file_name}*)
\`\`\`
//!zig-autodoc-guide: intro.md
//!zig-autodoc-guide: quickstart.md
//!zig-autodoc-guide: advanced-docs/advanced-stuff.md
\`\`\`

You can also create sections to group guides together:

\`\`\`
//!zig-autodoc-section: CLI Usage
//!zig-autodoc-guide: cli-basics.md
//!zig-autodoc-guide: cli-advanced.md
\`\`\`
  

**Note that this feature is still under heavy development so expect bugs**
**and missing features!**

Happy writing!
`);
    } else {
      domActiveGuide.innerHTML = markdown(activeGuide.body);
    }
    domActiveGuide.classList.remove("hidden");
  }

  function renderApi() {
    // set Api mode
    domApiSwitch.classList.add("active");
    domGuideSwitch.classList.remove("active");
    domGuidesSection.classList.add("hidden");
    domDocs.classList.remove("hidden");
    domApiMenu.classList.remove("hidden");
    domGuidesMenu.classList.add("hidden");

    domStatus.classList.add("hidden");
    domFnProto.classList.add("hidden");
    domSectParams.classList.add("hidden");
    domTldDocs.classList.add("hidden");
    domSectMainMod.classList.add("hidden");
    domSectMods.classList.add("hidden");
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
    renderModList();

    if (curNavSearch !== "") {
      return renderSearchAPI();
    }

    let rootMod = zigAnalysis.modules[zigAnalysis.rootMod];
    let mod = rootMod;
    curNav.modObjs = [mod];
    for (let i = 0; i < curNav.modNames.length; i += 1) {
      let childMod = zigAnalysis.modules[mod.table[curNav.modNames[i]]];
      if (childMod == null) {
        return render404();
      }
      mod = childMod;
      curNav.modObjs.push(mod);
    }

    let currentType = getType(mod.main);
    curNav.declObjs = [currentType];
    let lastDecl = mod.main;
    for (let i = 0; i < curNav.declNames.length; i += 1) {
      let childDecl = findSubDecl(currentType, curNav.declNames[i]);
      window.last_decl = childDecl;
      if (childDecl == null || childDecl.is_private === true) {
        return render404();
      }
      lastDecl = childDecl;

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

    renderDocTest(lastDecl);

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
    domDocTestsCode.innerHTML = renderTokens(
      DecoratedTokenizer(astNode.code, decl));
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

    domFnProtoCode.innerHTML = renderTokens(ex(value.expr, { fnDecl: fnDecl }));

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
    if (fields === null) {
      fields = getAstNode(typeObj.src).fields;
    }
    let isVarArgs = typeObj.is_var_args;

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
      let html = "<pre" + preClass + ">" + renderTokens((function*() {
        yield Tok.identifier(fieldNode.name);
        yield Tok.colon;
        yield Tok.space;
        if (isVarArgs && i === typeObj.params.length - 1) {
          yield Tok.period;
          yield Tok.period;
          yield Tok.period;
        } else {
          yield* ex(value, {});
        }
        yield Tok.comma;
      }()));

      html += "</pre>";

      if (docsNonEmpty) {
        html += '<div class="fieldDocs">' + markdown(docs) + "</div>";
      }
      divDom.innerHTML = html;
    }
    domSectParams.classList.remove("hidden");
  }

  function renderNav() {
    let len = curNav.modNames.length + curNav.declNames.length;
    resizeDomList(domListNav, len, '<li><a href="#"></a></li>');
    let list = [];
    let hrefModNames = [];
    let hrefDeclNames = [];
    for (let i = 0; i < curNav.modNames.length; i += 1) {
      hrefModNames.push(curNav.modNames[i]);
      let name = curNav.modNames[i];
      list.push({
        name: name,
        link: navLink(hrefModNames, hrefDeclNames),
      });
    }
    for (let i = 0; i < curNav.declNames.length; i += 1) {
      hrefDeclNames.push(curNav.declNames[i]);
      list.push({
        name: curNav.declNames[i],
        link: navLink(hrefModNames, hrefDeclNames),
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

  function renderModList() {
    const rootMod = zigAnalysis.modules[zigAnalysis.rootMod];
    let list = [];
    for (let key in rootMod.table) {
      let modIndex = rootMod.table[key];
      if (zigAnalysis.modules[modIndex] == null) continue;
      if (key == rootMod.name) continue;
      list.push({
        name: key,
        mod: modIndex,
      });
    }

    {
      let aDom = domSectMainMod.children[1].children[0].children[0];
      aDom.textContent = rootMod.name;
      aDom.setAttribute("href", navLinkMod(zigAnalysis.rootMod));
      if (rootMod.name === curNav.modNames[0]) {
        aDom.classList.add("active");
      } else {
        aDom.classList.remove("active");
      }
      domSectMainMod.classList.remove("hidden");
    }

    list.sort(function(a, b) {
      return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
    });

    if (list.length !== 0) {
      resizeDomList(domListMods, list.length, '<li><a href="#"></a></li>');
      for (let i = 0; i < list.length; i += 1) {
        let liDom = domListMods.children[i];
        let aDom = liDom.children[0];
        aDom.textContent = list[i].name;
        aDom.setAttribute("href", navLinkMod(list[i].mod));
        if (list[i].name === curNav.modNames[0]) {
          aDom.classList.add("active");
        } else {
          aDom.classList.remove("active");
        }
      }

      domSectMods.classList.remove("hidden");
    }
  }

  function navLink(modNames, declNames, callName) {
    let base = curNav.mode;

    if (modNames.length === 0 && declNames.length === 0) {
      return base;
    } else if (declNames.length === 0 && callName == null) {
      return base + modNames.join(".");
    } else if (callName == null) {
      return base + modNames.join(".") + ":" + declNames.join(".");
    } else {
      return (
        base + modNames.join(".") + ":" + declNames.join(".") + ";" + callName
      );
    }
  }

  function navLinkMod(modIndex) {
    return navLink(canonModPaths[modIndex], []);
  }

  function navLinkDecl(childName) {
    return navLink(curNav.modNames, curNav.declNames.concat([childName]));
  }

  function findDeclNavLink(declName) {
    if (curNav.declObjs.length == 0) return null;
    const curFile = getAstNode(curNav.declObjs[curNav.declObjs.length - 1].src).file;

    for (let i = curNav.declObjs.length - 1; i >= 0; i--) {
      const curDecl = curNav.declObjs[i];
      const curDeclName = curNav.declNames[i - 1];
      if (curDeclName == declName) {
        const declPath = curNav.declNames.slice(0, i);
        return navLink(curNav.modNames, declPath);
      }

      const subDecl = findSubDecl(curDecl, declName);

      if (subDecl != null) {
        if (subDecl.is_private === true) {
          return sourceFileLink(subDecl);
        } else {
          const declPath = curNav.declNames.slice(0, i).concat([declName]);
          return navLink(curNav.modNames, declPath);
        }
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
  //      return navLink(curNav.modNames, declNamesCopy);
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
      return { "undefined": {} };
    }
    return walkResultTypeRef(resolved);
  }

  function* DecoratedTokenizer(src, context) {
    let tok_it = Tokenizer(src);
    for (let t of tok_it) {
      if (t.tag == Tag.identifier) {
        const link = detectDeclPath(t.src, context);
        if (link) {
          t.link = link;
        }
      }

      yield t;
    }
  }


  function renderSingleToken(t) {

    if (t.tag == Tag.whitespace) {
      return t.src;
    }

    let src = t.src;
    // if (t.tag == Tag.identifier) {
    //     src = escapeHtml(src);
    // }
    let result = "";
    if (t.tag == Tag.identifier && isSimpleType(t.src)) {
      result = `<span class="zig_type">${src}</span>`;
    } else if (t.tag == Tag.identifier && isSpecialIndentifier(t.src)) {
      result = `<span class="zig_special">${src}</span>`;
    } else if (t.tag == Tag.identifier && t.fnDecl) {
      result = `<span class="zig_fn">${src}</span>`;
    } else {
      result = `<span class="zig_${t.tag}">${src}</span>`;
    }

    if (t.link) {
      result = `<a href="${t.link}">` + result + "</a>";
    }

    return result;
  }

  function renderTokens(tok_it) {
    var html = [];

    const max_iter = 100000;
    let i = 0;
    for (const t of tok_it) {
      i += 1;
      if (i > max_iter)
        throw "too many iterations";

      if (t.tag == Tag.eof)
        break;

      html.push(renderSingleToken(t));
    }

    return html.join("");
  }

  function* ex(expr, opts) {
    switch (Object.keys(expr)[0]) {
      default:
        throw "this expression is not implemented yet: " + Object.keys(expr)[0];
      case "comptimeExpr": {
        const src = zigAnalysis.comptimeExprs[expr.comptimeExpr].code;
        yield* DecoratedTokenizer(src);
        return;
      }
      case "declName": {
        yield { src: expr.declName, tag: Tag.identifier };
        return;
      }
      case "declRef": {
        const name = getDecl(expr.declRef).name;
        const link = declLinkOrSrcLink(expr.declRef);
        if (link) {
          yield { src: name, tag: Tag.identifier, link };
        } else {
          yield { src: name, tag: Tag.identifier };
        }
        return;
      }
      case "refPath": {
        for (let i = 0; i < expr.refPath.length; i += 1) {
          if (i > 0) yield Tok.period;
          yield* ex(expr.refPath[i]);
        }
        return;
      }
      case "fieldRef": {
        const field_idx = expr.fieldRef.index;
        const type = getType(expr.fieldRef.type);
        const field = getAstNode(type.src).fields[field_idx];
        const name = getAstNode(field).name;
        yield { src: name, tag: Tag.identifier };
        return;
      }
      case "bool": {
        if (expr.bool) {
          yield { src: "true", tag: Tag.identifier };
          return;
        }
        yield { src: "false", tag: Tag.identifier };
        return;
      }
      case "&": {
        yield { src: "&", tag: Tag.ampersand };
        yield* ex(zigAnalysis.exprs[expr["&"]], opts);
        return;
      }
      case "call": {

        let call = zigAnalysis.calls[expr.call];

        switch (Object.keys(call.func)[0]) {
          default:
            throw "TODO";
          case "declRef":
          case "refPath": {
            yield* ex(call.func, opts);
            break;
          }
        }
        yield Tok.l_paren;

        for (let i = 0; i < call.args.length; i++) {
          if (i != 0) {
            yield Tok.comma;
            yield Tok.space;
          }
          yield* ex(call.args[i], opts);
        }

        yield Tok.r_paren;
        return;
      }
      case "typeOf_peer": {
        yield { src: "@TypeOf", tag: Tag.builtin };
        yield { src: "(", tag: Tag.l_paren };
        for (let i = 0; i < expr.typeOf_peer.length; i+=1) {
          const elem = zigAnalysis.exprs[expr.typeOf_peer[i]];
          yield* ex(elem, opts);
          if (i != expr.typeOf_peer.length - 1) {
            yield Tok.comma;
            yield Tok.space;
          }
        }
        yield { src: ")", tag: Tag.r_paren };
        return;
      } 
      case "sizeOf": {
        const sizeOf = zigAnalysis.exprs[expr.sizeOf];
        yield { src: "@sizeOf", tag: Tag.builtin };
        yield { src: "(", tag: Tag.l_paren };
        yield* ex(sizeOf, opts);
        yield { src: ")", tag: Tag.r_paren };
        return;
      }

      case "as": {
        const exprArg = zigAnalysis.exprs[expr.as.exprArg];
        yield* ex(exprArg, opts);
        return;
      }

      case "int": {
        yield { src: expr.int, tag: Tag.number_literal };
        return;
      }

      case "int_big": {
        if (expr.int_big.negated) {
          yield { src: "-", tag: Tag.minus };
        }
        yield { src: expr.int_big.value, tag: Tag.number_literal };
        return;
      }

      case "float": {
        yield { src: expr.float, tag: Tag.number_literal };
        return;
      }

      case "float128": {
        yield { src: expr.float128, tag: Tag.number_literal };
        return;
      }

      case "array": {
        yield { src: ".", tag: Tag.period };
        yield Tok.l_brace;
        for (let i = 0; i < expr.array.length; i++) {
          if (i != 0) {
            yield { src: ",", tag: Tag.comma };
            yield Tok.space;
          }
          let elem = zigAnalysis.exprs[expr.array[i]];
          yield* ex(elem, opts);
        }
        yield Tok.r_brace;
        return;
      }

      case "compileError": {
        yield { src: "@compileError", tag: Tag.builtin };
        yield Tok.l_paren;
        yield* ex(zigAnalysis.exprs[expr.compileError], opts);
        yield Tok.r_paren;
        return;
      }

      case "string": {
        yield { src: '"' + expr.string + '"', tag: Tag.string_literal };
        return;
      }

      case "struct": {
        yield Tok.period;
        yield Tok.l_brace;
        yield Tok.space;

        for (let i = 0; i < expr.struct.length; i++) {
          const fv = expr.struct[i];
          const field_name = fv.name;
          const field_value = ex(fv.val.expr, opts);
          yield Tok.period;
          yield { src: field_name, tag: Tag.identifier };
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* field_value;
          if (i !== expr.struct.length - 1) {
            yield Tok.comma;
            yield Tok.space;
          } else {
            yield Tok.space;
          }
        }
        yield Tok.r_brace;
        return;
      }

      case "binOpIndex": {
        const binOp = zigAnalysis.exprs[expr.binOpIndex];
        yield* ex(binOp, opts);
        return;
      }

      case "binOp": {
        const lhsOp = zigAnalysis.exprs[expr.binOp.lhs];
        const rhsOp = zigAnalysis.exprs[expr.binOp.rhs];

        if (lhsOp["binOpIndex"] !== undefined) {
          yield Tok.l_paren;
          yield* ex(lhsOp, opts);
          yield Tok.r_paren;
        } else {
          yield* ex(lhsOp, opts);
        }

        yield Tok.space;

        switch (expr.binOp.name) {
          case "add": {
            yield { src: "+", tag: Tag.plus };
            break;
          }
          case "addwrap": {
            yield { src: "+%", tag: Tag.plus_percent };
            break;
          }
          case "add_sat": {
            yield { src: "+|", tag: Tag.plus_pipe };
            break;
          }
          case "sub": {
            yield { src: "-", tag: Tag.minus };
            break;
          }
          case "subwrap": {
            yield { src: "-%", tag: Tag.minus_percent };
            break;
          }
          case "sub_sat": {
            yield { src: "-|", tag: Tag.minus_pipe };
            break;
          }
          case "mul": {
            yield { src: "*", tag: Tag.asterisk };
            break;
          }
          case "mulwrap": {
            yield { src: "*%", tag: Tag.asterisk_percent };
            break;
          }
          case "mul_sat": {
            yield { src: "*|", tag: Tag.asterisk_pipe };
            break;
          }
          case "div": {
            yield { src: "/", tag: Tag.slash };
            break;
          }
          case "shl": {
            yield { src: "<<", tag: Tag.angle_bracket_angle_bracket_left };
            break;
          }
          case "shl_sat": {
            yield { src: "<<|", tag: Tag.angle_bracket_angle_bracket_left_pipe };
            break;
          }
          case "shr": {
            yield { src: ">>", tag: Tag.angle_bracket_angle_bracket_right };
            break;
          }
          case "bit_or": {
            yield { src: "|", tag: Tag.pipe };
            break;
          }
          case "bit_and": {
            yield { src: "&", tag: Tag.ampersand };
            break;
          }
          case "array_cat": {
            yield { src: "++", tag: Tag.plus_plus };
            break;
          }
          case "array_mul": {
            yield { src: "**", tag: Tag.asterisk_asterisk };
            break;
          }
          case "cmp_eq": {
            yield { src: "==", tag: Tag.equal_equal };
            break;
          }
          case "cmp_neq": {
            yield { src: "!=", tag: Tag.bang_equal };
            break;
          }
          case "cmp_gt": {
            yield { src: ">", tag: Tag.angle_bracket_right };
            break;
          }
          case "cmp_gte": {
            yield { src: ">=", tag: Tag.angle_bracket_right_equal };
            break;
          }
          case "cmp_lt": {
            yield { src: "<", tag: Tag.angle_bracket_left };
            break;
          }
          case "cmp_lte": {
            yield { src: "<=", tag: Tag.angle_bracket_left_equal };
            break;
          }
          case "bool_br_and": {
            yield { src: "and", tag: Tag.keyword_and };
            break;
          }
          case "bool_br_or": {
            yield { src: "or", tag: Tag.keyword_or };
            break;
          }
          default:
            console.log("operator not handled yet or doesn't exist!");
        }

        yield Tok.space;

        if (rhsOp["binOpIndex"] !== undefined) {
          yield Tok.l_paren;
          yield* ex(rhsOp, opts);
          yield Tok.r_paren;
        } else {
          yield* ex(rhsOp, opts);
        }
        return;
      }

      case "builtinBinIndex": {
        const builtinBinIndex = zigAnalysis.exprs[expr.builtinBinIndex];
        yield* ex(builtinBinIndex, opts);
        return;
      }

      case "builtinBin": {
        const lhsOp = zigAnalysis.exprs[expr.builtinBin.lhs];
        const rhsOp = zigAnalysis.exprs[expr.builtinBin.rhs];

        let builtinName = "@";
        switch (expr.builtinBin.name) {
          case "int_from_float": {
            builtinName += "intFromFloat";
            break;
          }
          case "float_from_int": {
            builtinName += "floatFromInt";
            break;
          }
          case "ptr_from_int": {
            builtinName += "ptrFromInt";
            break;
          }
          case "enum_from_int": {
            builtinName += "enumFromInt";
            break;
          }
          case "float_cast": {
            builtinName += "floatCast";
            break;
          }
          case "int_cast": {
            builtinName += "intCast";
            break;
          }
          case "ptr_cast": {
            builtinName += "ptrCast";
            break;
          }
          case "const_cast": {
            builtinName += "constCast";
            break;
          }
          case "volatile_cast": {
            builtinName += "volatileCast";
            break;
          }
          case "truncate": {
            builtinName += "truncate";
            break;
          }
          case "has_decl": {
            builtinName += "hasDecl";
            break;
          }
          case "has_field": {
            builtinName += "hasField";
            break;
          }
          case "bit_reverse": {
            builtinName += "bitReverse";
            break;
          }
          case "div_exact": {
            builtinName += "divExact";
            break;
          }
          case "div_floor": {
            builtinName += "divFloor";
            break;
          }
          case "div_trunc": {
            builtinName += "divTrunc";
            break;
          }
          case "mod": {
            builtinName += "mod";
            break;
          }
          case "rem": {
            builtinName += "rem";
            break;
          }
          case "mod_rem": {
            builtinName += "rem";
            break;
          }
          case "shl_exact": {
            builtinName += "shlExact";
            break;
          }
          case "shr_exact": {
            builtinName += "shrExact";
            break;
          }
          case "bitcast": {
            builtinName += "bitCast";
            break;
          }
          case "align_cast": {
            builtinName += "alignCast";
            break;
          }
          case "vector_type": {
            builtinName += "Vector";
            break;
          }
          case "reduce": {
            builtinName += "reduce";
            break;
          }
          case "splat": {
            builtinName += "splat";
            break;
          }
          case "offset_of": {
            builtinName += "offsetOf";
            break;
          }
          case "bit_offset_of": {
            builtinName += "bitOffsetOf";
            break;
          }
          default:
            console.log("builtin function not handled yet or doesn't exist!");
        }

        yield { src: builtinName, tag: Tag.builtin };
        yield Tok.l_paren;
        yield* ex(lhsOp, opts);
        yield Tok.comma;
        yield Tok.space;
        yield* ex(rhsOp, opts);
        yield Tok.r_paren;
        return;
      }

      case "enumLiteral": {
        let literal = expr.enumLiteral;
        yield Tok.period;
        yield { src: literal, tag: Tag.identifier };
        return;
      }

      case "void": {
        yield { src: "void", tag: Tag.identifier };
        return;
      }

      case "null": {
        yield { src: "null", tag: Tag.identifier };
        return;
      }

      case "undefined": {
        yield { src: "undefined", tag: Tag.identifier };
        return;
      }

      case "anytype": {
        yield { src: "anytype", tag: Tag.keyword_anytype };
        return;
      }

      case "this": {
        yield { src: "@This", tag: Tag.builtin };
        yield Tok.l_paren;
        yield Tok.r_paren;
        return;
      }

      case "typeInfo": {
        const arg = zigAnalysis.exprs[expr.typeInfo];
        yield { src: "@typeInfo", tag: Tag.builtin };
        yield Tok.l_paren;
        yield* ex(arg, opts);
        yield Tok.r_paren;
        return;
      }

      case "switchIndex": {
        const switchIndex = zigAnalysis.exprs[expr.switchIndex];
        yield* ex(switchIndex, opts);
        return;
      }

      case "errorSets": {
        const errSetsObj = getType(expr.errorSets);
        yield* ex(errSetsObj.lhs, opts);
        yield Tok.space;
        yield { src: "||", tag: Tag.pipe_pipe };
        yield Tok.space;
        yield* ex(errSetsObj.rhs, opts);
        return;
      }

      case "errorUnion": {
        const errUnionObj = getType(expr.errorUnion);
        yield* ex(errUnionObj.lhs, opts);
        yield { src: "!", tag: Tag.bang };
        yield* ex(errUnionObj.rhs, opts);
        return;
      }

      case "type": {
        let name = "";

        let typeObj = expr.type;
        if (typeof typeObj === "number") typeObj = getType(typeObj);
        switch (typeObj.kind) {
          default:
            throw "TODO: " + typeObj.kind;
          case typeKinds.Type: {
            yield { src: typeObj.name, tag: Tag.identifier };
            return;
          }
          case typeKinds.Void: {
            yield { src: "void", tag: Tag.identifier };
            return;
          }
          case typeKinds.NoReturn: {
            yield { src: "noreturn", tag: Tag.identifier };
            return;
          }
          case typeKinds.ComptimeExpr: {
            yield { src: "anyopaque", tag: Tag.identifier };
            return;
          }
          case typeKinds.Bool: {
            yield { src: "bool", tag: Tag.identifier };
            return;
          }
          case typeKinds.ComptimeInt: {
            yield { src: "comptime_int", tag: Tag.identifier };
            return;
          }
          case typeKinds.ComptimeFloat: {
            yield { src: "comptime_float", tag: Tag.identifier };
            return;
          }
          case typeKinds.Int: {
            yield { src: typeObj.name, tag: Tag.identifier };
            return;
          }
          case typeKinds.Float: {
            yield { src: typeObj.name, tag: Tag.identifier };
            return;
          }
          case typeKinds.Array: {
            yield Tok.l_bracket;
            yield* ex(typeObj.len, opts);
            if (typeObj.sentinel) {
              yield Tok.colon;
              yield* ex(typeObj.sentinel, opts);
            }
            yield Tok.r_bracket;
            yield* ex(typeObj.child, opts);
            return;
          }
          case typeKinds.Optional: {
            yield { src: "?", tag: Tag.question_mark };
            yield* ex(typeObj.child, opts);
            return;
          }
          case typeKinds.Pointer: {
            let ptrObj = typeObj;
            switch (ptrObj.size) {
              default:
                console.log("TODO: implement unhandled pointer size case");
              case pointerSizeEnum.One:
                yield { src: "*", tag: Tag.asterisk };
                break;
              case pointerSizeEnum.Many:
                yield Tok.l_bracket;
                yield { src: "*", tag: Tag.asterisk };
                if (ptrObj.sentinel !== null) {
                  yield Tok.colon;
                  yield* ex(ptrObj.sentinel, opts);
                }
                yield Tok.r_bracket;
                break;
              case pointerSizeEnum.Slice:
                if (ptrObj.is_ref) {
                  yield { src: "*", tag: Tag.asterisk };
                }
                yield Tok.l_bracket;
                if (ptrObj.sentinel !== null) {
                  yield Tok.colon;
                  yield* ex(ptrObj.sentinel, opts);
                }
                yield Tok.r_bracket;
                break;
              case pointerSizeEnum.C:
                yield Tok.l_bracket;
                yield { src: "*", tag: Tag.asterisk };
                yield { src: "c", tag: Tag.identifier };
                if (typeObj.sentinel !== null) {
                  yield Tok.colon;
                  yield* ex(ptrObj.sentinel, opts);
                }
                yield Tok.r_bracket;
                break;
            }
            if (!ptrObj.is_mutable) {
              yield Tok.const;
              yield Tok.space;
            }
            if (ptrObj.is_allowzero) {
              yield { src: "allowzero", tag: Tag.keyword_allowzero };
              yield Tok.space;
            }
            if (ptrObj.is_volatile) {
              yield { src: "volatile", tag: Tag.keyword_volatile };
            }
            if (ptrObj.has_addrspace) {
              yield { src: "addrspace", tag: Tag.keyword_addrspace };
              yield Tok.l_paren;
              yield Tok.period;
              yield Tok.r_paren;
            }
            if (ptrObj.has_align) {
              yield { src: "align", tag: Tag.keyword_align };
              yield Tok.l_paren;
              yield* ex(ptrObj.align, opts);
              if (ptrObj.hostIntBytes !== undefined && ptrObj.hostIntBytes !== null) {
                yield Tok.colon;
                yield* ex(ptrObj.bitOffsetInHost, opts);
                yield Tok.colon;
                yield* ex(ptrObj.hostIntBytes, opts);
              }
              yield Tok.r_paren;
              yield Tok.space;
            }
            yield* ex(ptrObj.child, opts);
            return;
          }
          case typeKinds.Struct: {
            let structObj = typeObj;
            if (structObj.layout !== null) {
              switch (structObj.layout.enumLiteral) {
                case "Packed": {
                  yield { src: "packed", tag: Tag.keyword_packed };
                  break;
                }
                case "Extern": {
                  yield { src: "extern", tag: Tag.keyword_extern };
                  break;
                }
              }
              yield Tok.space;
            }
            yield { src: "struct", tag: Tag.keyword_struct };
            if (structObj.backing_int !== null) {
              yield Tok.l_paren;
              yield* ex(structObj.backing_int, opts);
              yield Tok.r_paren;
            }
            yield Tok.space;
            yield Tok.l_brace;

            if (structObj.field_types.length > 1) {
              yield Tok.enter;
            } else {
              yield Tok.space;
            }

            let indent = 0;
            if (structObj.field_types.length > 1) {
              indent = 1;
            }
            if (opts.indent && structObj.field_types.length > 1) {
              indent += opts.ident;
            }

            let structNode = getAstNode(structObj.src);
            for (let i = 0; i < structObj.field_types.length; i += 1) {
              let fieldNode = getAstNode(structNode.fields[i]);
              let fieldName = fieldNode.name;

              for (let j = 0; j < indent; j += 1) {
                yield Tok.tab;
              }

              if (!typeObj.is_tuple) {
                yield { src: fieldName, tag: Tag.identifier };
              }

              let fieldTypeExpr = structObj.field_types[i];
              if (!typeObj.is_tuple) {
                yield Tok.colon;
                yield Tok.space;
              }
              yield* ex(fieldTypeExpr, { ...opts, indent: indent });

              if (structObj.field_defaults[i] !== null) {
                yield Tok.space;
                yield Tok.eql;
                yield Tok.space;
                yield* ex(structObj.field_defaults[i], opts);
              }

              if (structObj.field_types.length > 1) {
                yield Tok.comma;
                yield Tok.enter;
              } else {
                yield Tok.space;
              }
            }
            yield Tok.r_brace;
            return;
          }
          case typeKinds.Enum: {
            let enumObj = typeObj;
            yield { src: "enum", tag: Tag.keyword_enum };
            if (enumObj.tag) {
              yield Tok.l_paren;
              yield* ex(enumObj.tag, opts);
              yield Tok.r_paren;
            }
            yield Tok.space;
            yield Tok.l_brace;

            let enumNode = getAstNode(enumObj.src);
            let fields_len = enumNode.fields.length;
            if (enumObj.nonexhaustive) {
              fields_len += 1;
            }

            if (fields_len > 1) {
              yield Tok.enter;
            } else {
              yield Tok.space;
            }

            let indent = 0;
            if (fields_len > 1) {
              indent = 1;
            }
            if (opts.indent) {
              indent += opts.indent;
            }

            for (let i = 0; i < enumNode.fields.length; i += 1) {
              let fieldNode = getAstNode(enumNode.fields[i]);
              let fieldName = fieldNode.name;

              for (let j = 0; j < indent; j += 1) yield Tok.tab;
              yield { src: fieldName, tag: Tag.identifier };

              if (enumObj.values[i] !== null) {
                yield Tok.space;
                yield Tok.eql;
                yield Tok.space;
                yield* ex(enumObj.values[i], opts);
              }

              if (fields_len > 1) {
                yield Tok.comma;
                yield Tok.enter;
              }
            }
            for (let j = 0; j < indent; j += 1) yield Tok.tab;
            yield { src: "_", tag: Tag.identifier };
            if (fields_len > 1) {
              yield Tok.comma;
              yield Tok.enter;
            }
            if (opts.indent) {
              for (let j = 0; j < opts.indent; j += 1) yield Tok.tab;
            }
            yield Tok.r_brace;
            return;
          }
          case typeKinds.Union: {
            let unionObj = typeObj;
            if (unionObj.layout !== null) {
              switch (unionObj.layout.enumLiteral) {
                case "Packed": {
                  yield { src: "packed", tag: Tag.keyword_packed };
                  break;
                }
                case "Extern": {
                  yield { src: "extern", tag: Tag.keyword_extern };
                  break;
                }
              }
              yield Tok.space;
            }
            yield { src: "union", tag: Tag.keyword_union };
            if (unionObj.auto_tag) {
              yield Tok.l_paren;
              yield { src: "enum", tag: Tag.keyword_enum };
              if (unionObj.tag) {
                yield Tok.l_paren;
                yield* ex(unionObj.tag, opts);
                yield Tok.r_paren;
                yield Tok.r_paren;
              } else {
                yield Tok.r_paren;
              }
            } else if (unionObj.tag) {
              yield Tok.l_paren;
              yield* ex(unionObj.tag, opts);
              yield Tok.r_paren;
            }
            yield Tok.space;
            yield Tok.l_brace;
            if (unionObj.field_types.length > 1) {
              yield Tok.enter;
            } else {
              yield Tok.space;
            }
            let indent = 0;
            if (unionObj.field_types.length > 1) {
              indent = 1;
            }
            if (opts.indent) {
              indent += opts.indent;
            }
            let unionNode = getAstNode(unionObj.src);
            for (let i = 0; i < unionObj.field_types.length; i += 1) {
              let fieldNode = getAstNode(unionNode.fields[i]);
              let fieldName = fieldNode.name;
              for (let j = 0; j < indent; j += 1) yield Tok.tab;
              yield { src: fieldName, tag: Tag.identifier };

              let fieldTypeExpr = unionObj.field_types[i];
              yield Tok.colon;
              yield Tok.space;

              yield* ex(fieldTypeExpr, { ...opts, indent: indent });

              if (unionObj.field_types.length > 1) {
                yield Tok.comma;
                yield Tok.enter;
              } else {
                yield Tok.space;
              }
            }
            if (opts.indent) {
              for (let j = 0; j < opts.indent; j += 1) yield Tok.tab;
            }
            yield Tok.r_brace;
            return;
          }
          case typeKinds.Opaque: {
            yield { src: "opaque", tag: Tag.keyword_opaque };
            yield Tok.space;
            yield Tok.l_brace;
            yield Tok.r_brace;
            return;
          }
          case typeKinds.EnumLiteral: {
            yield { src: "(enum literal)", tag: Tag.identifier };
            return;
          }
          case typeKinds.ErrorSet: {
            let errSetObj = typeObj;
            if (errSetObj.fields === null) {
              yield { src: "anyerror", tag: Tag.identifier };
            } else if (errSetObj.fields.length == 0) {
              yield { src: "error", tag: Tag.keyword_error };
              yield Tok.l_brace;
              yield Tok.r_brace;
            } else if (errSetObj.fields.length == 1) {
              yield { src: "error", tag: Tag.keyword_error };
              yield Tok.l_brace;
              yield { src: errSetObj.fields[0].name, tag: Tag.identifier };
              yield Tok.r_brace;
            } else {
              yield { src: "error", tag: Tag.keyword_error };
              yield Tok.l_brace;
              yield { src: errSetObj.fields[0].name, tag: Tag.identifier };
              for (let i = 1; i < errSetObj.fields.length; i++) {
                yield Tok.comma;
                yield Tok.space;
                yield { src: errSetObj.fields[i].name, tag: Tag.identifier };
              }
              yield Tok.r_brace;
            }
            return;
          }
          case typeKinds.ErrorUnion: {
            let errUnionObj = typeObj;
            yield* ex(errUnionObj.lhs, opts);
            yield { src: "!", tag: Tag.bang };
            yield* ex(errUnionObj.rhs, opts);
            return;
          }
          case typeKinds.InferredErrorUnion: {
            let errUnionObj = typeObj;
            yield { src: "!", tag: Tag.bang };
            yield* ex(errUnionObj.payload, opts);
            return;
          }
          case typeKinds.Fn: {
            let fnObj = typeObj;
            let fnDecl = opts.fnDecl;
            let linkFnNameDecl = opts.linkFnNameDecl;
            opts.fnDecl = null;
            opts.linkFnNameDecl = null;
            if (opts.addParensIfFnSignature && fnObj.src == 0) {
              yield Tok.l_paren;
            }
            if (fnObj.is_extern) {
              yield { src: "extern", tag: Tag.keyword_extern };
              yield Tok.space;
            } else if (fnObj.has_cc) {
              let cc_expr = zigAnalysis.exprs[fnObj.cc];
              if (cc_expr.enumLiteral === "Inline") {
                yield { src: "inline", tag: Tag.keyword_inline };
                yield Tok.space;
              }
            }
            if (fnObj.has_lib_name) {
              yield { src: '"' + fnObj.lib_name + '"', tag: Tag.string_literal };
              yield Tok.space;
            }
            yield { src: "fn", tag: Tag.keyword_fn };
            yield Tok.space;
            if (fnDecl) {
              if (linkFnNameDecl) {
                yield { src: fnDecl.name, tag: Tag.identifier, link: linkFnNameDecl, fnDecl: false };
              } else {
                yield { src: fnDecl.name, tag: Tag.identifier, fnDecl: true };
              }
            }
            yield Tok.l_paren;
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
                  yield Tok.comma;
                  yield Tok.space;
                }

                let value = fnObj.params[i];
                let paramValue = resolveValue({ expr: value });

                if (fields != null) {
                  let paramNode = getAstNode(fields[i]);

                  if (paramNode.varArgs) {
                    yield Tok.period;
                    yield Tok.period;
                    yield Tok.period;
                    continue;
                  }

                  if (paramNode.noalias) {
                    yield { src: "noalias", tag: Tag.keyword_noalias };
                    yield Tok.space;
                  }

                  if (paramNode.comptime) {
                    yield { src: "comptime", tag: Tag.keyword_comptime };
                    yield Tok.space;
                  }

                  let paramName = paramNode.name;
                  if (paramName != null) {
                    // skip if it matches the type name
                    if (!shouldSkipParamName(paramValue, paramName)) {
                      if (paramName === "") {
                        paramName = "_";
                      }
                      yield { src: paramName, tag: Tag.identifier };
                      yield Tok.colon;
                      yield Tok.space;
                    }
                  }
                }

                // TODO: most of this seems redundant
                if (isVarArgs && i === fnObj.params.length - 1) {
                  yield Tok.period;
                  yield Tok.period;
                  yield Tok.period;
                } else if ("alignOf" in value) {
                  yield* ex(value, opts);
                } else if ("typeOf" in value) {
                  yield* ex(value, opts);
                } else if ("typeOf_peer" in value) {
                  yield* ex(value, opts);
                } else if ("declRef" in value) {
                  yield* ex(value, opts);
                } else if ("call" in value) {
                  yield* ex(value, opts);
                } else if ("refPath" in value) {
                  yield* ex(value, opts);
                } else if ("type" in value) {
                  yield* ex(value, opts);
                  //payloadHtml += '<span class="tok-kw">' + name + "</span>";
                } else if ("binOpIndex" in value) {
                  yield* ex(value, opts);
                } else if ("comptimeExpr" in value) {
                  let comptimeExpr =
                    zigAnalysis.comptimeExprs[value.comptimeExpr].code;
                  yield* Tokenizer(comptimeExpr);
                } else {
                  yield { src: "anytype", tag: Tag.keyword_anytype };
                }
              }
            }

            yield Tok.r_paren;
            yield Tok.space;

            if (fnObj.has_align) {
              let align = zigAnalysis.exprs[fnObj.align];
              yield { src: "align", tag: Tag.keyword_align };
              yield Tok.l_paren;
              yield* ex(align, opts);
              yield Tok.r_paren;
              yield Tok.space;
            }
            if (fnObj.has_cc) {
              let cc = zigAnalysis.exprs[fnObj.cc];
              if (cc) {
                if (cc.enumLiteral !== "Inline") {
                  yield { src: "callconv", tag: Tag.keyword_callconv };
                  yield Tok.l_paren;
                  yield* ex(cc, opts);
                  yield Tok.r_paren;
                  yield Tok.space;
                }
              }
            }

            if (fnObj.is_inferred_error) {
              yield { src: "!", tag: Tag.bang };
            }
            if (fnObj.ret != null) {
              yield* ex(fnObj.ret, {
                ...opts,
                addParensIfFnSignature: true,
              });
            } else {
              yield { src: "anytype", tag: Tag.keyword_anytype };
            }

            if (opts.addParensIfFnSignature && fnObj.src == 0) {
              yield Tok.r_paren;
            }
            return;
          }
        }
      }
      case "typeOf": {
        const typeRefArg = zigAnalysis.exprs[expr.typeOf];
        yield { src: "@TypeOf", tag: Tag.builtin };
        yield Tok.l_paren;
        yield* ex(typeRefArg, opts);
        yield Tok.r_paren;
        return;
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
      getType(zigAnalysis.modules[zigAnalysis.rootMod].main)
    ) {
      name = renderSingleToken(Tok.identifier("std"));
    } else {
      name = renderTokens(ex({ type: typeObj }));
    }
    if (name != null && name != "") {
      domHdrName.innerHTML = "<pre class='inline'>" + name + "</pre> ("
        + zigAnalysis.typeKinds[typeObj.kind] + ")";
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

  function renderValue(decl) {
    let resolvedValue = resolveValue(decl.value);
    if (resolvedValue.expr.fieldRef) {
      const declRef = decl.value.expr.refPath[0].declRef;
      const type = getDecl(declRef);

      domFnProtoCode.innerHTML = renderTokens(
        (function*() {
          yield Tok.const;
          yield Tok.space;
          yield Tok.identifier(decl.name);
          yield Tok.colon;
          yield Tok.space;
          yield Tok.identifier(type.name);
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* ex(decl.value.expr, {});
          yield Tok.semi;
        })());
    } else if (
      resolvedValue.expr.string !== undefined ||
      resolvedValue.expr.call !== undefined ||
      resolvedValue.expr.comptimeExpr !== undefined
    ) {
      domFnProtoCode.innerHTML = renderTokens(
        (function*() {
          yield Tok.const;
          yield Tok.space;
          yield Tok.identifier(decl.name);
          if (decl.value.typeRef) {
            yield Tok.colon;
            yield Tok.space;
            yield* ex(decl.value.typeRef, {});
          }
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* ex(decl.value.expr, {});
          yield Tok.semi;
        })());
    } else if (resolvedValue.expr.compileError) {
      domFnProtoCode.innerHTML = renderTokens(
        (function*() {
          yield Tok.const;
          yield Tok.space;
          yield Tok.identifier(decl.name);
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* ex(decl.value.expr, {});
          yield Tok.semi;
        })());
    } else {
      const parent = getType(decl.parent_container);
      domFnProtoCode.innerHTML = renderTokens(
        (function*() {
          yield Tok.const;
          yield Tok.space;
          yield Tok.identifier(decl.name);
          if (decl.value.typeRef !== null) {
            yield Tok.colon;
            yield Tok.space;
            yield* ex(decl.value.typeRef, {});
          }
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* ex(decl.value.expr, {});
          yield Tok.semi;
        })());
    }

    let docs = getAstNode(decl.src).docs;
    if (docs != null) {
      // TODO: it shouldn't just be decl.parent_container, but rather 
      //       the type that the decl holds (if the value is a type)
      domTldDocs.innerHTML = markdown(docs, decl);

      domTldDocs.classList.remove("hidden");
    }

    domFnProto.classList.remove("hidden");
  }

  function renderVar(decl) {
    let resolvedVar = resolveValue(decl.value);

    if (resolvedVar.expr.fieldRef) {
      const declRef = decl.value.expr.refPath[0].declRef;
      const type = getDecl(declRef);
      domFnProtoCode.innerHTML = renderTokens(
        (function*() {
          yield Tok.var;
          yield Tok.space;
          yield Tok.identifier(decl.name);
          yield Tok.colon;
          yield Tok.space;
          yield Tok.identifier(type.name);
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* ex(decl.value.expr, {});
          yield Tok.semi;
        })());
    } else if (
      resolvedVar.expr.string !== undefined ||
      resolvedVar.expr.call !== undefined ||
      resolvedVar.expr.comptimeExpr !== undefined
    ) {
      domFnProtoCode.innerHTML = renderTokens(
        (function*() {
          yield Tok.var;
          yield Tok.space;
          yield Tok.identifier(decl.name);
          if (decl.value.typeRef) {
            yield Tok.colon;
            yield Tok.space;
            yield* ex(decl.value.typeRef, {});
          }
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* ex(decl.value.expr, {});
          yield Tok.semi;
        })());
    } else if (resolvedVar.expr.compileError) {
      domFnProtoCode.innerHTML = renderTokens(
        (function*() {
          yield Tok.var;
          yield Tok.space;
          yield Tok.identifier(decl.name);
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* ex(decl.value.expr, {});
          yield Tok.semi;
        })());
    } else {
      domFnProtoCode.innerHTML = renderTokens(
        (function*() {
          yield Tok.var;
          yield Tok.space;
          yield Tok.identifier(decl.name);
          yield Tok.colon;
          yield Tok.space;
          yield* ex(resolvedVar.typeRef, {});
          yield Tok.space;
          yield Tok.eql;
          yield Tok.space;
          yield* ex(decl.value.expr, {});
          yield Tok.semi;
        })());
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
    const srcFile = getFile(srcNode.file);
    return sourceFileUrlTemplate.
      replace("{{mod}}", zigAnalysis.modules[srcFile.modIndex].name).
      replace("{{file}}", srcFile.name).
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
        '<div><dt><pre class="inline fnSignature"></pre><div></div></dt><dd></dd></div>'
      );

      for (let i = 0; i < fnsList.length; i += 1) {
        let decl = fnsList[i];
        let trDom = domListFns.children[i];

        let tdFnSignature = trDom.children[0].children[0];
        let tdFnSrc = trDom.children[0].children[1];
        let tdDesc = trDom.children[1];

        let declType = resolveValue(decl.value);
        console.assert("type" in declType.expr);
        tdFnSignature.innerHTML = renderTokens(ex(declType.expr, {
          fnDecl: decl,
          linkFnNameDecl: navLinkDecl(decl.name),
        }));
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
            html += renderTokens((function*() {
              yield Tok.space;
              yield Tok.eql;
              yield Tok.space;
              yield* ex(value, {});
            })());
          }
        } else {
          let fieldTypeExpr = container.field_types[i];
          if (container.kind !== typeKinds.Struct || !container.is_tuple) {
            html += renderTokens((function*() {
              yield Tok.colon;
              yield Tok.space;
            })());
          }
          html += renderTokens(ex(fieldTypeExpr, {}));
          let tsn = typeShorthandName(fieldTypeExpr);
          if (tsn) {
            html += "<span> (" + tsn + ")</span>";
          }
          if (container.kind === typeKinds.Struct && !container.is_tuple) {
            let defaultInitExpr = container.field_defaults[i];
            if (defaultInitExpr !== null) {
              html += renderTokens((function*() {
                yield Tok.space;
                yield Tok.eql;
                yield Tok.space;
                yield* ex(defaultInitExpr, {});
              })());
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
        '<tr><td><a href="#"></a></td><td><pre class="inline"></pre></td><td></td></tr>'
      );
      for (let i = 0; i < varsList.length; i += 1) {
        let decl = varsList[i];
        let trDom = domListGlobalVars.children[i];

        let tdName = trDom.children[0];
        let tdNameA = tdName.children[0];
        let tdType = trDom.children[1];
        let preType = tdType.children[0];
        let tdDesc = trDom.children[2];

        tdNameA.setAttribute("href", navLinkDecl(decl.name));
        tdNameA.textContent = decl.name;

        preType.innerHTML = renderTokens(ex(walkResultTypeRef(decl.value), {}));

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
        '<tr><td><a href="#"></a></td><td><pre class="inline"></pre></td><td></td></tr>'
      );
      for (let i = 0; i < valsList.length; i += 1) {
        let decl = valsList[i];
        let trDom = domListValues.children[i];

        let tdName = trDom.children[0];
        let tdNameA = tdName.children[0];
        let tdType = trDom.children[1];
        let preType = tdType.children[0];
        let tdDesc = trDom.children[2];

        tdNameA.setAttribute("href", navLinkDecl(decl.name));
        tdNameA.textContent = decl.name;

        preType.innerHTML = renderTokens(ex(walkResultTypeRef(decl.value), {}));

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
        '<tr><td><pre class="inline"></pre></td><td><pre class="inline"></pre></td><td></td></tr>'
      );
      for (let i = 0; i < testsList.length; i += 1) {
        let decl = testsList[i];
        let trDom = domListTests.children[i];

        let tdName = trDom.children[0];
        let tdNamePre = tdName.children[0];
        let tdType = trDom.children[1];
        let tdTypePre = tdType.children[0];
        let tdDesc = trDom.children[2];

        tdNamePre.innerHTML = renderSingleToken(Tok.identifier(decl.name));

        tdTypePre.innerHTML = ex(walkResultTypeRef(decl.value), {});

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
    let rootMod = zigAnalysis.modules[zigAnalysis.rootMod];
    if (rootMod.table["std"] == null) {
      // no std mapped into the root module
      return false;
    }
    let stdMod = zigAnalysis.modules[rootMod.table["std"]];
    if (stdMod == null) return false;
    return rootMod.file === stdMod.file;
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
      modNames: [],
      modObjs: [],
      declNames: [],
      declObjs: [],
      callName: null,
    };
    curNavSearch = "";

    const mode = location.hash.substring(0, 3);
    let query = location.hash.substring(3);

    let qpos = query.indexOf("?");
    let nonSearchPart;
    if (qpos === -1) {
      nonSearchPart = query;
    } else {
      nonSearchPart = query.substring(0, qpos);
      curNavSearch = decodeURIComponent(query.substring(qpos + 1));
    }

    const DEFAULT_HASH = NAV_MODES.API + zigAnalysis.modules[zigAnalysis.rootMod].name;
    switch (mode) {
      case NAV_MODES.API:
        // #A;MODULE:decl.decl.decl?search-term
        curNav.mode = mode;

        let parts = nonSearchPart.split(":");
        if (parts[0] == "") {
          location.hash = DEFAULT_HASH;
        } else {
          curNav.modNames = decodeURIComponent(parts[0]).split(".");
        }

        if (parts[1] != null) {
          curNav.declNames = decodeURIComponent(parts[1]).split(".");
        }

        return;
      case NAV_MODES.GUIDES:

        const sections = zigAnalysis.guide_sections;
        if (sections.length != 0 && sections[0].guides.length != 0 && nonSearchPart == "") {
          location.hash = NAV_MODES.GUIDES + sections[0].guides[0].name;
          if (qpos != -1) {
            location.hash += query.substring(qpos);
          }
          return;
        }

        curNav.mode = mode;
        curNav.activeGuide = nonSearchPart;

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
          childDecl.is_private = true;
          return childDecl;
        } else if (childDecl.is_uns) {
          let declValue = resolveValue(childDecl.value);
          if (!("type" in declValue.expr)) continue;
          let uns_container = getType(declValue.expr.type);
          let uns_res = findSubDecl(uns_container, childName);
          uns_res.is_private = true;
          if (uns_res !== null) return uns_res;
        }
      }
    }

    return null;
  }

  function computeCanonicalModulePaths() {
    let list = new Array(zigAnalysis.modules.length);
    // Now we try to find all the modules from root.
    let rootMod = zigAnalysis.modules[zigAnalysis.rootMod];
    // Breadth-first to keep the path shortest possible.
    let stack = [
      {
        path: [],
        mod: rootMod,
      },
    ];
    while (stack.length !== 0) {
      let item = stack.shift();
      for (let key in item.mod.table) {
        let childModIndex = item.mod.table[key];
        if (list[childModIndex] != null) continue;
        let childMod = zigAnalysis.modules[childModIndex];
        if (childMod == null) continue;

        let newPath = item.path.concat([key]);
        list[childModIndex] = newPath;
        stack.push({
          path: newPath,
          mod: childMod,
        });
      }
    }

    for (let i = 0; i < zigAnalysis.modules.length; i += 1) {
      const p = zigAnalysis.modules[i];
      // TODO
      // declSearchIndex.add(p.name, {moduleId: i});
    }
    return list;
  }

  function computeCanonDeclPaths() {
    let list = new Array(zigAnalysis.decls.length);
    canonTypeDecls = new Array(zigAnalysis.types.length);

    for (let modI = 0; modI < zigAnalysis.modules.length; modI += 1) {
      let mod = zigAnalysis.modules[modI];
      let modNames = canonModPaths[modI];
      if (modNames === undefined) continue;

      let stack = [
        {
          declNames: [],
          declIndexes: [],
          type: getType(mod.main),
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
              while (unsDeclList.length != 0) {
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
                    addDeclToSearchResults(childDecl, childDeclIndex, modNames, item, list, stack);
                  }
                }
              }
            } else {
              addDeclToSearchResults(decl, declIndex, modNames, item, list, stack);
            }
          }
        }
      }
    }
    window.cdp = list;
    return list;
  }

  function addDeclToSearchResults(decl, declIndex, modNames, item, list, stack) {
    let {value: declVal, seenDecls} = resolveValue(decl.value, true);
    let declNames = item.declNames.concat([decl.name]);
    let declIndexes = item.declIndexes.concat([declIndex]);

    if (list[declIndex] != null) return;
    list[declIndex] = {
      modNames: modNames,
      declNames: declNames,
      declIndexes: declIndexes,
    };

    for (let sd of seenDecls) {
      if (list[sd] != null) continue;
      list[sd] = {
        modNames: modNames,
        declNames: declNames,
        declIndexes: declIndexes,
      };
    }

    // add to search index
    {
      declSearchIndex.add(decl.name, { declIndex });
    }


    if ("type" in declVal.expr) {
      let value = getType(declVal.expr.type);
      if (declCanRepresentTypeKind(value.kind)) {
        canonTypeDecls[declVal.type] = declIndex;
      }

      if (isContainerType(value)) {
        stack.push({
          declNames: declNames,
          declIndexes: declIndexes,
          type: value,
        });
      }

      // Generic function
      if (typeIsGenericFn(declVal.expr.type)) {
        let ret = resolveGenericRet(value);
        if (ret != null && "type" in ret.expr) {
          let generic_type = getType(ret.expr.type);
          if (isContainerType(generic_type)) {
            stack.push({
              declNames: declNames,
              declIndexes: declIndexes,
              type: generic_type,
            });
          }
        }
      }
    }
  }

  function declLinkOrSrcLink(index) {
    
    let match = getCanonDeclPath(index);
    if (match) return navLink(match.modNames, match.declNames);

    // could not find a precomputed decl path
    const decl = getDecl(index);
    
    // try to find a public decl by scanning declRefs and declPaths
    let value = decl.value;    
    let i = 0;
    while (true) {
      i += 1;
      if (i >= 10000) {
        throw "getCanonDeclPath quota exceeded"
      }

      if ("refPath" in value.expr) {
        value = { expr: value.expr.refPath[value.expr.refPath.length - 1] };
        continue;
      }

      if ("declRef" in value.expr) {
        let cp = canonDeclPaths[value.expr.declRef];
        if (cp) return navLink(cp.modNames, cp.declNames);
        
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

      // if we got here it means that we failed 
      // produce a link to source code instead
      return sourceFileLink(decl);

    }
    
  }

  function getCanonDeclPath(index) {
    if (canonDeclPaths == null) {
      canonDeclPaths = computeCanonDeclPaths();
    }
    
    return canonDeclPaths[index];

      
  }

  function getCanonTypeDecl(index) {
    getCanonDeclPath(0);
    //let ct = (canonTypeDecls);
    return canonTypeDecls[index];
  }

  function escapeHtml(text) {
    return text.replace(/[&"<>]/g, function(m) {
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

  function parseGuides() {
    for (let j = 0; j < zigAnalysis.guide_sections.length; j += 1) {
      const section = zigAnalysis.guide_sections[j];
      for (let i = 0; i < section.guides.length; i += 1) {
        let reader = new commonmark.Parser({ smart: true });
        const guide = section.guides[i];
        const ast = reader.parse(guide.body);

        // Find the first text thing to use as a sidebar title
        guide.title = "[empty guide]";
        {
          let walker = ast.walker();
          let event, node;
          while ((event = walker.next())) {
            node = event.node;
            if (node.type === 'text') {
              guide.title = node.literal;
              break;
            }
          }
        }
        // Index this guide
        {
          let walker = ast.walker();
          let event, node;
          while ((event = walker.next())) {
            node = event.node;
            if (event.entering == true && node.type === 'text') {
              indexTextForGuide(j, i, node);
            }
          }
        }
      }
    }
  }

  function indexTextForGuide(section_idx, guide_idx, node) {
    const terms = node.literal.split(" ");
    for (let i = 0; i < terms.length; i += 1) {
      const t = terms[i];
      if (!guidesSearchIndex[t]) guidesSearchIndex[t] = new Set();
      node.guide = { section_idx, guide_idx };
      guidesSearchIndex[t].add(node);
    }
  }


  function markdown(input, contextType) {
    const parsed = new commonmark.Parser({ smart: true }).parse(input);

    // Look for decl references in inline code (`ref`)
    const walker = parsed.walker();
    let event;
    while ((event = walker.next())) {
      const node = event.node;
      if (node.type === "code") {
        const declHash = detectDeclPath(node.literal, contextType);
        if (declHash) {
          const link = new commonmark.Node("link");
          link.destination = declHash;
          node.insertBefore(link);
          link.appendChild(node);
        }
      }
    }

    return new commonmark.HtmlRenderer({ safe: true }).render(parsed);

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

        let lastModName = canonPath.modNames[canonPath.modNames.length - 1];
        let fullPath = lastModName + ":" + canonPath.declNames.join(".");

        separator = '.';
        result = "#A;" + fullPath;
      }

      break;
    }

    if (!curDeclOrType) {
      for (let i = 0; i < zigAnalysis.modules.length; i += 1) {
        const p = zigAnalysis.modules[i];
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
    if (isModalVisible(domHelpModal)) {
      hideModal(domHelpModal);
      ev.preventDefault();
      ev.stopPropagation();
    } else if (isModalVisible(domPrefsModal)) {
      hideModal(domPrefsModal);
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
        // Search is triggered via an `input` event handler, not on arbitrary `keydown` events.
        ev.stopPropagation();
        return;
    }
  }

  let domDotsToggleTimeout = null;
  function onSearchInput(ev) {
    curSearchIndex = -1;
  
    let replaced = domSearch.value.replaceAll(".", " ");
    if (replaced != domSearch.value) {
      domSearch.value = replaced;
      domSearchHelpSummary.classList.remove("normal");
      if (domDotsToggleTimeout != null) {
        clearTimeout(domDotsToggleTimeout);
        domDotsToggleTimeout = null;
      } 
      domDotsToggleTimeout = setTimeout(function () { 
        domSearchHelpSummary.classList.add("normal"); 
      }, 1000);
    } 
    startAsyncSearch();
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
      case "/":
        if (!getPrefSlashSearch()) break;
      // fallthrough
      case "s":
        if (!isModalVisible(domHelpModal) && !isModalVisible(domPrefsModal)) {
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
        if (!canToggleModal) break;

        if (isModalVisible(domPrefsModal)) {
          hideModal(domPrefsModal);
        }

        // toggle the help modal
        if (isModalVisible(domHelpModal)) {
          hideModal(domHelpModal);
        } else {
          showModal(domHelpModal);
        }
        ev.preventDefault();
        ev.stopPropagation();
        break;
      case "p":
        if (!canToggleModal) break;

        if (isModalVisible(domHelpModal)) {
          hideModal(domHelpModal);
        }

        // toggle the preferences modal
        if (isModalVisible(domPrefsModal)) {
          hideModal(domPrefsModal);
        } else {
          showModal(domPrefsModal);
        }
        ev.preventDefault();
        ev.stopPropagation();
    }
  }

  function isModalVisible(modal) {
    return !modal.classList.contains("hidden");
  }

  function showModal(modal) {
    modal.classList.remove("hidden");
    modal.style.left =
      window.innerWidth / 2 - modal.clientWidth / 2 + "px";
    modal.style.top =
      window.innerHeight / 2 - modal.clientHeight / 2 + "px";
    const firstInput = modal.querySelector("input");
    if (firstInput) {
      firstInput.focus();
    } else {
      modal.focus();
    }
    domSearch.blur();
    domBanner.inert = true;
    domMain.inert = true;
  }

  function hideModal(modal) {
    modal.classList.add("hidden");
    domBanner.inert = false;
    domMain.inert = false;
    modal.blur();
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
    return list;
  }

  function renderSearchGuides() {
    const searchTrimmed = false;
    let ignoreCase = curNavSearch.toLowerCase() === curNavSearch;

    let terms = getSearchTerms();
    let matchedItems = new Set();

    for (let i = 0; i < terms.length; i += 1) {
      const nodes = guidesSearchIndex[terms[i]];
      if (nodes) {
        for (const n of nodes) {
          matchedItems.add(n);
        }
      }
    }



    if (matchedItems.size !== 0) {
      // Build up the list of search results
      let matchedItemsHTML = "";

      for (const node of matchedItems) {
        const text = node.literal;
        const href = "";

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

  function renderSearchAPI() {
    if (canonDeclPaths == null) {
      canonDeclPaths = computeCanonDeclPaths();
    }
    let declSet = new Set();
    let otherDeclSet = new Set(); // for low quality results
    let declScores = {};

    let ignoreCase = curNavSearch.toLowerCase() === curNavSearch;
    let term_list = getSearchTerms();
    for (let i = 0; i < term_list.length; i += 1) {
      let term = term_list[i];
      let result = declSearchIndex.search(term.toLowerCase());
      if (result == null) {
        domSectSearchNoResults.classList.remove("hidden");
        domSectSearchResults.classList.add("hidden");
        return;
      }

      let termSet = new Set();
      let termOtherSet = new Set();

      for (let list of [result.full, result.partial]) {
        for (let r of list) {
          const d = r.declIndex;
          const decl = getDecl(d);
          const canonPath = getCanonDeclPath(d);

          // collect unconditionally for the first term
          if (i == 0) {
            declSet.add(d);
          } else {
            // path intersection for subsequent terms
            let found = false;
            for (let p of canonPath.declIndexes) {
              if (declSet.has(p)) {
                found = true;
                break;
              }
            }
            if (!found) {
              otherDeclSet.add(d);
            } else {
              termSet.add(d);
            }
          }

          if (declScores[d] == undefined) declScores[d] = 0;

          // scores (lower is better)
          let decl_name = decl.name;
          if (ignoreCase) decl_name = decl_name.toLowerCase();

          // shallow path are preferable
          const path_depth = canonPath.declNames.length * 50;
          // matching the start of a decl name is good
          const match_from_start = decl_name.startsWith(term) ? -term.length * (2 - ignoreCase) : (decl_name.length - term.length) + 1;
          // being a perfect match is good
          const is_full_match = (decl_name === term) ? -decl_name.length * (1 - ignoreCase) : Math.abs(decl_name.length - term.length);
          // matching the end of a decl name is good
          const matches_the_end = decl_name.endsWith(term) ? -term.length * (1 - ignoreCase) : (decl_name.length - term.length) + 1;
          // explicitly penalizing scream case decls
          const decl_is_scream_case = decl.name.toUpperCase() != decl.name ? 0 : decl.name.length;

          const score = path_depth
            + match_from_start
            + is_full_match
            + matches_the_end
            + decl_is_scream_case;

          declScores[d] += score;
        }
      }
      if (i != 0) {
        for (let d of declSet) {
          if (termSet.has(d)) continue;
          let found = false;
          for (let p of getCanonDeclPath(d).declIndexes) {
            if (termSet.has(p) || otherDeclSet.has(p)) {
              found = true;
              break;
            }
          }
          if (found) {
            declScores[d] = declScores[d] / term_list.length;
          }

          termOtherSet.add(d);
        }
        declSet = termSet;
        for (let d of termOtherSet) {
          otherDeclSet.add(d);
        }

      }
    }

    let matchedItems = {
      high_quality: [],
      low_quality: [],
    };
    for (let idx of declSet) {
      matchedItems.high_quality.push({ points: declScores[idx], declIndex: idx })
    }
    for (let idx of otherDeclSet) {
      matchedItems.low_quality.push({ points: declScores[idx], declIndex: idx })
    }

    matchedItems.high_quality.sort(function(a, b) {
      let cmp = operatorCompare(a.points, b.points);
      return cmp;
    });
    matchedItems.low_quality.sort(function(a, b) {
      let cmp = operatorCompare(a.points, b.points);
      return cmp;
    });

    // Build up the list of search results
    let matchedItemsHTML = "";

    for (let list of [matchedItems.high_quality, matchedItems.low_quality]) {
      if (list == matchedItems.low_quality && list.length > 0) {
        matchedItemsHTML += "<hr class='other-results'>"
      }
      for (let result of list) {
        const points = result.points;
        const match = result.declIndex;

        let canonPath = getCanonDeclPath(match);
        if (canonPath == null) continue;

        let lastModName = canonPath.modNames[canonPath.modNames.length - 1];
        let text = lastModName + "." + canonPath.declNames.join(".");


        const href = navLink(canonPath.modNames, canonPath.declNames);

        matchedItemsHTML += "<li><a href=\"" + href + "\">" + text + "</a></li>";
      }
    }

    // Replace the search results using our newly constructed HTML string
    domListSearchResults.innerHTML = matchedItemsHTML;
    renderSearchCursor();

    domSectSearchResults.classList.remove("hidden");
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

  function getFile(idx) {
    const file = zigAnalysis.files[idx];
    return {
      name: file[0],
      modIndex: file[1],
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
          backing_int: ty[7],
          is_tuple: ty[8],
          line_number: ty[9],
          parent_container: ty[10],
          layout: ty[11],
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
          layout: ty[9],
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

  function getLocalStorage() {
    if ("localStorage" in window) {
      try {
        return window.localStorage;
      } catch (ignored) {
        // localStorage may be disabled (SecurityError)
      }
    }
    // If localStorage isn't available, persist preferences only for the current session
    const sessionPrefs = {};
    return {
      getItem(key) {
        return key in sessionPrefs ? sessionPrefs[key] : null;
      },
      setItem(key, value) {
        sessionPrefs[key] = String(value);
      },
    };
  }

  function loadPrefs() {
    const storedPrefSlashSearch = prefs.getItem("slashSearch");
    if (storedPrefSlashSearch === null) {
      // Slash search defaults to enabled for all browsers except Firefox
      setPrefSlashSearch(navigator.userAgent.indexOf("Firefox") === -1);
    } else {
      setPrefSlashSearch(storedPrefSlashSearch === "true");
    }
  }

  function getPrefSlashSearch() {
    return prefs.getItem("slashSearch") === "true";
  }

  function setPrefSlashSearch(enabled) {
    prefs.setItem("slashSearch", String(enabled));
    domPrefSlashSearch.checked = enabled;
    const searchKeys = enabled ? "<kbd>/</kbd> or <kbd>s</kbd>" : "<kbd>s</kbd>";
    domSearchKeys.innerHTML = searchKeys;
    domSearchPlaceholder.innerHTML = searchKeys + " to search, <kbd>?</kbd> for more options";
  }
})();

function toggleExpand(event) {
  const parent = event.target.parentElement;
  parent.toggleAttribute("open");

  if (!parent.open && parent.getBoundingClientRect().top < 0) {
    parent.parentElement.parentElement.scrollIntoView(true);
  }
}

function RadixTree() {
  this.root = null;

  RadixTree.prototype.search = function(query) {
    return this.root.search(query);

  }

  RadixTree.prototype.add = function(declName, value) {
    if (this.root == null) {
      this.root = new Node(declName.toLowerCase(), null, [value]);
    } else {
      this.root.add(declName.toLowerCase(), value);
    }

    const not_scream_case = declName.toUpperCase() != declName;
    let found_separator = false;
    for (let i = 1; i < declName.length; i += 1) {
      if (declName[i] == '_' || declName[i] == '.') {
        found_separator = true;
        continue;
      }


      if (found_separator || (declName[i].toLowerCase() !== declName[i])) {
        if (declName.length > i + 1
          && declName[i + 1].toLowerCase() != declName[i + 1]) continue;
        let suffix = declName.slice(i);
        this.root.add(suffix.toLowerCase(), value);
        found_separator = false;
      }
    }
  }

  function Node(labels, next, values) {
    this.labels = labels;
    this.next = next;
    this.values = values;
  }

  Node.prototype.isCompressed = function() {
    return !Array.isArray(this.next);
  }

  Node.prototype.search = function(word) {
    let full_matches = [];
    let partial_matches = [];
    let subtree_root = null;

    let cn = this;
    char_loop: for (let i = 0; i < word.length;) {
      if (cn.isCompressed()) {
        for (let j = 0; j < cn.labels.length; j += 1) {
          let current_idx = i + j;

          if (current_idx == word.length) {
            partial_matches = cn.values;
            subtree_root = cn.next;
            break char_loop;
          }

          if (word[current_idx] != cn.labels[j]) return null;
        }

        // the full label matched
        let new_idx = i + cn.labels.length;
        if (new_idx == word.length) {
          full_matches = cn.values;
          subtree_root = cn.next;
          break char_loop;
        }


        i = new_idx;
        cn = cn.next;
        continue;
      } else {
        for (let j = 0; j < cn.labels.length; j += 1) {
          if (word[i] == cn.labels[j]) {
            if (i == word.length - 1) {
              full_matches = cn.values[j];
              subtree_root = cn.next[j];
              break char_loop;
            }

            let next = cn.next[j];
            if (next == null) return null;
            cn = next;
            i += 1;
            continue char_loop;
          }
        }

        // didn't find a match
        return null;
      }
    }

    // Match was found, let's collect all other 
    // partial matches from the subtree
    let stack = [subtree_root];
    let node;
    while (node = stack.pop()) {
      if (node.isCompressed()) {
        partial_matches = partial_matches.concat(node.values);
        if (node.next != null) {
          stack.push(node.next);
        }
      } else {
        for (let v of node.values) {
          partial_matches = partial_matches.concat(v);
        }

        for (let n of node.next) {
          if (n != null) stack.push(n);
        }
      }
    }

    return { full: full_matches, partial: partial_matches };
  }

  Node.prototype.add = function(word, value) {
    let cn = this;
    char_loop: for (let i = 0; i < word.length;) {
      if (cn.isCompressed()) {
        for (let j = 0; j < cn.labels.length; j += 1) {
          let current_idx = i + j;

          if (current_idx == word.length) {
            if (j < cn.labels.length - 1) {
              let node = new Node(cn.labels.slice(j), cn.next, cn.values);
              cn.labels = cn.labels.slice(0, j);
              cn.next = node;
              cn.values = [];
            }
            cn.values.push(value);
            return;
          }

          if (word[current_idx] == cn.labels[j]) continue;

          // if we're here, a mismatch was found
          if (j != cn.labels.length - 1) {
            // create a suffix node
            const label_suffix = cn.labels.slice(j + 1);
            let node = new Node(label_suffix, cn.next, [...cn.values]);
            cn.next = node;
            cn.values = [];
          }

          // turn current node into a split node
          let node = null;
          let word_values = [];
          if (current_idx == word.length - 1) {
            // mismatch happened in the last character of word
            // meaning that the current node should hold its value
            word_values.push(value);
          } else {
            node = new Node(word.slice(current_idx + 1), null, [value]);
          }

          cn.labels = cn.labels[j] + word[current_idx];
          cn.next = [cn.next, node];
          cn.values = [cn.values, word_values];

          if (j != 0) {
            // current node must be turned into a prefix node
            let splitNode = new Node(cn.labels, cn.next, cn.values);
            cn.labels = word.slice(i, current_idx);
            cn.next = splitNode;
            cn.values = [];
          }

          return;
        }
        // label matched fully with word, are there any more chars?
        const new_idx = i + cn.labels.length;
        if (new_idx == word.length) {
          cn.values.push(value);
          return;
        } else {
          if (cn.next == null) {
            let node = new Node(word.slice(new_idx), null, [value]);
            cn.next = node;
            return;
          } else {
            cn = cn.next;
            i = new_idx;
            continue;
          }
        }
      } else { // node is not compressed
        let letter = word[i];
        for (let j = 0; j < cn.labels.length; j += 1) {
          if (letter == cn.labels[j]) {
            if (i == word.length - 1) {
              cn.values[j].push(value);
              return;
            }
            if (cn.next[j] == null) {
              let node = new Node(word.slice(i + 1), null, [value]);
              cn.next[j] = node;
              return;
            } else {
              cn = cn.next[j];
              i += 1;
              continue char_loop;
            }
          }
        }

        // if we're here we didn't find a match
        cn.labels += letter;
        if (i == word.length - 1) {
          cn.next.push(null);
          cn.values.push([value]);
        } else {
          let node = new Node(word.slice(i + 1), null, [value]);
          cn.next.push(node);
          cn.values.push([]);
        }
        return;
      }
    }
  }
}

