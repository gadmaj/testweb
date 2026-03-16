let c = 0;
const counter = document.getElementById("clickCount");

document.getElementById("shepherd").addEventListener("click", function() {
    c++;
    counter.textContent = c;

    if (c === 11) {
    document.body.style.background = "black";
    } 
     
    if (c === 13) {
        window.location.href = "../בָּרָא/";
    }

});