const { app, BrowserWindow, dialog } = require("electron");
const fs = require("fs");
const path = require("path");
const { startFlashPolicy } = require("./flash-policy");

const logPath = path.join(__dirname, "..", "logs", "electron-net.log");

function logLine(line) {
  const stamp = new Date().toISOString();
  try {
    fs.mkdirSync(path.dirname(logPath), { recursive: true });
    fs.appendFileSync(logPath, "[" + stamp + "] " + line + "\n", "utf8");
  } catch (e) {
    process.stderr.write(String(e) + "\n");
  }
}

function findPepperFlash() {
  const candidates = [
    path.join(__dirname, "flashver", "pepflashplayer64.dll"),
    path.join(
      process.env.LOCALAPPDATA || "",
      "Programs",
      "ddclassico-launcher",
      "resources",
      "flashver",
      "pepflashplayer64.dll"
    )
  ];
  return candidates.find(function (p) {
    return p && fs.existsSync(p);
  });
}

function startUrlFromArgs() {
  for (var i = 0; i < process.argv.length; i++) {
    if (process.argv[i].indexOf("http://") === 0 || process.argv[i].indexOf("https://") === 0) {
      return process.argv[i];
    }
  }
  return "http://127.0.0.1/index.htm";
}

const pepper = findPepperFlash();
if (!pepper) {
  app.whenReady().then(function () {
    dialog.showErrorBox(
      "DDTank41",
      "Nao achei o Pepper Flash (pepflashplayer64.dll).\nColoque o arquivo em Launcher.Electron\\flashver\\ ou mantenha o DDClassico instalado."
    );
    app.quit();
  });
} else {
  app.commandLine.appendSwitch("ppapi-flash-path", pepper);
  app.commandLine.appendSwitch("ppapi-flash-version", "32.0.0.303");
  app.commandLine.appendSwitch("disable-http-cache");
  app.commandLine.appendSwitch("remote-debugging-port", "9222");
}

app.whenReady().then(function () {
  if (!pepper) {
    return;
  }

  try {
    if (fs.existsSync(logPath)) {
      fs.writeFileSync(logPath.replace(/\.log$/, ".prev.log"), fs.readFileSync(logPath));
    }
    fs.writeFileSync(logPath, "", "utf8");
  } catch (e) {}

  const { session } = require("electron");
  const ses = session.defaultSession;

  ses.webRequest.onBeforeRequest(function (details, callback) {
    logLine("REQ  " + details.method + " " + (details.resourceType || "?") + " " + details.url);
    callback({});
  });
  ses.webRequest.onCompleted(function (details) {
    logLine(
      "OK   " +
        details.statusCode +
        " " +
        details.method +
        " " +
        (details.resourceType || "?") +
        " " +
        details.url +
        (details.fromCache ? " (cache)" : "")
    );
  });
  ses.webRequest.onErrorOccurred(function (details) {
    logLine("ERR  " + details.error + " " + details.method + " " + details.url);
  });

  logLine("pepper=" + pepper);
  startFlashPolicy(logLine);
  const startUrl = startUrlFromArgs();
  logLine("start=" + startUrl);

  const win = new BrowserWindow({
    width: 1100,
    height: 740,
    backgroundColor: "#000000",
    webPreferences: {
      plugins: true,
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  win.webContents.on("console-message", function (event, level, message, line, sourceId) {
    logLine("CONS[" + level + "] " + message + " (" + sourceId + ":" + line + ")");
  });
  win.webContents.on("did-fail-load", function (event, code, desc, url, isMain) {
    logLine("FAIL load code=" + code + " " + desc + " main=" + isMain + " " + url);
  });
  win.webContents.on("plugin-crashed", function (event, name, version) {
    logLine("PLUGIN crash " + name + " " + version);
  });
  win.webContents.on("did-finish-load", function () {
    logLine("PAGE loaded " + win.webContents.getURL());
  });

  setInterval(function () {
    win.webContents
      .capturePage()
      .then(function (img) {
        fs.writeFileSync(path.join(__dirname, "..", "logs", "electron-screen.png"), img.toPNG());
      })
      .catch(function () {});
  }, 8000);

  win.loadURL(startUrl);
});

app.on("window-all-closed", function () {
  app.quit();
});
