package coolui;

import coolui.CoolTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.desktop.Clipboard;
import openfl.desktop.ClipboardFormats;

/**
 * CoolNumericStepper — Drop-in replacement for `FlxUINumericStepper`.
 *
 * FIXED:
 *   - Edit mode now auto-selects the full value text so the user can start
 *     typing a new number immediately (no need to manually select first).
 *     Requires CoolInputText to expose a `textField:openfl.text.TextField`
 *     property (standard for FlxInputText-based wrappers).
 *   - Double-click timer is reset to -1 after entering edit mode, preventing
 *     a spurious third click from immediately reopening the editor.
 *   - Hit-test uses FlxG.mouse.screenX/Y (screen-space) instead of
 *     getWorldPosition() so the widget works on HUD cameras (scrollFactor=0)
 *     regardless of world-camera scroll.
 *
 * WHEEL BEHAVIOUR:
 *   Plain scroll           → ± stepSize
 *   SHIFT + scroll         → ± stepSize × 10   (big step)
 *   CTRL  + scroll         → ± stepSize × 10   (big step — same as SHIFT)
 *
 * KEYBOARD BEHAVIOUR (button clicks inherit these via step()):
 *   Plain click            → ± stepSize
 *   SHIFT held             → ± stepSize × 10
 *   CTRL  held             → ± stepSize ÷ 10   (fine step — keyboard only)
 *
 * OTHER:
 *   Ctrl+C while hovered   → copies current value to the system clipboard.
 *   Double-click centre    → opens an inline numeric text-editor.
 *   Enter / Escape         → confirms / cancels the inline editor.
 */
class CoolNumericStepper extends FlxSpriteGroup {
	static inline var BTN_W:Int = 16;
	static inline var HEIGHT:Int = 18;

	public var value_change:Float->Void;
	public var value(get, set):Float;
	public var stepSize:Float;
	public var minValue:Float;
	public var maxValue:Float;
	public var decimals:Int;

	var _value:Float;
	var _w:Int;
	var _bg:FlxSprite;
	var _btnUp:_StepBtn;
	var _btnDn:_StepBtn;
	var _label:FlxText;
	var _editField:CoolInputText;
	var _editing:Bool = false;
	var _dblClickTimer:Float = -1;
	var _hover:Bool = false;

	static inline var DCLICK_MS:Float = 0.3;

	public function new(px:Float = 0, py:Float = 0, stepSize:Float = 1, value:Float = 0, min:Float = 0, max:Float = 100, decimals:Int = 0, width:Int = 80) {
		super(px, py);
		this.stepSize = stepSize;
		this.minValue = min;
		this.maxValue = max;
		this.decimals = decimals;
		_value = _clamp(value);
		_w = (width > 0) ? width : 80;
		_build();
	}

	function get_value():Float
		return _value;

	function set_value(v:Float):Float {
		var clamped = _clamp(v);
		if (clamped == _value)
			return _value;
		_value = clamped;
		_updateLabel();
		if (value_change != null)
			value_change(_value);
		return _value;
	}

	function _build():Void {
		var T = coolui.CoolUITheme.current;
		var labelW = _w - BTN_W * 2;

		_bg = new FlxSprite(BTN_W, 0);
		_bg.makeGraphic(labelW, HEIGHT, T.bgPanelAlt);
		add(_bg);

		_btnDn = new _StepBtn(0, 0, BTN_W, HEIGHT, "-", T);
		_btnDn.scrollFactor.set(0, 0);
		_btnDn.onClick = function() step(-1);
		add(_btnDn);

		_btnUp = new _StepBtn(_w - BTN_W, 0, BTN_W, HEIGHT, "+", T);
		_btnUp.scrollFactor.set(0, 0);
		_btnUp.onClick = function() step(1);
		add(_btnUp);

		_label = new FlxText(BTN_W + 2, 1, labelW - 4, _formatValue(_value), 10);
		_label.alignment = CENTER;
		_label.color = FlxColor.fromInt(T.textPrimary);
		_label.scrollFactor.set(0, 0);
		add(_label);
	}

	/**
	 * Step by one unit in the given direction, applying keyboard-modifier
	 * scaling.  Called by the +/- buttons and can be called externally.
	 *
	 *   SHIFT → ×10  (coarse keyboard step)
	 *   CTRL  → ÷10  (fine  keyboard step)
	 */
	public function step(dir:Int):Void {
		var s = stepSize;
		if (FlxG.keys.pressed.SHIFT)
			s *= 10;
		if (FlxG.keys.pressed.CONTROL)
			s /= 10;
		value = _value + dir * s;
	}

	/**
	 * Step from the mouse wheel, bypassing keyboard-modifier logic so we can
	 * apply our own wheel-specific scaling.
	 *
	 *   Plain scroll        → ×1   (stepSize)
	 *   SHIFT/CTRL scroll   → ×10  (big step — both modifiers behave the same
	 *                                on the wheel for intuitive operation)
	 */
	function _wheelStep(dir:Int):Void {
		var factor:Float = (FlxG.keys.pressed.SHIFT || FlxG.keys.pressed.CONTROL) ? 10.0 : 1.0;
		value = _value + dir * stepSize * factor;
	}

	// ── Value helpers ──────────────────────────────────────────────────────
	function _clamp(v:Float):Float {
		if (v < minValue)
			return minValue;
		if (v > maxValue)
			return maxValue;
		return _round(v);
	}

