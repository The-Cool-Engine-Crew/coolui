package coolui;

import coolui.CoolUITheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * CoolKnob — Rotary knob control.
 *
 * Default image: "assets/images/coolui_knob.png"
 * To use the default, copy your knob sprite there (or override with imagePath).
 *
 * The `vertical` parameter controls both drag axis and keyboard bindings:
 *   vertical = false  →  drag LEFT/RIGHT,  keys ← →
 *   vertical = true   →  drag UP/DOWN,     keys ↑ ↓
 *
 * In both modes the knob graphic rotates from MIN_ANGLE to MAX_ANGLE.
 * Mouse wheel always works regardless of orientation.
 *
 * Usage:
 *   // Horizontal knob (e.g. pan), using default image:
 *   var k = new CoolKnob(x, y, -100, 100, 0);
 *   k.showValue = true;
 *   k.onChange  = function(v) trace("Pan: " + v);
 *
 *   // Vertical knob (e.g. volume), using default image:
 *   var k = new CoolKnob(x, y, 0, 100, 75, 48, true);
 *
 *   // Custom image:
 *   var k = new CoolKnob(x, y, 0, 100, 50, 48, false, "assets/images/myknob.png");
 */
class CoolKnob extends FlxSpriteGroup {

	/** Angle (degrees) at minimum value. */
	public static inline var MIN_ANGLE:Float = -135.0;
	/** Angle (degrees) at maximum value. */
	public static inline var MAX_ANGLE:Float =  135.0;

	/** Default image used when no imagePath is given. */
	public static inline var DEFAULT_IMAGE:String = "assets/images/coolui_knob.png";

	// ── Public API ─────────────────────────────────────────────────────────
	public var onChange:Float->Void;

	public var value(get, set):Float;
	public var minValue:Float;
	public var maxValue:Float;
	public var step:Float;

	/**
	 * Orientation of the knob.
	 *   false = horizontal  →  drag left/right,  ← → keys
	 *   true  = vertical    →  drag up/down,     ↑ ↓ keys
	 */
	public var vertical:Bool;

	/** Show the current value as a label below the knob. */
	public var showValue:Bool = false;
	/** Decimal places shown in the value label (0 = integer). */
	public var decimals:Int   = 0;
	/**
	 * Pixels of mouse travel needed to sweep the full range.
	 * Default 120. Lower = more sensitive.
	 */
	public var dragSensitivity:Float = 120.0;

	// ── Internals ──────────────────────────────────────────────────────────
	var _value:Float;
	var _size:Int;
	var _imagePath:String;

	var _knob:FlxSprite;
	var _label:FlxText;

	var _dragging:Bool        = false;
	var _hovered:Bool         = false;
	var _dragStartMouse:Float = 0.0;   // x or y depending on orientation
	var _dragStartValue:Float = 0.0;

	/**
	 * @param px         X position
	 * @param py         Y position
	 * @param min        Minimum value
	 * @param max        Maximum value
	 * @param initValue  Initial value
	 * @param size       Width/height of the knob in pixels (default 48)
	 * @param vertical   false = horizontal drag+keys,  true = vertical drag+keys
	 * @param imagePath  Path to knob image. Pass null to use DEFAULT_IMAGE.
	 *                   Pass "" to force the procedural drawn knob.
	 * @param step       Arrow-key / wheel step (default 1)
	 */
	public function new(px:Float = 0, py:Float = 0, min:Float = 0, max:Float = 1,
	                    initValue:Float = 0, size:Int = 48, vertical:Bool = false,
	                    imagePath:String = null, step:Float = 1) {
		super(px, py);
		minValue       = min;
		maxValue       = max;
		this.step      = step;
		this.vertical  = vertical;
		_size          = (size > 8) ? size : 8;
		// null  → use default image
		// ""    → force procedural (no image)
		_imagePath     = (imagePath == null) ? DEFAULT_IMAGE : imagePath;
		_value         = _clamp(initValue);
		_build();
	}

	// ── Getters / Setters ──────────────────────────────────────────────────
	function get_value():Float return _value;
	function set_value(v:Float):Float {
		var c = _clamp(v);
		if (c == _value) return _value;
		_value = c;
		_syncAngle();
		if (onChange != null) onChange(_value);
		return _value;
	}

	// ── Build ──────────────────────────────────────────────────────────────
	function _build():Void {
		var T = CoolUITheme.current;

		if (_imagePath.length > 0) {
			_knob = new FlxSprite(0, 0, _imagePath);
			_knob.setGraphicSize(_size, _size);
			_knob.updateHitbox();
		} else {
			_knob = new FlxSprite(0, 0);
			_knob.makeGraphic(_size, _size, FlxColor.TRANSPARENT);
			_drawProceduralKnob(T);
		}
		_knob.antialiasing = true;
		_knob.scrollFactor.set(0, 0);
		add(_knob);

		_label = new FlxText(0, _size + 3, _size, "", 8);
		_label.alignment   = CENTER;
		_label.color       = FlxColor.fromInt(T.textSecondary);
		_label.scrollFactor.set(0, 0);
		_label.visible     = false;
		add(_label);

		_syncAngle();
	}

