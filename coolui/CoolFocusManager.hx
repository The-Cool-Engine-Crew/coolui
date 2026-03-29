package coolui;

import flixel.FlxG;

/**
 * CoolFocusManager — Keyboard Tab cycling between `CoolInputText` fields.
 *
 * Usage:
 *   CoolFocusManager.register(nameField);
 *   CoolFocusManager.register(emailField);
 *   CoolFocusManager.register(ageField);
 *   // Press Tab to move forward, Shift+Tab to move backward.
 *   // Call CoolFocusManager.update() once per frame (e.g. in your state).
 *
 * Fields are cycled in registration order. Destroyed fields are removed
 * automatically on the next Tab press.
 */
class CoolFocusManager {
	static var _fields:Array<CoolInputText> = [];
	static var _active:Int = -1;

	/** Add a field to the focus cycle. */
	public static function register(field:CoolInputText):Void {
		if (field != null && !_fields.contains(field))
			_fields.push(field);
	}

	/** Remove a field from the cycle (called automatically when destroyed). */
	public static function unregister(field:CoolInputText):Void {
		var idx = _fields.indexOf(field);
		if (idx < 0) return;
		_fields.splice(idx, 1);
		if (_active >= _fields.length) _active = _fields.length - 1;
	}

	/** Clear all registered fields. */
	public static function clear():Void {
		_fields = [];
		_active = -1;
	}

	/**
	 * Call once per frame from your state's `update()`.
	 * Handles Tab / Shift+Tab focus movement.
	 */
	public static function update():Void {
		if (_fields.length == 0) return;

		// Prune destroyed fields
		_fields = _fields.filter(f -> f != null && f.alive && f.exists);

		if (!FlxG.keys.justPressed.TAB) return;
		// Tab only fires when keys are enabled (i.e. no field has text focus).
		// When a CoolInputText is focused it disables FlxG.keys — but we still
		// want Tab to work. We fire the tab via CoolInputText's own key listener
		// indirectly: if any field is focused, transfer now.
		_pruneAndFocus(FlxG.keys.pressed.SHIFT ? -1 : 1);
	}

	static function _pruneAndFocus(dir:Int):Void {
		if (_fields.length == 0) return;

		// Find currently focused field
		var cur = -1;
		for (i in 0..._fields.length) {
			if (_fields[i].hasFocus) { cur = i; break; }
		}

		var next = (cur < 0) ? 0 : Std.int((_fields.length + cur + dir) % _fields.length);
		if (cur >= 0) _fields[cur].hasFocus = false;
		_fields[next].hasFocus = true;
		_active = next;
	}

	/**
	 * Programmatically focus a registered field by index.
	 * Blurs the previously focused field.
	 */
	public static function focusIndex(idx:Int):Void {
		if (idx < 0 || idx >= _fields.length) return;
		for (i in 0..._fields.length) _fields[i].hasFocus = (i == idx);
		_active = idx;
	}

	/** Returns the index of the currently focused field, or -1 if none. */
	public static function activeFocusIndex():Int {
		for (i in 0..._fields.length) if (_fields[i].hasFocus) return i;
		return -1;
	}
}
