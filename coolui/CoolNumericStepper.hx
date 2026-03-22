package coolui;

import coolui.CoolTheme;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;


/**
 * CoolNumericStepper — Reemplazo de `FlxUINumericStepper` sin flixel-ui.
 *
 * API compatible:
 *
 *   var s = new CoolNumericStepper(x, y, step, value, min, max, decimals);
 *   s.value_change = function(v:Float) { trace(v); };
 *
 * Controles:
 *  • Clic en ▲ / ▼     → incrementa / decrementa `step`.
 *  • Rueda del ratón    → incrementa / decrementa cuando el cursor está encima.
 *  • Doble clic label   → abre CoolInputText inline para escribir el valor.
 *  • Mantener Shift     → multiplica el step por 10.
 *  • Mantener Ctrl      → divide el step entre 10.
 */
class CoolNumericStepper extends FlxSpriteGroup
{
	// ── Layout ───────────────────────────────────────────────────────────────

	static inline var BTN_W  : Int = 16;
	static inline var HEIGHT : Int = 18;

	// ── Propiedades públicas ─────────────────────────────────────────────────

	/** Callback cuando el valor cambia: `value_change(newValue)`. */
	public var value_change : Float -> Void;

	public var value(get, set)   : Float;
	public var stepSize          : Float;
	public var minValue          : Float;
	public var maxValue          : Float;
	public var decimals          : Int;

	// ── Estado ───────────────────────────────────────────────────────────────

	var _value  : Float;
	var _w      : Int;

	var _bg     : FlxSprite;
	var _btnUp  : _StepBtn;
	var _btnDn  : _StepBtn;
	var _label  : FlxText;

	var _editField : CoolInputText;
	var _editing   : Bool = false;
	var _dblClickTimer : Float = -1;
	static inline var DCLICK_MS : Float = 0.3;

	// ── Constructor ──────────────────────────────────────────────────────────

	/**
	 * @param px        Posición X
	 * @param py        Posición Y
	 * @param stepSize  Cuánto suma/resta cada clic
	 * @param value     Valor inicial
	 * @param min       Valor mínimo
	 * @param max       Valor máximo
	 * @param decimals  Decimales a mostrar (0 = entero)
	 * @param width     Ancho total (por defecto 80)
	 */
	public function new(px:Float = 0, py:Float = 0,
	                    stepSize:Float = 1, value:Float = 0,
	                    min:Float = 0, max:Float = 100,
	                    decimals:Int = 0, width:Int = 80)
	{
		super(px, py);
		this.stepSize = stepSize;
		this.minValue = min;
		this.maxValue = max;
		this.decimals = decimals;
		_value = _clamp(value);
		_w = (width > 0) ? width : 80;
		_build();
	}

	// ── Getters / Setters ────────────────────────────────────────────────────

	function get_value():Float return _value;

	function set_value(v:Float):Float
	{
		var clamped = _clamp(v);
		if (clamped == _value) return _value;
		_value = clamped;
		_updateLabel();
		if (value_change != null) value_change(_value);
		return _value;
	}

	// ── Build ────────────────────────────────────────────────────────────────

	function _build():Void
	{
		var T = coolui.CoolUITheme.current;
		var labelW = _w - BTN_W * 2;

		// Fondo label
		_bg = new FlxSprite(BTN_W, 0);
		_bg.makeGraphic(labelW, HEIGHT, T.bgPanelAlt);
		add(_bg);

		// Botón ▼
		_btnDn = new _StepBtn(0, 0, BTN_W, HEIGHT, "◀", T);
		_btnDn.scrollFactor.set();
		_btnDn.onClick = function() step(-1);
		add(_btnDn);

		// Botón ▲
		_btnUp = new _StepBtn(_w - BTN_W, 0, BTN_W, HEIGHT, "▶", T);
		_btnUp.scrollFactor.set();
		_btnUp.onClick = function() step(1);
		add(_btnUp);

		// Label
		_label = new FlxText(BTN_W + 2, 1, labelW - 4, _formatValue(_value), 8);
		_label.alignment = CENTER;
		_label.color = FlxColor.fromInt(T.textPrimary);
		_label.scrollFactor.set();
		add(_label);
	}

	// ── Lógica ───────────────────────────────────────────────────────────────

	public function step(dir:Int):Void
	{
		var s = stepSize;
		if (FlxG.keys.pressed.SHIFT) s *= 10;
		if (FlxG.keys.pressed.CONTROL) s /= 10;
		value = _value + dir * s;
	}

