(function() {
    const CAT_namespace = 0;
    const CAT_container = 1;
    const CAT_global_variable = 2;
    const CAT_function = 3;
    const CAT_primitive = 4;
    const CAT_error_set = 5;
    const CAT_global_const = 6;
    const CAT_alias = 7;
    const CAT_type = 8;
    const CAT_type_type = 9;
    const CAT_type_function = 10;

    const LOG_err = 0;
    const LOG_warn = 1;
    const LOG_info = 2;
    const LOG_debug = 3;

    const domDocTestsCode = document.getElementById("docTestsCode");
    const domFnErrorsAnyError = document.getElementById("fnErrorsAnyError");
    const domFnProto = document.getElementById("fnProto");
    const domFnProtoCode = document.getElementById("fnProtoCode");
    const domHdrName = document.getElementById("hdrName");
    const domHelpModal = document.getElementById("helpDialog");
    const domListErrSets = document.getElementById("listErrSets");
    const domListFields = document.getElementById("listFields");
    const domListParams = document.getElementById("listParams");
    const domListFnErrors = document.getElementById("listFnErrors");
    const domListFns = document.getElementById("listFns");
    const domListGlobalVars = document.getElementById("listGlobalVars");
    const domListInfo = document.getElementById("listInfo");
    const domListNamespaces = document.getElementById("listNamespaces");
    const domListNav = document.getElementById("listNav");
    const domListSearchResults = document.getElementById("listSearchResults");
    const domListTypes = document.getElementById("listTypes");
    const domListValues = document.getElementById("listValues");
    const domSearch = document.getElementById("search");
    const domSectDocTests = document.getElementById("sectDocTests");
    const domSectErrSets = document.getElementById("sectErrSets");
    const domSectFields = document.getElementById("sectFields");
    const domSectParams = document.getElementById("sectParams");
    const domSectFnErrors = document.getElementById("sectFnErrors");
    const domSectFns = document.getElementById("sectFns");
    const domSectGlobalVars = document.getElementById("sectGlobalVars");
    const domSectNamespaces = document.getElementById("sectNamespaces");
    const domSectNav = document.getElementById("sectNav");
    const domSectSearchNoResults = document.getElementById("sectSearchNoResults");
    const domSectSearchResults = document.getElementById("sectSearchResults");
    const domSectSource = document.getElementById("sectSource");
    const domSectTypes = document.getElementById("sectTypes");
    const domSectValues = document.getElementById("sectValues");
    const domSourceText = document.getElementById("sourceText");
    const domStatus = document.getElementById("status");
    const domTableFnErrors = document.getElementById("tableFnErrors");
    const domTldDocs = document.getElementById("tldDocs");
    const domErrors = document.getElementById("errors");
    const domErrorsText = document.getElementById("errorsText");

    var searchTimer = null;

    const curNav = {
      // 0 = home
      // 1 = decl (decl)
      // 2 = source (path)
      tag: 0,
      // unsigned int: decl index
      decl: null,
      // string file name matching tarball path
      path: null,

      // when this is populated, pressing the "view source" command will
      // navigate to this hash.
      viewSourceHash: null,
    };
    var curNavSearch = "";
    var curSearchIndex = -1;
    var imFeelingLucky = false;

    // names of modules in the same order as wasm
    const moduleList = [];

    let wasm_promise = fetch("main.wasm");
    let sources_promise = fetch("sources.tar").then(function(response) {
      if (!response.ok) throw new Error("unable to download sources");
      return response.arrayBuffer();
    });
    var wasm_exports = null;

    const text_decoder = new TextDecoder();
    const text_encoder = new TextEncoder();

    WebAssembly.instantiateStreaming(wasm_promise, {
      js: {
        log: function(level, ptr, len) {
          const msg = decodeString(ptr, len);
          switch (level) {
            case LOG_err:
              console.error(msg);
              domErrorsText.textContent += msg + "\n";
              domErrors.classList.remove("hidden");
              break;
            case LOG_warn:
              console.warn(msg);
              break;
            case LOG_info:
              console.info(msg);
              break;
            case LOG_debug:
              console.debug(msg);
              break;
          }
        },
      },
    }).then(function(obj) {
      wasm_exports = obj.instance.exports;
      window.wasm = obj; // for debugging

      sources_promise.then(function(buffer) {
        const js_array = new Uint8Array(buffer);
        const ptr = wasm_exports.alloc(js_array.length);
        const wasm_array = new Uint8Array(wasm_exports.memory.buffer, ptr, js_array.length);
        wasm_array.set(js_array);
        wasm_exports.unpack(ptr, js_array.length);

        updateModuleList();

        window.addEventListener('popstate', onPopState, false);
        domSearch.addEventListener('keydown', onSearchKeyDown, false);
        domSearch.addEventListener('input', onSearchChange, false);
        window.addEventListener('keydown', onWindowKeyDown, false);
        onHashChange(null);
      });
    });

    function renderTitle() {
      const suffix = " - Zig Documentation";
      if (curNavSearch.length > 0) {
        document.title = curNavSearch + " - Search" + suffix;
      } else if (curNav.decl != null) {
        document.title = fullyQualifiedName(curNav.decl) + suffix;
      } else if (curNav.path != null) {
        document.title = curNav.path + suffix;
      } else {
        document.title = moduleList[0] + suffix; // Home
      }
    }

    function render() {
        domFnErrorsAnyError.classList.add("hidden");
        domFnProto.classList.add("hidden");
        domHdrName.classList.add("hidden");
        domHelpModal.classList.add("hidden");
        domSectErrSets.classList.add("hidden");
        domSectDocTests.classList.add("hidden");
        domSectFields.classList.add("hidden");
        domSectParams.classList.add("hidden");
        domSectFnErrors.classList.add("hidden");
        domSectFns.classList.add("hidden");
        domSectGlobalVars.classList.add("hidden");
        domSectNamespaces.classList.add("hidden");
        domSectNav.classList.add("hidden");
        domSectSearchNoResults.classList.add("hidden");
        domSectSearchResults.classList.add("hidden");
        domSectSource.classList.add("hidden");
        domSectTypes.classList.add("hidden");
        domSectValues.classList.add("hidden");
        domStatus.classList.add("hidden");
        domTableFnErrors.classList.add("hidden");
        domTldDocs.classList.add("hidden");

        renderTitle();

        if (curNavSearch !== "") return renderSearch();

        switch (curNav.tag) {
          case 0: return renderHome();
          case 1:
            if (curNav.decl == null) {
              return renderNotFound();
            } else {
              return renderDecl(curNav.decl);
            }
          case 2: return renderSource(curNav.path);
          default: throw new Error("invalid navigation state");
        }
    }

    function renderHome() {
      if (moduleList.length == 0) {
        domStatus.textContent = "sources.tar contains no modules";
        domStatus.classList.remove("hidden");
        return;
      }
      return renderModule(0);
    }

    function renderModule(pkg_index) {
      const root_decl = wasm_exports.find_module_root(pkg_index);
      return renderDecl(root_decl);
    }

    function renderDecl(decl_index) {
      const category = wasm_exports.categorize_decl(decl_index, 0);
      switch (category) {
        case CAT_namespace:
        case CAT_container:
          return renderNamespacePage(decl_index);
        case CAT_global_variable:
        case CAT_primitive:
        case CAT_global_const:
        case CAT_type:
        case CAT_type_type:
          return renderGlobal(decl_index);
        case CAT_function:
          return renderFunction(decl_index);
        case CAT_type_function:
          return renderTypeFunction(decl_index);
        case CAT_error_set:
          return renderErrorSetPage(decl_index);
        case CAT_alias:
          return renderDecl(wasm_exports.get_aliasee());
        default:
          throw new Error("unrecognized category " + category);
      }
    }

    function renderSource(path) {
      const decl_index = findFileRoot(path);
      if (decl_index == null) return renderNotFound();

      renderNavFancy(decl_index, [{
        name: "[src]",
        href: location.hash,
      }]);

      domSourceText.innerHTML = declSourceHtml(decl_index);

      domSectSource.classList.remove("hidden");
    }

    function renderDeclHeading(decl_index) {
      curNav.viewSourceHash = "#src/" + unwrapString(wasm_exports.decl_file_path(decl_index));

      const hdrNameSpan = domHdrName.children[0];
      const srcLink = domHdrName.children[1];
      hdrNameSpan.innerText = unwrapString(wasm_exports.decl_category_name(decl_index));
      srcLink.setAttribute('href', curNav.viewSourceHash);
      domHdrName.classList.remove("hidden");

      renderTopLevelDocs(decl_index);
    }

    function renderTopLevelDocs(decl_index) {
      const tld_docs_html = unwrapString(wasm_exports.decl_docs_html(decl_index, false));
      if (tld_docs_html.length > 0) {
        domTldDocs.innerHTML = tld_docs_html;
        domTldDocs.classList.remove("hidden");
      }
    }

    function renderNav(cur_nav_decl, list) {
      return renderNavFancy(cur_nav_decl, []);
    }

    function renderNavFancy(cur_nav_decl, list) {
      {
        // First, walk backwards the decl parents within a file.
        let decl_it = cur_nav_decl;
        let prev_decl_it = null;
        while (decl_it != null) {
          list.push({
            name: declIndexName(decl_it),
            href: navLinkDeclIndex(decl_it),
          });
          prev_decl_it = decl_it;
          decl_it = declParent(decl_it);
        }

        // Next, walk backwards the file path segments.
        if (prev_decl_it != null) {
          const file_path = fullyQualifiedName(prev_decl_it);
          const parts = file_path.split(".");
          parts.pop(); // skip last
          for (;;) {
            const href = navLinkFqn(parts.join("."));
            const part = parts.pop();
            if (!part) break;
            list.push({
              name: part,
              href: href,
            });
          }
        }

        list.reverse();
      }
      resizeDomList(domListNav, list.length, '<li><a href="#"></a></li>');

      for (let i = 0; i < list.length; i += 1) {
          const liDom = domListNav.children[i];
          const aDom = liDom.children[0];
          aDom.textContent = list[i].name;
          aDom.setAttribute('href', list[i].href);
          if (i + 1 == list.length) {
              aDom.classList.add("active");
          } else {
              aDom.classList.remove("active");
          }
      }

      domSectNav.classList.remove("hidden");
    }

    function renderNotFound() {
        domStatus.textContent = "Declaration not found.";
        domStatus.classList.remove("hidden");
    }

    function navLinkFqn(full_name) {
      return '#' + full_name;
    }

    function navLinkDeclIndex(decl_index) {
      return navLinkFqn(fullyQualifiedName(decl_index));
    }

    function resizeDomList(listDom, desiredLen, templateHtml) {
        // add the missing dom entries
        var i, ev;
        for (i = listDom.childElementCount; i < desiredLen; i += 1) {
            listDom.insertAdjacentHTML('beforeend', templateHtml);
        }
        // remove extra dom entries
        while (desiredLen < listDom.childElementCount) {
            listDom.removeChild(listDom.lastChild);
        }
    }

    function renderErrorSetPage(decl_index) {
      renderNav(decl_index);
      renderDeclHeading(decl_index);

      const errorSetList = declErrorSet(decl_index).slice();
      renderErrorSet(decl_index, errorSetList);
    }

    function renderErrorSet(base_decl, errorSetList) {
      if (errorSetList == null) {
        domFnErrorsAnyError.classList.remove("hidden");
      } else {
        resizeDomList(domListFnErrors, errorSetList.length, '<div></div>');
        for (let i = 0; i < errorSetList.length; i += 1) {
            const divDom = domListFnErrors.children[i];
            const html = unwrapString(wasm_exports.error_html(base_decl, errorSetList[i]));
            divDom.innerHTML = html;
        }
        domTableFnErrors.classList.remove("hidden");
      }
      domSectFnErrors.classList.remove("hidden");
    }

    function renderParams(decl_index) {
      // Prevent params from being emptied next time wasm calls memory.grow.
      const params = declParams(decl_index).slice();
      if (params.length !== 0) {
          resizeDomList(domListParams, params.length, '<div></div>');
          for (let i = 0; i < params.length; i += 1) {
              const divDom = domListParams.children[i];
              divDom.innerHTML = unwrapString(wasm_exports.decl_param_html(decl_index, params[i]));
          }
          domSectParams.classList.remove("hidden");
      }
    }

    function renderTypeFunction(decl_index) {
      renderNav(decl_index);
      renderDeclHeading(decl_index);
      renderTopLevelDocs(decl_index);
      renderParams(decl_index);
      renderDocTests(decl_index);

      const members = unwrapSlice32(wasm_exports.type_fn_members(decl_index, false)).slice();
      const fields = unwrapSlice32(wasm_exports.type_fn_fields(decl_index)).slice();
      if (members.length !== 0 || fields.length !== 0) {
        renderNamespace(decl_index, members, fields);
      } else {
        domSourceText.innerHTML = declSourceHtml(decl_index);
        domSectSource.classList.remove("hidden");
      }
    }

    function renderDocTests(decl_index) {
      const doctest_html = declDoctestHtml(decl_index);
      if (doctest_html.length > 0) {
        domDocTestsCode.innerHTML = doctest_html;
        domSectDocTests.classList.remove("hidden");
      }
    }

    function renderFunction(decl_index) {
      renderNav(decl_index);
      renderDeclHeading(decl_index);
      renderTopLevelDocs(decl_index);
      renderParams(decl_index);
      renderDocTests(decl_index);

      domFnProtoCode.innerHTML = fnProtoHtml(decl_index, false);
      domFnProto.classList.remove("hidden");


      const errorSetNode = fnErrorSet(decl_index);
      if (errorSetNode != null) {
        const base_decl = wasm_exports.fn_error_set_decl(decl_index, errorSetNode);
        renderErrorSet(base_decl, errorSetNodeList(decl_index, errorSetNode));
      }

      domSourceText.innerHTML = declSourceHtml(decl_index);
      domSectSource.classList.remove("hidden");
    }

    function renderGlobal(decl_index) {
      renderNav(decl_index);
      renderDeclHeading(decl_index);

      const docs_html = declDocsHtmlShort(decl_index);
      if (docs_html.length > 0) {
        domTldDocs.innerHTML = docs_html;
        domTldDocs.classList.remove("hidden");
      }

      domSourceText.innerHTML = declSourceHtml(decl_index);
      domSectSource.classList.remove("hidden");
    }

    function renderNamespace(base_decl, members, fields) {
      const typesList = [];
      const namespacesList = [];
      const errSetsList = [];
      const fnsList = [];
      const varsList = [];
      const valsList = [];

      member_loop: for (let i = 0; i < members.length; i += 1) {
        let member = members[i];
        const original = member;
        while (true) {
          const member_category = wasm_exports.categorize_decl(member, 0);
          switch (member_category) {
            case CAT_namespace:
              namespacesList.push({original: original, member: member});
              continue member_loop;
            case CAT_container:
              typesList.push({original: original, member: member});
              continue member_loop;
            case CAT_global_variable:
              varsList.push(member);
              continue member_loop;
            case CAT_function:
              fnsList.push(member);
              continue member_loop;
            case CAT_type:
            case CAT_type_type:
            case CAT_type_function:
              typesList.push({original: original, member: member});
              continue member_loop;
            case CAT_error_set:
              errSetsList.push({original: original, member: member});
              continue member_loop;
            case CAT_global_const:
            case CAT_primitive:
              valsList.push({original: original, member: member});
              continue member_loop;
            case CAT_alias:
              member = wasm_exports.get_aliasee();
              continue;
            default:
              throw new Error("uknown category: " + member_category);
          }
        }
      }

      typesList.sort(byDeclIndexName2);
      namespacesList.sort(byDeclIndexName2);
      errSetsList.sort(byDeclIndexName2);
      fnsList.sort(byDeclIndexName);
      varsList.sort(byDeclIndexName);
      valsList.sort(byDeclIndexName2);

      if (typesList.length !== 0) {
          resizeDomList(domListTypes, typesList.length, '<li><a href="#"></a></li>');
          for (let i = 0; i < typesList.length; i += 1) {
              const liDom = domListTypes.children[i];
              const aDom = liDom.children[0];
              const original_decl = typesList[i].original;
              const decl = typesList[i].member;
              aDom.textContent = declIndexName(original_decl);
              aDom.setAttribute('href', navLinkDeclIndex(decl));
          }
          domSectTypes.classList.remove("hidden");
      }
      if (namespacesList.length !== 0) {
          resizeDomList(domListNamespaces, namespacesList.length, '<li><a href="#"></a></li>');
          for (let i = 0; i < namespacesList.length; i += 1) {
              const liDom = domListNamespaces.children[i];
              const aDom = liDom.children[0];
              const original_decl = namespacesList[i].original;
              const decl = namespacesList[i].member;
              aDom.textContent = declIndexName(original_decl);
              aDom.setAttribute('href', navLinkDeclIndex(decl));
          }
          domSectNamespaces.classList.remove("hidden");
      }

      if (errSetsList.length !== 0) {
          resizeDomList(domListErrSets, errSetsList.length, '<li><a href="#"></a></li>');
          for (let i = 0; i < errSetsList.length; i += 1) {
              const liDom = domListErrSets.children[i];
              const aDom = liDom.children[0];
              const original_decl = errSetsList[i].original;
              const decl = errSetsList[i].member;
              aDom.textContent = declIndexName(original_decl);
              aDom.setAttribute('href', navLinkDeclIndex(decl));
          }
          domSectErrSets.classList.remove("hidden");
      }

      if (fnsList.length !== 0) {
          resizeDomList(domListFns, fnsList.length,
              '<div><dt><code></code></dt><dd></dd></div>');
          for (let i = 0; i < fnsList.length; i += 1) {
              const decl = fnsList[i];
              const divDom = domListFns.children[i];

              const dtDom = divDom.children[0];
              const ddDocs = divDom.children[1];
              const protoCodeDom = dtDom.children[0];

              protoCodeDom.innerHTML = fnProtoHtml(decl, true);
              ddDocs.innerHTML = declDocsHtmlShort(decl);
          }
          domSectFns.classList.remove("hidden");
      }

      if (fields.length !== 0) {
          resizeDomList(domListFields, fields.length, '<div></div>');
          for (let i = 0; i < fields.length; i += 1) {
              const divDom = domListFields.children[i];
              divDom.innerHTML = unwrapString(wasm_exports.decl_field_html(base_decl, fields[i]));
          }
          domSectFields.classList.remove("hidden");
      }

      if (varsList.length !== 0) {
          resizeDomList(domListGlobalVars, varsList.length,
              '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
          for (let i = 0; i < varsList.length; i += 1) {
              const decl = varsList[i];
              const trDom = domListGlobalVars.children[i];

              const tdName = trDom.children[0];
              const tdNameA = tdName.children[0];
              const tdType = trDom.children[1];
              const tdDesc = trDom.children[2];

              tdNameA.setAttribute('href', navLinkDeclIndex(decl));
              tdNameA.textContent = declIndexName(decl);

              tdType.innerHTML = declTypeHtml(decl);
              tdDesc.innerHTML = declDocsHtmlShort(decl);
          }
          domSectGlobalVars.classList.remove("hidden");
      }

      if (valsList.length !== 0) {
          resizeDomList(domListValues, valsList.length,
              '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
          for (let i = 0; i < valsList.length; i += 1) {
              const trDom = domListValues.children[i];
              const tdName = trDom.children[0];
              const tdNameA = tdName.children[0];
              const tdType = trDom.children[1];
              const tdDesc = trDom.children[2];

              const original_decl = valsList[i].original;
              const decl = valsList[i].member;
              tdNameA.setAttribute('href', navLinkDeclIndex(decl));
              tdNameA.textContent = declIndexName(original_decl);

              tdType.innerHTML = declTypeHtml(decl);
              tdDesc.innerHTML = declDocsHtmlShort(decl);
          }
          domSectValues.classList.remove("hidden");
      }
    }

    function renderNamespacePage(decl_index) {
      renderNav(decl_index);
      renderDeclHeading(decl_index);
      const members = namespaceMembers(decl_index, false).slice();
      const fields = declFields(decl_index).slice();
      renderNamespace(decl_index, members, fields);
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

    function updateCurNav(location_hash) {
        curNav.tag = 0;
        curNav.decl = null;
        curNav.path = null;
        curNav.viewSourceHash = null;
        curNavSearch = "";

        if (location_hash.length > 1 && location_hash[0] === '#') {
            const query = location_hash.substring(1);
            const qpos = query.indexOf("?");
            let nonSearchPart;
            if (qpos === -1) {
                nonSearchPart = query;
            } else {
                nonSearchPart = query.substring(0, qpos);
                curNavSearch = decodeURIComponent(query.substring(qpos + 1));
            }

            if (nonSearchPart.length > 0) {
              const source_mode = nonSearchPart.startsWith("src/");
              if (source_mode) {
                curNav.tag = 2;
                curNav.path = nonSearchPart.substring(4);
              } else {
                curNav.tag = 1;
                curNav.decl = findDecl(nonSearchPart);
              }
            }
        }
    }

    function onHashChange(state) {
      history.replaceState({}, "");
      navigate(location.hash);
      if (state == null) window.scrollTo({top: 0});
    }

    function onPopState(ev) {
      onHashChange(ev.state);
    }

    function navigate(location_hash) {
      updateCurNav(location_hash);
      if (domSearch.value !== curNavSearch) {
          domSearch.value = curNavSearch;
      }
      render();
      if (imFeelingLucky) {
          imFeelingLucky = false;
          activateSelectedResult();
      }
    }

    function activateSelectedResult() {
        if (domSectSearchResults.classList.contains("hidden")) {
            return;
        }

        var liDom = domListSearchResults.children[curSearchIndex];
        if (liDom == null && domListSearchResults.children.length !== 0) {
            liDom = domListSearchResults.children[0];
        }
        if (liDom != null) {
            var aDom = liDom.children[0];
            location.href = aDom.getAttribute("href");
            curSearchIndex = -1;
        }
        domSearch.blur();
    }

    function onSearchKeyDown(ev) {
      switch (ev.code) {
        case "Enter":
          if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;

          clearAsyncSearch();
          imFeelingLucky = true;
          location.hash = computeSearchHash();

          ev.preventDefault();
          ev.stopPropagation();
          return;
        case "Escape":
          if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;

          domSearch.value = "";
          domSearch.blur();
          curSearchIndex = -1;
          ev.preventDefault();
          ev.stopPropagation();
          startSearch();
          return;
        case "ArrowUp":
          if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;

          moveSearchCursor(-1);
          ev.preventDefault();
          ev.stopPropagation();
          return;
        case "ArrowDown":
          if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;

          moveSearchCursor(1);
          ev.preventDefault();
          ev.stopPropagation();
          return;
        default:
          ev.stopPropagation(); // prevent keyboard shortcuts
          return;
      }
    }

    function onSearchChange(ev) {
      curSearchIndex = -1;
      startAsyncSearch();
    }

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

    function onWindowKeyDown(ev) {
        switch (ev.code) {
            case "Escape":
                if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;
                if (!domHelpModal.classList.contains("hidden")) {
                    domHelpModal.classList.add("hidden");
                    ev.preventDefault();
                    ev.stopPropagation();
                }
                break;
            case "KeyS":
                if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;
                domSearch.focus();
                domSearch.select();
                ev.preventDefault();
                ev.stopPropagation();
                startAsyncSearch();
                break;
            case "KeyU":
                if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;
                ev.preventDefault();
                ev.stopPropagation();
                navigateToSource();
                break;
            case "Slash":
                if (!ev.shiftKey || ev.ctrlKey || ev.altKey) return;
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

    function navigateToSource() {
      if (curNav.viewSourceHash != null) {
        location.hash = curNav.viewSourceHash;
      }
    }

    function clearAsyncSearch() {
        if (searchTimer != null) {
            clearTimeout(searchTimer);
            searchTimer = null;
        }
    }

    function startAsyncSearch() {
      clearAsyncSearch();
      searchTimer = setTimeout(startSearch, 10);
    }
    function computeSearchHash() {
      // How location.hash works:
      // 1. http://example.com/     => ""
      // 2. http://example.com/#    => ""
      // 3. http://example.com/#foo => "#foo"
      // wat
      const oldWatHash = location.hash;
      const oldHash = oldWatHash.startsWith("#") ? oldWatHash : "#" + oldWatHash;
      const parts = oldHash.split("?");
      const newPart2 = (domSearch.value === "") ? "" : ("?" + domSearch.value);
      return parts[0] + newPart2;
    }
    function startSearch() {
      clearAsyncSearch();
      navigate(computeSearchHash());
    }
    function renderSearch() {
        renderNav(curNav.decl);

        const ignoreCase = (curNavSearch.toLowerCase() === curNavSearch);
        const results = executeQuery(curNavSearch, ignoreCase);

        if (results.length !== 0) {
            resizeDomList(domListSearchResults, results.length, '<li><a href="#"></a></li>');

            for (let i = 0; i < results.length; i += 1) {
                const liDom = domListSearchResults.children[i];
                const aDom = liDom.children[0];
                const match = results[i];
                const full_name = fullyQualifiedName(match);
                aDom.textContent = full_name;
                aDom.setAttribute('href', navLinkFqn(full_name));
            }
            renderSearchCursor();

            domSectSearchResults.classList.remove("hidden");
        } else {
            domSectSearchNoResults.classList.remove("hidden");
        }
    }

    function renderSearchCursor() {
        for (let i = 0; i < domListSearchResults.children.length; i += 1) {
            var liDom = domListSearchResults.children[i];
            if (curSearchIndex === i) {
                liDom.classList.add("selected");
            } else {
                liDom.classList.remove("selected");
            }
        }
    }

    function updateModuleList() {
      moduleList.length = 0;
      for (let i = 0;; i += 1) {
        const name = unwrapString(wasm_exports.module_name(i));
        if (name.length == 0) break;
        moduleList.push(name);
      }
    }

    function byDeclIndexName(a, b) {
      const a_name = declIndexName(a);
      const b_name = declIndexName(b);
      return operatorCompare(a_name, b_name);
    }

    function byDeclIndexName2(a, b) {
      const a_name = declIndexName(a.original);
      const b_name = declIndexName(b.original);
      return operatorCompare(a_name, b_name);
    }

    function decodeString(ptr, len) {
      if (len === 0) return "";
      return text_decoder.decode(new Uint8Array(wasm_exports.memory.buffer, ptr, len));
    }

    function unwrapString(bigint) {
      const ptr = Number(bigint & 0xffffffffn);
      const len = Number(bigint >> 32n);
      return decodeString(ptr, len);
    }

    function declTypeHtml(decl_index) {
      return unwrapString(wasm_exports.decl_type_html(decl_index));
    }

    function declDocsHtmlShort(decl_index) {
      return unwrapString(wasm_exports.decl_docs_html(decl_index, true));
    }

    function fullyQualifiedName(decl_index) {
      return unwrapString(wasm_exports.decl_fqn(decl_index));
    }

    function declIndexName(decl_index) {
      return unwrapString(wasm_exports.decl_name(decl_index));
    }

    function declSourceHtml(decl_index) {
      return unwrapString(wasm_exports.decl_source_html(decl_index));
    }

    function declDoctestHtml(decl_index) {
      return unwrapString(wasm_exports.decl_doctest_html(decl_index));
    }

    function fnProtoHtml(decl_index, linkify_fn_name) {
      return unwrapString(wasm_exports.decl_fn_proto_html(decl_index, linkify_fn_name));
    }

    function setQueryString(s) {
      const jsArray = text_encoder.encode(s);
      const len = jsArray.length;
      const ptr = wasm_exports.query_begin(len);
      const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, len);
      wasmArray.set(jsArray);
    }

    function executeQuery(query_string, ignore_case) {
      setQueryString(query_string);
      const ptr = wasm_exports.query_exec(ignore_case);
      const head = new Uint32Array(wasm_exports.memory.buffer, ptr, 1);
      const len = head[0];
      return new Uint32Array(wasm_exports.memory.buffer, ptr + 4, len);
    }

    function namespaceMembers(decl_index, include_private) {
      return unwrapSlice32(wasm_exports.namespace_members(decl_index, include_private));
    }

    function declFields(decl_index) {
      return unwrapSlice32(wasm_exports.decl_fields(decl_index));
    }

    function declParams(decl_index) {
      return unwrapSlice32(wasm_exports.decl_params(decl_index));
    }

    function declErrorSet(decl_index) {
      return unwrapSlice64(wasm_exports.decl_error_set(decl_index));
    }

    function errorSetNodeList(base_decl, err_set_node) {
      return unwrapSlice64(wasm_exports.error_set_node_list(base_decl, err_set_node));
    }

    function unwrapSlice32(bigint) {
      const ptr = Number(bigint & 0xffffffffn);
      const len = Number(bigint >> 32n);
      if (len === 0) return [];
      return new Uint32Array(wasm_exports.memory.buffer, ptr, len);
    }

    function unwrapSlice64(bigint) {
      const ptr = Number(bigint & 0xffffffffn);
      const len = Number(bigint >> 32n);
      if (len === 0) return [];
      return new BigUint64Array(wasm_exports.memory.buffer, ptr, len);
    }

    function findDecl(fqn) {
      setInputString(fqn);
      const result = wasm_exports.find_decl();
      if (result === -1) return null;
      return result;
    }

    function findFileRoot(path) {
      setInputString(path);
      const result = wasm_exports.find_file_root();
      if (result === -1) return null;
      return result;
    }

    function declParent(decl_index) {
      const result = wasm_exports.decl_parent(decl_index);
      if (result === -1) return null;
      return result;
    }

    function fnErrorSet(decl_index) {
      const result = wasm_exports.fn_error_set(decl_index);
      if (result === 0) return null;
      return result;
    }

    function setInputString(s) {
      const jsArray = text_encoder.encode(s);
      const len = jsArray.length;
      const ptr = wasm_exports.set_input_string(len);
      const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, len);
      wasmArray.set(jsArray);
    }
})();

