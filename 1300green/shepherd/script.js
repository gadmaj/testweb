let c = 0;
const counter = document.getElementById("clickCount");

document.getElementById("shepherd").addEventListener("click", function() {
    c++;
    counter.textContent = c;

    if (c >= 12) {
    document.body.style.background = "black";
    document.body.style.color = "white";
    document.getElementById("shepherd").style.filter = "invert(100%)";
    } 
    if (c >= 13) {
        window.location.href = "../בָּרָא/";
    }

});