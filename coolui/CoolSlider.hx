package coolui;

import coolui.CoolUITheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * CoolSlider — Horizontal or vertical linear slider.
 *
 * Can use a custom sprite image as the thumb (handle), or the built-in
 * procedural rectangle thumb.
 *
 * Usage — simple horizontal:
 *   var s = new CoolSlider(x, y, 0, 100, 50, 200);
 *   s.showValue = true;
 *   s.onChange  = function(v) trace(v);
 *
 * Usage — vertical with custom thumb image:
 *   var s = new CoolSlider(x, y, 0, 1, 0.5, 120, true, 1, "assets/images/knob.png");
 *
 * Controls:
 *   Drag the thumb or click anywhere on the track to jump.
 *   Left/Right (horizontal) or Up/Down (vertical) arrow keys when hovered.
 *   Mouse wheel when hovered.
 */
class CoolSlider extends FlxSpriteGroup {

	static inline var THUMB_W:Int = 12;
	static inline var THUMB_H:Int = 20;
	static inline var TRACK_H:Int = 4;

	// ── Public API ─────────────────────────────────────────────────────────
	public var onChange:Float->Void;

	public var value(get, set):Float;
	public var minValue:Float;
	public var maxValue:Float;
	public var step:Float;
	public var vertical:Bool;

	/** Show the current value as a label next to the thumb. */
	public var showValue:Bool = false;
	/** Decimal places in value label (0 = integer). */
	public var decimals:Int   = 0;

	// ── Internals ──────────────────────────────────────────────────────────
	var _value:Float;
	var _trackLen:Int;
	var _imagePath:String;
	var _thumbW:Int;
	var _thumbH:Int;

	var _track:FlxSprite;
	var _fill:FlxSprite;
	var _thumb:FlxSprite;
	var _label:FlxText;

	var _dragging:Bool = false;
	var _hovered:Bool  = false;

	/**
	 * @param px         X position
	 * @param py         Y position
	 * @param min        Minimum value
	 * @param max        Maximum value
	 * @param initValue  Initial value
	 * @param trackLen   Length of the track in pixels
	 * @param vertical   True for vertical orientation
	 * @param step       Arrow-key / wheel step (default 1)
	 * @param imagePath  Optional path to a custom thumb image asset.
	 *                   Pass null or "" to use the procedural thumb.
	 * @param thumbW     Width  of the custom thumb in pixels
	 * @param thumbH     Height of the custom thumb in pixels
	 */
	public function new(px:Float = 0, py:Float = 0, min:Float = 0, max:Float = 1,
	                    initValue:Float = 0, trackLen:Int = 120, vertical:Bool = false,
	                    step:Float = 1, imagePath:String = "assets/images/coolui_knob.png",
	                    thumbW:Int = 32, thumbH:Int = 32) {
		super(px, py);
		minValue       = min;
		maxValue       = max;
		this.step      = step;
		this.vertical  = vertical;
		_trackLen      = (trackLen > THUMB_W * 2) ? trackLen : THUMB_W * 2;
		_imagePath     = imagePath;
		_thumbW        = thumbW;
		_thumbH        = thumbH;
		_value         = _clamp(initValue);
		_build();
	}

	// ── Getters / Setters ──────────────────────────────────────────────────
	function get_value():Float return _value;
	function set_value(v:Float):Float {
		var c = _clamp(v);
		if (c == _value) return _value;
		_value = c;
		_syncThumb();
		if (onChange != null) onChange(_value);
		return _value;
	}

	// ── Build ──────────────────────────────────────────────────────────────
	function _build():Void {
		var T = CoolUITheme.current;
		var hasImage = (_imagePath != null && _imagePath.length > 0);

		var tW = hasImage ? _thumbW : (vertical ? THUMB_H : THUMB_W);
		var tH = hasImage ? _thumbH : (vertical ? THUMB_W : THUMB_H);

		var trackX = vertical ? Std.int((tW - TRACK_H) / 2) : 0;
		var trackY = vertical ? 0 : Std.int((tH - TRACK_H) / 2);
		var trackW = vertical ? TRACK_H : _trackLen;
		var trackH = vertical ? _trackLen : TRACK_H;

		_track = new FlxSprite(trackX, trackY);
		_track.makeGraphic(trackW, trackH, FlxColor.fromInt(T.bgHover));
		_track.scrollFactor.set(0, 0);
		var brd = FlxColor.fromInt(T.borderColor);
		brd.alphaFloat = 0.5;
		_drawBorder(_track, brd);
		add(_track);

		_fill = new FlxSprite(trackX, trackY);
		_fill.makeGraphic(
			vertical ? TRACK_H : 1,
			vertical ? 1 : TRACK_H,
			FlxColor.fromInt(T.accent)
		);
		_fill.scrollFactor.set(0, 0);
		add(_fill);

		if (hasImage) {
			_thumb = new FlxSprite(0, 0, _imagePath);
			_thumb.setGraphicSize(tW, tH);
			_thumb.updateHitbox();
		} else {
			_thumb = new FlxSprite(0, 0);
			_thumb.makeGraphic(tW, tH, FlxColor.TRANSPARENT);
			_drawProceduralThumb(FlxColor.fromInt(T.accent), FlxColor.fromInt(T.bgPanel));
		}
		_thumb.antialiasing = true;
		_thumb.scrollFactor.set(0, 0);
		add(_thumb);

		_label = new FlxText(0, 0, 50, "", 8);
		_label.color = FlxColor.fromInt(T.textSecondary);
		_label.scrollFactor.set(0, 0);
		_label.visible = false;
		add(_label);

		_syncThumb();
	}

