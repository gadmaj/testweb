document.addEventListener("DOMContentLoaded", function () {
    var spinText = document.getElementById("spinText");
    var isSpinning = true;

    function toggleSpin() {
        if (isSpinning) {
            spinText.style.animationPlayState = "paused";
            isSpinning = false;
        } else {
            spinText.style.animationPlayState = "running";
            isSpinning = true;
        }
    }

    spinText.addEventListener("click", toggleSpin);
});