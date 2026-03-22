package coolui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import openfl.events.Event;
import openfl.events.FocusEvent;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;

/**
 * CoolInputText — Campo de texto editable, sin dependencia de flixel-ui.
 *
 * Drop-in para FlxUIInputText / FlxInputText.
 *
 * Constructor compatible con ambas APIs originales:
 *   new CoolInputText(x, y, width, text, fontSize)
 *   new CoolInputText(x, y, width, text, fontSize, textColor, bgColor)
 *
 * Propiedades extra vs FlxUIInputText:
 *   lines                 — alto en líneas de texto
 *   backgroundColor       — color de fondo del TextField (proxy)
 *   fieldBorderColor      — color del borde del TextField (proxy)
 *   fieldBorderThickness  — grosor del borde (actualmente estético)
 *   focusGained / focusLost  — alias de onFocusGained / onFocusLost
 */
class CoolInputText extends FlxSpriteGroup
{
	// ── Filtros ──────────────────────────────────────────────────────────────
	public static inline var NO_FILTER         : Int = 0;
	public static inline var ONLY_ALPHA        : Int = 1;
	public static inline var ONLY_NUMERIC      : Int = 2;
	public static inline var ONLY_ALPHANUMERIC : Int = 3;
	public static inline var CUSTOM_FILTER     : Int = 4;

	// ── Callbacks ────────────────────────────────────────────────────────────
	public var callback      : String -> String -> Void;
	public var onFocusGained : Void -> Void;
	public var onFocusLost   : Void -> Void;

	/** Alias de onFocusGained (compat DialogueEditor). */
	public var focusGained(get, set) : Void -> Void;
	/** Alias de onFocusLost  (compat DialogueEditor). */
	public var focusLost(get, set)   : Void -> Void;

	function get_focusGained() return onFocusGained;
	function set_focusGained(v) { onFocusGained = v; return v; }
	function get_focusLost()    return onFocusLost;
	function set_focusLost(v)   { onFocusLost = v; return v; }

	// ── Propiedades públicas ─────────────────────────────────────────────────
	public var text(get, set)        : String;
	public var hasFocus(get, set)    : Bool;
	public var maxLength(get, set)   : Int;
	public var passwordMode(get,set) : Bool;
	public var filterMode            : Int = NO_FILTER;
	public var customFilterPattern   : String = "";

	/** Alto del campo expresado en líneas de texto. */
	public var lines(get, set) : Int;

	/** Color de fondo del TextField interno. */
	public var backgroundColor(get, set) : Int;
	/** Color del borde del TextField interno. */
	public var fieldBorderColor(get, set) : Int;
	/** Grosor del borde (visual, no nativo OpenFL). */
	public var fieldBorderThickness(default, set) : Int = 1;

	// ── Internals ────────────────────────────────────────────────────────────
	var _bg      : FlxSprite;
	var _display : FlxText;
	var _field   : TextField;
	var _fmt     : TextFormat;
	var _w       : Int;
	var _h       : Int;
	var _fontSize: Int;
	var _lines   : Int = 1;
	var _bgColor : Int;
	var _brdColor: Int;

	var _fieldOnStage  : Bool = false;
	var _needsMount    : Bool = true;   // mount on first update

	// ── Constructor ──────────────────────────────────────────────────────────
	public function new(px:Float = 0, py:Float = 0, width:Int = 150,
	                    text:String = "", fontSize:Int = 8,
	                    ?textColor:Int, ?bgColor:Int)
	{
		super(px, py);
		_w        = (width > 0) ? width : 150;
		_fontSize = (fontSize > 0) ? fontSize : 8;
		_h        = _fontSize + 8;
		_bgColor  = (bgColor  != null) ? bgColor  : coolui.CoolUITheme.current.bgPanelAlt;
		_brdColor = coolui.CoolUITheme.current.borderColor;

		var tc = (textColor != null) ? textColor : coolui.CoolUITheme.current.textPrimary;
		_buildVisuals(text, tc);
		_buildTextField(text, tc);
	}

