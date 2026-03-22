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
 * CoolButton — Drop-in replacement for `FlxUIButton` and `FlxButtonPlus`, no flixel-ui required.
 *
 * API compatible:
 *
 *   var btn = new CoolButton(x, y, "Click me", function() { trace("clicked"); });
 *   btn.resize(100, 24);
 *
 * Available styles:
 *  • `CoolButton.STYLE_DEFAULT`  — solid background with accent border
 *  • `CoolButton.STYLE_ACCENT`   — accent-coloured background
 *  • `CoolButton.STYLE_DANGER`   — red background (for destructive actions)
 *  • `CoolButton.STYLE_GHOST`    — border only, no background
 */
class CoolButton extends FlxSpriteGroup
{
	// ── Styles ──────────────────────────────────────────────────────────────
	public static inline var STYLE_DEFAULT : Int = 0;
	public static inline var STYLE_ACCENT  : Int = 1;
	public static inline var STYLE_DANGER  : Int = 2;
	public static inline var STYLE_GHOST   : Int = 3;

	static inline var DEFAULT_W : Int = 80;
	static inline var DEFAULT_H : Int = 20;

	// ── Public properties ─────────────────────────────────────────────────

	/** Callback fired on click. */
	public var onClick : Void -> Void;

	/** When false, the button ignores clicks and appears semi-transparent. */
	public var enabled(get, set) : Bool;

	// ── Internals ────────────────────────────────────────────────────────────

	var _bg      : FlxSprite;
	var _label   : FlxText;
	var _style   : Int;
	var _bw      : Int;
	var _bh      : Int;
	var _enabled : Bool = true;
	var _tween   : FlxTween;
	var _hover        : Bool = false;
	var _wasPressed   : Bool = false;
	/** True for ONE frame after the button is released while hovered. */
	public var justReleased : Bool = false;

	// ── Constructor ──────────────────────────────────────────────────────────

	/**
	 * @param px      X position
	 * @param py      Y position
	 * @param label   Button label text
	 * @param onClick Click callback
	 * @param width   Width (default 80)
	 * @param height  Height (default 20)
	 * @param style   One of STYLE_* (default STYLE_DEFAULT)
	 */
	public function new(px:Float = 0, py:Float = 0,
	                    label:String = "",
	                    ?onClick:Void->Void,
	                    width:Int = DEFAULT_W,
	                    height:Int = DEFAULT_H,
	                    style:Int = STYLE_DEFAULT)
	{
		super(px, py);
		this.onClick = onClick;
		_bw    = (width  > 0) ? width  : DEFAULT_W;
		_bh    = (height > 0) ? height : DEFAULT_H;
		_style = style;
		_build(label);
	}

	// ── Getter / Setter ──────────────────────────────────────────────────────

	function get_enabled():Bool return _enabled;
	function set_enabled(v:Bool):Bool
	{
		_enabled = v;
		alpha = v ? 1.0 : 0.45;
		return v;
	}

	// ── Build ────────────────────────────────────────────────────────────────

	/**
	 * FlxButtonPlus/FlxUIButton compat: changes the label font, size and colour.
	 */
	public function setLabelFormat(?font:String, size:Int = 8, color:Int = 0xFFFFFFFF,
	                               alignment:String = "center"):Void
	{
		if (_label == null) return;
		if (font != null) _label.font = font;
		_label.size      = size;
		_label.color     = flixel.util.FlxColor.fromInt(color);
		_label.alignment = switch (alignment.toLowerCase()) {
			case "left":  LEFT;
			case "right": RIGHT;
			default:      CENTER;
		};
		_label.y = Std.int((_bh - _label.height) * 0.5);
	}

	public function resize(w:Float, h:Float):Void
	{
		_bw = Std.int(w); _bh = Std.int(h);
		var lbl = (_label != null) ? _label.text : "";
		for (m in members) { remove(m, true); m.destroy(); }
		members.resize(0);
		_build(lbl);
	}

	function _build(labelText:String):Void
	{
		var T    = coolui.CoolUITheme.current;
		var bgC  = _bgColor(T);
		var brdC = _borderColor(T);
		var txtC = _textColor(T);

		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(_bw, _bh, bgC);
		_drawBorderr(_bg, brdC);
		add(_bg);

		_label = new FlxText(2, 0, _bw - 4, labelText, 8);
		_label.alignment = CENTER;
		_label.color = FlxColor.fromInt(txtC);
		_label.y = Std.int((_bh - _label.height) * 0.5);
		_label.scrollFactor.set();
		add(_label);
	}

	function _bgColor(T:CoolTheme):Int
	{
		return switch (_style)
		{
			case STYLE_ACCENT:  T.accent;
			case STYLE_DANGER:  T.error;
			case STYLE_GHOST:   FlxColor.TRANSPARENT;
			default:            T.bgHover;
		};
	}

	function _borderColor(T:CoolTheme):Int
	{
		return switch (_style)
		{
			case STYLE_ACCENT: T.accent;
			case STYLE_DANGER: T.error;
			case STYLE_GHOST:  T.borderColor;
			default:           T.borderColor;
		};
	}

	function _textColor(T:CoolTheme):Int
	{
		return switch (_style)
		{
			case STYLE_ACCENT: T.bgDark;
			default:           T.textPrimary;
		};
	}

	function _drawBorderr(s:FlxSprite, color:Int):Void
	{
		var w = s.frameWidth; var h = s.frameHeight;
		var c = FlxColor.fromInt(color);
		c.alphaFloat = 0.75;
		var p = s.pixels;
		for (i in 0...w) { p.setPixel32(i, 0, c); p.setPixel32(i, h-1, c); }
		for (j in 0...h) { p.setPixel32(0, j, c); p.setPixel32(w-1, j, c); }
		s.pixels = p;
	}

	// ── Update ───────────────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		justReleased = false;
		if (!_enabled) return;

		var mx = FlxG.mouse.x; var my = FlxG.mouse.y;
		var inBtn = mx >= x && mx <= x + _bw && my >= y && my <= y + _bh;
		if (inBtn && _wasPressed && FlxG.mouse.justReleased) justReleased = true;
		_wasPressed = inBtn && FlxG.mouse.pressed;

		if (inBtn != _hover)
		{
			_hover = inBtn;
			if (_tween != null) _tween.cancel();
			_tween = FlxTween.globalManager.tween(
				_bg, {alpha: _hover ? 1.3 : 1.0}, 0.08, {ease: FlxEase.quartOut}
			);
		}

		if (inBtn && FlxG.mouse.justPressed)
		{
			_flashPress();
			if (onClick != null) onClick();
		}
	}

	function _flashPress():Void
	{
		if (_tween != null) _tween.cancel();
		_bg.alpha = 0.6;
		_tween = FlxTween.globalManager.tween(_bg, {alpha: 1.0}, 0.12, {ease: FlxEase.quartOut});
	}

	override public function destroy():Void
	{
		if (_tween != null) { _tween.cancel(); _tween = null; }
		onClick = null;
		super.destroy();
	}
}
