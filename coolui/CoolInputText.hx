package coolui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import openfl.events.Event;
import openfl.events.FocusEvent;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import openfl.text.Font;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.geom.Point;

@:font("assets/vcr.ttf")
private class _VCRFont extends Font {}

/**
 * CoolInputText — Editable text input field, no flixel-ui required.
 *
 * Z-ORDER FIX: The native OpenFL TextField is only added to the display list
 * while the field has focus (i.e. the user is actively typing). At all other
 * times the field is rendered entirely through normal Flixel sprites
 * (_bgSprite + _displayText), so it sits at whatever z-order the caller
 * chooses via add() — exactly like any other FlxSpriteGroup.
 *
 * CAMERA FIX: No private camera is created. The group inherits whatever
 * camera the parent state/group assigns, and screen-position syncing for the
 * native overlay uses that same camera.
 *
 * CLIPBOARD: Ctrl+C / Ctrl+X / Ctrl+V / Ctrl+A are handled natively by
 * OpenFL's INPUT TextField — no extra code needed.
 *
 * Compatible constructors:
 *   new CoolInputText(x, y, width, text, fontSize)
 *   new CoolInputText(x, y, width, text, fontSize, textColor, bgColor)
 */
class CoolInputText extends FlxSpriteGroup {
	// ── Filters ───────────────────────────────────────────────────────────────
	public static inline var NO_FILTER:Int         = 0;
	public static inline var ONLY_ALPHA:Int        = 1;
	public static inline var ONLY_NUMERIC:Int      = 2;
	public static inline var ONLY_ALPHANUMERIC:Int = 3;
	public static inline var CUSTOM_FILTER:Int     = 4;

	// ── Callbacks ─────────────────────────────────────────────────────────────
	public var callback:String->String->Void;
	public var onFocusGained:Void->Void;
	public var onFocusLost:Void->Void;
	public var onEnterPressed:Void->Void;
	public var onEscapePressed:Void->Void;

	public var focusGained(get, set):Void->Void;
	public var focusLost(get, set):Void->Void;
	function get_focusGained() return onFocusGained;
	function set_focusGained(v) { onFocusGained = v; return v; }
	function get_focusLost()    return onFocusLost;
	function set_focusLost(v)   { onFocusLost = v; return v; }

	// ── Public properties ─────────────────────────────────────────────────────
	public var text(get, set):String;
	public var hasFocus(get, set):Bool;
	public var maxLength(get, set):Int;
	public var passwordMode(get, set):Bool;
	public var filterMode:Int = NO_FILTER;
	public var customFilterPattern:String = "";
	public var lines(get, set):Int;
	public var backgroundColor(get, set):Int;
	public var fieldBorderColor(get, set):Int;
	/** OpenFL TextField supports only 1px borders; stored for API compat. */
	public var fieldBorderThickness(default, set):Int = 1;

	// ── Internals ─────────────────────────────────────────────────────────────
	// Native OpenFL TextField — only lives in the display list while focused.
	var _field:TextField;
	static var _fontRegistered:Bool = false;
	var _fmt:TextFormat;
	var _w:Int;
	var _h:Int;
	var _fontSize:Int;
	var _lines:Int = 1;
	var _bgColor:Int;
	var _brdColor:Int;
	var _textColor:Int;
	var _onStage:Bool = false;

	// Flixel sprites — always present, respect z-order like any FlxSprite.
	var _bgSprite:FlxSprite;
	var _displayText:FlxText;

