# CoolUI

**Native HaxeFlixel UI library** — drop-in replacement for `flixel-ui`.

No XML. No event bus. No `getEvent()`. Pure `FlxSpriteGroup` widgets with direct callbacks, fully integrated with any HaxeFlixel project.

Built for [FNF: Cool Engine](https://github.com/The-Cool-Engine-Crew/FNF-Cool-Engine) but usable in any HaxeFlixel project.

---

## Why not flixel-ui?

`flixel-ui` has several well-known issues:
- Requires an XML layout system to initialize widgets
- Uses a global event bus (`getEvent()`) instead of direct callbacks
- Has camera and scroll factor bugs with non-default cameras
- No theming support — every widget looks the same
- `FlxUITabMenu` requires `@:access` hacks to customize
- Build issues on newer Haxe/HXCPP versions

CoolUI fixes all of that.

## Why not HaxeUI?

HaxeUI is a full framework with its own lifecycle, XML layout engine, and rendering pipeline. Integrating it into an existing HaxeFlixel project means rewriting all your UIs from scratch. CoolUI is a **drop-in replacement** — the migration is search-and-replace in imports.

---

## Installation

```bash
haxelib git coolui https://github.com/The-Cool-Engine-Crew/coolui
```

Or in your `project.hxp` / `Project.xml`:
```haxe
haxelibs.push(new Haxelib("coolui", ""));
```

---

## Widget reference

| Widget | Replaces (flixel-ui) | Description |
|---|---|---|
| `CoolUIState` | `FlxUIState` | Base state, extends `FlxState` |
| `CoolUIGroup` | `FlxUIGroup` | Tab content container |
| `CoolTabMenu` | `FlxUITabMenu` | Tabbed panel with visual theme |
| `CoolInputText` | `FlxUIInputText`, `FlxInputText` | Text input with OpenFL overlay |
| `CoolNumericStepper` | `FlxUINumericStepper` | Number input with ▲▼ buttons |
| `CoolCheckBox` | `FlxUICheckBox` | Checkbox with animated tick |
| `CoolDropDown` | `FlxUIDropDownMenu` | Dropdown selector |
| `CoolButton` | `FlxUIButton`, `FlxButtonPlus` | Clickable button (4 styles) |
| `Cool9Slice` | `FlxUI9SliceSprite` | 9-slice scaled bitmap |
| `CoolTooltip` | `FlxUITooltip` | Floating tooltip (singleton) |
| `CoolUIList` | `FlxUIList` | Scrollable list |

---

## Quick start

```haxe
import coolui.*;

class MyState extends CoolUIState
{
    override public function create():Void
    {
        super.create();

        // Tab menu
        var menu = new CoolTabMenu(null, [
            {name: "general", label: "General"},
            {name: "audio",   label: "Audio"},
        ], true);
        menu.resize(250, 400);
        add(menu);

        // Tab content
        var tab = new CoolUIGroup();
        tab.name = "general";

        var inp = new CoolInputText(10, 10, 200, "hello");
        inp.callback = function(text, action) trace(text);
        tab.add(inp);

        var stepper = new CoolNumericStepper(10, 40, 1, 5, 0, 100);
        stepper.value_change = function(v) trace(v);
        tab.add(stepper);

        var check = new CoolCheckBox(10, 70, null, null, "Enable feature", 140);
        check.callback = function(v) trace(v);
        tab.add(check);

        menu.addGroup(tab);
        menu.selected_tab_id = "general";
    }
}
```

---

## Theming

CoolUI ships with a **dark theme** by default and two built-in presets. You can also connect it to your own theming system:

```haxe
// Built-in presets
CoolUITheme.applyDark();
CoolUITheme.applyNeon();
CoolUITheme.applyLight();

// Custom theme
CoolUITheme.set({
    bgDark:        0xFF0B0B16,
    bgPanel:       0xFF13131F,
    bgPanelAlt:    0xFF1B1B2B,
    bgHover:       0xFF242438,
    borderColor:   0xFF3A3A5C,
    accent:        0xFF00E5FF,
    accentAlt:     0xFFFF6FD8,
    textPrimary:   0xFFE8E8FF,
    textSecondary: 0xFFAAA8CC,
    rowSelected:   0xFF1E2B3C,
    rowEven:       0xFF16162A,
    rowOdd:        0xFF111124,
    error:         0xFFFF4444,
});

// Sync from an external engine theme (e.g. EditorTheme)
CoolUITheme.syncFromDynamic(EditorTheme.current);

// React to theme changes
CoolUITheme.onChange = function() { myTabMenu.refresh(); };
```

---

## CoolButton styles

```haxe
new CoolButton(x, y, "Normal",  cb, 100, 24, CoolButton.STYLE_DEFAULT);
new CoolButton(x, y, "Accent",  cb, 100, 24, CoolButton.STYLE_ACCENT);
new CoolButton(x, y, "Danger",  cb, 100, 24, CoolButton.STYLE_DANGER);
new CoolButton(x, y, "Ghost",   cb, 100, 24, CoolButton.STYLE_GHOST);
```

---

## CoolInputText

Unlike `FlxUIInputText`, the callback is always direct — no parent state bus:

```haxe
var inp = new CoolInputText(x, y, 200, "initial text");

// Filters
inp.filterMode = CoolInputText.ONLY_NUMERIC;
inp.filterMode = CoolInputText.ONLY_ALPHA;
inp.filterMode = CoolInputText.CUSTOM_FILTER;
inp.customFilterPattern = "a-zA-Z0-9_\\-";

inp.maxLength    = 32;
inp.passwordMode = true;

inp.callback      = function(text, action) { ... }; // action: "change", "enter"
inp.onFocusGained = function() { ... };
inp.onFocusLost   = function() { ... };
```

---

## CoolDropDown

```haxe
// From string array
var items = CoolDropDown.makeStrIdLabelArray(["Option A", "Option B", "Option C"]);
var dd = new CoolDropDown(x, y, items, function(id) { trace(id); });

// Read selected
trace(dd.selectedLabel);  // "Option A"
trace(dd.selectedId);     // "Option A" (or index if useIndexAsId=true)
```

---

## Migration from flixel-ui

See [MIGRATION.md](MIGRATION.md) for the complete field-by-field guide.

**TL;DR:**
1. Remove `flixel-ui` from your dependencies
2. Add `coolui` 
3. Replace `import flixel.addons.ui.*` with `import coolui.*`
4. Replace type names (see table above)
5. Replace `getEvent()` overrides with direct `.callback` assignments
6. Replace `new FlxUI(null, tabMenu)` with `new CoolUIGroup()` + set `.name`

---

## License

MIT — see [LICENSE](LICENSE)
