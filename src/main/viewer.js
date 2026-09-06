/**
 * The output viewer - a second window that shows what the API just produced.
 *
 * The desktop UI renders results inside its own workspaces, so nothing here
 * fires for anything you do in the app. This exists for inference driven from
 * *outside* it: the local HTTP API, and through it the MCP server. Those callers
 * get JSON; without this, a detection an agent ran on your machine is visible to
 * everyone except you.
 *
 * The engine announces each finished result on the `viewer:output` event
 * (python/api/viewer.py) and this turns that into a window.
 *
 * Design notes:
 *   - The window is reused. A tool loop that runs ten inferences must not open
 *     ten windows; results stack newest-first in the one that is already open.
 *   - Visible, but not rude. `showInactive()` + `moveTop()` raises the window to
 *     the front without taking keyboard focus, so you can see the result without
 *     an agent yanking the cursor out of whatever you are typing. showInactive()
 *     alone is not enough: on Windows it opens the window *behind* the active
 *     one, which for our purposes is the same as not opening it at all.
 *   - Results that arrive before the page has loaded are queued, not dropped -
 *     the first result is precisely the one that opens the window, so it always
 *     races the page.
 */
'use strict';

const { BrowserWindow } = require('electron');
const path = require('path');

const { appIcon } = require('./branding');

/** Keep the last N results in the window; each one holds a base64 blob. */
const MAX_RESULTS = 20;

let win = null;
let ready = false;
let pending = [];

function create() {
  win = new BrowserWindow({
    width: 720,
    height: 780,
    minWidth: 420,
    minHeight: 360,
    show: false,
    backgroundColor: '#0b0d12',
    title: 'ZeroInfer - Output',
    ...(appIcon() ? { icon: appIcon() } : {}),
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'viewer-preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.once('ready-to-show', () => {
    // Worth showing, not worth interrupting for: raise it, don't focus it.
    win.showInactive();
    win.moveTop();
  });

  win.webContents.on('did-finish-load', () => {
    ready = true;
    for (const payload of pending) win.webContents.send('viewer:output', payload);
    pending = [];
  });

  win.on('closed', () => {
    win = null;
    ready = false;
    pending = [];
  });

  win.loadFile(path.join(__dirname, 'viewer.html'));
  return win;
}

/**
 * Show one finished result, opening the window if it isn't already up.
 * Safe to call from an engine event: it never throws into the caller.
 */
function showOutput(payload) {
  if (!payload || !Array.isArray(payload.items) || !payload.items.length) return;
  try {
    if (!win || win.isDestroyed()) create();
    if (!ready) {
      // Bound the queue too: a burst before first paint is still a burst.
      pending.push(payload);
      if (pending.length > MAX_RESULTS) pending.shift();
      return;
    }
    if (win.isMinimized()) win.restore();
    if (!win.isVisible()) win.showInactive();
    // A new result on an already-open window is easy to miss if the window is
    // buried; surface it again, still without taking focus.
    win.moveTop();
    win.webContents.send('viewer:output', payload);
  } catch {
    // A viewer that cannot open must never break the inference that fed it.
  }
}

function closeViewer() {
  if (win && !win.isDestroyed()) win.destroy();
  win = null;
  ready = false;
  pending = [];
}

module.exports = { showOutput, closeViewer, MAX_RESULTS };
