(function() {
    var options = {
        env: {
            wasmEval: function(code_ptr, code_len) {
                console.log("code_ptr", code_ptr, "code_len", code_len);
            },
            stderr: function(msg_ptr, msg_len) {
                console.log(makeString(msg_ptr, msg_len));
            },
        },
    };

    WebAssembly.instantiateStreaming(fetch("playground.wasm"), options).then(function(result) {
        callback(null, result);
    }, function(err) {
        callback(err, null);
    });
    function callback(err, result) {
        if (err) {
            document.getElementById('status').textContent = "error: " + err;
            return;
        }
        // for debugging
        window._wasm = result.instance;
        console.log(result.instance.exports.zigEval());
    }

    function makeString(ptr, len) {
        var bytes = new Uint8Array(window._wasm.exports.memory.buffer, ptr, len);
        return new TextDecoder().decode(bytes);
    }
})();
