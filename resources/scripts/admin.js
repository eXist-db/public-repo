$(function () {
    'use strict';
    $('#fileupload').fileupload({
        url: "publish",
        dataType: 'json',
        done: function (e, data) {
            $.each(data.result.files, function (index, file) {
                var tr = document.createElement("tr");
                var td = document.createElement("td");
                td.appendChild(document.createTextNode(file.name));
                tr.appendChild(td);
                $("#files").append(tr);
            });
        },
        progressall: function (e, data) {
            var progress = parseInt(data.loaded / data.total * 100, 10);
            $('#progress .progress-bar').css(
                'width',
                progress + '%'
            );
        }
    }).prop('disabled', !$.support.fileInput)
        .parent().addClass($.support.fileInput ? undefined : 'disabled');
});
