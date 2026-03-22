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
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;

/**
 * CoolInputText — Campo de texto editable nativo, sin dependencia de flixel-ui.
 *
 * Usa un `openfl.text.TextField` como overlay en el stage de OpenFL para la
 * captura real de teclado, igual que hacía `flixel.addons.ui.FlxInputText`.
 * La posición del overlay se sincroniza cada frame con la posición en pantalla.
 *
 * API compatible con FlxUIInputText:
 *
 *   var inp = new CoolInputText(x, y, width, "texto inicial");
 *   inp.callback = function(text:String, action:String) { trace(text); };
 *   add(inp);
 *
 * Acciones en callback: "enter", "backspace", "delete", "change"
 *
 * Notas:
 *  • scrollFactor.set(0, 0) si el input vive en un panel fijo de editor.
 *  • El TextField de OpenFL se añade a `FlxG.stage` al hacer `add()` y se
 *    retira en `destroy()`. Si lo eliminas del grupo con `remove()` llama
 *    `destroy()` explícitamente para limpiar el overlay.
 *  • `maxLength`: limita caracteres (0 = sin límite).
 *  • `passwordMode`: oculta el texto con asteriscos.
 *  • `filterMode`: ONLY_ALPHA, ONLY_NUMERIC, ONLY_ALPHANUMERIC, CUSTOM.
 *  • `customFilterPattern`: regex para CUSTOM filterMode.
 */
class CoolInputText extends FlxSpriteGroup
{
	// ── Filtros (mismos valores que FlxInputText para compatibilidad) ────────
	public static inline var NO_FILTER         : Int = 0;
	public static inline var ONLY_ALPHA        : Int = 1;
	public static inline var ONLY_NUMERIC      : Int = 2;
	public static inline var ONLY_ALPHANUMERIC : Int = 3;
	public static inline var CUSTOM_FILTER     : Int = 4;

	// ── Señales / callbacks ──────────────────────────────────────────────────

	/** Llamado cuando el texto cambia: `callback(newText, action)`. */
	public var callback   : String -> String -> Void;
	/** Llamado cuando el campo gana el foco. */
	public var onFocusGained : Void -> Void;
	/** Llamado cuando el campo pierde el foco. */
	public var onFocusLost  : Void -> Void;

	// ── Propiedades públicas ─────────────────────────────────────────────────

	public var text(get, set)        : String;
	public var hasFocus(get, set)    : Bool;
	public var maxLength(get, set)   : Int;
	public var passwordMode(get,set) : Bool;
	public var filterMode            : Int = NO_FILTER;
	/** Patrón regex para CUSTOM_FILTER (sin delimitadores). */
	public var customFilterPattern   : String = "";

	// ── Internals ────────────────────────────────────────────────────────────

	var _bg       : FlxSprite;
	var _display  : FlxText;   // muestra el texto cuando el campo no tiene foco

	/** El TextField de OpenFL que hace la edición real. */
	var _field    : TextField;
	/** Formato de texto aplicado al TextField. */
	var _fmt      : TextFormat;

	var _w        : Int;
	var _h        : Int;
	var _fontSize : Int;

	var _fieldOnStage : Bool = false;

	// ── Constructor ──────────────────────────────────────────────────────────

	/**
	 * @param px        Posición X
	 * @param py        Posición Y
	 * @param width     Ancho del campo (px)
	 * @param text      Texto inicial
	 * @param fontSize  Tamaño de fuente (por defecto 8)
	 */
	public function new(px:Float = 0, py:Float = 0, width:Int = 150,
	                    text:String = "", fontSize:Int = 8)
	{
		super(px, py);
		_w = (width > 0) ? width : 150;
		_fontSize = (fontSize > 0) ? fontSize : 8;
		_h = _fontSize + 8;

		_buildVisuals(text);
		_buildTextField(text);
	}

	// ── Getters / Setters ────────────────────────────────────────────────────

	function get_text():String
		return (_field != null) ? _field.text : "";

	function set_text(v:String):String
	{
		if (_field != null) _field.text = v;
		if (_display != null) _display.text = v;
		return v;
	}

	function get_hasFocus():Bool
		return _fieldOnStage && FlxG.stage != null && FlxG.stage.focus == _field;

	function set_hasFocus(v:Bool):Bool
	{
		if (FlxG.stage == null) return v;
		if (v)
		{
			if (!_fieldOnStage) _mountTextField();
			FlxG.stage.focus = _field;
		}
		else if (FlxG.stage.focus == _field)
		{
			FlxG.stage.focus = null;
		}
		return v;
	}

	function get_maxLength():Int
		return (_field != null) ? _field.maxChars : 0;

	function set_maxLength(v:Int):Int
	{
		if (_field != null) _field.maxChars = v;
		return v;
	}

	function get_passwordMode():Bool
		return (_field != null) ? _field.displayAsPassword : false;

	function set_passwordMode(v:Bool):Bool
	{
		if (_field != null) _field.displayAsPassword = v;
		if (_display != null) _display.text = v ? _maskText(_field.text) : _field.text;
		return v;
	}

