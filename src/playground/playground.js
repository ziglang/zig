(function() {
    var options = {
        env: {
            wasmEval: function(code_ptr, code_len) {
                console.log("code_ptr", code_ptr, "code_len", code_len);
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
})();