	function _clamp(v:Float):Float
	{
		if (v < minValue) return minValue;
		if (v > maxValue) return maxValue;
		return _round(v);
	}

	function _round(v:Float):Float
	{
		if (decimals <= 0) return Math.round(v);
		var factor = Math.pow(10, decimals);
		return Math.round(v * factor) / factor;
	}

	function _formatValue(v:Float):String
	{
		if (decimals <= 0) return Std.string(Std.int(v));
		var s = Std.string(Math.round(v * Math.pow(10, decimals)) / Math.pow(10, decimals));
		// Asegurar mínimo de decimals dígitos después del punto
		var dotIdx = s.indexOf(".");
		if (dotIdx < 0) { s += "."; dotIdx = s.length - 1; }
		while (s.length - dotIdx - 1 < decimals) s += "0";
		return s;
	}

	function _updateLabel():Void
	{
		if (_label != null) _label.text = _formatValue(_value);
	}

	// ── Update ───────────────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Doble clic sobre el label → edición inline (detección manual)
		if (FlxG.mouse.justPressed && !_editing)
		{
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			if (mx >= x + BTN_W && mx <= x + _w - BTN_W && my >= y && my <= y + HEIGHT)
			{
				var now = haxe.Timer.stamp();
				if (_dblClickTimer >= 0 && (now - _dblClickTimer) < DCLICK_MS)
					_startEdit();
				_dblClickTimer = now;
			}
		}

		// Rueda encima del widget
		if (FlxG.mouse.wheel != 0)
		{
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			if (mx >= x && mx <= x + _w && my >= y && my <= y + HEIGHT)
				step(FlxG.mouse.wheel > 0 ? 1 : -1);
		}

		// Confirmar edición con Enter
		if (_editing && (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE))
			_endEdit(FlxG.keys.justPressed.ENTER);
	}

	function _startEdit():Void
	{
		if (_editField != null) return;
		_editing = true;
		_label.visible = false;
		_editField = new CoolInputText(BTN_W, 0, _w - BTN_W * 2, _formatValue(_value), 8);
		_editField.filterMode = CoolInputText.ONLY_NUMERIC;
		_editField.scrollFactor.set();
		add(_editField);
		_editField.hasFocus = true;
	}

	function _endEdit(confirm:Bool):Void
	{
		if (!_editing || _editField == null) return;
		if (confirm)
		{
			var parsed = Std.parseFloat(_editField.text);
			if (!Math.isNaN(parsed)) value = parsed;
		}
		_editField.destroy();
		remove(_editField, true);
		_editField = null;
		_editing = false;
		_label.visible = true;
	}

	override public function destroy():Void
	{
		value_change = null;
		if (_editField != null) { _editField.destroy(); _editField = null; }
		super.destroy();
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// _StepBtn
// ─────────────────────────────────────────────────────────────────────────────

private class _StepBtn extends FlxSpriteGroup
{
	public var onClick : Void -> Void;

	var _bg    : FlxSprite;
	var _label : FlxText;
	var _bw    : Int;
	var _bh    : Int;

	public function new(bx:Float, by:Float, bw:Int, bh:Int, arrow:String,
	                    T:CoolTheme)
	{
		super(bx, by);
		_bw = bw; _bh = bh;

		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(bw, bh, T.bgHover);
		add(_bg);

		_label = new FlxText(0, 0, bw, arrow, 8);
		_label.alignment = CENTER;
		_label.color = FlxColor.fromInt(T.accent);
		_label.y = Std.int((bh - _label.height) * 0.5);
		add(_label);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var hover = FlxG.mouse.x >= x && FlxG.mouse.x <= x + _bw
		         && FlxG.mouse.y >= y && FlxG.mouse.y <= y + _bh;
		_bg.alpha = hover ? 1.4 : 1.0;
		if (hover && FlxG.mouse.justPressed && onClick != null) onClick();

		// Mantener presionado: dispara rápido después de 400ms
		if (hover && FlxG.mouse.pressed)
		{
			@:privateAccess if (_holdTimer >= 0.4 && _holdRepeat >= 0.08)
			{
				if (onClick != null) onClick();
				_holdRepeat = 0;
			}
			_holdTimer  += elapsed;
			_holdRepeat += elapsed;
		}
		else { _holdTimer = 0; _holdRepeat = 0; }
	}

	var _holdTimer  : Float = 0;
	var _holdRepeat : Float = 0;

	override public function destroy():Void { onClick = null; super.destroy(); }
}