	function _drawProceduralKnob(T:CoolTheme):Void {
		var p  = _knob.pixels;
		var cx = _size * 0.5;
		var cy = _size * 0.5;
		var r  = cx - 1;
		var r2 = r * r;
		var ri = (r - 2) * (r - 2);

		var bodyColor = FlxColor.fromInt(T.bgPanel);
		var rimColor  = FlxColor.fromInt(T.accent);

		for (py in 0..._size) {
			for (px in 0..._size) {
				var dx = px - cx;
				var dy = py - cy;
				var d2 = dx * dx + dy * dy;
				if (d2 <= r2) {
					if (d2 >= ri) {
						p.setPixel32(px, py, rimColor);
					} else {
						var shade = Std.int(Math.max(0, Math.min(255, 220 + dy * 0.3)));
						var c = FlxColor.fromRGB(
							Std.int(bodyColor.red   * shade / 255),
							Std.int(bodyColor.green * shade / 255),
							Std.int(bodyColor.blue  * shade / 255)
						);
						p.setPixel32(px, py, c);
					}
				}
			}
		}

		// Indicator dot at top-centre
		var dotR  = Std.int(Math.max(2, _size / 10));
		var dotCX = Std.int(cx);
		var dotCY = dotR + 3;
		var dotColor = FlxColor.fromInt(T.accent);
		for (py in (dotCY - dotR)...(dotCY + dotR + 1)) {
			for (px in (dotCX - dotR)...(dotCX + dotR + 1)) {
				var dx = px - dotCX; var dy = py - dotCY;
				if (dx * dx + dy * dy <= dotR * dotR)
					if (px >= 0 && px < _size && py >= 0 && py < _size)
						p.setPixel32(px, py, dotColor);
			}
		}
		_knob.pixels = p;
	}

	// ── Angle sync ─────────────────────────────────────────────────────────
	function _syncAngle():Void {
		var ratio    = (maxValue > minValue) ? (_value - minValue) / (maxValue - minValue) : 0.0;
		_knob.angle  = MIN_ANGLE + ratio * (MAX_ANGLE - MIN_ANGLE);

		if (showValue && _label != null) {
			_label.text    = _formatValue(_value);
			_label.visible = true;
		} else if (_label != null) {
			_label.visible = false;
		}
	}

	// ── Update ─────────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		var mp = FlxG.mouse.getWorldPosition(camera);
		var mx = mp.x; var my = mp.y;
		mp.put();

		// Circular hit-test
		var cx   = x + _size * 0.5;
		var cy   = y + _size * 0.5;
		var r    = _size * 0.5;
		var dx   = mx - cx; var dy = my - cy;
		_hovered = (dx * dx + dy * dy) <= (r * r);

		if (_hovered && FlxG.mouse.justPressed) {
			_dragging       = true;
			_dragStartMouse = vertical ? my : mx;
			_dragStartValue = _value;
		}
		if (!FlxG.mouse.pressed) _dragging = false;

		if (_dragging) {
			var range    = maxValue - minValue;
			var current  = vertical ? my : mx;
			// vertical:   drag up   = higher value  (startMouse - current > 0)
			// horizontal: drag right = higher value  (current - startMouse > 0)
			var delta:Float;
			if (vertical) delta = (_dragStartMouse - current) / dragSensitivity * range;
			else          delta = (current - _dragStartMouse) / dragSensitivity * range;
			value = _dragStartValue + delta;
		}

		// Keyboard: bindings depend on orientation
		if (_hovered || _dragging) {
			var dir = 0;
			if (vertical) {
				// ↑ = more,  ↓ = less
				if (FlxG.keys.justPressed.UP)   dir =  1;
				if (FlxG.keys.justPressed.DOWN) dir = -1;
			} else {
				// → = more,  ← = less
				if (FlxG.keys.justPressed.RIGHT) dir =  1;
				if (FlxG.keys.justPressed.LEFT)  dir = -1;
			}
			// Mouse wheel always works
			if (FlxG.mouse.wheel != 0) dir = (FlxG.mouse.wheel > 0) ? 1 : -1;
			if (dir != 0) value = _value + dir * step;
		}

		_knob.alpha = _dragging ? 1.0 : (_hovered ? 0.92 : 0.82);
	}

	// ── Helpers ────────────────────────────────────────────────────────────
	function _clamp(v:Float):Float {
		if (v < minValue) return minValue;
		if (v > maxValue) return maxValue;
		return v;
	}

	function _formatValue(v:Float):String {
		if (decimals <= 0) return Std.string(Std.int(v));
		var factor = Math.pow(10, decimals);
		return Std.string(Math.round(v * factor) / factor);
	}

	override public function destroy():Void {
		onChange = null;
		super.destroy();
	}
}
