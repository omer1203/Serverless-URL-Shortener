"use strict";

const API_main = "" //add the http api here

const form = document.getElementById("shortenForm");
const longURLInput = document.getElementById("longURL");
const submitBtn = document.getElementById("submitBtn");
const status1 = document.getElementById("status");
const result = document.getElementById("result");
const shortLink = document.getElementById("shortLink");

function setStatus(message, isError = false) {

    status1.textContent = message || ""; // update the status para with a message or empty
    if(isError && message) status1.textContent = `Error: ${message}`;

}

const shortenEndPoint = `${API_main}/shorten`; // post here
const redirectBase = `${API_main}/r/` // users will visit this + short code


function showResult(shortCode, longURL) { 

    //now build a full short url based on http api pattern
    const shortURL = `${redirectBase}${encodeURIComponent(shortCode)}`;

    shortLink.href = shortURL// fill hte href and text so its clickable
    shortLink.textContent = shortCode; // show only the code as the link text

    setStatus(`Destination: ${longURL}`); // show the long url too 
    result.hidden = false; // reveal the result para which was hidden at first in html 

}


//function for basic http link verification
function httpURL(value) { 
    return /^https?:\/\//i.test(value) && value.includes("."); // check if the value starts with http:// or https://
}


form.addEventListener("submit", async (event) => {
    event.preventDefault(); // prevent the form from submitting normally
    result.hidden = true;
    setStatus("");

    const longURL = longURLInput.value.trim(); // get the value of the input field and trim any whitespace

    if(!httpURL(longURL)) {
        setStatus("Invalid URL. Please enter a valid http or https URL.", true);
        return;
    }

    submitBtn.disabled = true;
    setStatus("Shortening URL..."); // set the status to "shortening url"

    try {
        //send POST /shorten tothe api with json body {long_url: "wtv"}
        const response = await fetch(`${API_main}/shorten`, {
            method: "POST", // the backend expects a post 
            headers: {
                "Content-Type": "application/json" //obv, tell server its json
            },
            body: JSON.stringify({ long_url: longURL }) //serialize the payload as json text using key that lambda expects
        });

        const data = await response.json().catch(() => ({}));
        if(!response.ok) { // if there is an error
            const msg = data && data.error ? data.error : `HTTP ${response.status}`;
            setStatus(msg, true); // Mark as error in the status area
            return; //stop if error
        }

        if (!data || !data.short_code) {
            setStatus("Invalid response from server", true);
            return;
        }

        
        showResult(data.short_code, longURL);
        setStatus(`Destination: ${longURL}`); //the long url 
    } 
    catch (error) {
        setStatus(`Error shortening URL: ${error.message}`, true);
    }
    finally { 
        submitBtn.disabled = false
    }
});