package coolui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

/**
 * CoolCheckBox — Drop-in replacement for `FlxUICheckBox`.
 * FIX: Mouse hit uses camera-aware position.
 */
class CoolCheckBox extends FlxSpriteGroup {
	static inline var BOX_SIZE:Int = 14;
	static inline var HEIGHT:Int   = 16;

	public var callback:Bool->Void;
	public var checked(get, set):Bool;

	var _box:FlxSprite;
	var _check:FlxSprite;
	var _label:FlxText;
	var _checked:Bool;
	var _lw:Int;
	var _tween:FlxTween;

	public function new(px:Float = 0, py:Float = 0, onGfx:Dynamic = null, offGfx:Dynamic = null,
	                    label:String = "", labelWidth:Int = 100, checked:Bool = false) {
		super(px, py);
		_lw      = labelWidth;
		_checked = checked;
		_build(label);
	}

	function get_checked():Bool return _checked;
	function set_checked(v:Bool):Bool {
		if (_checked == v) return v;
		_checked = v;
		_animateCheck(v);
		if (callback != null) callback(v);
		return v;
	}

	function _build(label:String):Void {
		var T = coolui.CoolUITheme.current;
		_box = new FlxSprite(0, (HEIGHT - BOX_SIZE) >> 1);
		_box.makeGraphic(BOX_SIZE, BOX_SIZE, T.bgPanelAlt);
		var brd = FlxColor.fromInt(T.borderColor);
		brd.alphaFloat = 0.8;
		_drawBorder(_box, brd);
		add(_box);

		_check = new FlxSprite(2, (HEIGHT - BOX_SIZE) >> 1);
		_check.makeGraphic(BOX_SIZE - 4, BOX_SIZE - 4, FlxColor.TRANSPARENT);
		_drawCheck(_check, FlxColor.fromInt(T.accent));
		_check.alpha   = _checked ? 1.0 : 0.0;
		_check.visible = _checked;
		add(_check);

		if (label != null && label.length > 0) {
			_label = new FlxText(BOX_SIZE + 4, 1, _lw, label, 10);
			_label.color = FlxColor.fromInt(T.textPrimary);
			_label.scrollFactor.set(0, 0);
			add(_label);
		}
	}

	function _drawBorder(s:FlxSprite, color:FlxColor):Void {
		var w = s.frameWidth; var h = s.frameHeight; var p = s.pixels;
		for (i in 0...w) { p.setPixel32(i, 0, color); p.setPixel32(i, h-1, color); }
		for (j in 0...h) { p.setPixel32(0, j, color); p.setPixel32(w-1, j, color); }
		s.pixels = p;
	}

	function _drawCheck(s:FlxSprite, color:FlxColor):Void {
		var p = s.pixels; var w = s.frameWidth; var h = s.frameHeight;
		inline function line(ax:Int, ay:Int, bx:Int, by:Int):Void {
			var dx = bx - ax; var dy = by - ay;
			var steps = Std.int(Math.max(Math.abs(dx), Math.abs(dy)));
			for (i in 0...steps + 1) {
				var t = (steps == 0) ? 0.0 : i / steps;
				var px2 = Std.int(ax + t * dx); var py2 = Std.int(ay + t * dy);
				if (px2 >= 0 && px2 < w && py2 >= 0 && py2 < h) p.setPixel32(px2, py2, color);
			}
		}
		line(1, h >> 1, Std.int(w * 0.35), h - 2);
		line(Std.int(w * 0.35), h - 2, w - 1, 1);
		s.pixels = p;
	}

	function _animateCheck(on:Bool):Void {
		if (_tween != null) _tween.cancel();
		if (on) {
			_check.visible = true; _check.alpha = 0;
			_tween = FlxTween.globalManager.tween(_check, {alpha: 1.0}, 0.1, {ease: FlxEase.quartOut});
		} else {
			_tween = FlxTween.globalManager.tween(_check, {alpha: 0.0}, 0.08, {
				ease: FlxEase.quartIn,
				onComplete: function(_) { _check.visible = false; }
			});
		}
	}

	public function getLabel():Null<flixel.text.FlxText> return _label;

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!FlxG.mouse.justPressed) return;
		// FIX: camera-aware mouse position
		var mp     = FlxG.mouse.getWorldPosition(camera);
		var totalW = BOX_SIZE + (_label != null ? 4 + _lw : 0);
		if (mp.x >= x && mp.x <= x + totalW && mp.y >= y && mp.y <= y + HEIGHT)
			checked = !_checked;
		mp.put();
	}

	override public function destroy():Void {
		if (_tween != null) { _tween.cancel(); _tween = null; }
		callback = null;
		super.destroy();
	}
}
