const files = document.getElementById('files');
const upload = document.getElementById('upload');
const uploaded = document.getElementById('uploaded');

async function handleUpload () {
    for (let fileIndex = 0; fileIndex < files.files.length; fileIndex++) {
        const file = files.files[fileIndex];
        const data = new FormData()
        data.append('files[]', file)
        const response = await fetch('publish', {
            'method' : 'POST',
            'body' : data
        })
        const result = await response.json().catch(() => ({}))
        // The server derives a versioned filename ({abbrev}-{version}.xar) from the
        // package's expath-pkg.xml descriptor; show that so the user knows what was
        // actually stored. Falls back to the local upload name if the response is
        // missing or malformed.
        const storedName = result?.files?.[0]?.name ?? file.name

        const tr = document.createElement('tr')
        const td = document.createElement('td')
        const text = document.createTextNode(storedName)
        td.appendChild(text)
        tr.appendChild(td)
        uploaded.appendChild(tr)
    }
}

upload.addEventListener('click', handleUpload)
