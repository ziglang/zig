(function() {
  const domStatus = document.getElementById("status");
  const domSectSource = document.getElementById("sectSource");
  const domSectStats = document.getElementById("sectStats");
  const domSourceText = document.getElementById("sourceText");
  const domStatTotalRuns = document.getElementById("statTotalRuns");
  const domStatUniqueRuns = document.getElementById("statUniqueRuns");
  const domStatLowestStack = document.getElementById("statLowestStack");

  let wasm_promise = fetch("main.wasm");
  let sources_promise = fetch("sources.tar").then(function(response) {
    if (!response.ok) throw new Error("unable to download sources");
    return response.arrayBuffer();
  });
  var wasm_exports = null;

  const text_decoder = new TextDecoder();
  const text_encoder = new TextEncoder();

  domStatus.textContent = "Loading WebAssembly...";
  WebAssembly.instantiateStreaming(wasm_promise, {
    js: {
      log: function(ptr, len) {
        const msg = decodeString(ptr, len);
        console.log(msg);
      },
      panic: function (ptr, len) {
          const msg = decodeString(ptr, len);
          throw new Error("panic: " + msg);
      },
      emitSourceIndexChange: onSourceIndexChange,
      emitCoverageUpdate: onCoverageUpdate,
    },
  }).then(function(obj) {
    wasm_exports = obj.instance.exports;
    window.wasm = obj; // for debugging
    domStatus.textContent = "Loading sources tarball...";

    sources_promise.then(function(buffer) {
      domStatus.textContent = "Parsing sources...";
      const js_array = new Uint8Array(buffer);
      const ptr = wasm_exports.alloc(js_array.length);
      const wasm_array = new Uint8Array(wasm_exports.memory.buffer, ptr, js_array.length);
      wasm_array.set(js_array);
      wasm_exports.unpack(ptr, js_array.length);

      domStatus.textContent = "Waiting for server to send source location metadata...";
      connectWebSocket();
    });
  });

  function connectWebSocket() {
    const host = window.document.location.host;
    const pathname = window.document.location.pathname;
    const isHttps = window.document.location.protocol === 'https:';
    const match = host.match(/^(.+):(\d+)$/);
    const defaultPort = isHttps ? 443 : 80;
    const port = match ? parseInt(match[2], 10) : defaultPort;
    const hostName = match ? match[1] : host;
    const wsProto = isHttps ? "wss:" : "ws:";
    const wsUrl = wsProto + '//' + hostName + ':' + port + pathname;
    ws = new WebSocket(wsUrl);
    ws.binaryType = "arraybuffer";
    ws.addEventListener('message', onWebSocketMessage, false);
    ws.addEventListener('error', timeoutThenCreateNew, false);
    ws.addEventListener('close', timeoutThenCreateNew, false);
    ws.addEventListener('open', onWebSocketOpen, false);
  }

  function onWebSocketOpen() {
    console.log("web socket opened");
  }

  function onWebSocketMessage(ev) {
    wasmOnMessage(ev.data);
  }

  function timeoutThenCreateNew() {
    ws.removeEventListener('message', onWebSocketMessage, false);
    ws.removeEventListener('error', timeoutThenCreateNew, false);
    ws.removeEventListener('close', timeoutThenCreateNew, false);
    ws.removeEventListener('open', onWebSocketOpen, false);
    ws = null;
    setTimeout(connectWebSocket, 1000);
  }

  function wasmOnMessage(data) {
    const jsArray = new Uint8Array(data);
    const ptr = wasm_exports.message_begin(jsArray.length);
    const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, jsArray.length);
    wasmArray.set(jsArray);
    wasm_exports.message_end();
  }

  function onSourceIndexChange() {
    console.log("source location index metadata updated");
    render();
  }

  function onCoverageUpdate() {
    renderStats();
  }

  function render() {
    domStatus.classList.add("hidden");
    domSectSource.classList.add("hidden");

    // TODO this is temporary debugging data
    renderSource("/home/andy/dev/zig/lib/std/zig/tokenizer.zig");
  }

  function renderStats() {
    const totalRuns = wasm_exports.totalRuns();
    const uniqueRuns = wasm_exports.uniqueRuns();
    domStatTotalRuns.innerText = totalRuns;
    domStatUniqueRuns.innerText = uniqueRuns + " (" + percent(uniqueRuns, totalRuns) + "%)";
    domStatLowestStack.innerText = unwrapString(wasm_exports.lowestStack());

    domSectStats.classList.remove("hidden");
  }

  function percent(a, b) {
    return ((Number(a) / Number(b)) * 100).toFixed(1);
  }

  function renderSource(path) {
    const decl_index = findFileRoot(path);
    if (decl_index == null) throw new Error("file not found: " + path);

    const h2 = domSectSource.children[0];
    h2.innerText = path;
    domSourceText.innerHTML = declSourceHtml(decl_index);

    domSectSource.classList.remove("hidden");
  }

  function findFileRoot(path) {
    setInputString(path);
    const result = wasm_exports.find_file_root();
    if (result === -1) return null;
    return result;
  }

  function decodeString(ptr, len) {
    if (len === 0) return "";
    return text_decoder.decode(new Uint8Array(wasm_exports.memory.buffer, ptr, len));
  }

  function setInputString(s) {
    const jsArray = text_encoder.encode(s);
    const len = jsArray.length;
    const ptr = wasm_exports.set_input_string(len);
    const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, len);
    wasmArray.set(jsArray);
  }

  function declSourceHtml(decl_index) {
    return unwrapString(wasm_exports.decl_source_html(decl_index));
  }

  function unwrapString(bigint) {
    const ptr = Number(bigint & 0xffffffffn);
    const len = Number(bigint >> 32n);
    return decodeString(ptr, len);
  }
})();
