package coolui;

import coolui.CoolTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * CoolColorPicker — Inline HSV color picker.
 *
 * Usage:
 *   var cp = new CoolColorPicker(x, y);
 *   cp.color    = 0xFF00E5FF;  // set initial color (ARGB)
 *   cp.onChange = function(c:Int) { mySprite.color = c; };
 *
 * Layout (all pixel-drawn, no external assets):
 *   ┌───────────────────┐
 *   │  SV square  │ Hue │  ← saturation/value square + hue strip
 *   ├─────────────────── │
 *   │ Alpha strip        │
 *   ├──── preview ───────│
 *   │ #RRGGBB  [hex box] │  ← hex input
 *   └────────────────────┘
 */
class CoolColorPicker extends FlxSpriteGroup {
	// ── Layout constants ──────────────────────────────────────────────────────
	static inline var SV_SIZE:Int = 96; // saturation-value square size
	static inline var HUE_W:Int = 14; // hue strip width
	static inline var ALPHA_H:Int = 10; // alpha strip height
	static inline var PREVIEW_H:Int = 14; // color preview bar height
	static inline var GAP:Int = 4; // gap between sections
	static inline var TOTAL_W:Int = SV_SIZE + GAP + HUE_W;

	// ── Public API ────────────────────────────────────────────────────────────
	public var onChange:Int->Void;

	/** Current color as ARGB int (0xAARRGGBB). */
	public var color(get, set):Int;

	// ── Internal state ────────────────────────────────────────────────────────
	var _h:Float = 0; // hue 0-360
	var _s:Float = 1; // saturation 0-1
	var _v:Float = 1; // value 0-1
	var _a:Float = 1; // alpha 0-1

	var _svSprite:FlxSprite;
	var _hueBitmap:FlxSprite;
	var _alphaBitmap:FlxSprite;
	var _preview:FlxSprite;
	var _svThumb:FlxSprite;
	var _hueThumb:FlxSprite;
	var _alphaThumb:FlxSprite;
	var _hexField:CoolInputText;

	var _draggingSV:Bool = false;
	var _draggingHue:Bool = false;
	var _draggingAlpha:Bool = false;

	var _svY:Int; // y offset of SV square
	var _hueY:Int;
	var _alphaY:Int;
	var _previewY:Int;
	var _hexY:Int;
	var _totalH:Int;

	public function new(px:Float = 0, py:Float = 0) {
		super(px, py);
		_svY = 0;
		_hueY = _svY;
		_alphaY = SV_SIZE + GAP;
		_previewY = _alphaY + ALPHA_H + GAP;
		_hexY = _previewY + PREVIEW_H + GAP;
		_totalH = _hexY + 20;
		_build();
	}

	function get_color():Int {
		var rgb = _hsvToRgb(_h, _s, _v);
		var alpha = Std.int(_a * 255);
		return (alpha << 24) | (rgb & 0x00FFFFFF);
	}

	function set_color(v:Int):Int {
		var fc = FlxColor.fromInt(v);
		_a = fc.alphaFloat;
		var r = fc.redFloat;
		var g = fc.greenFloat;
		var b = fc.blueFloat;
		_rgbToHsv(r, g, b);
		_refreshAll();
		return v;
	}

	// ── Build ─────────────────────────────────────────────────────────────────
	function _build():Void {
		var T = coolui.CoolUITheme.current;

		// SV square
		_svSprite = new FlxSprite(0, _svY);
		_svSprite.makeGraphic(SV_SIZE, SV_SIZE, FlxColor.WHITE);
		_svSprite.scrollFactor.set(0, 0);
		add(_svSprite);

		// Hue strip
		_hueBitmap = new FlxSprite(SV_SIZE + GAP, _hueY);
		_hueBitmap.makeGraphic(HUE_W, SV_SIZE, FlxColor.WHITE);
		_hueBitmap.scrollFactor.set(0, 0);
		add(_hueBitmap);

		// Alpha strip
		_alphaBitmap = new FlxSprite(0, _alphaY);
		_alphaBitmap.makeGraphic(TOTAL_W, ALPHA_H, FlxColor.WHITE);
		_alphaBitmap.scrollFactor.set(0, 0);
		add(_alphaBitmap);

		// Preview
		_preview = new FlxSprite(0, _previewY);
		_preview.makeGraphic(TOTAL_W, PREVIEW_H, FlxColor.WHITE);
		_preview.scrollFactor.set(0, 0);
		add(_preview);

		// Thumbs (small crosshairs/indicators)
		_svThumb = new FlxSprite(0, _svY);
		_svThumb.makeGraphic(5, 5, FlxColor.TRANSPARENT);
		_svThumb.scrollFactor.set(0, 0);
		_drawCrosshair(_svThumb);
		add(_svThumb);

		_hueThumb = new FlxSprite(SV_SIZE + GAP - 1, _hueY);
		_hueThumb.makeGraphic(HUE_W + 2, 3, 0xFFFFFFFF);
		_hueThumb.scrollFactor.set(0, 0);
		add(_hueThumb);

		_alphaThumb = new FlxSprite(0, _alphaY - 1);
		_alphaThumb.makeGraphic(3, ALPHA_H + 2, 0xFFFFFFFF);
		_alphaThumb.scrollFactor.set(0, 0);
		add(_alphaThumb);

		// Hex input
		_hexField = new CoolInputText(0, _hexY, TOTAL_W, "", 8);
		_hexField.maxLength = 8;
		_hexField.scrollFactor.set(0, 0);
		_hexField.onEnterPressed = function() _applyHex(_hexField.text);
		_hexField.onFocusLost = function() _applyHex(_hexField.text);
		add(_hexField);

		_refreshAll();
		_paintHueStrip();
		_paintAlphaStrip();
	}

