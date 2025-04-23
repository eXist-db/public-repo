const files = document.getElementById('files');
const upload = document.getElementById('upload');
const uploaded = document.getElementById('uploaded');

async function handleUpload () {
    for (let fileIndex = 0; fileIndex < files.files.length; fileIndex++) {
        const file = files.files[fileIndex];
        const data = new FormData()
        data.append('files[]', file)
        await fetch('publish', {
            'method' : 'POST',
            'body' : data
        })

        //append file name to table
        const tr = document.createElement('tr')
        const td = document.createElement('td')
        const text = document.createTextNode(file.name)
        td.appendChild(text)
        tr.appendChild(td)
        uploaded.appendChild(tr)
    }
}

upload.addEventListener('click', handleUpload)
