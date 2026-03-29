package coolui;

import coolui.CoolTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

typedef CoolTooltipStyle = { ?width:Float, ?height:Float, ?titleSize:Int, ?bodySize:Int }

class CoolTooltip extends FlxSpriteGroup {
	static inline var OFFSET_X:Float = 12;
	static inline var OFFSET_Y:Float = 6;

	static var _instance:CoolTooltip;

	public static function show(text:String, ?style:CoolTooltipStyle):Void {
		_ensureInstance();
		_instance._showText(text, style);
	}
	public static function hide():Void {
		if (_instance != null) _instance._hideTooltip();
	}

	static function _ensureInstance():Void {
		if (_instance != null && (!_instance.alive || !_instance.exists)) _instance = null;
		if (_instance == null) { _instance = new CoolTooltip(); FlxG.state.add(_instance); }
	}

	var _bg:FlxSprite;
	var _text:FlxText;
	var _tween:FlxTween;
	var _showing:Bool        = false;
	var _currentText:String  = "";
	var _currentWidth:Int    = 0;
	var _currentFontSize:Int = 0;

	function new() { super(0, 0); scrollFactor.set(0, 0); visible = false; }

	function _showText(text:String, ?style:CoolTooltipStyle):Void {
		var T  = coolui.CoolUITheme.current;
		var tw = (style?.width ?? 0.0) > 0 ? Std.int(style.width) : 160;
		var fs = (style?.bodySize ?? 0) > 0 ? style.bodySize : 8;
		if (text != _currentText || tw != _currentWidth || fs != _currentFontSize)
			_rebuild(text, tw, fs, T);
		visible = true; _showing = true; alpha = 0;
		if (_tween != null) _tween.cancel();
		_tween = FlxTween.globalManager.tween(this, {alpha: 1.0}, 0.12, {ease: FlxEase.quartOut});
	}

	function _hideTooltip():Void {
		if (!_showing) return;
		_showing = false;
		if (_tween != null) _tween.cancel();
		_tween = FlxTween.globalManager.tween(this, {alpha: 0.0}, 0.08, {
			ease: FlxEase.quartIn,
			onComplete: function(_) { visible = false; }
		});
	}

	function _rebuild(text:String, tw:Int, fontSize:Int, T:CoolTheme):Void {
		for (m in members) { remove(m, true); m.destroy(); }
		members.resize(0);
		_currentText = text; _currentWidth = tw; _currentFontSize = fontSize;
		var lbl = new FlxText(6, 4, tw - 12, text, fontSize);
		lbl.color = FlxColor.fromInt(T.textPrimary);
		lbl.scrollFactor.set(0, 0);
		var th = Std.int(lbl.height) + 10;
		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(tw, th, T.bgPanel);
		var brdC = FlxColor.fromInt(T.accent);
		brdC.alphaFloat = 0.6;
		var p = _bg.pixels;
		for (i in 0...tw) { p.setPixel32(i, 0, brdC); p.setPixel32(i, th-1, brdC); }
		for (j in 0...th) { p.setPixel32(0, j, brdC); p.setPixel32(tw-1, j, brdC); }
		_bg.pixels = p;
		_bg.scrollFactor.set(0, 0);
		add(_bg); add(lbl); _text = lbl;
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!_showing || !visible) return;
		var nx = FlxG.mouse.screenX + OFFSET_X;
		var ny = FlxG.mouse.screenY + OFFSET_Y;
		if (_bg != null) {
			if (nx + _bg.frameWidth  > FlxG.width)  nx = FlxG.mouse.screenX - _bg.frameWidth  - OFFSET_X;
			if (ny + _bg.frameHeight > FlxG.height) ny = FlxG.mouse.screenY - _bg.frameHeight - OFFSET_Y;
		}
		x = nx; y = ny;
	}

	override public function destroy():Void {
		if (_instance == this) _instance = null;
		if (_tween != null) { _tween.cancel(); _tween = null; }
		super.destroy();
	}
}

/**
 * CoolTooltipTarget — attaches tooltip behaviour to any sprite.
 *
 * NEW: `delay` property (default 0.4s) is now publicly settable.
 */
class CoolTooltipTarget extends FlxSpriteGroup {
	var _target:FlxSprite;
	var _tipText:String;
	var _timer:Float   = 0;
	var _visible:Bool  = false;

	/** Seconds to wait before showing the tooltip. Default 0.4. */
	public var delay:Float = 0.4;

	public function new(target:FlxSprite, tipText:String, w:Float = 0, h:Float = 0) {
		super(target.x, target.y);
		_target  = target;
		_tipText = tipText;
		add(target);
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		var mp       = FlxG.mouse.getWorldPosition(camera);
		var inBounds = mp.x >= x && mp.x <= x + _target.width && mp.y >= y && mp.y <= y + _target.height;
		mp.put();

		if (inBounds) {
			_timer += elapsed;
			if (_timer >= delay && !_visible) { _visible = true; CoolTooltip.show(_tipText); }
		} else {
			if (_visible) { CoolTooltip.hide(); _visible = false; }
			_timer = 0;
		}
	}

	override public function destroy():Void {
		if (_visible) { CoolTooltip.hide(); _visible = false; }
		super.destroy();
	}
}