	function _drawCrosshair(s:FlxSprite):Void {
		var p = s.pixels;
		var w = s.frameWidth;
		var h = s.frameHeight;
		var c = FlxColor.WHITE;
		var c2 = FlxColor.BLACK;
		// Outer
		for (i in 0...w) {
			p.setPixel32(i, 0, c);
			p.setPixel32(i, h - 1, c);
		}
		for (j in 0...h) {
			p.setPixel32(0, j, c);
			p.setPixel32(w - 1, j, c);
		}
		// Center cut
		p.setPixel32(Std.int(w / 2), Std.int(h / 2), c2);
		s.pixels = p;
	}

	// ── Rendering ─────────────────────────────────────────────────────────────
	function _paintSVSquare():Void {
		var p = _svSprite.pixels;
		var w = SV_SIZE;
		var h = SV_SIZE;
		for (py in 0...h) {
			var sv = 1.0 - py / (h - 1); // value: top=1, bottom=0
			for (px in 0...w) {
				var ss = px / (w - 1); // saturation: left=0, right=1
				var rgb = _hsvToRgb(_h, ss, sv);
				p.setPixel32(px, py, rgb | 0xFF000000);
			}
		}
		_svSprite.pixels = p;
	}

	function _paintHueStrip():Void {
		var p = _hueBitmap.pixels;
		var h = SV_SIZE;
		for (py in 0...h) {
			var hue = (1.0 - py / (h - 1)) * 360;
			var rgb = _hsvToRgb(hue, 1, 1);
			for (px in 0...HUE_W)
				p.setPixel32(px, py, rgb | 0xFF000000);
		}
		_hueBitmap.pixels = p;
	}

	function _paintAlphaStrip():Void {
		var p = _alphaBitmap.pixels;
		var rgb = _hsvToRgb(_h, _s, _v) & 0x00FFFFFF;
		for (px in 0...TOTAL_W) {
			var a = Std.int((px / (TOTAL_W - 1)) * 255);
			for (py in 0...ALPHA_H)
				p.setPixel32(px, py, (a << 24) | rgb | 0x80808080);
		}
		_alphaBitmap.pixels = p;
	}

	function _paintPreview():Void {
		var p = _preview.pixels;
		var c = get_color();
		for (py in 0...PREVIEW_H)
			for (px in 0...TOTAL_W)
				p.setPixel32(px, py, c);
		_preview.pixels = p;
	}

	function _refreshAll():Void {
		_paintSVSquare();
		_paintAlphaStrip();
		_paintPreview();
		_syncThumbs();
		_syncHexField();
	}

	function _syncThumbs():Void {
		_svThumb.x = x + Std.int(_s * (SV_SIZE - 1)) - 2;
		_svThumb.y = y + _svY + Std.int((1 - _v) * (SV_SIZE - 1)) - 2;

		_hueThumb.y = y + _hueY + Std.int((1 - _h / 360) * (SV_SIZE - 1));

		_alphaThumb.x = x + Std.int(_a * (TOTAL_W - 1)) - 1;
		_alphaThumb.y = y + _alphaY - 1;
	}

