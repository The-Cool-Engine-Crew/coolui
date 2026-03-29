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
 * CoolSlider — Horizontal or vertical value slider.
 *
 * Usage:
 *   var s = new CoolSlider(x, y, 0, 100, 50, 200);      // horizontal, 0-100, value 50, 200px wide
 *   var v = new CoolSlider(x, y, 0, 1, 0.5, 120, true); // vertical
 *   s.onChange = function(v:Float) { trace(v); };
 *   s.showValue = true;   // draws current value as text next to the thumb
 *
 * Controls:
 *   Drag the thumb with the mouse.
 *   Click anywhere on the track to jump.
 *   Left/Right (or Up/Down for vertical) arrows when hovered change by `step`.
 *   Mouse wheel changes by `step`.
 */
class CoolSlider extends FlxSpriteGroup {
	static inline var THUMB_W:Int  = 8;
	static inline var THUMB_H:Int  = 16;
	static inline var TRACK_H:Int  = 4;

	// ── Public API ────────────────────────────────────────────────────────────
	public var onChange:Float->Void;

	public var value(get, set):Float;
	public var minValue:Float;
	public var maxValue:Float;
	public var step:Float;
	public var vertical:Bool;
	public var showValue:Bool = false;
	public var decimals:Int   = 0;

	// ── Internals ─────────────────────────────────────────────────────────────
	var _value:Float;
	var _trackLen:Int;   // usable length (width or height depending on orientation)
	var _track:FlxSprite;
	var _fill:FlxSprite;
	var _thumb:FlxSprite;
	var _valueLabel:FlxText;
	var _dragging:Bool  = false;
	var _hovered:Bool   = false;
	var _tween:FlxTween;

	/**
	 * @param px         X
	 * @param py         Y
	 * @param min        Minimum value
	 * @param max        Maximum value
	 * @param value      Initial value
	 * @param trackLen   Length of the slider track in pixels
	 * @param vertical   True for a vertical slider
	 * @param step       Arrow-key / wheel step (default 1)
	 */
	public function new(px:Float = 0, py:Float = 0, min:Float = 0, max:Float = 1,
	                    value:Float = 0, trackLen:Int = 120, vertical:Bool = false, step:Float = 1) {
		super(px, py);
		minValue  = min;
		maxValue  = max;
		this.step = step;
		this.vertical = vertical;
		_trackLen = (trackLen > THUMB_W * 2) ? trackLen : THUMB_W * 2;
		_value    = _clamp(value);
		_build();
	}

	// ── Getters / Setters ─────────────────────────────────────────────────────
	function get_value():Float return _value;
	function set_value(v:Float):Float {
		var clamped = _clamp(v);
		if (clamped == _value) return _value;
		_value = clamped;
		_syncThumb();
		if (onChange != null) onChange(_value);
		return _value;
	}

	// ── Build ─────────────────────────────────────────────────────────────────
	function _build():Void {
		var T = coolui.CoolUITheme.current;

		var tw = vertical ? THUMB_H : _trackLen;
		var th = vertical ? _trackLen : THUMB_H;
		var tx = vertical ? Std.int((THUMB_H - TRACK_H) / 2) : 0;
		var ty = vertical ? 0 : Std.int((THUMB_H - TRACK_H) / 2);
		var tLen = vertical ? th : tw;
		var tW   = vertical ? TRACK_H : tLen;
		var tH   = vertical ? tLen : TRACK_H;

		// Track background
		_track = new FlxSprite(tx, ty);
		_track.makeGraphic(tW, tH, T.bgHover);
		_track.scrollFactor.set(0, 0);
		var brd = FlxColor.fromInt(T.borderColor);
		brd.alphaFloat = 0.5;
		_drawBorder(_track, brd);
		add(_track);

		// Fill (accent color, same shape but shorter)
		_fill = new FlxSprite(tx, ty);
		_fill.makeGraphic(vertical ? TRACK_H : 1, vertical ? 1 : TRACK_H, FlxColor.fromInt(T.accent));
		_fill.scrollFactor.set(0, 0);
		add(_fill);

		// Thumb
		_thumb = new FlxSprite(0, 0);
		_thumb.makeGraphic(vertical ? THUMB_H : THUMB_W, vertical ? THUMB_W : THUMB_H, FlxColor.TRANSPARENT);
		_thumb.scrollFactor.set(0, 0);
		_drawThumb(_thumb, FlxColor.fromInt(T.accent), FlxColor.fromInt(T.bgPanel));
		add(_thumb);

		// Value label
		_valueLabel = new FlxText(0, 0, 50, "", 8);
		_valueLabel.color = FlxColor.fromInt(T.textSecondary);
		_valueLabel.scrollFactor.set(0, 0);
		_valueLabel.visible = showValue;
		add(_valueLabel);

		_syncThumb();
	}