	// ── Getters / Setters ────────────────────────────────────────────────────
	function get_text():String
		return (_field != null) ? _field.text : "";
	function set_text(v:String):String
	{
		if (_field   != null) _field.text   = v;
		if (_display != null) _display.text = passwordMode ? _maskText(v) : v;
		return v;
	}

	function get_hasFocus():Bool
		return _fieldOnStage && FlxG.stage != null && FlxG.stage.focus == _field;
	function set_hasFocus(v:Bool):Bool
	{
		if (FlxG.stage == null) return v;
		if (v) { if (!_fieldOnStage) _mountTextField(); FlxG.stage.focus = _field; }
		else if (FlxG.stage.focus == _field) FlxG.stage.focus = null;
		return v;
	}

	function get_maxLength():Int   return (_field != null) ? _field.maxChars : 0;
	function set_maxLength(v:Int):Int { if (_field != null) _field.maxChars = v; return v; }

	function get_passwordMode():Bool return (_field != null) ? _field.displayAsPassword : false;
	function set_passwordMode(v:Bool):Bool
	{
		if (_field != null) _field.displayAsPassword = v;
		if (_display != null) _display.text = v ? _maskText(_field.text) : _field.text;
		return v;
	}

	function get_lines():Int return _lines;
	function set_lines(v:Int):Int
	{
		_lines = (v > 0) ? v : 1;
		_h = _lines * (_fontSize + 4) + 4;
		if (_field   != null) { _field.height = _h; _field.multiline = _lines > 1; _field.wordWrap = _lines > 1; }
		if (_bg      != null) _bg.makeGraphic(_w, _h, _bgColor);
		if (_display != null) { _display.fieldHeight = _h - 4; }
		return _lines;
	}

	function get_backgroundColor():Int return _bgColor;
	function set_backgroundColor(v:Int):Int
	{
		_bgColor = v;
		if (_field != null) { _field.background = true; _field.backgroundColor = v; }
		if (_bg    != null) _bg.makeGraphic(_w, _h, v);
		return v;
	}

	function get_fieldBorderColor():Int return _brdColor;
	function set_fieldBorderColor(v:Int):Int
	{
		_brdColor = v;
		if (_field != null) { _field.border = true; _field.borderColor = v; }
		return v;
	}
	function set_fieldBorderThickness(v:Int):Int
	{
		fieldBorderThickness = v;
		// OpenFL TextField only supports 1px native border; thicker borders are visual-only.
		// Redraw the bg sprite border on next build if needed.
		return v;
	}

	// ── Build ────────────────────────────────────────────────────────────────
	function _buildVisuals(initialText:String, tc:Int):Void
	{
		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(_w, _h, _bgColor);
		add(_bg);

		_display = new FlxText(3, 2, _w - 6, initialText, _fontSize);
		_display.color = FlxColor.fromInt(tc);
		_display.scrollFactor.set();
		add(_display);
	}

	function _buildTextField(initialText:String, tc:Int):Void
	{
		_fmt = new TextFormat(null, _fontSize, tc);
		_field = new TextField();
		_field.type          = TextFieldType.INPUT;
		_field.defaultTextFormat = _fmt;
		_field.background    = true;
		_field.backgroundColor = _bgColor;
		_field.border        = true;
		_field.borderColor   = _brdColor;
		_field.textColor     = tc;
		_field.width         = _w;
		_field.height        = _h;
		_field.text          = initialText;
		_field.visible       = false;

		_field.addEventListener(Event.CHANGE,         _onChange);
		_field.addEventListener(FocusEvent.FOCUS_IN,  _onFocusIn);
		_field.addEventListener(FocusEvent.FOCUS_OUT, _onFocusOut);
	}

