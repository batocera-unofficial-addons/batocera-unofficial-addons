#!/usr/bin/env python3
"""Build app/apps_x86.json and app/apps_arm64.json from the menu app's tables.

The menu files stay the source of truth. This script never imports them (that
would start pygame); it parses each file, picks out the top-level statements
that build CHANGELOG, BUA_BASE_URL, bua(), CUSTOM_UNINSTALL, APPS,
DESCRIPTIONS, CATEGORIES and get_uninstall_command(), and runs only those.
The tables can be moved around or extended with more .update({...}) blocks
or TABLE["name"] = ... lines; renaming them or building them inside a function or loop is not supported.
"""
import ast
import json
import re
import sys
import typing
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

MENUS = {
    "app/bua_installerx86.py": "app/apps_x86.json",
    "app/bua_installerarm64.py": "app/apps_arm64.json",
}

TABLES = {"APPS", "DESCRIPTIONS", "CATEGORIES", "CUSTOM_UNINSTALL"}
CONSTANTS = {"CHANGELOG", "BUA_BASE_URL"}
FUNCTIONS = {"bua", "get_uninstall_command"}


def assigned_names(node: ast.stmt) -> set[str]:
    if isinstance(node, ast.Assign):
        return {t.id for t in node.targets if isinstance(t, ast.Name)}
    if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
        return {node.target.id}
    return set()


def is_table_call(node: ast.stmt) -> bool:
    """APPS.update({...}) and similar calls on a table at the top level."""
    if not (isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)):
        return False
    func = node.value.func
    return (
        isinstance(func, ast.Attribute)
        and isinstance(func.value, ast.Name)
        and func.value.id in TABLES
    )


def is_table_item(node: ast.stmt) -> bool:
    """APPS["Name"] = ... at the top level."""
    return isinstance(node, ast.Assign) and any(
        isinstance(t, ast.Subscript) and isinstance(t.value, ast.Name) and t.value.id in TABLES
        for t in node.targets
    )


def wanted(node: ast.stmt) -> bool:
    if assigned_names(node) & (TABLES | CONSTANTS) or is_table_item(node):
        return True
    if isinstance(node, ast.FunctionDef) and node.name in FUNCTIONS:
        return True
    return is_table_call(node)


def limited_import(name, *args, **kwargs):
    # get_uninstall_command() does "import re"; nothing else may be imported.
    if name == "re":
        return re
    raise ImportError(f"import of {name!r} is not allowed here")


def load_tables(menu: Path) -> dict:
    tree = ast.parse(menu.read_text(encoding="utf-8"), filename=str(menu))
    body = [node for node in tree.body if wanted(node)]
    module = ast.Module(body=body, type_ignores=[])
    namespace = {
        # str is needed for the type hints in the function definitions.
        "__builtins__": {"__import__": limited_import, "str": str},
        "Dict": typing.Dict,
        "List": typing.List,
        "Tuple": typing.Tuple,
        "CUSTOM_UNINSTALL": {},
    }
    exec(compile(module, str(menu), "exec"), namespace)
    return namespace


def uninstall_command(get_cmd, install_cmd: str, name: str):
    # The x86 menu takes (install_cmd, app_name), the ARM menu only install_cmd.
    if get_cmd.__code__.co_argcount >= 2:
        return get_cmd(install_cmd, name)
    return get_cmd(install_cmd)


def build(menu_rel: str) -> tuple[dict, list[str], list[str]]:
    """Return the JSON data plus lists of errors and warnings."""
    errors: list[str] = []
    warnings: list[str] = []
    try:
        ns = load_tables(REPO_ROOT / menu_rel)
    except Exception as e:
        return {}, [f"{menu_rel}: could not evaluate the app tables: {e}"], []

    for key in ("APPS", "DESCRIPTIONS", "CATEGORIES", "get_uninstall_command"):
        if key not in ns:
            errors.append(f"{menu_rel}: {key} not found at the top level")
    if errors:
        return {}, errors, warnings

    apps = ns["APPS"]
    descriptions = ns["DESCRIPTIONS"]
    categories = ns["CATEGORIES"]
    get_cmd = ns["get_uninstall_command"]

    if not apps:
        errors.append(f"{menu_rel}: APPS is empty")
    for name, cmd in apps.items():
        if not isinstance(name, str) or not isinstance(cmd, str):
            errors.append(f"{menu_rel}: APPS entry {name!r} is not a string pair")
    for cat, names in categories.items():
        for name in names:
            if name not in apps:
                warnings.append(f"{menu_rel}: \"{name}\" is in category \"{cat}\" but not in APPS")
    for name in descriptions:
        if name not in apps:
            warnings.append(f"{menu_rel}: \"{name}\" has a description but is not in APPS")
    if errors:
        return {}, errors, warnings

    entries = []
    for name in sorted(apps, key=str.lower):
        cats = [cat for cat, names in categories.items() if name in names]
        if name not in descriptions:
            warnings.append(f"{menu_rel}: \"{name}\" has no description")
        if not cats:
            warnings.append(f"{menu_rel}: \"{name}\" is not in any category")
        try:
            uninstall = uninstall_command(get_cmd, apps[name], name)
        except Exception as e:
            errors.append(f"{menu_rel}: get_uninstall_command failed for \"{name}\": {e}")
            continue
        entries.append({
            "name": name,
            "description": descriptions.get(name, ""),
            "categories": cats,
            "install": apps[name],
            "uninstall": uninstall,
        })

    data = {
        "generated_from": menu_rel,
        "changelog": ns.get("CHANGELOG", ""),
        "apps": entries,
    }
    return data, errors, warnings


def main() -> int:
    failed = False
    for menu_rel, out_rel in MENUS.items():
        data, errors, warnings = build(menu_rel)
        # ::warning:: and ::error:: lines show up as annotations on GitHub
        for w in warnings:
            print(f"::warning::{w}")
        for e in errors:
            print(f"::error::{e}")
        if errors:
            failed = True
            continue
        out = REPO_ROOT / out_rel
        out.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Wrote {out_rel} ({len(data['apps'])} apps)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
