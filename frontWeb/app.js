"use strict";

// Replace with your actual API Gateway URL after deployment (placeholder kept intentionally)
const API_main = "https://YOUR_API_GATEWAY_URL.execute-api.us-east-1.amazonaws.com"

// DOM elements
const form = document.getElementById("shortenForm");
const longURLInput = document.getElementById("longURL");
const submitBtn = document.getElementById("submitBtn");
const btnText = submitBtn.querySelector(".btn-text");
const status = document.getElementById("status");
const result = document.getElementById("result");
const shortLink = document.getElementById("shortLink");
const destinationUrl = document.getElementById("destinationUrl");
const copyBtn = document.getElementById("copyBtn");

// API endpoints
const shortenEndPoint = `${API_main}/shorten`;
const redirectBase = `${API_main}/r/`;

// Utility functions
function setStatus(message, type = "info") {
    status.textContent = message || "";
    status.className = `status ${type}`;
    if (!message) {
        status.className = "status";
    }
}

function showLoading() {
    submitBtn.disabled = true;
    btnText.innerHTML = '<div class="loading"></div> Shortening...';
}

function hideLoading() {
    submitBtn.disabled = false;
    btnText.innerHTML = '<i class="fas fa-compress-alt"></i> Shorten URL';
}

function showResult(shortCode, longURL) {
    const shortURL = `${redirectBase}${encodeURIComponent(shortCode)}`;
    
    // Show only the code for display, but keep full URL for the href
    shortLink.href = shortURL;
    shortLink.textContent = shortCode;
    destinationUrl.textContent = longURL;
    
    result.classList.add("show");
    setStatus("URL shortened successfully!", "success");
    
    // Scroll to result
    result.scrollIntoView({ behavior: "smooth", block: "nearest" });
}

function hideResult() {
    result.classList.remove("show");
}

// URL validation
function isValidURL(value) {
    try {
        const url = new URL(value);
        return url.protocol === "http:" || url.protocol === "https:";
    } catch {
        return false;
    }
}

// Copy to clipboard functionality
async function copyToClipboard(text) {
    try {
        await navigator.clipboard.writeText(text);
        copyBtn.innerHTML = '<i class="fas fa-check"></i>';
        copyBtn.classList.add("copied");
        
        setTimeout(() => {
            copyBtn.innerHTML = '<i class="fas fa-copy"></i>';
            copyBtn.classList.remove("copied");
        }, 2000);
        
        setStatus("Link copied to clipboard!", "success");
    } catch (err) {
        // Fallback for older browsers
        const textArea = document.createElement("textarea");
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand("copy");
        document.body.removeChild(textArea);
        
        copyBtn.innerHTML = '<i class="fas fa-check"></i>';
        copyBtn.classList.add("copied");
        
        setTimeout(() => {
            copyBtn.innerHTML = '<i class="fas fa-copy"></i>';
            copyBtn.classList.remove("copied");
        }, 2000);
        
        setStatus("Link copied to clipboard!", "success");
    }
}

// Event listeners
form.addEventListener("submit", async (event) => {
    event.preventDefault();
    
    const longURL = longURLInput.value.trim();
    
    // Clear previous results
    hideResult();
    setStatus("");
    
    // Validate URL
    if (!longURL) {
        setStatus("Please enter a URL", "error");
        longURLInput.focus();
        return;
    }
    
    if (!isValidURL(longURL)) {
        setStatus("Please enter a valid URL (must start with http:// or https://)", "error");
        longURLInput.focus();
        return;
    }
    
    // Show loading state
    showLoading();
    setStatus("Shortening your URL...", "info");
    
    try {
        const response = await fetch(shortenEndPoint, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ long_url: longURL })
        });
        
        const data = await response.json();
        
        if (!response.ok) {
            const errorMessage = data?.error || `HTTP ${response.status}`;
            setStatus(`Error: ${errorMessage}`, "error");
            return;
        }
        
        if (!data?.short_code) {
            setStatus("Invalid response from server", "error");
            return;
        }
        
        // Show success result
        showResult(data.short_code, longURL);
        
    } catch (error) {
        console.error("Error:", error);
        setStatus(`Network error: ${error.message}`, "error");
    } finally {
        hideLoading();
    }
});

// Copy button event listener
copyBtn.addEventListener("click", () => {
    // Get the full URL from the href attribute
    const urlToCopy = shortLink.href;
    copyToClipboard(urlToCopy);
});

// Input validation feedback
longURLInput.addEventListener("input", () => {
    const value = longURLInput.value.trim();
    if (value && !isValidURL(value)) {
        longURLInput.style.borderColor = "#e53e3e";
    } else {
        longURLInput.style.borderColor = "#e2e8f0";
    }
});

// Auto-focus on page load
window.addEventListener("load", () => {
    longURLInput.focus();
});

// Keyboard shortcuts
document.addEventListener("keydown", (event) => {
    // Ctrl/Cmd + Enter to submit
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
        if (!submitBtn.disabled) {
            form.dispatchEvent(new Event("submit"));
        }
    }
    
    // Escape to clear
    if (event.key === "Escape") {
        hideResult();
        setStatus("");
        longURLInput.focus();
    }
});

// Add some nice animations on page load
window.addEventListener("load", () => {
    document.body.style.opacity = "0";
    document.body.style.transition = "opacity 0.5s ease";
    
    setTimeout(() => {
        document.body.style.opacity = "1";
    }, 100);
});