	function _drawBorder(s:FlxSprite, c:FlxColor):Void {
		var w = s.frameWidth; var h = s.frameHeight; var p = s.pixels;
		for (i in 0...w) { p.setPixel32(i, 0, c); p.setPixel32(i, h-1, c); }
		for (j in 0...h) { p.setPixel32(0, j, c); p.setPixel32(w-1, j, c); }
		s.pixels = p;
	}

	function _drawProceduralThumb(fill:FlxColor, bg:FlxColor):Void {
		var w = _thumb.frameWidth; var h = _thumb.frameHeight; var p = _thumb.pixels;
		for (py in 0...h) for (px in 0...w) {
			if (px == 0 || px == w-1 || py == 0 || py == h-1)
				p.setPixel32(px, py, fill);
			else
				p.setPixel32(px, py, bg);
		}
		var cx = Std.int(w / 2); var cy = Std.int(h / 2);
		if (vertical) { for (px in 2...w-2) p.setPixel32(px, cy, fill); }
		else          { for (py in 2...h-2) p.setPixel32(cx, py, fill); }
		_thumb.pixels = p;
	}

	// ── Thumb sync ─────────────────────────────────────────────────────────
	function _syncThumb():Void {
		var ratio  = (maxValue > minValue) ? (_value - minValue) / (maxValue - minValue) : 0.0;
		var tW     = _thumb.frameWidth;
		var tH     = _thumb.frameHeight;
		var usable = _trackLen - (vertical ? tH : tW);

		if (vertical) {
			var pos  = Std.int(ratio * usable);
			_thumb.x = Std.int(_track.x - tW / 2 + TRACK_H / 2);
			_thumb.y = pos;
			_fill.x  = _track.x;
			_fill.y  = 0;
			_fill.setGraphicSize(TRACK_H, pos + Std.int(tH / 2));
			_fill.updateHitbox();
		} else {
			var pos  = Std.int(ratio * usable);
			_thumb.x = pos;
			_thumb.y = Std.int(_track.y - tH / 2 + TRACK_H / 2);
			_fill.x  = _track.x;
			_fill.y  = _track.y;
			_fill.setGraphicSize(pos + Std.int(tW / 2), TRACK_H);
			_fill.updateHitbox();
		}

		if (showValue && _label != null) {
			_label.text    = _formatValue(_value);
			_label.visible = true;
			if (vertical) {
				_label.x = _thumb.x + _thumb.frameWidth + 4;
				_label.y = _thumb.y + Std.int((_thumb.frameHeight - _label.height) / 2);
			} else {
				_label.x = _trackLen + 4;
				_label.y = _thumb.y + Std.int((_thumb.frameHeight - _label.height) / 2);
			}
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

		var totalW = vertical ? (_thumb.frameWidth  + 8) : _trackLen;
		var totalH = vertical ? _trackLen : (_thumb.frameHeight + 8);
		_hovered   = mx >= x && mx <= x + totalW && my >= y && my <= y + totalH;

		if (_hovered && FlxG.mouse.justPressed) _dragging = true;
		if (!FlxG.mouse.pressed) _dragging = false;

		if (_dragging) {
			var usable = _trackLen - (vertical ? _thumb.frameHeight : _thumb.frameWidth);
			var ratio:Float;
			if (vertical) ratio = (my - y) / usable;
			else          ratio = (mx - x) / usable;
			value = minValue + _clamp01(ratio) * (maxValue - minValue);
		}

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

		_thumb.alpha = (_dragging) ? 1.0 : (_hovered ? 0.92 : 0.82);
	}

	// ── Helpers ────────────────────────────────────────────────────────────
	function _clamp(v:Float):Float {
		if (v < minValue) return minValue;
		if (v > maxValue) return maxValue;
		return v;
	}

	function _clamp01(v:Float):Float return Math.max(0.0, Math.min(1.0, v));

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
