// hypr-whichkey — hold SUPER to see your Hyprland shortcuts, like subtitles.
// https://github.com/MerelyPerfect/hypr-whichkey  ·  MIT
//
// Contract with the drivers: $XDG_RUNTIME_DIR/hypr-whichkey contains "<modmask> <monitor>"
// while a modifier is held, and "0" when released. Mask bits = Hyprland's: SHIFT=1 CTRL=4 ALT=8 SUPER=64.
// Config (all optional): ~/.config/hypr-whichkey/config.json — see config.example.json.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // ---------- state ----------
    property int rawMask: 0          // what the driver says right now
    property int mask: 0             // what we display (after delay)
    property string monitor: ""
    property var binds: []

    // ---------- config (defaults; overridden by config.json) ----------
    property var cfg: ({})
    readonly property int    delay:        cfg.delay ?? 400
    readonly property string position:     cfg.position ?? "bottom"         // bottom | top | center
    readonly property int    offset:       cfg.offset ?? 60
    readonly property int    maxColumns:   cfg.maxColumns ?? 4
    readonly property int    rowsPerCol:   cfg.rowsPerColumn ?? 8
    readonly property bool   onlyDescribed: cfg.onlyDescribed ?? false
    readonly property var    hidden:       cfg.hide ?? []                   // regexes matched against "key desc"
    readonly property real   uiScale:        ({ small: 0.85, medium: 1.0, large: 1.2 })[cfg.size ?? "medium"] ?? (cfg.size || 1.0)
    property string font:    cfg.font ?? ""

    // ---------- theme (config > pywal/wallust > Hyprland border > fallback) ----------
    property color accent:     "#7dd3fc"
    property color background: "#101014"
    property color foreground: "#f5f5f5"
    property color header:     "#ffd479"
    readonly property real bgOpacity: cfg.opacity ?? 0.95

    function applyTheme(t, src) {
        if (!t) return;
        if (t.accent) accent = t.accent;
        if (t.background) background = t.background;
        if (t.foreground) foreground = t.foreground;
        if (t.header) header = t.header;
        console.info("hypr-whichkey: theme from", src);
    }

    readonly property var shown: binds
        .filter(b => b.mask === mask)
        .sort((a, b) => a.key.localeCompare(b.key))

    function modsLabel(m) {
        const p = [];
        if (m & 64) p.push("SUPER");
        if (m & 4)  p.push("CTRL");
        if (m & 8)  p.push("ALT");
        if (m & 1)  p.push("SHIFT");
        return p.join(" + ");
    }
    function prettyKey(k) {
        const map = { Return: "⏎", SPACE: "Space", space: "Space", Escape: "Esc", Tab: "Tab", BackSpace: "⌫",
                      left: "←", right: "→", up: "↑", down: "↓", period: ".", comma: ",", minus: "-", equal: "=",
                      plus: "+", slash: "/", backslash: "\\", semicolon: ";", apostrophe: "'", grave: "`",
                      bracketleft: "[", bracketright: "]", mouse_down: "Scroll ↓", mouse_up: "Scroll ↑",
                      "mouse:272": "LMB drag", "mouse:273": "RMB drag", Print: "PrtSc", Delete: "Del" };
        if (map[k]) return map[k];
        if (/^code:1\d$/.test(k)) return String((parseInt(k.slice(5)) - 9) % 10);   // number row keycodes
        return k.length === 1 ? k.toUpperCase() : k;
    }
    // Readable fallback for binds without a description
    function describe(b) {
        if (b.has_description) return b.description;
        const d = b.dispatcher || "", a = (b.arg || "").trim();
        if (!d || d.startsWith("function:")) return "";         // Lua closures: nothing to show
        if (d === "exec") return "run " + a.split(/\s+/)[0].replace(/^.*\//, "");
        return a ? d + " " + a : d;
    }

    // ---------- data loading ----------
    Process {
        id: bindsProc
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const seen = {}, hide = root.hidden.map(r => new RegExp(r, "i"));
                    root.binds = JSON.parse(text)
                        .filter(b => !b.key.startsWith("switch:") && b.submap === "" && (b.modmask & 64))
                        .filter(b => !root.onlyDescribed || b.has_description)
                        .map(b => ({ mask: b.modmask, key: b.key, desc: root.describe(b) }))
                        .filter(b => b.desc !== "")
                        .filter(b => !hide.some(r => r.test(b.key + " " + b.desc)))
                        .filter(b => { const id = b.mask + b.key; if (seen[id]) return false; seen[id] = true; return true; });
                } catch (e) { console.warn("hypr-whichkey: cannot parse binds:", e); }
            }
        }
    }

    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/hypr-whichkey/config.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: {
            try { root.cfg = JSON.parse(text()); } catch (e) { console.warn("hypr-whichkey: bad config.json:", e); return; }
            if (root.cfg.theme) root.applyTheme(root.cfg.theme, "config.json");
        }
        onLoadFailed: autoTheme()
    }
    function autoTheme() { walFile.reload(); }

    // pywal / wallust (pywal-compatible template) / matugen with a pywal template
    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        printErrors: false
        blockLoading: false
        onLoaded: {
            if (root.cfg.theme) return;
            try {
                const w = JSON.parse(text());
                root.applyTheme({ background: w.special.background, foreground: w.special.foreground,
                                  accent: w.colors.color4, header: w.colors.color3 }, "~/.cache/wal/colors.json");
            } catch (e) { hyprBorder.running = true; }
        }
        onLoadFailed: if (!root.cfg.theme) hyprBorder.running = true
    }
    // Hyprland's active border colour as accent
    Process {
        id: hyprBorder
        command: ["hyprctl", "-j", "getoption", "general:col.active_border"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text);
                    const hex = (o.gradient || "").split(" ")[0] || (o.int !== undefined ? (o.int >>> 0).toString(16) : "");
                    if (/^[0-9a-f]{8}$/i.test(hex))   // AARRGGBB
                        root.applyTheme({ accent: "#" + hex.slice(2) }, "Hyprland col.active_border");
                } catch (e) {}
            }
        }
    }
    Process {
        id: fontProc
        command: ["fc-match", "monospace", "-f", "%{family[0]}"]
        stdout: StdioCollector { onStreamFinished: if (!root.font) root.font = text.trim() }
    }

    Component.onCompleted: { bindsProc.running = true; fontProc.running = true; }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr-whichkey"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: {
            const parts = text().trim().split(/\s+/);
            const m = parseInt(parts[0]) || 0;
            if (parts[1]) root.monitor = parts[1];
            if (m !== 0 && root.rawMask === 0) bindsProc.running = true;   // refresh on every show
            root.rawMask = m;
            if (m === 0) { showTimer.stop(); root.mask = 0; }
            else if (root.mask !== 0) root.mask = m;                        // already visible: narrow instantly
            else showTimer.restart();
        }
    }
    Timer { id: showTimer; interval: root.delay; onTriggered: root.mask = root.rawMask }

    // ---------- UI ----------
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.mask !== 0 && root.shown.length > 0
                     && (root.monitor === "" || modelData.name === root.monitor)
            color: "transparent"
            anchors {
                bottom: root.position === "bottom"
                top: root.position === "top"
                left: true; right: true
            }
            margins.bottom: root.position === "bottom" ? root.offset : 0
            margins.top: root.position === "top" ? root.offset : 0
            implicitHeight: box.implicitHeight
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "hypr-whichkey"

            Rectangle {
                id: box
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 80, grid.implicitWidth + 40 * root.uiScale)
                implicitHeight: col.implicitHeight + 32 * root.uiScale
                radius: 10
                color: Qt.rgba(root.background.r, root.background.g, root.background.b, root.bgOpacity)
                border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                border.width: 1

                Column {
                    id: col
                    anchors.centerIn: parent
                    spacing: 8 * root.uiScale
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.modsLabel(root.mask) + "  +  …"
                        color: root.header; font.pixelSize: 18 * root.uiScale; font.bold: true
                        font.family: root.font
                    }
                    Grid {
                        id: grid
                        columns: Math.max(1, Math.min(root.maxColumns, Math.ceil(root.shown.length / root.rowsPerCol)))
                        rows: Math.ceil(root.shown.length / columns)
                        flow: Grid.TopToBottom
                        columnSpacing: 32 * root.uiScale; rowSpacing: 4 * root.uiScale
                        Repeater {
                            model: root.shown
                            Row {
                                required property var modelData
                                spacing: 12 * root.uiScale
                                Item {
                                    width: 90 * root.uiScale; height: cap.height
                                    Rectangle {
                                        id: cap
                                        anchors.right: parent.right
                                        width: Math.max(32 * root.uiScale, keyText.implicitWidth + 14 * root.uiScale)
                                        height: keyText.implicitHeight + 6 * root.uiScale
                                        radius: 6
                                        color: root.accent
                                        Text {
                                            id: keyText
                                            anchors.centerIn: parent
                                            text: root.prettyKey(modelData.key)
                                            color: root.background; font.pixelSize: 17 * root.uiScale; font.bold: true
                                            font.family: root.font
                                        }
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.desc
                                    color: root.foreground; font.pixelSize: 16 * root.uiScale
                                    font.family: root.font
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