	// ── Constructor ───────────────────────────────────────────────────────────
	public function new(px:Float = 0, py:Float = 0, width:Int = 150, text:String = "",
	                    fontSize:Int = 8, ?textColor:Int, ?bgColor:Int) {
		super(px, py);
		_w         = (width    > 0) ? width    : 150;
		_fontSize  = (fontSize > 0) ? fontSize : 8;
		_h         = _fontSize + 8;
		_textColor = (textColor != null) ? textColor : coolui.CoolUITheme.current.textPrimary;
		_bgColor   = (bgColor   != null) ? bgColor   : coolui.CoolUITheme.current.bgPanelAlt;
		_brdColor  = coolui.CoolUITheme.current.borderColor;

		if (!_fontRegistered) { Font.registerFont(_VCRFont); _fontRegistered = true; }

		_fmt = new TextFormat("VCR OSD Mono", Std.int(_fontSize * 1.5), _textColor);

		// ── Native TextField (overlay, only when focused) ──────────────────
		_field = new TextField();
		_field.type              = TextFieldType.INPUT;
		_field.defaultTextFormat = _fmt;
		_field.background        = true;
		_field.backgroundColor   = _bgColor;
		_field.border            = true;
		_field.borderColor       = _brdColor;
		_field.width             = _w;
		_field.height            = _h;
		_field.text              = text;
		_field.selectable        = true;

		_field.addEventListener(Event.CHANGE,          _onChange);
		_field.addEventListener(FocusEvent.FOCUS_IN,   _onFocusIn);
		_field.addEventListener(FocusEvent.FOCUS_OUT,  _onFocusOut);
		_field.addEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);

		// ── Flixel visual representation (always visible, z-order correct) ─
		// IMPORTANT: Children must be initialised at (0, 0), NOT at (x, y).
		// FlxSpriteGroup.onAdd() in Flixel 5.x automatically offsets every newly
		// added child by the group's current (x, y). Initialising at (x, y) causes
		// a double-offset → children end up at (2*x, 2*y), creating a visible
		// "phantom" duplicate rendered far below/right of where the field should be.
		_bgSprite = new FlxSprite(0, 0);
		_rebuildBg();
		add(_bgSprite);

		_displayText = new FlxText(2, Std.int((_h - _fontSize) * 0.5), _w - 4, text, _fontSize);
		_displayText.color = FlxColor.fromInt(_textColor);
		add(_displayText);

