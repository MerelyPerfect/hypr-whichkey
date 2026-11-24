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
import Quickshell.Hyprland

ShellRoot {
    id: root

    // ---------- state ----------
    property int rawMask: 0          // what the driver says right now
    property int mask: 0             // what we display (after delay)
    property string submap: ""       // active Hyprland submap ("" = none)
    readonly property bool inSubmap: showSubmaps && submap !== ""
    property string monitor: ""
    property var binds: []

    // ---------- config (defaults; overridden by config.json) ----------
    property var cfg: ({})
    readonly property int    delay:        cfg.delay ?? 400
    readonly property string position:     cfg.position ?? "bottom"         // bottom | top | center
    readonly property int    offset:       cfg.offset ?? 60
    readonly property int    maxColumns:   cfg.maxColumns ?? 5
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

    readonly property bool showSubmaps: cfg.submaps ?? true
    readonly property bool grouping: (cfg.group ?? true) && !inSubmap
    // Built-in categories, checked in order against "<label> <dispatcher> <arg>".
    // Users can prepend their own via config "categories": { "Name": "regex", ... }
    readonly property var builtinCategories: [
        ["Workspaces",  "workspace|scratchpad|special"],
        ["Screenshots", "screenshot|screen ?shot|record|hyprshot|grim|picker|colou?r"],
        ["Media",       "volume|audio|music|media|playerctl|brightness|\\bmic\\b|play|pause"],
        ["Layout",      "layout|split|dwindle|master|gaps|group|pseudo|togglesplit"],
        ["Windows",     "window|focus|move|swap|resize|fullscreen|float|kill|close|pin|cycle|maximi|centerwindow"],
        ["System",      "lock|logout|power|reload|exit|notification|wallpaper|theme|setting|blur|game ?mode|idle|keybind|bar|waybar|zoom"],
        ["Apps",        "^run |exec|terminal|browser|file|launcher|editor|open|menu"]
    ]
    readonly property var categoryRules: {
        const user = Object.entries(cfg.categories ?? {});
        return user.concat(builtinCategories).map(([n, r]) => [n, new RegExp(r, "i")]);
    }
    // Explicit wins: a description like "Media: play/pause" or "[Media] play/pause"
    function categorize(b) {
        let m = b.desc.match(/^\[([^\]]+)\]\s*(.*)$/) || b.desc.match(/^([A-Z][\w &/-]{1,18}):\s+(.*)$/);
        if (m) return { cat: m[1], label: m[2] };
        const hay = b.desc + " " + b.dispatcher + " " + b.arg;
        for (const [n, r] of categoryRules) if (r.test(hay)) return { cat: n, label: b.desc };
        return { cat: "Other", label: b.desc };
    }

    readonly property var shown: (inSubmap
            ? binds.filter(b => b.submap === submap)
            : binds.filter(b => b.submap === "" && b.mask === mask))
        .sort((a, b) => a.key.localeCompare(b.key))

    // [{ title, items }] — sections split into chunks of rowsPerCol so tall groups wrap
    readonly property var sections: {
        if (!grouping) {
            const out = [];
            for (let i = 0; i < shown.length; i += rowsPerCol)
                out.push({ title: "", items: shown.slice(i, i + rowsPerCol).map(b => ({ key: b.key, mask: b.mask, label: b.desc })) });
            return out;
        }
        const order = categoryRules.map(r => r[0]).concat(["Other"]);
        const by = {};
        for (const b of shown) {
            const c = categorize(b);
            (by[c.cat] = by[c.cat] || []).push({ key: b.key, mask: b.mask, label: c.label });
        }
        const names = Object.keys(by).sort((a, b) => {
            const ia = order.indexOf(a), ib = order.indexOf(b);
            return (ia < 0 ? 999 : ia) - (ib < 0 ? 999 : ib) || a.localeCompare(b);
        });
        const out = [];
        for (const n of names)
            for (let i = 0; i < by[n].length; i += rowsPerCol)
                out.push({ title: i === 0 ? n : "", items: by[n].slice(i, i + rowsPerCol) });
        return out;
    }

    function modsLabel(m) {
        const p = [];
        if (m & 64) p.push("SUPER");
        if (m & 4)  p.push("CTRL");
        if (m & 8)  p.push("ALT");
        if (m & 1)  p.push("SHIFT");
        return p.join(" + ");
    }
    // In a submap, binds can use any modifiers, so show them on the keycap ("⇧ H")
    function keyLabel(item) {
        if (!inSubmap || !item.mask) return prettyKey(item.key);
        const p = [];
        if (item.mask & 64) p.push("❖");
        if (item.mask & 4)  p.push("Ctrl");
        if (item.mask & 8)  p.push("Alt");
        if (item.mask & 1)  p.push("⇧");
        return p.join(" ") + " " + prettyKey(item.key);
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
                        .filter(b => !b.key.startsWith("switch:") && (b.submap !== "" || (b.modmask & 64)))
                        .filter(b => !root.onlyDescribed || b.has_description)
                        .map(b => ({ mask: b.modmask, key: b.key, desc: root.describe(b), dispatcher: b.dispatcher || "", arg: b.arg || "", submap: b.submap || "" }))
                        .filter(b => b.desc !== "")
                        .filter(b => !hide.some(r => r.test(b.key + " " + b.desc)))
                        .filter(b => { const id = b.submap + "/" + b.mask + b.key; if (seen[id]) return false; seen[id] = true; return true; });
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
    // Submaps: Hyprland announces them on its event socket ("submap>>name", empty on reset).
    // Works for both hyprland.conf and hyprland.lua, no driver needed.
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "submap") return;
            if (ev.data !== "") {
                bindsProc.running = true;
                if (Hyprland.focusedMonitor) root.monitor = Hyprland.focusedMonitor.name;
            }
            root.submap = ev.data;
        }
    }
    Timer { id: showTimer; interval: root.delay; onTriggered: root.mask = root.rawMask }

    // ---------- UI ----------
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: (root.mask !== 0 || root.inSubmap) && root.shown.length > 0
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
                implicitHeight: col.implicitHeight + 20 * root.uiScale
                radius: 10
                color: Qt.rgba(root.background.r, root.background.g, root.background.b, root.bgOpacity)
                border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                border.width: 1

                Column {
                    id: col
                    anchors.centerIn: parent
                    spacing: 6 * root.uiScale
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.inSubmap ? "submap  ·  " + root.submap : root.modsLabel(root.mask) + "  +  …"
                        color: root.header; font.pixelSize: 15 * root.uiScale; font.bold: true
                        font.family: root.font
                    }
                    Grid {
                        id: grid
                        columns: Math.max(1, Math.min(root.maxColumns, root.sections.length))
                        columnSpacing: 28 * root.uiScale; rowSpacing: 8 * root.uiScale
                        Repeater {
                            model: root.sections
                            Column {
                                required property var modelData
                                spacing: 2 * root.uiScale
                                Text {                                  // category title (blank for continuations)
                                    visible: root.grouping
                                    text: modelData.title || " "
                                    color: root.accent; opacity: 0.85
                                    font.pixelSize: 11 * root.uiScale; font.bold: true
                                    font.capitalization: Font.AllUppercase; font.letterSpacing: 1.5
                                    font.family: root.font
                                    leftPadding: 64 * root.uiScale + 8 * root.uiScale
                                }
                                Repeater {
                                    model: modelData.items
                                    Row {
                                        required property var modelData
                                        spacing: 6 * root.uiScale
                                        Item {
                                            width: 64 * root.uiScale; height: cap.height
                                            Rectangle {
                                                id: cap
                                                anchors.right: parent.right
                                                width: Math.max(24 * root.uiScale, keyText.implicitWidth + 10 * root.uiScale)
                                                height: keyText.implicitHeight + 2 * root.uiScale
                                                radius: 6
                                                color: root.accent
                                                Text {
                                                    id: keyText
                                                    anchors.centerIn: parent
                                                    text: root.keyLabel(modelData)
                                                    color: root.background; font.pixelSize: 14 * root.uiScale; font.bold: true
                                                    font.family: root.font
                                                }
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label
                                            color: root.foreground; font.pixelSize: 14 * root.uiScale
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
    }
}
