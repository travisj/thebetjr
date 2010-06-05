$(function () {
    var johnson = [],
		smith = [];
    $.plot($("#chart"), [ johnson, smith ], { xaxis: { mode: "time" } });
});
