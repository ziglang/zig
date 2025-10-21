const domConnectionStatus = document.getElementById("connectionStatus");
const domFirefoxWebSocketBullshitExplainer = document.getElementById("firefoxWebSocketBullshitExplainer");

const domMain = document.getElementsByTagName("main")[0];
const domSummary = {
  stepCount: document.getElementById("summaryStepCount"),
  status: document.getElementById("summaryStatus"),
};
const domButtonRebuild = document.getElementById("buttonRebuild");
const domStepList = document.getElementById("stepList");
let domSteps = [];

let wasm_promise = fetch("main.wasm");
let wasm_exports = null;

const text_decoder = new TextDecoder();
const text_encoder = new TextEncoder();

domButtonRebuild.addEventListener("click", () => wasm_exports.rebuild());

setConnectionStatus("Loading WebAssembly...", false);
WebAssembly.instantiateStreaming(wasm_promise, {
  core: {
    log: function(ptr, len) {
      const msg = decodeString(ptr, len);
      console.log(msg);
    },
    panic: function (ptr, len) {
      const msg = decodeString(ptr, len);
      throw new Error("panic: " + msg);
    },
    timestamp: function () {
      return BigInt(new Date());
    },
    hello: hello,
    updateBuildStatus: updateBuildStatus,
    updateStepStatus: updateStepStatus,
    sendWsMessage: (ptr, len) => ws.send(new Uint8Array(wasm_exports.memory.buffer, ptr, len)),
  },
  fuzz: {
    requestSources: fuzzRequestSources,
    ready: fuzzReady,
    updateStats: fuzzUpdateStats,
    updateEntryPoints: fuzzUpdateEntryPoints,
    updateSource: fuzzUpdateSource,
    updateCoverage: fuzzUpdateCoverage,
  },
  time_report: {
    updateGeneric: timeReportUpdateGeneric,
    updateCompile: timeReportUpdateCompile,
    updateRunTest: timeReportUpdateRunTest,
  },
}).then(function(obj) {
  setConnectionStatus("Connecting to WebSocket...", true);
  connectWebSocket();

  wasm_exports = obj.instance.exports;
  window.wasm = obj; // for debugging
});

function connectWebSocket() {
  const host = document.location.host;
  const pathname = document.location.pathname;
  const isHttps = document.location.protocol === 'https:';
  const match = host.match(/^(.+):(\d+)$/);
  const defaultPort = isHttps ? 443 : 80;
  const port = match ? parseInt(match[2], 10) : defaultPort;
  const hostName = match ? match[1] : host;
  const wsProto = isHttps ? "wss:" : "ws:";
  const wsUrl = wsProto + '//' + hostName + ':' + port + pathname;
  ws = new WebSocket(wsUrl);
  ws.binaryType = "arraybuffer";
  ws.addEventListener('message', onWebSocketMessage, false);
  ws.addEventListener('error', onWebSocketClose, false);
  ws.addEventListener('close', onWebSocketClose, false);
  ws.addEventListener('open', onWebSocketOpen, false);
}
function onWebSocketOpen() {
  setConnectionStatus("Waiting for data...", false);
}
function onWebSocketMessage(ev) {
  const jsArray = new Uint8Array(ev.data);
  const ptr = wasm_exports.message_begin(jsArray.length);
  const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, jsArray.length);
  wasmArray.set(jsArray);
  wasm_exports.message_end();
}
function onWebSocketClose() {
  setConnectionStatus("WebSocket connection closed. Re-connecting...", true);
  ws.removeEventListener('message', onWebSocketMessage, false);
  ws.removeEventListener('error', onWebSocketClose, false);
  ws.removeEventListener('close', onWebSocketClose, false);
  ws.removeEventListener('open', onWebSocketOpen, false);
  ws = null;
  setTimeout(connectWebSocket, 1000);
}

function setConnectionStatus(msg, is_websocket_connect) {
  domConnectionStatus.textContent = msg;
  if (msg.length > 0) {
    domConnectionStatus.classList.remove("hidden");
    domMain.classList.add("hidden");
  } else {
    domConnectionStatus.classList.add("hidden");
    domMain.classList.remove("hidden");
  }
  if (is_websocket_connect) {
    domFirefoxWebSocketBullshitExplainer.classList.remove("hidden");
  } else {
    domFirefoxWebSocketBullshitExplainer.classList.add("hidden");
  }
}

