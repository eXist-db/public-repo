$(document).ready(function() {
    $(".package").each(function () {
        var pkg = $(this);
        $(".icon", pkg).click(function (ev) {
            $(".details", pkg).show();
            $(".close-details", pkg).click(function (ev) {
                $(".details", pkg).hide();
            });
        });
    });
});