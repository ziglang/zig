(function() {
    var env = {
        imports: { }
    };

    WebAssembly.instantiateStreaming(fetch("playground.wasm"), {env}).then(function(result) {
        callback(null, result);
    }, function(err) {
        callback(err, null);
    });
    function callback(err, result) {
        if (err) {
            document.getElementById('status').innerText = "error: " + err;
            return;
        }
        // for debugging
        window._wasm = result.instance;
        console.log(result.instance.exports.eval());
    }
})();
