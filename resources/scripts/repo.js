$(document).ready(function() {
    $(".package").each(function () {
        var pkg = $(this);
        $(".icon", pkg).click(function (ev) {
            $(".details").hide();
            $(".details", pkg).show();
            $(".close-details", pkg).click(function (ev) {
                $(".details", pkg).hide();
            });
        });
    });
    var tallest = 0;
    $(".packages li.package").each(function () {
        if ($(this).height() > tallest) {
            tallest = $(this).height();
        }
    });
    $(".packages li.package").each(function() {
        $(this).height(tallest);
    });
});