	function _syncHexField():Void {
		if (_hexField == null)
			return;
		var c = get_color();
		var fc = FlxColor.fromInt(c);
		_hexField.text = StringTools.hex(fc.red, 2) + StringTools.hex(fc.green, 2) + StringTools.hex(fc.blue, 2) + StringTools.hex(fc.alpha, 2);
	}

	function _applyHex(s:String):Void {
		s = s.toUpperCase();
		var len = s.length;
		var parsed:Null<Int> = null;
		try {
			if (len == 6)
				parsed = Std.parseInt("0xFF" + s);
			else if (len == 8)
				parsed = Std.parseInt("0x" + s.substr(6, 2) + s.substr(0, 6));
		} catch (_) {}
		if (parsed != null)
			color = parsed;
	}

	function _fireChange():Void {
		if (onChange != null)
			onChange(get_color());
	}

	// ── Update ────────────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		var mp = FlxG.mouse.getWorldPosition(camera);
		var mx = mp.x - x;
		var my = mp.y - y;
		mp.put();

		// SV square drag
		var inSV = mx >= 0 && mx < SV_SIZE && my >= _svY && my < _svY + SV_SIZE;
		if (inSV && FlxG.mouse.justPressed)
			_draggingSV = true;
		if (!FlxG.mouse.pressed)
			_draggingSV = false;
		if (_draggingSV) {
			_s = Math.max(0, Math.min(1, mx / (SV_SIZE - 1)));
			_v = Math.max(0, Math.min(1, 1 - (my - _svY) / (SV_SIZE - 1)));
			_refreshAll();
			_fireChange();
		}

		// Hue strip drag
		var inHue = mx >= SV_SIZE + GAP && mx < SV_SIZE + GAP + HUE_W && my >= _hueY && my < _hueY + SV_SIZE;
		if (inHue && FlxG.mouse.justPressed)
			_draggingHue = true;
		if (!FlxG.mouse.pressed)
			_draggingHue = false;
		if (_draggingHue) {
			_h = (1 - Math.max(0, Math.min(1, (my - _hueY) / (SV_SIZE - 1)))) * 360;
			_paintSVSquare();
			_syncThumbs();
			_paintAlphaStrip();
			_paintPreview();
			_syncHexField();
			_fireChange();
		}

		// Alpha strip drag
		var inAlpha = mx >= 0 && mx < TOTAL_W && my >= _alphaY && my < _alphaY + ALPHA_H;
		if (inAlpha && FlxG.mouse.justPressed)
			_draggingAlpha = true;
		if (!FlxG.mouse.pressed)
			_draggingAlpha = false;
		if (_draggingAlpha) {
			_a = Math.max(0, Math.min(1, mx / (TOTAL_W - 1)));
			_paintPreview();
			_syncThumbs();
			_syncHexField();
			_fireChange();
		}

		// Sync thumb screen positions (in case the group moved)
		_syncThumbs();
	}

	// ── Color math ────────────────────────────────────────────────────────────
	function _hsvToRgb(hDeg:Float, s:Float, v:Float):Int {
		if (s == 0) {
			var g = Std.int(v * 255);
			return (g << 16) | (g << 8) | g;
		}
		var h6 = hDeg / 60;
		var i = Std.int(h6);
		var f = h6 - i;
		var p = v * (1 - s);
		var q = v * (1 - s * f);
		var t = v * (1 - s * (1 - f));
		var r:Float;
		var g:Float;
		var b:Float;
		switch (i % 6) {
			case 0:
				r = v;
				g = t;
				b = p;
			case 1:
				r = q;
				g = v;
				b = p;
			case 2:
				r = p;
				g = v;
				b = t;
			case 3:
				r = p;
				g = q;
				b = v;
			case 4:
				r = t;
				g = p;
				b = v;
			default:
				r = v;
				g = p;
				b = q;
		}
		return (Std.int(r * 255) << 16) | (Std.int(g * 255) << 8) | Std.int(b * 255);
	}

	function _rgbToHsv(r:Float, g:Float, b:Float):Void {
		var max = Math.max(r, Math.max(g, b));
		var min = Math.min(r, Math.min(g, b));
		var delta = max - min;
		_v = max;
		_s = (max == 0) ? 0 : delta / max;
		if (delta == 0) {
			_h = 0;
			return;
		}
		if (max == r)
			_h = 60 * (((g - b) / delta) % 6);
		else if (max == g)
			_h = 60 * ((b - r) / delta + 2);
		else
			_h = 60 * ((r - g) / delta + 4);
		if (_h < 0)
			_h += 360;
	}

	override public function destroy():Void {
		onChange = null;
		super.destroy();
	}
}
