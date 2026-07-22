// ==UserScript==
// @name         Focus Website Blocker
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Prevents access to distracting websites by replacing the page content instantly.
// @author       You
// @match        *://*.reddit.com/*
// @match        *://*.facebook.com/*
// @match        *://*.x.com/*
// @match        *://*.tiktok.com/*
// @match        *://*.instagram.com/*
// @match        *://*.webnovel.com/*
// @match        *://*.discord.com/*
// @match        *://*.scribblehub.com/*
// @match        *://*.deviantart.com/*
// @match        *://*.pixiv.com/*
// @match        *://*.icloud.com/*
// @match        *://*.youtube.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function() {
    'use strict';
    window.stop();
    document.documentElement.innerHTML = `
        <style>
            body {
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                background-color: #1e1e2e;
                color: #cdd6f4;
                font-family: system-ui, -apple-system, sans-serif;
                text-align: center;
            }
            .container {
                background-color: #313244;
                padding: 40px 60px;
                border-radius: 12px;
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
                border: 1px solid #45475a;
            }
            h1 {
                color: #f38ba8;
                margin-top: 0;
                font-size: 2.5em;
            }
            p {
                font-size: 1.2em;
                color: #a6adc8;
            }
            .url {
                font-family: monospace;
                background: #181825;
                padding: 5px 10px;
                border-radius: 5px;
                color: #89b4fa;
            }
        </style>
        <body>
            <div class="container">
                <h1>Focus Mode Active</h1>
                <p>You have blocked access to this website.</p>
                <p>Blocked URL: <span class="url">${window.location.hostname}</span></p>
                <br>
                <p><em>Time to get back to work!</em></p>
            </div>
        </body>
    `;
})();
