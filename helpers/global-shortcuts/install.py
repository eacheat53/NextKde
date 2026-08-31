#!/usr/bin/env python3
"""Register the Quickshell global shortcuts as KDE Command Shortcuts.

Each shortcut in shortcuts.json becomes:
  - a .desktop launcher in ~/.local/share/applications whose Exec runs
    `qs -p <config> ipc call <target> <action>`, and
  - a `[services][<id>.desktop] _launch=<combo>` entry in kglobalshortcutsrc —
    the exact format Plasma itself writes for Command Shortcuts.

kglobalaccel grabs the key and launches the .desktop when the combo is
pressed. Conflicts are detected against every existing binding in
kglobalshortcutsrc; a duplicate combo is reported and skipped so two actions
never fight over one key. Run install.py again after editing shortcuts.json
to re-apply. Combo changes are best done in System Settings → Shortcuts, which
keeps the per-user bindings (this script only seeds defaults).

Usage: python3 install.py [config-dir]     (default: this repository root)
"""
import json
import os
import re
import shutil
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_DIR = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(SCRIPT_DIR, "..", ".."))
APPS_DIR = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "applications")
SHORTCUTS_RC = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "kglobalshortcutsrc")


def load_table():
    with open(os.path.join(SCRIPT_DIR, "shortcuts.json"), encoding="utf-8") as f:
        return json.load(f)