	function _drawBorder(s:FlxSprite, c:FlxColor):Void {
		var w = s.frameWidth; var h = s.frameHeight; var p = s.pixels;
		for (i in 0...w) { p.setPixel32(i, 0, c); p.setPixel32(i, h-1, c); }
		for (j in 0...h) { p.setPixel32(0, j, c); p.setPixel32(w-1, j, c); }
		s.pixels = p;
	}

	function _drawThumb(s:FlxSprite, fill:FlxColor, bg:FlxColor):Void {
		var w = s.frameWidth; var h = s.frameHeight; var p = s.pixels;
		for (py in 0...h) for (px in 0...w) {
			if (px == 0 || px == w-1 || py == 0 || py == h-1) p.setPixel32(px, py, fill);
			else p.setPixel32(px, py, bg);
		}
		// Accent center line
		var cx = Std.int(w / 2); var cy = Std.int(h / 2);
		if (vertical) { for (px in 2...w-2) p.setPixel32(px, cy, fill); }
		else          { for (py in 2...h-2) p.setPixel32(cx, py, fill); }
		s.pixels = p;
	}

	// ── Thumb sync ─────────────────────────────────────────────────────────────
	function _syncThumb():Void {
		var ratio   = (maxValue > minValue) ? (_value - minValue) / (maxValue - minValue) : 0.0;
		var usable  = _trackLen - (vertical ? THUMB_W : THUMB_W);

		if (vertical) {
			var fillH   = Std.int(ratio * usable);
			var thumbY  = Std.int(ratio * usable);
			_thumb.y    = thumbY;
			_fill.y     = 0;
			_fill.setGraphicSize(TRACK_H, fillH + Std.int(THUMB_W / 2));
			_fill.updateHitbox();
		} else {
			var fillW   = Std.int(ratio * usable);
			var thumbX  = Std.int(ratio * usable);
			_thumb.x    = thumbX;
			_fill.x     = Std.int((THUMB_H - TRACK_H) / 2);
			_fill.setGraphicSize(fillW + Std.int(THUMB_W / 2), TRACK_H);
			_fill.updateHitbox();
		}

		if (showValue && _valueLabel != null) {
			_valueLabel.text = _formatValue(_value);
			_valueLabel.visible = true;
			if (vertical) { _valueLabel.x = THUMB_H + 4; _valueLabel.y = _thumb.y; }
			else          { _valueLabel.x = _trackLen + 4; _valueLabel.y = Std.int((THUMB_H - _valueLabel.height) / 2); }
		}
	}

	function _formatValue(v:Float):String {
		if (decimals <= 0) return Std.string(Std.int(v));
		var factor = Math.pow(10, decimals);
		return Std.string(Math.round(v * factor) / factor);
	}

	function _clamp(v:Float):Float {
		if (v < minValue) return minValue;
		if (v > maxValue) return maxValue;
		return v;
	}

	// ── Update ────────────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		var mp = FlxG.mouse.getWorldPosition(camera);
		var mx = mp.x; var my = mp.y;
		mp.put();

		// Bounds of the full widget
		var totalW = vertical ? THUMB_H : _trackLen;
		var totalH = vertical ? _trackLen : THUMB_H;
		_hovered   = mx >= x && mx <= x + totalW && my >= y && my <= y + totalH;

		// Start drag on click anywhere in the track
		if (_hovered && FlxG.mouse.justPressed) _dragging = true;
		if (!FlxG.mouse.pressed) _dragging = false;

		if (_dragging) {
			var ratio:Float;
			if (vertical) {
				var usable = _trackLen - THUMB_W;
				ratio = (my - y) / usable;
			} else {
				var usable = _trackLen - THUMB_W;
				ratio = (mx - x) / usable;
			}
			value = minValue + _clamp01(ratio) * (maxValue - minValue);
		}

		// Arrow keys + mouse wheel when hovered
		if (_hovered || _dragging) {
			var dir = 0;
			if (vertical) {
				if (FlxG.keys.justPressed.UP)   dir = -1;
				if (FlxG.keys.justPressed.DOWN) dir =  1;
			} else {
				if (FlxG.keys.justPressed.LEFT)  dir = -1;
				if (FlxG.keys.justPressed.RIGHT) dir =  1;
			}
			if (FlxG.mouse.wheel != 0) dir = (FlxG.mouse.wheel > 0) ? 1 : -1;
			if (dir != 0) value = _value + dir * step;
		}

		// Thumb hover highlight
		if (_thumb != null) _thumb.alpha = (_hovered || _dragging) ? 1.0 : 0.85;
	}

	inline function _clamp01(v:Float):Float return Math.max(0.0, Math.min(1.0, v));

	override public function destroy():Void {
		onChange = null;
		super.destroy();
	}
}