		// This is a UI overlay widget — it must not scroll with the game camera.
		// Setting scrollFactor here also propagates to _bgSprite and _displayText
		// via FlxSpriteGroup's set_scrollFactor override, so the native TextField
		// position (computed in _syncFieldPosition via getScreenPosition) will
		// match the visual position even when the game camera is scrolled/zoomed.
		scrollFactor.set(0, 0);
	}

	// ── Getters / Setters ─────────────────────────────────────────────────────
	function get_text()  return (_field != null) ? _field.text : "";
	function set_text(v:String):String {
		var filtered = _applyFilter(v);
		if (_field != null)        _field.text = filtered;
		if (_displayText != null)  _displayText.text = _passwordMask(filtered);
		return v;
	}

	function get_hasFocus():Bool
		return _onStage && FlxG.stage != null && FlxG.stage.focus == _field;

	function set_hasFocus(v:Bool):Bool {
		if (FlxG.stage == null) return v;
		if (v) {
			_mountAndFocus();
		} else {
			if (FlxG.stage.focus == _field) FlxG.stage.focus = null;
		}
		return v;
	}

	function get_maxLength()     return (_field != null) ? _field.maxChars : 0;
	function set_maxLength(v:Int):Int { if (_field != null) _field.maxChars = v; return v; }

	function get_passwordMode()  return (_field != null) ? _field.displayAsPassword : false;
	function set_passwordMode(v:Bool):Bool {
		if (_field != null) _field.displayAsPassword = v;
		// Refresh display text mask when not focused
		if (_displayText != null) _displayText.text = _passwordMask(_field != null ? _field.text : "");
		return v;
	}

	function get_lines()         return _lines;
	function set_lines(v:Int):Int {
		_lines = (v > 0) ? v : 1;
		_h     = _lines * (_fontSize + 4) + 4;
		if (_field != null) {
			_field.height    = _h;
			_field.multiline = _lines > 1;
			_field.wordWrap  = _lines > 1;
		}
		if (_bgSprite != null)    _rebuildBg();
		return _lines;
	}

	function get_backgroundColor()  return _bgColor;
	function set_backgroundColor(v:Int):Int {
		_bgColor = v;
		if (_field != null)    { _field.background = true; _field.backgroundColor = v; }
		if (_bgSprite != null) _rebuildBg();
		return v;
	}

	function get_fieldBorderColor() return _brdColor;
	function set_fieldBorderColor(v:Int):Int {
		_brdColor = v;
		if (_field != null)    { _field.border = true; _field.borderColor = v; }
		if (_bgSprite != null) _rebuildBg();
		return v;
	}
	function set_fieldBorderThickness(v:Int):Int { fieldBorderThickness = v; return v; }

	// ── Resize ────────────────────────────────────────────────────────────────
	public function resize(w:Int, h:Int = -1):Void {
		if (w > 0) _w = w;
		if (h > 0) _h = h;
		if (_field != null) { _field.width = _w; _field.height = _h; }
		if (_bgSprite != null) _rebuildBg();
		if (_displayText != null) {
			_displayText.fieldWidth = _w - 4;
			_displayText.y = y + Std.int((_h - _fontSize) * 0.5);
		}
	}

	// ── Background sprite builder ─────────────────────────────────────────────
	function _rebuildBg():Void {
		_bgSprite.makeGraphic(_w, _h, FlxColor.TRANSPARENT);
		var p    = _bgSprite.pixels;
		var bgC  = FlxColor.fromInt(_bgColor);
		var brdC = FlxColor.fromInt(_brdColor);
		for (py in 0..._h) {
			for (px in 0..._w) {
				if (px == 0 || px == _w - 1 || py == 0 || py == _h - 1)
					p.setPixel32(px, py, brdC);
				else
					p.setPixel32(px, py, bgC);
			}
		}
		_bgSprite.pixels = p;
	}

	// ── Native TextField mount/unmount ────────────────────────────────────────
	/**
	 * Adds the native TextField to FlxG.stage (NOT FlxG.game), syncs its
	 * screen position, and gives it keyboard focus.
	 *
	 * FIX: Adding to FlxG.game could prevent keyboard-focus routing on some
	 * targets (HashLink, HTML5) because FlxGame's internal display objects may
	 * intercept events. Stage is always the correct root for native overlays.
	 */
	function _mountAndFocus():Void {
		if (_field == null || FlxG.game == null || FlxG.stage == null) return;
		if (!_onStage) {
			_syncFieldPosition();
			FlxG.stage.addChild(_field);
			_onStage = true;
		}
		FlxG.stage.focus = _field;
	}

	function _unmount():Void {
		if (!_onStage || _field == null) return;
		if (_field.parent != null) _field.parent.removeChild(_field);
		_onStage = false;
	}

	/** Syncs the native TextField's screen position to match our Flixel position. */
	function _syncFieldPosition():Void {
		if (_field == null) return;
		var sp = FlxPoint.get();
		getScreenPosition(sp, camera);
		// FIX: getScreenPosition returns coordinates in the game's viewport
		// space. The TextField is a child of FlxG.stage, which is in actual
		// display-pixel (stage) space. localToGlobal converts correctly even
		// when the game has a scale or letterbox offset applied.
		var pt = FlxG.game.localToGlobal(new Point(sp.x, sp.y));
		_field.x      = pt.x;
		_field.y      = pt.y;
		_field.width  = _w;
		_field.height = _h;
		sp.put();
	}

	// ── Events ────────────────────────────────────────────────────────────────
	function _onChange(_:Event):Void {
		var raw      = _field.text;
		var filtered = _applyFilter(raw);
		if (filtered != raw) {
			var caretPos = _field.caretIndex;
			var removed  = raw.length - filtered.length;
			_field.text  = filtered;
			_field.setSelection(
				Std.int(Math.max(0, caretPos - removed)),
				Std.int(Math.max(0, caretPos - removed)));
		}
		// Keep display text in sync even while native field is visible.
		if (_displayText != null) _displayText.text = _passwordMask(filtered);
		if (callback != null) callback(filtered, "change");
	}

	function _onFocusIn(_:FocusEvent):Void {
		FlxG.keys.enabled = false;
		// Hide Flixel sprites while the native TextField is the active overlay.
		if (_bgSprite    != null) _bgSprite.visible    = false;
		if (_displayText != null) _displayText.visible = false;
		if (onFocusGained != null) onFocusGained();
	}

	function _onFocusOut(_:FocusEvent):Void {
		FlxG.keys.enabled = true;
		// FIX: reset key state so Flixel doesn't replay keys held during input
		// capture (classic "double-Enter" bug).
		FlxG.keys.reset();
		// Sync display text, then unmount the overlay and restore Flixel sprites.
		if (_displayText != null) {
			_displayText.text    = _passwordMask(_field != null ? _field.text : "");
			_displayText.visible = visible && alive && exists;
		}
		if (_bgSprite != null) _bgSprite.visible = visible && alive && exists;
		_unmount();
		if (onFocusLost != null) onFocusLost();
	}

	function _onKeyDown(e:KeyboardEvent):Void {
		switch (e.keyCode) {
			case Keyboard.ENTER | Keyboard.NUMPAD_ENTER:
				if (callback != null) callback(_field.text, "enter");
				if (onEnterPressed != null) onEnterPressed();
			case Keyboard.ESCAPE:
				if (callback != null) callback(_field.text, "escape");
				if (onEscapePressed != null) onEscapePressed();
			default:
		}
	}

	// ── Filter / password helpers ─────────────────────────────────────────────
	function _applyFilter(t:String):String {
		return switch (filterMode) {
			case ONLY_ALPHA:        ~/[^a-zA-Z]/.replace(t, "");
			case ONLY_NUMERIC:
				var sign = t.charAt(0) == "-" ? "-" : "";
				var rest = sign.length > 0 ? t.substr(1) : t;
				rest = ~/[^0-9\.]/.replace(rest, "");
				var dotIdx = rest.indexOf(".");
				if (dotIdx >= 0)
					rest = rest.substr(0, dotIdx + 1) + ~/\./.replace(rest.substr(dotIdx + 1), "");
				sign + rest;
			case ONLY_ALPHANUMERIC: ~/[^a-zA-Z0-9]/.replace(t, "");
			case CUSTOM_FILTER:
				customFilterPattern != "" ? new EReg('[^${customFilterPattern}]', "g").replace(t, "") : t;
			default: t;
		};
	}

	/** Returns bullet placeholders when passwordMode is on, plain text otherwise. */
	inline function _passwordMask(t:String):String {
		return (_field != null && _field.displayAsPassword) ? [for (_ in 0...t.length) "●"].join("") : t;
	}

	// ── Update ────────────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		// Detect clicks inside the field area → mount native TextField and focus.
		if (FlxG.mouse.justPressed && visible && alive && exists) {
			var sp = FlxPoint.get();
			getScreenPosition(sp, camera);
			var mx      = FlxG.mouse.screenX;
			var my      = FlxG.mouse.screenY;
			var inField = mx >= sp.x && mx <= sp.x + _w && my >= sp.y && my <= sp.y + _h;
			sp.put();

			if (inField) {
				_mountAndFocus();
			} else if (_onStage && FlxG.stage != null && FlxG.stage.focus == _field) {
				// Clicked outside while we had focus → release focus (triggers _onFocusOut).
				FlxG.stage.focus = null;
			}
		}

		// While the native overlay is on stage, keep it in sync with our position.
		if (_onStage) {
			_syncFieldPosition();
			_field.visible = visible && alive && exists;
		}
	}

	// ── Visibility helpers ─────────────────────────────────────────────────────
	override function set_visible(v:Bool):Bool {
		// Native field visibility is managed separately when on stage.
		if (_onStage && _field != null) _field.visible = v;
		return super.set_visible(v);
	}
	override public function kill():Void {
		FlxG.keys.enabled = true;
		if (_onStage && _field != null) _field.visible = false;
		super.kill();
	}
	override public function revive():Void {
		if (_onStage && _field != null) _field.visible = true;
		super.revive();
	}
	override public function destroy():Void {
		FlxG.keys.enabled = true;
		_unmount();
		if (_field != null) {
			_field.removeEventListener(Event.CHANGE,          _onChange);
			_field.removeEventListener(FocusEvent.FOCUS_IN,   _onFocusIn);
			_field.removeEventListener(FocusEvent.FOCUS_OUT,  _onFocusOut);
			_field.removeEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);
			_field = null;
		}
		_bgSprite    = null;
		_displayText = null;
		callback = null; onFocusGained = null; onFocusLost = null;
		onEnterPressed = null; onEscapePressed = null;
		super.destroy();
	}
}