def existing_launch_bindings():
    """Return {combo: [section ids]} parsed from kglobalshortcutsrc."""
    bindings = {}
    section = None
    try:
        with open(SHORTCUTS_RC, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                m = re.match(r"\[(.+)\]", line)
                if m:
                    sec = m.group(1)
                    if sec.startswith("services]["):
                        sec = sec[len("services]["):]
                    section = sec
                    continue
                m = re.match(r"(?:_launch|[^=]+)=([^,\n]+)", line)
                if m and section:
                    for combo in m.group(1).split("\\t"):
                        combo = combo.strip()
                        if combo and combo != "none":
                            bindings.setdefault(combo, []).append(section)
    except FileNotFoundError:
        pass
    return bindings


def clear_default_claims(combo):
    """Strip `combo` from other components' *default* bindings.

    kglobalaccel lets a component claim its default keys whenever it
    re-registers, even when the current binding is "none". klipper defaults
    to Meta+V ("show clipboard item at mouse position"), powerdevil's
    powerProfile to Meta+B, and KWin's window walking to Meta+Tab — after the
    daemon restarts they steal those combos back from the Command Shortcuts
    this script just registered. Removing the combo from the default field
    (leaving genuinely active bindings untouched) prevents the theft.
    """
    try:
        with open(SHORTCUTS_RC, encoding="utf-8") as f:
            lines = f.readlines()
    except FileNotFoundError:
        return
    changed = False
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("[") or stripped.startswith("_"):
            continue
        key, sep, value = stripped.partition("=")
        if not sep:
            continue
        parts = value.split(",", 2)
        if len(parts) != 3:
            continue
        current, defaults, label = parts
        current_keys = current.split("\\t")
        default_keys = defaults.split("\\t")
        if combo not in default_keys:
            continue
        # The combo sits in the default column. If it also sits in the current
        # column the component merely claimed its default (klipper does this
        # with Meta+V after a daemon restart), so free both columns; if only
        # the default holds it, strip just the default so it can never be
        # claimed back later.
        new_current_keys = [k for k in current_keys if k != combo] or ["none"]
        new_default_keys = [k for k in default_keys if k != combo] or ["none"]
        new_current = "\\t".join(new_current_keys)
        new_defaults = "\\t".join(new_default_keys)
        lines[index] = f"{key}={new_current},{new_defaults},{label}\n"
        print(f"[global-shortcuts] 释放默认绑定 {combo} <- {key.strip()}")
        changed = True
    if changed:
        with open(SHORTCUTS_RC, "w", encoding="utf-8") as f:
            f.writelines(lines)


def rewrite_shortcut_rc(shortcut_id, combo):
    """Write the `[services][<id>.desktop]` group Plasma uses for Command
    Shortcuts, replacing every group previously written for this shortcut.

    The bare `[<id>.desktop]` groups an older version of this script wrote
    are removed too: kglobalaccel reads those as a regular application
    component that no running client owns, and that dead component collides
    with the Command Shortcut registered under the same name — the key ends
    up grabbed by a component whose trigger nobody answers.
    """
    own_headers = {f"[{shortcut_id}.desktop]", f"[services][{shortcut_id}.desktop]"}
    try:
        with open(SHORTCUTS_RC, encoding="utf-8") as f:
            lines = f.readlines()
    except FileNotFoundError:
        lines = []

    kept, dropping = [], False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            dropping = stripped in own_headers
            if dropping:
                continue
        elif dropping:
            continue
        kept.append(line)

    if kept and not kept[-1].endswith("\n"):
        kept[-1] += "\n"
    kept.append(f"[services][{shortcut_id}.desktop]\n")
    kept.append(f"_launch={combo}\n")
    with open(SHORTCUTS_RC, "w", encoding="utf-8") as f:
        f.writelines(kept)


KEY_MAP = {
    "space": 0x20,
    "tab": 0x01000001,
    "return": 0x01000004,
    "enter": 0x01000004,
    "esc": 0x01000000,
    "escape": 0x01000000,
}

MOD_MAP = {
    "meta": 0x10000000,
    "super": 0x10000000,
    "ctrl": 0x04000000,
    "control": 0x04000000,
    "alt": 0x08000000,
    "shift": 0x02000000,
}


def parse_combo(combo: str) -> int:
    mods = 0
    key = 0
    for part in combo.split("+"):
        pl = part.lower()
        if pl in MOD_MAP:
            mods |= MOD_MAP[pl]
        elif pl in KEY_MAP:
            key = KEY_MAP[pl]
        elif len(part) == 1:
            key = ord(part.upper())
    return mods | key


def component_is_active(bus, desktop_name):
    """Whether the live daemon treats this service component as active.

    A component registered from this short-lived client can stay inactive:
    kglobalaccel keeps its bindings and answers invokeShortcut, but never
    grabs the physical key for it. isActive only flips when the compositor
    loads kglobalshortcutsrc at startup, so an inactive shortcut needs a
    re-login before its combo actually fires. Return True when the check
    itself fails so registration output stays quietly optimistic.
    """
    try:
        import dbus
        kg = bus.get_object("org.kde.kglobalaccel", "/kglobalaccel")
        iface = dbus.Interface(kg, "org.kde.KGlobalAccel")
        path = str(iface.getComponent(desktop_name))
        comp = bus.get_object("org.kde.kglobalaccel", path)
        comp_iface = dbus.Interface(comp, "org.kde.kglobalaccel.Component")
        return bool(comp_iface.isActive())
    except Exception:
        return True


def register_via_dbus(shortcuts):
    """Re-apply the bindings in the live daemon.

    This runs AFTER the daemon restart, not before: a restart drops all
    in-memory DBus registrations, so registering first and restarting second
    throws the work away.

    Newly seeded components registered from this temp client may stay
    inactive for the rest of the session (bindings visible, key never
    grabbed); collect those and tell the user a re-login is required.
    """
    for attempt in range(5):
        try:
            import dbus
            bus = dbus.SessionBus()
            kg = bus.get_object("org.kde.kglobalaccel", "/kglobalaccel")
            iface = dbus.Interface(kg, "org.kde.KGlobalAccel")
            needs_relogin = []
            for entry in shortcuts:
                desktop_name = entry["id"] + ".desktop"
                action_id = [desktop_name, "_launch", entry["description"], entry["description"]]
                iface.doRegister(action_id)
                keys = dbus.Array([dbus.Int32(parse_combo(entry["default"]))], signature="i")
                iface.setForeignShortcut(action_id, keys)
                if component_is_active(bus, desktop_name):
                    print(f"[global-shortcuts] DBus 实时注册: {desktop_name} -> {entry['default']}")
                else:
                    needs_relogin.append(entry)
                    print(f"[global-shortcuts] DBus 注册(组件未激活): {desktop_name} -> {entry['default']}")
            if needs_relogin:
                print("[global-shortcuts] 以下快捷键已写入配置，但需注销并重新登录后物理按键才会生效:")
                for entry in needs_relogin:
                    print(f"[global-shortcuts]   {entry['default']} -> {entry['id']}")
            return
        except ImportError:
            print("[global-shortcuts] 未安装 python3-dbus，跳过实时注册（重启守护进程后由配置生效）")
            return
        except Exception as e:
            if attempt == 4:
                print(f"[global-shortcuts] DBus 注册失败: {e}")
            else:
                time.sleep(1)


def running_instance_exes():
    """Realpaths of the quickshell binaries currently running this config.

    The desktop files written here must launch a `qs` whose IPC protocol
    matches the live instance: a mismatched CLI (e.g. the Fedora 0.2.1
    package against a self-built 0.3.1 shell) makes every shortcut die
    with "No running instances". The live process is the only reliable
    source of truth — PATH order is not.
    """
    exes = set()
    try:
        pids = os.listdir("/proc")
    except OSError:
        return exes
    for pid in pids:
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = [a.decode("utf-8", "replace")
                        for a in f.read().split(b"\0") if a]
            # Skip short-lived `qs ... ipc call` clients, keep the shell.
            if "ipc" in args:
                continue
            if not any(a == CONFIG_DIR or a.startswith(CONFIG_DIR + os.sep)
                       for a in args):
                continue
            exe = os.path.realpath(f"/proc/{pid}/exe")
        except OSError:
            continue
        if os.path.basename(exe).lower() in ("quickshell", "qs"):
            exes.add(exe)
    return exes


def autostart_exes():
    """Realpaths of quickshell binaries referenced by session autostart.

    Fallback source of truth when no instance is running yet: the session
    will later start the shell from this entry, so the qs written into the
    desktop files should match it.
    """
    base = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    exes = set()
    try:
        names = os.listdir(os.path.join(base, "autostart"))
    except OSError:
        return exes
    for name in names:
        if not name.endswith(".desktop"):
            continue
        try:
            with open(os.path.join(base, "autostart", name), encoding="utf-8") as f:
                for line in f:
                    if not line.startswith("Exec="):
                        continue
                    exe = line[len("Exec="):].strip().split(None, 1)[0]
                    if os.path.basename(exe).lower() in ("quickshell", "qs"):
                        exes.add(os.path.realpath(exe))
                    break
        except (OSError, IndexError):
            continue
    return exes


def resolve_qs_bin():
    """Pick the `qs` binary for Exec lines, immune to PATH pollution.

    Preference: a qs candidate whose realpath equals the binary the
    session actually runs (user-local path first, then PATH order, then
    the binary's own directory); the running binary itself; the
    user-local default; finally shutil.which. Divergent candidates are
    reported so a shadowing package can never win silently again.
    """
    truth = running_instance_exes() or autostart_exes()
    if not truth:
        print("[global-shortcuts] 未发现运行中的 quickshell 实例，按固定优先级选择 qs")

    candidates = []
    seen = set()

    def add(cand):
        if cand and os.path.isfile(cand):
            rp = os.path.realpath(cand)
            if rp not in seen:
                seen.add(rp)
                candidates.append((cand, rp))

    add(os.path.expanduser("~/.local/bin/qs"))
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        add(os.path.join(entry, "qs") if entry else None)
    for exe in sorted(truth):
        add(os.path.join(os.path.dirname(exe), "qs"))
    add("/usr/local/bin/qs")

    def warn_divergent():
        for cand, rp in candidates:
            if rp not in truth:
                print(f"[global-shortcuts] 警告: 忽略与运行实例不一致的 qs: {cand} -> {rp}")

    if truth:
        for cand, rp in candidates:
            if rp in truth:
                warn_divergent()
                return cand, f"与运行实例二进制一致: {rp}"
        for exe in sorted(truth):
            if os.path.isfile(exe) and os.access(exe, os.X_OK):
                warn_divergent()
                return exe, "运行实例二进制（未找到指向它的 qs 链接）"
        print(f"[global-shortcuts] 警告: 运行实例二进制 {sorted(truth)} 不可用")

    local = os.path.expanduser("~/.local/bin/qs")
    if os.path.isfile(local):
        return local, "默认用户路径"
    found = shutil.which("qs")
    if found:
        return found, "PATH 解析"
    raise SystemExit("[global-shortcuts] 错误: 找不到 qs 可执行文件，无法写入快捷键")


def main():
    table = load_table()
    os.makedirs(APPS_DIR, exist_ok=True)
    # Release the default-column claims (klipper's Meta+V, powerdevil's
    # Meta+B, KWin's Meta+Tab) before reading bindings, so the conflict
    # check below only trips on shortcuts the user assigned deliberately.
    for entry in table["shortcuts"]:
        clear_default_claims(entry["default"])
    bindings = existing_launch_bindings()
    registered_shortcuts = []
    qs_bin, qs_reason = resolve_qs_bin()
    print(f"[global-shortcuts] qs 二进制: {qs_bin}（{qs_reason}）")
    for entry in table["shortcuts"]:
        shortcut_id = entry["id"]
        command = table["command"].format(qs=qs_bin,
                                          config=CONFIG_DIR,
                                          target=entry["target"],
                                          action=entry["action"])
        desktop_path = os.path.join(APPS_DIR, shortcut_id + ".desktop")

        # Conflict detection: a combo already claimed by any section is refused
        # unless it is this exact shortcut re-binding its own default.
        conflict = [sec for sec in bindings.get(entry["default"], [])
                    if sec != shortcut_id + ".desktop"]
        if conflict:
            print(f"[global-shortcuts] 冲突: {entry['default']} 已被 "
                  f"{', '.join(conflict)} 占用，跳过 {shortcut_id}")
            continue

        with open(desktop_path, "w", encoding="utf-8") as f:
            f.write(
                "[Desktop Entry]\n"
                f"Exec={command}\n"
                f"Name={entry['description']}\n"
                "NoDisplay=true\n"
                "StartupNotify=false\n"
                "Type=Application\n"
                "X-KDE-GlobalAccel-CommandShortcut=true\n"
            )
        print(f"[global-shortcuts] 写入 {desktop_path}")

        rewrite_shortcut_rc(shortcut_id, entry["default"])
        print(f"[global-shortcuts] 绑定 {entry['default']} -> {shortcut_id}")
        registered_shortcuts.append(entry)

    # Register bindings directly via DBus in the live compositor.
    register_via_dbus(registered_shortcuts)

    # kglobalaccel may rewrite kglobalshortcutsrc while servicing the DBus
    # registrations above, restoring default-column claims. Clear them again
    # after registration so other components cannot steal these combos when
    # they re-register.
    for entry in registered_shortcuts:
        clear_default_claims(entry["default"])

    print("[global-shortcuts] 完成；kglobalaccel 已重载")


if __name__ == "__main__":
    main()
