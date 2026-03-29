package coolui;

import coolui.CoolTheme;

/**
 * CoolUITheme — Standalone theming system for the CoolUI library.
 *
 * CHANGE: `onChange` is now a multi-listener system. Widgets subscribe
 * via `addListener` / `removeListener`. The old single-slot `onChange`
 * field is kept for backwards compatibility and fires together with the
 * listener array.
 *
 * Example:
 *   CoolUITheme.addListener(function() trace("theme changed"));
 *   CoolUITheme.set(CoolUITheme.neon());
 */
class CoolUITheme {
	// ── Active theme ──────────────────────────────────────────────────────────
	public static var current(get, never):CoolTheme;

	static var _current:CoolTheme = _defaultDark();

	static function get_current():CoolTheme
		return _current;

	// ── Multi-listener system ─────────────────────────────────────────────────
	/** @deprecated Use addListener() instead. */
	public static var onChange:Void->Void;

	static var _listeners:Array<Void->Void> = [];

	/** Register a callback to fire whenever the theme changes. */
	public static function addListener(fn:Void->Void):Void {
		if (fn != null && !_listeners.contains(fn))
			_listeners.push(fn);
	}

	/** Unregister a previously registered callback. */
	public static function removeListener(fn:Void->Void):Void {
		_listeners.remove(fn);
	}

	// ── Public API ──────────────────────────────────────────────────────────

	/** Applies a new theme and notifies all listeners. */
	public static function set(theme:CoolTheme):Void {
		_current = theme;
		if (onChange != null) onChange();
		for (fn in _listeners) fn();
	}

	/** Syncs from a Dynamic object (e.g. the engine's EditorTheme.current). */
	public static function syncFromDynamic(t:Dynamic):Void {
		set({
			bgDark:        _int(t, "bgDark",        0xFF0B0B16),
			bgPanel:       _int(t, "bgPanel",       0xFF13131F),
			bgPanelAlt:    _int(t, "bgPanelAlt",    0xFF1B1B2B),
			bgHover:       _int(t, "bgHover",       0xFF242438),
			borderColor:   _int(t, "borderColor",   0xFF3A3A5C),
			accent:        _int(t, "accent",        0xFF00E5FF),
			accentAlt:     _int(t, "accentAlt",     0xFFFF6FD8),
			textPrimary:   _int(t, "textPrimary",   0xFFE8E8FF),
			textSecondary: _int(t, "textSecondary", 0xFFAAA8CC),
			rowSelected:   _int(t, "rowSelected",   0xFF1E2B3C),
			rowEven:       _int(t, "rowEven",       0xFF16162A),
			rowOdd:        _int(t, "rowOdd",        0xFF111124),
			error:         _int(t, "error",         0xFFFF4444),
		});
	}

	// ── Built-in presets ──────────────────────────────────────────────────────
	public static function applyDark():Void  set(_defaultDark());
	public static function applyNeon():Void  set(_neon());
	public static function applyLight():Void set(_light());

	// ── Private helpers ───────────────────────────────────────────────────────
	static function _int(t:Dynamic, field:String, fallback:Int):Int {
		try {
			var v = Reflect.field(t, field);
			if (v == null)              return fallback;
			if (Std.isOfType(v, Int))   return cast v;
			if (Std.isOfType(v, Float)) return Std.int(cast v);
		} catch (_:Dynamic) {}
		return fallback;
	}

	static function _defaultDark():CoolTheme return {
		bgDark: 0xFF0B0B16, bgPanel: 0xFF13131F, bgPanelAlt: 0xFF1B1B2B,
		bgHover: 0xFF242438, borderColor: 0xFF3A3A5C, accent: 0xFF00E5FF,
		accentAlt: 0xFFFF6FD8, textPrimary: 0xFFE8E8FF, textSecondary: 0xFFAAA8CC,
		rowSelected: 0xFF1E2B3C, rowEven: 0xFF16162A, rowOdd: 0xFF111124,
		error: 0xFFFF4444,
	};

	static function _neon():CoolTheme return {
		bgDark: 0xFF060612, bgPanel: 0xFF0E0E22, bgPanelAlt: 0xFF14142E,
		bgHover: 0xFF1C1C3C, borderColor: 0xFF4400FF, accent: 0xFF00FF88,
		accentAlt: 0xFFFF00AA, textPrimary: 0xFFEEFFEE, textSecondary: 0xFF88FFCC,
		rowSelected: 0xFF001A22, rowEven: 0xFF0A0A1E, rowOdd: 0xFF080816,
		error: 0xFFFF0055,
	};

	static function _light():CoolTheme return {
		bgDark: 0xFFD8D8E8, bgPanel: 0xFFEAEAF4, bgPanelAlt: 0xFFF2F2FF,
		bgHover: 0xFFDDDDEE, borderColor: 0xFFAAAAAA, accent: 0xFF0055CC,
		accentAlt: 0xFF8800CC, textPrimary: 0xFF111122, textSecondary: 0xFF444466,
		rowSelected: 0xFFCCDDFF, rowEven: 0xFFE8E8F8, rowOdd: 0xFFEEEEFF,
		error: 0xFFCC2222,
	};
}