	// ── OpenFL events ────────────────────────────────────────────────────────
	function _onChange(_:Event):Void
	{
		var t = _applyFilter(_field.text);
		if (t != _field.text) _field.text = t;
		_display.text = passwordMode ? _maskText(t) : t;
		if (callback != null) callback(t, "change");
	}
	function _onFocusIn(_:FocusEvent):Void
	{
		_display.visible = false;
		_field.visible   = true;
		if (onFocusGained != null) onFocusGained();
	}
	function _onFocusOut(_:FocusEvent):Void
	{
		_display.text    = passwordMode ? _maskText(_field.text) : _field.text;
		_display.visible = true;
		_field.visible   = false;
		if (onFocusLost != null) onFocusLost();
	}

	// ── Filter ───────────────────────────────────────────────────────────────
	function _applyFilter(t:String):String
	{
		return switch (filterMode)
		{
			case ONLY_ALPHA:        ~/[^a-zA-Z]/.replace(t, "");
			case ONLY_NUMERIC:      ~/[^0-9\-\.]/.replace(t, "");
			case ONLY_ALPHANUMERIC: ~/[^a-zA-Z0-9]/.replace(t, "");
			case CUSTOM_FILTER:
				(customFilterPattern != "") ? new EReg('[^${customFilterPattern}]', "g").replace(t, "") : t;
			default: t;
		};
	}
	function _maskText(t:String):String return ~/./g.replace(t, "*");

	// ── TextField mount / unmount ─────────────────────────────────────────────
	public function _mountTextField():Void
	{
		if (_fieldOnStage || _field == null || FlxG.stage == null) return;
		FlxG.stage.addChild(_field);
		_fieldOnStage = true;
		_needsMount   = false;
	}
	function _unmountTextField():Void
	{
		if (!_fieldOnStage || _field == null) return;
		if (_field.parent != null) _field.parent.removeChild(_field);
		_fieldOnStage = false;
	}

	// ── Lifecycle ────────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void
	{
		// Mount overlay on first update (replaces non-existent onAddedToState)
		if (_needsMount && FlxG.stage != null)
			_mountTextField();

		super.update(elapsed);
		if (!_fieldOnStage) return;

		// Sync overlay position with screen position
		var sp = FlxPoint.get();
		getScreenPosition(sp, camera);
		var sx = FlxG.scaleMode.scale.x;
		var sy = FlxG.scaleMode.scale.y;
		_field.x      = sp.x * sx;
		_field.y      = sp.y * sy;
		_field.width  = _w * sx;
		_field.height = _h * sy;
		sp.put();

		// Click outside → blur
		if (FlxG.mouse.justPressed && hasFocus)
		{
			var sp2 = getScreenPosition();
			if (FlxG.mouse.x < sp2.x || FlxG.mouse.x > sp2.x + _w
			 || FlxG.mouse.y < sp2.y || FlxG.mouse.y > sp2.y + _h)
				FlxG.stage.focus = null;
			sp2.put();
		}
		// Click inside → focus
		if (FlxG.mouse.justPressed && !hasFocus)
		{
			var sp2 = getScreenPosition();
			if (FlxG.mouse.x >= sp2.x && FlxG.mouse.x <= sp2.x + _w
			 && FlxG.mouse.y >= sp2.y && FlxG.mouse.y <= sp2.y + _h)
				FlxG.stage.focus = _field;
			sp2.put();
		}
	}

	override public function kill():Void   { _unmountTextField(); super.kill();   }
	override public function revive():Void { _mountTextField();   super.revive(); }

	override public function destroy():Void
	{
		_unmountTextField();
		if (_field != null)
		{
			_field.removeEventListener(Event.CHANGE,         _onChange);
			_field.removeEventListener(FocusEvent.FOCUS_IN,  _onFocusIn);
			_field.removeEventListener(FocusEvent.FOCUS_OUT, _onFocusOut);
			_field = null;
		}
		callback      = null;
		onFocusGained = null;
		onFocusLost   = null;
		_bg           = FlxDestroyUtil.destroy(_bg);
		_display      = FlxDestroyUtil.destroy(_display);
		super.destroy();
	}
}