function hello(
  steps_len,
  build_status,
  time_report,
) {
  domSummary.stepCount.textContent = steps_len;
  updateBuildStatus(build_status);
  setConnectionStatus("", false);

  {
    let entries = [];
    for (let i = 0; i < steps_len; i += 1) {
      const step_name = unwrapString(wasm_exports.stepName(i));
      const code = document.createElement("code");
      code.textContent = step_name;
      const li = document.createElement("li");
      li.appendChild(code);
      entries.push(li);
    }
    domStepList.replaceChildren(...entries);
    for (let i = 0; i < steps_len; i += 1) {
      updateStepStatus(i);
    }
  }

  if (time_report) timeReportReset(steps_len);
  fuzzReset();
}

function updateBuildStatus(s) {
  let text;
  let active = false;
  let reset_time_reports = false;
  if (s == 0) {
    text = "Idle";
  } else if (s == 1) {
    text = "Watching for changes...";
  } else if (s == 2) {
    text = "Running...";
    active = true;
    reset_time_reports = true;
  } else if (s == 3) {
    text = "Starting fuzzer...";
    active = true;
  } else {
    console.log(`bad build status: ${s}`);
  }
  domSummary.status.textContent = text;
  if (active) {
    domSummary.status.classList.add("status-running");
    domSummary.status.classList.remove("status-idle");
    domButtonRebuild.disabled = true;
  } else {
    domSummary.status.classList.remove("status-running");
    domSummary.status.classList.add("status-idle");
    domButtonRebuild.disabled = false;
  }
  if (reset_time_reports) {
    // Grey out and collapse all the time reports
    for (const time_report_host of domTimeReportList.children) {
      const details = time_report_host.shadowRoot.querySelector(":host > details");
      details.classList.add("pending");
      details.open = false;
    }
  }
}
function updateStepStatus(step_idx) {
  const li = domStepList.children[step_idx];
  const step_status = wasm_exports.stepStatus(step_idx);
  li.classList.remove("step-wip", "step-success", "step-failure");
  if (step_status == 0) {
    // pending
  } else if (step_status == 1) {
    li.classList.add("step-wip");
  } else if (step_status == 2) {
    li.classList.add("step-success");
  } else if (step_status == 3) {
    li.classList.add("step-failure");
  } else {
    console.log(`bad step status: ${step_status}`);
  }
}

function decodeString(ptr, len) {
  if (len === 0) return "";
  return text_decoder.decode(new Uint8Array(wasm_exports.memory.buffer, ptr, len));
}
function getU32Array(ptr, len) {
  if (len === 0) return new Uint32Array();
  return new Uint32Array(wasm_exports.memory.buffer, ptr, len);
}
function unwrapString(bigint) {
  const ptr = Number(bigint & 0xffffffffn);
  const len = Number(bigint >> 32n);
  return decodeString(ptr, len);
}

const time_report_entry_template = document.getElementById("timeReportEntryTemplate").content;
const domTimeReport = document.getElementById("timeReport");
const domTimeReportList = document.getElementById("timeReportList");
function timeReportReset(steps_len) {
  let entries = [];
  for (let i = 0; i < steps_len; i += 1) {
    const step_name = unwrapString(wasm_exports.stepName(i));
    const host = document.createElement("div");
    const shadow = host.attachShadow({ mode: "open" });
    shadow.appendChild(time_report_entry_template.cloneNode(true));
    shadow.querySelector(":host > details").classList.add("pending");
    const slotted_name = document.createElement("code");
    slotted_name.setAttribute("slot", "step-name");
    slotted_name.textContent = step_name;
    host.appendChild(slotted_name);
    entries.push(host);
  }
  domTimeReportList.replaceChildren(...entries);
  domTimeReport.classList.remove("hidden");
}
function timeReportUpdateCompile(
  step_idx,
  inner_html_ptr,
  inner_html_len,
  file_table_html_ptr,
  file_table_html_len,
  decl_table_html_ptr,
  decl_table_html_len,
  use_llvm,
) {
  const inner_html = decodeString(inner_html_ptr, inner_html_len);
  const file_table_html = decodeString(file_table_html_ptr, file_table_html_len);
  const decl_table_html = decodeString(decl_table_html_ptr, decl_table_html_len);

  const host = domTimeReportList.children.item(step_idx);
  const shadow = host.shadowRoot;

  shadow.querySelector(":host > details").classList.remove("pending", "no-llvm");

  shadow.getElementById("genericReport").classList.add("hidden");
  shadow.getElementById("compileReport").classList.remove("hidden");
  shadow.getElementById("runTestReport").classList.add("hidden");

  if (!use_llvm) shadow.querySelector(":host > details").classList.add("no-llvm");
  host.innerHTML = inner_html;
  shadow.getElementById("fileTableBody").innerHTML = file_table_html;
  shadow.getElementById("declTableBody").innerHTML = decl_table_html;
}
function timeReportUpdateGeneric(
  step_idx,
  inner_html_ptr,
  inner_html_len,
) {
  const inner_html = decodeString(inner_html_ptr, inner_html_len);
  const host = domTimeReportList.children.item(step_idx);
  const shadow = host.shadowRoot;
  shadow.querySelector(":host > details").classList.remove("pending", "no-llvm");
  shadow.getElementById("genericReport").classList.remove("hidden");
  shadow.getElementById("compileReport").classList.add("hidden");
  shadow.getElementById("runTestReport").classList.add("hidden");
  host.innerHTML = inner_html;
}
function timeReportUpdateRunTest(
  step_idx,
  table_html_ptr,
  table_html_len,
) {
  const table_html = decodeString(table_html_ptr, table_html_len);
  const host = domTimeReportList.children.item(step_idx);
  const shadow = host.shadowRoot;

  shadow.querySelector(":host > details").classList.remove("pending", "no-llvm");

  shadow.getElementById("genericReport").classList.add("hidden");
  shadow.getElementById("compileReport").classList.add("hidden");
  shadow.getElementById("runTestReport").classList.remove("hidden");

  shadow.getElementById("runTestTableBody").innerHTML = table_html;
}

