const HOST_NAME = "com.danieltang.chrome_bookmarks";
let port = null;
let reconnectTimer = null;

function connect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  try {
    port = chrome.runtime.connectNative(HOST_NAME);
    console.log("[BookmarkManager] Connected to native host");

    port.onMessage.addListener(handleMessage);
    port.onDisconnect.addListener(() => {
      const err = chrome.runtime.lastError;
      console.log("[BookmarkManager] Disconnected:", err?.message || "unknown");
      port = null;
      scheduleReconnect();
    });
  } catch (e) {
    console.error("[BookmarkManager] Connect failed:", e);
    scheduleReconnect();
  }
}

function scheduleReconnect() {
  if (!reconnectTimer) {
    reconnectTimer = setTimeout(connect, 3000);
  }
}

async function handleMessage(msg) {
  const { id, command, args } = msg;
  try {
    const result = await dispatch(command, args || {});
    sendResponse(id, { success: true, data: result });
  } catch (e) {
    sendResponse(id, { success: false, error: e.message });
  }
}

function sendResponse(id, payload) {
  if (!port) {
    console.error("[BookmarkManager] Cannot send: port disconnected");
    return;
  }
  port.postMessage({ id, ...payload });
}

async function dispatch(command, args) {
  switch (command) {
    case "list":
      return await cmdList(args);
    case "tree":
      return await cmdTree(args);
    case "search":
      return await cmdSearch(args);
    case "mkdir":
      return await cmdMkdir(args);
    case "move":
      return await cmdMove(args);
    case "move_by_id":
      return await cmdMoveById(args);
    case "rename":
      return await cmdRename(args);
    case "remove":
      return await cmdRemove(args);
    case "ping":
      return { pong: true };
    default:
      throw new Error(`Unknown command: ${command}`);
  }
}

// Find a folder by path like "Bookmarks Bar/NHD Database"
async function findFolderByPath(path) {
  const parts = path.split("/").filter(Boolean);
  const tree = await chrome.bookmarks.getTree();
  let current = tree[0]; // root

  for (const part of parts) {
    if (!current.children) {
      throw new Error(`"${current.title}" is not a folder`);
    }
    const child = current.children.find(
      (c) => c.title === part && c.children !== undefined
    );
    if (!child) {
      throw new Error(`Folder not found: "${part}" in "${current.title}"`);
    }
    current = child;
  }
  return current;
}

function formatNode(node) {
  const result = { id: node.id, title: node.title };
  if (node.url) {
    result.url = node.url;
  }
  if (node.children !== undefined) {
    result.type = "folder";
    result.childCount = node.children.length;
  } else {
    result.type = "bookmark";
  }
  return result;
}

function formatTree(node) {
  const result = formatNode(node);
  if (node.children) {
    result.children = node.children.map(formatTree);
  }
  return result;
}

// --- Commands ---

async function cmdList(args) {
  const { path } = args;
  if (!path) throw new Error("path is required");

  const folder = await findFolderByPath(path);
  return {
    folder: formatNode(folder),
    children: folder.children.map(formatNode),
    count: folder.children.length,
  };
}

async function cmdTree(args) {
  const tree = await chrome.bookmarks.getTree();
  return formatTree(tree[0]);
}

async function cmdSearch(args) {
  const { query } = args;
  if (!query) throw new Error("query is required");

  const results = await chrome.bookmarks.search(query);
  return {
    results: results.map(formatNode),
    count: results.length,
  };
}

async function cmdMkdir(args) {
  const { path } = args;
  if (!path) throw new Error("path is required");

  const parts = path.split("/").filter(Boolean);
  const folderName = parts.pop();
  const parentPath = parts.join("/");

  let parent;
  if (parentPath) {
    parent = await findFolderByPath(parentPath);
  } else {
    const tree = await chrome.bookmarks.getTree();
    parent = tree[0];
  }

  const created = await chrome.bookmarks.create({
    parentId: parent.id,
    title: folderName,
  });

  return formatNode({ ...created, children: [] });
}

async function cmdMove(args) {
  const { pattern, source, destination } = args;

  if (!source) throw new Error("source is required");
  if (!destination) throw new Error("destination is required");

  const srcFolder = await findFolderByPath(source);
  const dstFolder = await findFolderByPath(destination);

  let toMove;
  if (pattern) {
    const regex = new RegExp(pattern, "i");
    toMove = srcFolder.children.filter(
      (c) => regex.test(c.title) || (c.url && regex.test(c.url))
    );
  } else {
    throw new Error("pattern is required for move");
  }

  const moved = [];
  for (const node of toMove) {
    const result = await chrome.bookmarks.move(node.id, {
      parentId: dstFolder.id,
    });
    moved.push(formatNode(result));
  }

  return { moved, count: moved.length };
}

async function cmdMoveById(args) {
  const { id, parentId, index } = args;
  if (!id) throw new Error("id is required");
  if (!parentId) throw new Error("parentId is required");

  const dest = { parentId };
  if (index !== undefined) dest.index = index;

  const result = await chrome.bookmarks.move(id, dest);
  return formatNode(result);
}

async function cmdRename(args) {
  const { id, title } = args;
  if (!id) throw new Error("id is required");
  if (!title) throw new Error("title is required");

  const result = await chrome.bookmarks.update(id, { title });
  return formatNode(result);
}

async function cmdRemove(args) {
  const { id } = args;
  if (!id) throw new Error("id is required");

  const nodes = await chrome.bookmarks.get(id);
  const node = nodes[0];
  const info = formatNode(node);

  if (node.children !== undefined) {
    await chrome.bookmarks.removeTree(id);
  } else {
    await chrome.bookmarks.remove(id);
  }

  return { removed: info };
}

// Start connection
connect();
