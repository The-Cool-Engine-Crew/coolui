package coolui;

import coolui.CoolTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

/**
 * CoolProgressBar — Animated horizontal progress bar.
 *
 * Usage:
 *   var bar = new CoolProgressBar(x, y, 200, 16);
 *   bar.value = 0.75;          // 75% filled
 *   bar.showPercent = true;    // draws "75%" label inside the bar
 *   bar.animated   = true;     // smoothly tweens fill on value change (default true)
 *
 *   // Custom colors:
 *   bar.fillColor = 0xFF00FF88;
 *
 *   // Range mode (min/max instead of 0-1):
 *   bar.setRange(0, 100);
 *   bar.value = 42;            // displays 42/100
 */
class CoolProgressBar extends FlxSpriteGroup {
	// ── Public API ────────────────────────────────────────────────────────────
	public var value(get, set):Float;
	public var minValue:Float = 0;
	public var maxValue:Float = 1;
	public var animated:Bool  = true;
	public var showPercent:Bool = false;

	/** Override the fill colour (0 = use theme accent). */
	public var fillColor(get, set):Int;

	// ── Internals ─────────────────────────────────────────────────────────────
	var _value:Float   = 0;
	var _w:Int; var _h:Int;
	var _bg:FlxSprite;
	var _fill:FlxSprite;
	var _label:FlxText;
	var _fillColor:Int = 0;  // 0 = theme accent
	var _tween:FlxTween;
	var _fillRatio:Float = 0; // current visible fill 0-1, tweened independently

	public function new(px:Float = 0, py:Float = 0, width:Int = 160, height:Int = 14) {
		super(px, py);
		_w = (width  > 4) ? width  : 60;
		_h = (height > 4) ? height : 8;
		_build();
	}

	function get_value():Float return _value;
	function set_value(v:Float):Float {
		_value = Math.max(minValue, Math.min(maxValue, v));
		var ratio = (maxValue > minValue) ? (_value - minValue) / (maxValue - minValue) : 0.0;
		if (animated) {
			if (_tween != null) _tween.cancel();
			_tween = FlxTween.globalManager.tween(this, {_fillRatio: ratio}, 0.25,
				{ease: FlxEase.quartOut, onUpdate: function(_) _applyFill()});
		} else {
			_fillRatio = ratio;
			_applyFill();
		}
		return _value;
	}

	function get_fillColor():Int  return _fillColor;
	function set_fillColor(v:Int):Int {
		_fillColor = v;
		if (_fill != null) _fill.makeGraphic(1, _h - 2, v != 0 ? v : coolui.CoolUITheme.current.accent);
		return v;
	}

	/** Convenience: set min/max range then set value. */
	public function setRange(min:Float, max:Float):Void {
		minValue = min; maxValue = max;
	}

	function _build():Void {
		var T = coolui.CoolUITheme.current;
		var accentC = (_fillColor != 0) ? _fillColor : T.accent;

		// Background
		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(_w, _h, T.bgHover);
		_bg.scrollFactor.set(0, 0);
		var brd = FlxColor.fromInt(T.borderColor);
		brd.alphaFloat = 0.6;
		var p = _bg.pixels;
		for (i in 0..._w) { p.setPixel32(i, 0, brd); p.setPixel32(i, _h-1, brd); }
		for (j in 0..._h) { p.setPixel32(0, j, brd); p.setPixel32(_w-1, j, brd); }
		_bg.pixels = p;
		add(_bg);

		// Fill (1px wide initially; sized in _applyFill)
		_fill = new FlxSprite(1, 1);
		_fill.makeGraphic(1, _h - 2, accentC);
		_fill.scrollFactor.set(0, 0);
		add(_fill);

		// Label
		_label = new FlxText(0, 0, _w, "", 8);
		_label.alignment = CENTER;
		_label.color = FlxColor.fromInt(T.textPrimary);
		_label.scrollFactor.set(0, 0);
		_label.y = Std.int((_h - _label.height) / 2);
		add(_label);

		_applyFill();
	}

	function _applyFill():Void {
		if (_fill == null) return;
		var fillW = Std.int(_fillRatio * (_w - 2));
		if (fillW < 1) fillW = 1;
		_fill.setGraphicSize(fillW, _h - 2);
		_fill.updateHitbox();

		if (_label != null) {
			_label.visible = showPercent;
			if (showPercent) {
				var pct = Std.int(_fillRatio * 100);
				_label.text = '${pct}%';
			}
		}
	}

	override public function destroy():Void {
		if (_tween != null) { _tween.cancel(); _tween = null; }
		super.destroy();
	}
}