const fuzz_entry_template = document.getElementById("fuzzEntryTemplate").content;
const domFuzz = document.getElementById("fuzz");
const domFuzzStatus = document.getElementById("fuzzStatus");
const domFuzzEntries = document.getElementById("fuzzEntries");
let domFuzzInstance = null;
function fuzzRequestSources() {
  domFuzzStatus.classList.remove("hidden");
  domFuzzStatus.textContent = "Loading sources tarball...";
  fetch("sources.tar").then(function(response) {
    if (!response.ok) throw new Error("unable to download sources");
    domFuzzStatus.textContent = "Parsing fuzz test sources...";
    return response.arrayBuffer();
  }).then(function(buffer) {
    if (buffer.length === 0) throw new Error("sources.tar was empty");
    const js_array = new Uint8Array(buffer);
    const ptr = wasm_exports.alloc(js_array.length);
    const wasm_array = new Uint8Array(wasm_exports.memory.buffer, ptr, js_array.length);
    wasm_array.set(js_array);
    wasm_exports.fuzzUnpackSources(ptr, js_array.length);
    domFuzzStatus.textContent = "";
    domFuzzStatus.classList.add("hidden");
  });
}
function fuzzReady() {
  domFuzz.classList.remove("hidden");

  // TODO: multiple fuzzer instances
  if (domFuzzInstance !== null) return;

  const host = document.createElement("div");
  const shadow = host.attachShadow({ mode: "open" });
  shadow.appendChild(fuzz_entry_template.cloneNode(true));

  domFuzzInstance = host;
  domFuzzEntries.appendChild(host);
}
function fuzzReset() {
  domFuzz.classList.add("hidden");
  domFuzzEntries.replaceChildren();
  domFuzzInstance = null;
}
function fuzzUpdateStats(stats_html_ptr, stats_html_len) {
  if (domFuzzInstance === null) throw new Error("fuzzUpdateStats called when fuzzer inactive");
  const stats_html = decodeString(stats_html_ptr, stats_html_len);
  const host = domFuzzInstance;
  host.innerHTML = stats_html;
}
function fuzzUpdateEntryPoints(entry_points_html_ptr, entry_points_html_len) {
  if (domFuzzInstance === null) throw new Error("fuzzUpdateEntryPoints called when fuzzer inactive");
  const entry_points_html = decodeString(entry_points_html_ptr, entry_points_html_len);
  const domEntryPointList = domFuzzInstance.shadowRoot.getElementById("entryPointList");
  domEntryPointList.innerHTML = entry_points_html;
}
function fuzzUpdateSource(source_html_ptr, source_html_len) {
  if (domFuzzInstance === null) throw new Error("fuzzUpdateSource called when fuzzer inactive");
  const source_html = decodeString(source_html_ptr, source_html_len);
  const domSourceText = domFuzzInstance.shadowRoot.getElementById("sourceText");
  domSourceText.innerHTML = source_html;
  domFuzzInstance.shadowRoot.getElementById("source").classList.remove("hidden");
}
function fuzzUpdateCoverage(covered_ptr, covered_len) {
  if (domFuzzInstance === null) throw new Error("fuzzUpdateCoverage called when fuzzer inactive");
  const shadow = domFuzzInstance.shadowRoot;
  const domSourceText = shadow.getElementById("sourceText");
  const covered = getU32Array(covered_ptr, covered_len);
  for (let i = 0; i < domSourceText.children.length; i += 1) {
    const childDom = domSourceText.children[i];
    if (childDom.id != null && childDom.id[0] == "l") {
      childDom.classList.add("l");
      childDom.classList.remove("c");
    }
  }
  for (const sli of covered) {
    shadow.getElementById(`l${sli}`).classList.add("c");
  }
}