	// ── Construcción visual ──────────────────────────────────────────────────

	function _buildVisuals(initialText:String):Void
	{
		var T = coolui.CoolUITheme.current;

		// Fondo
		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(_w, _h, T.bgPanelAlt);
		add(_bg);

		// Borde
		var border = new FlxSprite(0, 0);
		border.makeGraphic(_w, _h, FlxColor.TRANSPARENT);
		// Marco de 1px dibujado manualmente
		_drawBorder(border, T.borderColor);
		add(border);

		// Texto de display (visible cuando no hay foco)
		_display = new FlxText(3, 2, _w - 6, initialText, _fontSize);
		_display.color = FlxColor.fromInt(T.textPrimary);
		_display.scrollFactor.set();
		add(_display);
	}

	function _buildTextField(initialText:String):Void
	{
		var T = coolui.CoolUITheme.current;

		_fmt = new TextFormat(null, _fontSize, T.textPrimary);

		_field = new TextField();
		_field.type          = TextFieldType.INPUT;
		_field.defaultTextFormat = _fmt;
		_field.background    = true;
		_field.backgroundColor = T.bgPanelAlt;
		_field.border        = true;
		_field.borderColor   = T.borderColor;
		_field.textColor     = T.textPrimary;
		_field.width         = _w;
		_field.height        = _h;
		_field.text          = initialText;
		_field.visible       = false; // se muestra solo al ganar foco

		_field.addEventListener(Event.CHANGE,          _onChange);
		_field.addEventListener(FocusEvent.FOCUS_IN,   _onFocusIn);
		_field.addEventListener(FocusEvent.FOCUS_OUT,  _onFocusOut);
	}

	function _drawBorder(s:FlxSprite, color:Int):Void
	{
		// Dibuja 4 líneas de 1px alrededor del sprite
		s.makeGraphic(_w, _h, FlxColor.TRANSPARENT);
		var pixels = s.pixels;
		var c = FlxColor.fromInt(color);
		c.alphaFloat = 0.6;
		for (i in 0..._w)
		{
			pixels.setPixel32(i, 0,      c);
			pixels.setPixel32(i, _h - 1, c);
		}
		for (j in 0..._h)
		{
			pixels.setPixel32(0,      j, c);
			pixels.setPixel32(_w - 1, j, c);
		}
		s.pixels = pixels;
	}

	// ── Eventos OpenFL ───────────────────────────────────────────────────────

	function _onChange(_:Event):Void
	{
		var t = _field.text;
		t = _applyFilter(t);
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

	// ── Filtro de entrada ────────────────────────────────────────────────────

	function _applyFilter(t:String):String
	{
		return switch (filterMode)
		{
			case ONLY_ALPHA:        ~/[^a-zA-Z]/.replace(t, "");
			case ONLY_NUMERIC:      ~/[^0-9\-\.]/.replace(t, "");
			case ONLY_ALPHANUMERIC: ~/[^a-zA-Z0-9]/.replace(t, "");
			case CUSTOM_FILTER:
				if (customFilterPattern != "")
					new EReg('[^${customFilterPattern}]', "g").replace(t, "")
				else t;
			default: t;
		};
	}

	function _maskText(t:String):String
		return ~/./g.replace(t, "*");

	// ── Lifecycle ────────────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!_fieldOnStage) return;

		// Sincronizar posición del overlay con la posición en pantalla
		var screenPos = FlxPoint.get();
		getScreenPosition(screenPos, camera);

		var sx = FlxG.scaleMode.scale.x;
		var sy = FlxG.scaleMode.scale.y;

		_field.x = screenPos.x * sx;
		_field.y = screenPos.y * sy;
		_field.width  = _w * sx;
		_field.height = _h * sy;

		screenPos.put();

		// Clic fuera del campo → quitar foco
		if (FlxG.mouse.justPressed && hasFocus)
		{
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			var sp = getScreenPosition();
			if (mx < sp.x || mx > sp.x + _w || my < sp.y || my > sp.y + _h)
				FlxG.stage.focus = null;
			sp.put();
		}

		// Clic dentro → dar foco
		if (FlxG.mouse.justPressed && !hasFocus)
		{
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			var sp = getScreenPosition();
			if (mx >= sp.x && mx <= sp.x + _w && my >= sp.y && my <= sp.y + _h)
				FlxG.stage.focus = _field;
			sp.put();
		}
	}

	/** Añade el TextField al stage de OpenFL (llamar después de add()). */
	override public function onAddedToState():Void
	{
		_mountTextField();
		super.onAddedToState();
	}

	function _mountTextField():Void
	{
		if (_fieldOnStage || _field == null || FlxG.stage == null) return;
		FlxG.stage.addChild(_field);
		_fieldOnStage = true;
	}

	function _unmountTextField():Void
	{
		if (!_fieldOnStage || _field == null) return;
		if (_field.parent != null) _field.parent.removeChild(_field);
		_fieldOnStage = false;
	}

	override public function kill():Void
	{
		_unmountTextField();
		super.kill();
	}

	override public function revive():Void
	{
		_mountTextField();
		super.revive();
	}

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
