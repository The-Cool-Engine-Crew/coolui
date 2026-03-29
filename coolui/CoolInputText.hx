package coolui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import openfl.desktop.Clipboard;
import openfl.desktop.ClipboardFormats;
import openfl.events.Event;
import openfl.events.FocusEvent;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import openfl.text.Font;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;

@:font("assets/vcr.ttf")
private class _VCRFont extends Font {}

/**
 * CoolInputText — Editable text input field, no flixel-ui required.
 *
 * CLIPBOARD: OpenFL's TextField (INPUT type) handles Ctrl+C / Ctrl+X /
 * Ctrl+V / Ctrl+A natively on all targets. No extra code is needed —
 * just focus the field and use standard shortcuts.
 *
 * FIX: `_bringToFront()` is only called on focus gain, not every frame,
 * so unfocused fields stay at their natural z-order.
 *
 * FIX: `FlxG.keys.reset()` on focus-out eliminates the double-Enter bug.
 *
 * NEW: `resize(w, h)` method to change dimensions after construction.
 *
 * Compatible constructors:
 *   new CoolInputText(x, y, width, text, fontSize)
 *   new CoolInputText(x, y, width, text, fontSize, textColor, bgColor)
 */
class CoolInputText extends FlxSpriteGroup {
	// ── Filters ──────────────────────────────────────────────────────────────
	public static inline var NO_FILTER:Int          = 0;
	public static inline var ONLY_ALPHA:Int         = 1;
	public static inline var ONLY_NUMERIC:Int       = 2;
	public static inline var ONLY_ALPHANUMERIC:Int  = 3;
	public static inline var CUSTOM_FILTER:Int      = 4;

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
	function set_focusLost(v)   { onFocusLost = v;   return v; }

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

		_field.addEventListener(Event.CHANGE,           _onChange);
		_field.addEventListener(FocusEvent.FOCUS_IN,    _onFocusIn);
		_field.addEventListener(FocusEvent.FOCUS_OUT,   _onFocusOut);
		_field.addEventListener(KeyboardEvent.KEY_DOWN,  _onKeyDown);
	}

	// ── Getters / Setters ─────────────────────────────────────────────────────
	function get_text()  return (_field != null) ? _field.text : "";
	function set_text(v:String):String {
		if (_field != null) _field.text = _applyFilter(v);
		return v;
	}

	function get_hasFocus():Bool
		return _onStage && FlxG.stage != null && FlxG.stage.focus == _field;
	function set_hasFocus(v:Bool):Bool {
		if (FlxG.stage == null) return v;
		if (v) { _mount(); FlxG.stage.focus = _field; }
		else if (FlxG.stage.focus == _field) FlxG.stage.focus = null;
		return v;
	}

	function get_maxLength()     return (_field != null) ? _field.maxChars : 0;
	function set_maxLength(v:Int):Int { if (_field != null) _field.maxChars = v; return v; }

	function get_passwordMode()  return (_field != null) ? _field.displayAsPassword : false;
	function set_passwordMode(v:Bool):Bool { if (_field != null) _field.displayAsPassword = v; return v; }

	function get_lines()         return _lines;
	function set_lines(v:Int):Int {
		_lines = (v > 0) ? v : 1;
		_h     = _lines * (_fontSize + 4) + 4;
		if (_field != null) {
			_field.height    = _h;
			_field.multiline = _lines > 1;
			_field.wordWrap  = _lines > 1;
		}
		return _lines;
	}

	function get_backgroundColor()  return _bgColor;
	function set_backgroundColor(v:Int):Int {
		_bgColor = v;
		if (_field != null) { _field.background = true; _field.backgroundColor = v; }
		return v;
	}

	function get_fieldBorderColor() return _brdColor;
	function set_fieldBorderColor(v:Int):Int {
		_brdColor = v;
		if (_field != null) { _field.border = true; _field.borderColor = v; }
		return v;
	}
	function set_fieldBorderThickness(v:Int):Int { fieldBorderThickness = v; return v; }

	// ── Resize ────────────────────────────────────────────────────────────────
	/**
	 * Change the field width (and optionally height) after construction.
	 * Height defaults to -1 which keeps the current auto-calculated height.
	 */
	public function resize(w:Int, h:Int = -1):Void {
		if (w > 0) _w = w;
		if (h > 0) _h = h;
		if (_field != null) {
			_field.width  = _w;
			_field.height = _h;
		}
	}

	// ── TextField mount ────────────────────────────────────────────────────────
	function _mount():Void {
		if (_onStage || _field == null || FlxG.game == null) return;
		FlxG.game.addChild(_field);
		_onStage = true;
		// Do NOT bring to front here — the field enters at its natural z-index.
	}

	/** Only called when the field gains focus, not every frame. */
	function _bringToFront():Void {
		if (_field == null || FlxG.game == null || !_onStage) return;
		var top = FlxG.game.numChildren - 1;
		if (FlxG.game.getChildIndex(_field) != top)
			FlxG.game.setChildIndex(_field, top);
	}

	function _unmount():Void {
		if (!_onStage || _field == null) return;
		if (_field.parent != null) _field.parent.removeChild(_field);
		_onStage = false;
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
		if (callback != null) callback(filtered, "change");
	}

	function _onFocusIn(_:FocusEvent):Void {
		FlxG.keys.enabled = false;
		_bringToFront(); // only on focus, not every frame
		if (onFocusGained != null) onFocusGained();
	}

	function _onFocusOut(_:FocusEvent):Void {
		FlxG.keys.enabled = true;
		// FIX: reset key state so Flixel doesn't replay keys held during input
		// capture (classic "double-Enter" bug).
		FlxG.keys.reset();
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
			// Note: Ctrl+C / Ctrl+X / Ctrl+V / Ctrl+A are handled natively
			// by OpenFL's TextField INPUT type — no extra code required.
			default:
		}
	}

	// ── Filter ────────────────────────────────────────────────────────────────
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

	// ── Update ────────────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!_onStage) { _mount(); return; }

		// Sync position every frame — do NOT call _bringToFront() here.
		var sp = FlxPoint.get();
		getScreenPosition(sp, camera);
		_field.x      = sp.x;
		_field.y      = sp.y;
		_field.width  = _w;
		_field.height = _h;
		_fmt.size = Std.int(_fontSize * 1.5);
		_field.defaultTextFormat = _fmt;
		_field.setTextFormat(_fmt);
		sp.put();

		_field.visible = visible && alive && exists;
	}

	// ── Visibility helpers ─────────────────────────────────────────────────────
	override function set_visible(v:Bool):Bool {
		if (_field != null) _field.visible = v;
		return super.set_visible(v);
	}
	override public function kill():Void {
		FlxG.keys.enabled = true;
		if (_field != null) _field.visible = false;
		super.kill();
	}
	override public function revive():Void {
		if (_field != null) _field.visible = true;
		super.revive();
	}
	override public function destroy():Void {
		FlxG.keys.enabled = true;
		_unmount();
		if (_field != null) {
			_field.removeEventListener(Event.CHANGE,           _onChange);
			_field.removeEventListener(FocusEvent.FOCUS_IN,    _onFocusIn);
			_field.removeEventListener(FocusEvent.FOCUS_OUT,   _onFocusOut);
			_field.removeEventListener(KeyboardEvent.KEY_DOWN,  _onKeyDown);
			_field = null;
		}
		callback = null; onFocusGained = null; onFocusLost = null;
		onEnterPressed = null; onEscapePressed = null;
		super.destroy();
	}
}