	function _round(v:Float):Float {
		if (decimals <= 0)
			return Math.round(v);
		var factor = Math.pow(10, decimals);
		return Math.round(v * factor) / factor;
	}

	function _formatValue(v:Float):String {
		if (decimals <= 0)
			return Std.string(Std.int(v));
		var s = Std.string(Math.round(v * Math.pow(10, decimals)) / Math.pow(10, decimals));
		var dotIdx = s.indexOf(".");
		if (dotIdx < 0) {
			s += ".";
			dotIdx = s.length - 1;
		}
		while (s.length - dotIdx - 1 < decimals)
			s += "0";
		return s;
	}

	function _updateLabel():Void {
		if (_label != null)
			_label.text = _formatValue(_value);
	}

	// ── Update ─────────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		// FIX: Use screen-space coordinates for hit testing.
		// scrollFactor = (0,0) means the widget renders at its world (x, y)
		// on screen regardless of camera scroll. Using getWorldPosition()
		// would add camera.scroll and produce wrong results.
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		_hover = mx >= x && mx <= x + _w && my >= y && my <= y + HEIGHT;

		// ── Double-click to open inline editor ────────────────────────────
		if (FlxG.mouse.justPressed && !_editing) {
			var inCenter = mx >= x + BTN_W && mx <= x + _w - BTN_W && my >= y && my <= y + HEIGHT;
			if (inCenter) {
				var now = haxe.Timer.stamp();
				if (_dblClickTimer >= 0 && (now - _dblClickTimer) < DCLICK_MS) {
					_startEdit();
					// FIX: Reset timer so a third rapid click doesn't reopen
					// the editor the instant it is closed.
					_dblClickTimer = -1;
				} else {
					_dblClickTimer = now;
				}
			}
		}

		// ── Mouse wheel ───────────────────────────────────────────────────
		// Uses _wheelStep() so SHIFT/CTRL both mean ×10 on the wheel.
		if (FlxG.mouse.wheel != 0 && _hover && !_editing)
			_wheelStep(FlxG.mouse.wheel > 0 ? 1 : -1);

		// ── Ctrl+C — copy to clipboard ────────────────────────────────────
		if (_hover && !_editing && FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C)
			Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, _formatValue(_value));
	}

	// ── Inline editor ──────────────────────────────────────────────────────
	function _startEdit():Void {
		if (_editField != null)
			return;
		_editing = true;
		_label.visible = false;

		_editField = new CoolInputText(BTN_W, 0, _w - BTN_W * 2, _formatValue(_value), 8);
		_editField.filterMode = CoolInputText.ONLY_NUMERIC;
		_editField.scrollFactor.set(0, 0);
		_editField.onEnterPressed = function() _endEdit(true);
		_editField.onEscapePressed = function() _endEdit(false);
		add(_editField);
		_editField.hasFocus = true;

		// FIX: Auto-select all text so the user can immediately type a new
		// value without having to manually clear the old one first.
		// selectAll() is a public method on CoolInputText that forwards to
		// the internal TextField — no need to expose _field directly.
		_editField.selectAll();
	}

	function _endEdit(confirm:Bool):Void {
		if (!_editing || _editField == null)
			return;
		if (confirm) {
			var parsed = Std.parseFloat(_editField.text);
			if (!Math.isNaN(parsed))
				value = parsed;
		}
		_editField.destroy();
		remove(_editField, true);
		_editField = null;
		_editing = false;
		_label.visible = true;
	}

	override public function destroy():Void {
		value_change = null;
		if (_editField != null) {
			_editField.destroy();
			_editField = null;
		}
		super.destroy();
	}
}

// ── Private helper: step button ────────────────────────────────────────────
private class _StepBtn extends FlxSpriteGroup {
	public var onClick:Void->Void;

	var _bg:FlxSprite;
	var _label:FlxText;
	var _bw:Int;
	var _bh:Int;
	var _holdTimer:Float = 0;
	var _holdRepeat:Float = 0;

	public function new(bx:Float, by:Float, bw:Int, bh:Int, arrow:String, T:CoolTheme) {
		super(bx, by);
		_bw = bw;
		_bh = bh;

		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(bw, bh, T.bgHover);
		add(_bg);

		_label = new FlxText(0, 0, bw, arrow, 11);
		_label.alignment = CENTER;
		_label.color = FlxColor.fromInt(T.accent);
		_label.y = Std.int((bh - _label.height) * 0.5);
		add(_label);
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		// FIX: Screen-space hit test (scrollFactor = 0 on HUD).
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		var hover = mx >= x && mx <= x + _bw && my >= y && my <= y + _bh;

		_bg.alpha = hover ? 1.0 : 0.8;

		if (hover && FlxG.mouse.justPressed && onClick != null)
			onClick();

		// Hold-to-repeat
		if (hover && FlxG.mouse.pressed) {
			_holdTimer += elapsed;
			_holdRepeat += elapsed;
			if (_holdTimer >= 0.4 && _holdRepeat >= 0.08) {
				if (onClick != null)
					onClick();
				_holdRepeat = 0;
			}
		} else {
			_holdTimer = 0;
			_holdRepeat = 0;
		}
	}

	override public function destroy():Void {
		onClick = null;
		super.destroy();
	}
}
