const params = new URLSearchParams(window.location.search);
        const file = params.get('file');
        if (file) {
            document.getElementById('filename').textContent = file;
            fetch(file)
                .then(r => r.text())
                .then(data => document.getElementById('code').textContent = data)
                .catch(err => document.getElementById('code').textContent = 'Error: ' + err);
        }