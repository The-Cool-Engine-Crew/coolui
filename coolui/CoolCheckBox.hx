package coolui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;


/**
 * CoolCheckBox — Drop-in replacement for `FlxUICheckBox`, no flixel-ui required.
 *
 * API compatible:
 *
 *   var cb = new CoolCheckBox(x, y, null, null, "Etiqueta", 120);
 *   cb.checked  = true;
 *   cb.callback = function(v:Bool) { trace(v); };
 *
 * Parameters at positions 3 and 4 (on/off state text) are ignored
 * to maintain API compatibility with FlxUICheckBox.
 */
class CoolCheckBox extends FlxSpriteGroup
{
	static inline var BOX_SIZE : Int = 14;
	static inline var HEIGHT   : Int = 16;

	// ── Public API ──────────────────────────────────────────────────────────

	public var callback : Bool -> Void;

	public var checked(get, set) : Bool;

	// ── Internals ────────────────────────────────────────────────────────────

	var _box     : FlxSprite;
	var _check   : FlxSprite;
	var _label   : FlxText;
	var _checked : Bool;
	var _lw      : Int;
	var _tween   : FlxTween;

	// ── Constructor ──────────────────────────────────────────────────────────

	/**
	 * @param px          X
	 * @param py          Y
	 * @param onGfx       Ignored (FlxUICheckBox compat — was the "on" graphic)
	 * @param offGfx      Ignored (FlxUICheckBox compat — was the "off" graphic)
	 * @param label       Text shown to the right
	 * @param labelWidth  Label width in px
	 * @param checked     Initial checked state
	 */
	public function new(px:Float = 0, py:Float = 0,
	                    onGfx:Dynamic = null, offGfx:Dynamic = null,
	                    label:String = "", labelWidth:Int = 100,
	                    checked:Bool = false)
	{
		super(px, py);
		_lw      = labelWidth;
		_checked = checked;
		_build(label);
	}

	// ── Getter / Setter ──────────────────────────────────────────────────────

	function get_checked():Bool return _checked;

	function set_checked(v:Bool):Bool
	{
		if (_checked == v) return v;
		_checked = v;
		_animateCheck(v);
		return v;
	}

	// ── Build ────────────────────────────────────────────────────────────────

	function _build(label:String):Void
	{
		var T = coolui.CoolUITheme.current;

		// Box background
		_box = new FlxSprite(0, (HEIGHT - BOX_SIZE) >> 1);
		_box.makeGraphic(BOX_SIZE, BOX_SIZE, T.bgPanelAlt);
		// Border
		var brd = FlxColor.fromInt(T.borderColor);
		brd.alphaFloat = 0.8;
		_drawBorderr(_box, brd);
		add(_box);

		// Checkmark (✓)
		_check = new FlxSprite(2, (HEIGHT - BOX_SIZE) >> 1);
		_check.makeGraphic(BOX_SIZE - 4, BOX_SIZE - 4, FlxColor.TRANSPARENT);
		_drawCheck(_check, FlxColor.fromInt(T.accent));
		_check.alpha   = _checked ? 1.0 : 0.0;
		_check.visible = _checked;
		add(_check);

		// Label
		if (label != null && label.length > 0)
		{
			_label = new FlxText(BOX_SIZE + 4, 1, _lw, label, 8);
			_label.color = FlxColor.fromInt(T.textPrimary);
			_label.scrollFactor.set();
			add(_label);
		}
	}

	function _drawBorderr(s:FlxSprite, color:FlxColor):Void
	{
		var w = s.frameWidth;
		var h = s.frameHeight;
		var p = s.pixels;
		for (i in 0...w) { p.setPixel32(i, 0, color); p.setPixel32(i, h-1, color); }
		for (j in 0...h) { p.setPixel32(0, j, color); p.setPixel32(w-1, j, color); }
		s.pixels = p;
	}

	function _drawCheck(s:FlxSprite, color:FlxColor):Void
	{
		var p = s.pixels;
		var w = s.frameWidth;
		var h = s.frameHeight;
		// Draw ✓ as two line segments
		inline function px(ax:Int, ay:Int, bx:Int, by:Int):Void
		{
			var dx = bx - ax; var dy = by - ay;
			var steps = Std.int(Math.max(Math.abs(dx), Math.abs(dy)));
			for (i in 0...steps + 1)
			{
				var t = (steps == 0) ? 0.0 : i / steps;
				var px2 = Std.int(ax + t * dx);
				var py2 = Std.int(ay + t * dy);
				if (px2 >= 0 && px2 < w && py2 >= 0 && py2 < h)
					p.setPixel32(px2, py2, color);
			}
		}
		px(1, h >> 1, Std.int(w * 0.35), h - 2);
		px(Std.int(w * 0.35), h - 2, w - 1, 1);
		s.pixels = p;
	}

	function _animateCheck(on:Bool):Void
	{
		if (_tween != null) _tween.cancel();
		if (on)
		{
			_check.visible = true;
			_check.alpha   = 0;
			_tween = FlxTween.globalManager.tween(_check, {alpha: 1.0}, 0.1, {ease: FlxEase.quartOut});
		}
		else
		{
			_tween = FlxTween.globalManager.tween(_check, {alpha: 0.0}, 0.08, {
				ease: FlxEase.quartIn,
				onComplete: function(_) { _check.visible = false; }
			});
		}
	}

	/** FlxUICheckBox compat: returns the label FlxText. */
	public function getLabel():flixel.text.FlxText
		return _label;

	// ── Update ───────────────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (FlxG.mouse.justPressed)
		{
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			var totalW = BOX_SIZE + (_label != null ? 4 + _lw : 0);
			if (mx >= x && mx <= x + totalW && my >= y && my <= y + HEIGHT)
			{
				var newVal = !_checked;
				checked = newVal;
				if (callback != null) callback(newVal);
			}
		}
	}

	override public function destroy():Void
	{
		if (_tween != null) { _tween.cancel(); _tween = null; }
		callback = null;
		super.destroy();
	}
}
