const form = document.getElementById('recon-form');
const consoleOutput = document.getElementById('console-output');

// Matrix background animation
const canvas = document.getElementById("backgroundCanvas");
const ctx = canvas.getContext("2d");

canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

const binary = "01";
const fontSize = 16;
const columns = Math.floor(canvas.width / fontSize);
const drops = Array(columns).fill(1);

function drawMatrix() {
    ctx.fillStyle = "rgba(0, 0, 0, 0.05)";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.fillStyle = "#0f0";
    ctx.font = `${fontSize}px monospace`;

    for (let i = 0; i < drops.length; i++) {
        const text = binary[Math.floor(Math.random() * binary.length)];
        ctx.fillText(text, i * fontSize, drops[i] * fontSize);

        if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
            drops[i] = 0;
        }

        drops[i]++;
    }
}

setInterval(drawMatrix, 50);

// Handle form submission
form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const domain = document.getElementById('domain').value;
    const task = document.getElementById('task').value;

    consoleOutput.innerText = `Running task: ${task} for domain: ${domain}...\n`;

    try {
        const response = await fetch('/run', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ domain, task })
        });

        if (!response.ok) {
            const errorData = await response.json();
            consoleOutput.innerText += `\nError: ${errorData.error}\n`;
            return;
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder("utf-8");
        let done = false;

        while (!done) {
            const { value, done: readerDone } = await reader.read();
            done = readerDone;
            consoleOutput.innerText += decoder.decode(value);
            consoleOutput.scrollTop = consoleOutput.scrollHeight; // Auto-scroll to latest output
        }
    } catch (error) {
        consoleOutput.innerText += `\nAn unexpected error occurred: ${error}\n`;
    }
});
