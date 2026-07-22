// ==UserScript==
// @name         Focus Website Blocker
// @namespace    http://tampermonkey.net/
// @version      2.2
// @description  Blocks distracting websites on a schedule, with a settings tab to configure sites, block duration, and break duration. Settings persist across restarts.
// @author       You
// @match        *://*/*
// @run-at       document-start
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_registerMenuCommand
// @grant        GM_openInTab
// ==/UserScript==

(function () {
    'use strict';

    const STORAGE_KEY = 'fb_config_v2';

    const DEFAULTS = {
        enabled: true,
        blockedSites: [
            'reddit.com', 'facebook.com', 'x.com', 'tiktok.com',
            'instagram.com'
        ],
        blockValue: 25,
        blockUnit: 'minutes',
        breakValue: 5,
        breakUnit: 'minutes',
        cycleStart: Date.now()
    };

    function loadConfig() {
        const cfg = GM_getValue(STORAGE_KEY, null);
        if (!cfg) {
            GM_setValue(STORAGE_KEY, DEFAULTS);
            return JSON.parse(JSON.stringify(DEFAULTS));
        }
        return cfg;
    }

    function saveConfig(cfg) {
        GM_setValue(STORAGE_KEY, cfg);
    }

    function toMinutes(value, unit) {
        const v = Number(value) || 0;
        return unit === 'hours' ? v * 60 : v;
    }

    function formatDuration(ms) {
        if (ms < 0) ms = 0;
        const totalSec = Math.floor(ms / 1000);
        const h = Math.floor(totalSec / 3600);
        const m = Math.floor((totalSec % 3600) / 60);
        const s = totalSec % 60;
        if (h > 0) {
            return `${h}h ${String(m).padStart(2, '0')}m ${String(s).padStart(2, '0')}s`;
        }
        return `${String(m).padStart(2, '0')}m ${String(s).padStart(2, '0')}s`;
    }

    function getPhase(cfg) {
        const blockMin = toMinutes(cfg.blockValue, cfg.blockUnit);
        const breakMin = toMinutes(cfg.breakValue, cfg.breakUnit);
        const totalMs = (blockMin + breakMin) * 60000;

        if (totalMs <= 0) return { phase: 'break', remainingMs: 0 };

        let elapsed = (Date.now() - cfg.cycleStart) % totalMs;
        if (elapsed < 0) elapsed += totalMs;

        const blockMs = blockMin * 60000;
        if (elapsed < blockMs) {
            return { phase: 'blocked', remainingMs: blockMs - elapsed };
        }
        return { phase: 'break', remainingMs: totalMs - elapsed };
    }

    function isBlockedHost(hostname, list) {
        return list.some(d => {
            d = d.trim().toLowerCase();
            if (!d) return false;
            return hostname === d || hostname.endsWith('.' + d);
        });
    }

    const SETTINGS_MARKER = '#fb-settings-panel';

    function openSettingsPage() {
        GM_openInTab('https://example.com/' + SETTINGS_MARKER, { active: true, insert: true });
    }

    if (typeof GM_registerMenuCommand === 'function') {
        GM_registerMenuCommand('Settings', openSettingsPage);
    }

    if (location.hash === SETTINGS_MARKER) {
        window.stop();
        renderSettingsPage();
        return;
    }

    if (window.top !== window.self) {
        return;
    }

    const cfg = loadConfig();
    if (!cfg.enabled) return;

    const hostname = location.hostname;
    if (!isBlockedHost(hostname, cfg.blockedSites)) return;

    const phase = getPhase(cfg);
    if (phase.phase === 'blocked') {
        renderBlockPage();
    } else {
        injectBreakBadge();
    }

    function renderBlockPage() {
        window.stop();
        document.documentElement.innerHTML = `
            <style>
                body {
                    display: flex; justify-content: center; align-items: center;
                    height: 100vh; margin: 0; background-color: #f0f8ff; color: #2b3a4a;
                    font-family: system-ui, -apple-system, sans-serif; text-align: center;
                }
                .container {
                    background-color: #ffffff; padding: 48px 56px; border-radius: 16px;
                    box-shadow: 0 4px 24px rgba(59, 130, 246, 0.10); border: 1px solid #dceefc;
                    max-width: 460px;
                }
                .icon { font-size: 2.2em; margin-bottom: 4px; }
                h1 { color: #2b3a4a; margin: 8px 0 0; font-size: 1.6em; font-weight: 600; }
                p { font-size: 1em; color: #6b8299; margin: 14px 0; }
                .url { font-family: monospace; background: #eef7ff; padding: 4px 10px; border-radius: 6px; color: #3b82c4; }
                #fb-countdown { font-family: monospace; font-size: 1.3em; color: #3b82c4; margin: 18px 0; font-weight: 600; }
                .fb-buttons { margin-top: 24px; display: flex; gap: 10px; justify-content: center; }
                .fb-btn {
                    background-color: #eaf3fc; color: #3b6ea5; border: 1px solid #d7e9fb; padding: 10px 18px;
                    border-radius: 8px; font-size: 0.95em; cursor: pointer; transition: background-color 0.15s;
                }
                .fb-btn:hover { background-color: #dcedfb; }
                .fb-btn.primary { background-color: #4fa3e3; color: #ffffff; border-color: #4fa3e3; }
                .fb-btn.primary:hover { background-color: #3f92d1; }
            </style>
            <body>
                <div class="container">
                    <div class="icon">☁</div>
                    <h1>Focus Mode</h1>
                    <p>Blocked: <span class="url">${hostname}</span></p>
                    <div id="fb-countdown">Calculating...</div>
                    <p>Time to get back to work.</p>
                    <div class="fb-buttons">
                        <button class="fb-btn primary" id="fb-break-btn">Take Break Now</button>
                        <button class="fb-btn" id="fb-settings-btn">Settings</button>
                    </div>
                </div>
            </body>
        `;

        document.getElementById('fb-settings-btn').addEventListener('click', openSettingsPage);
        document.getElementById('fb-break-btn').addEventListener('click', () => {
            const c = loadConfig();
            const blockMin = toMinutes(c.blockValue, c.blockUnit);
            c.cycleStart = Date.now() - blockMin * 60000;
            saveConfig(c);
            location.reload();
        });

        const countdownEl = document.getElementById('fb-countdown');
        const timer = setInterval(() => {
            const c = loadConfig();
            const p = getPhase(c);
            if (p.phase !== 'blocked') {
                clearInterval(timer);
                location.reload();
                return;
            }
            countdownEl.textContent = `Break in: ${formatDuration(p.remainingMs)}`;
        }, 1000);
    }

    function injectBreakBadge() {
        const badge = document.createElement('div');
        badge.id = 'fb-break-badge';
        badge.style.cssText = `
            position: fixed; bottom: 16px; right: 16px; z-index: 2147483647;
            background-color: #ffffff; color: #3b6ea5; font-family: system-ui, -apple-system, sans-serif;
            padding: 10px 16px; border-radius: 10px; border: 1px solid #d7e9fb;
            box-shadow: 0 4px 16px rgba(59, 130, 246, 0.12); font-size: 0.85em;
        `;
        document.documentElement.appendChild(badge);

        const update = () => {
            const c = loadConfig();
            const p = getPhase(c);
            if (p.phase !== 'break') {
                location.reload();
                return;
            }
            badge.textContent = `☁ Break — blocked again in ${formatDuration(p.remainingMs)}`;
        };

        const start = () => {
            update();
            setInterval(update, 1000);
        };
        if (document.body) start();
        else document.addEventListener('DOMContentLoaded', start);
    }

    function renderSettingsPage() {
        document.title = 'Focus Blocker Settings';
        document.documentElement.innerHTML = `
            <style>
                body {
                    margin: 0; background-color: #f0f8ff; color: #2b3a4a;
                    font-family: system-ui, -apple-system, sans-serif; padding: 48px 24px;
                }
                .wrap { max-width: 600px; margin: 0 auto; }
                .header { display: flex; align-items: center; gap: 10px; margin-bottom: 8px; }
                .header .icon { font-size: 1.4em; }
                h1 { color: #2b3a4a; font-size: 1.4em; font-weight: 600; margin: 0; }
                label { display: block; margin-top: 22px; margin-bottom: 6px; color: #6b8299; font-size: 0.9em; font-weight: 600; }
                textarea, input[type=number] {
                    width: 100%; box-sizing: border-box; background: #ffffff; color: #2b3a4a;
                    border: 1px solid #d7e9fb; border-radius: 8px; padding: 10px 12px; font-family: monospace;
                    font-size: 0.95em;
                }
                textarea:focus, input:focus, select:focus { outline: none; border-color: #8ec7f2; }
                textarea { height: 130px; resize: vertical; }
                select {
                    background: #ffffff; color: #2b3a4a; border: 1px solid #d7e9fb;
                    border-radius: 8px; padding: 10px 12px; font-family: inherit; font-size: 0.95em;
                }
                .row { display: flex; gap: 10px; align-items: center; }
                .row input { flex: 1; }
                .checkbox-row { display: flex; align-items: center; gap: 10px; margin-top: 24px; }
                .checkbox-row input { width: auto; }
                .checkbox-row label { margin: 0; color: #2b3a4a; font-weight: 500; }
                #fb-status {
                    margin-top: 28px; padding: 14px 16px; background: #ffffff; border-radius: 10px;
                    border: 1px solid #d7e9fb; font-family: monospace; font-size: 0.9em; color: #3b6ea5;
                }
                .fb-buttons { margin-top: 28px; display: flex; align-items: center; gap: 10px; }
                .fb-btn {
                    background-color: #4fa3e3; color: #ffffff; border: none; padding: 11px 20px;
                    border-radius: 8px; font-size: 0.95em; font-weight: 600; cursor: pointer;
                    transition: background-color 0.15s;
                }
                .fb-btn:hover { background-color: #3f92d1; }
                .fb-btn.secondary { background-color: #eaf3fc; color: #3b6ea5; border: 1px solid #d7e9fb; }
                .fb-btn.secondary:hover { background-color: #dcedfb; }
                #fb-saved-msg { color: #4fa3e3; font-size: 0.9em; font-weight: 600; display: none; }
            </style>
            <body>
                <div class="wrap">
                    <div class="header">
                        <span class="icon">☁</span>
                        <h1>Focus Blocker Settings</h1>
                    </div>

                    <div class="checkbox-row">
                        <input type="checkbox" id="fb-enabled">
                        <label>Enable blocking</label>
                    </div>

                    <label for="fb-sites">Blocked websites (one domain per line, e.g. reddit.com)</label>
                    <textarea id="fb-sites"></textarea>

                    <label>Block duration (how long the site stays blocked)</label>
                    <div class="row">
                        <input type="number" min="0" id="fb-block-value">
                        <select id="fb-block-unit">
                            <option value="minutes">Minutes</option>
                            <option value="hours">Hours</option>
                        </select>
                    </div>

                    <label>Break duration (how long sites are unblocked before re-blocking)</label>
                    <div class="row">
                        <input type="number" min="0" id="fb-break-value">
                        <select id="fb-break-unit">
                            <option value="minutes">Minutes</option>
                            <option value="hours">Hours</option>
                        </select>
                    </div>

                    <div class="fb-buttons">
                        <button class="fb-btn" id="fb-save-btn">Save</button>
                        <button class="fb-btn secondary" id="fb-save-restart-btn">Save &amp; Restart Cycle</button>
                        <span id="fb-saved-msg">Saved ✓</span>
                    </div>

                    <div id="fb-status">Loading status...</div>
                </div>
            </body>
        `;

        const cfg = loadConfig();

        document.getElementById('fb-enabled').checked = !!cfg.enabled;
        document.getElementById('fb-sites').value = (cfg.blockedSites || []).join('\n');
        document.getElementById('fb-block-value').value = cfg.blockValue;
        document.getElementById('fb-block-unit').value = cfg.blockUnit;
        document.getElementById('fb-break-value').value = cfg.breakValue;
        document.getElementById('fb-break-unit').value = cfg.breakUnit;

        function readFormIntoConfig(existing) {
            const sites = document.getElementById('fb-sites').value
                .split('\n')
                .map(s => s.trim().toLowerCase())
                .filter(Boolean);

            return {
                enabled: document.getElementById('fb-enabled').checked,
                blockedSites: sites,
                blockValue: Number(document.getElementById('fb-block-value').value) || 0,
                blockUnit: document.getElementById('fb-block-unit').value,
                breakValue: Number(document.getElementById('fb-break-value').value) || 0,
                breakUnit: document.getElementById('fb-break-unit').value,
                cycleStart: existing.cycleStart
            };
        }

        function flashSaved() {
            const msg = document.getElementById('fb-saved-msg');
            msg.style.display = 'inline';
            setTimeout(() => { msg.style.display = 'none'; }, 1500);
        }

        document.getElementById('fb-save-btn').addEventListener('click', () => {
            const current = loadConfig();
            const updated = readFormIntoConfig(current);
            saveConfig(updated);
            flashSaved();
        });

        document.getElementById('fb-save-restart-btn').addEventListener('click', () => {
            const current = loadConfig();
            const updated = readFormIntoConfig(current);
            updated.cycleStart = Date.now();
            saveConfig(updated);
            flashSaved();
        });

        const statusEl = document.getElementById('fb-status');
        function updateStatus() {
            const c = loadConfig();
            if (!c.enabled) {
                statusEl.textContent = 'Blocking is currently disabled.';
                return;
            }
            const p = getPhase(c);
            if (p.phase === 'blocked') {
                statusEl.textContent = `Status: BLOCKED — break starts in ${formatDuration(p.remainingMs)}`;
            } else {
                statusEl.textContent = `Status: BREAK — blocking resumes in ${formatDuration(p.remainingMs)}`;
            }
        }
        updateStatus();
        setInterval(updateStatus, 1000);
    }
})();
