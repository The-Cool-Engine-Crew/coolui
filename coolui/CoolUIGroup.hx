package coolui;

import flixel.FlxBasic;
import flixel.group.FlxSpriteGroup;

/**
 * CoolUIGroup — Drop-in replacement for `FlxUIGroup`.
 *
 * NEW: Optional auto-layout system. Call `setLayout(...)` then `doLayout()`
 * to automatically position children in rows, columns, or a grid.
 *
 * Usage:
 *   var g = new CoolUIGroup();
 *   g.setLayout(CoolUIGroup.LAYOUT_VERTICAL, 4, 8);
 *   g.add(btn1); g.add(btn2); g.add(btn3);
 *   g.doLayout();          // positions children top-to-bottom with 4px spacing
 *   g.doLayout(true);      // same + updates on every subsequent add/remove
 */
class CoolUIGroup extends FlxSpriteGroup {
	// ── Layout modes ──────────────────────────────────────────────────────────
	public static inline var LAYOUT_NONE:Int       = 0;
	public static inline var LAYOUT_HORIZONTAL:Int = 1;
	public static inline var LAYOUT_VERTICAL:Int   = 2;
	public static inline var LAYOUT_GRID:Int       = 3;

	/** Name used by `CoolTabMenu` to identify this group. */
	public var name:String = "";

	// ── Layout properties ─────────────────────────────────────────────────────
	/** Pixels between children along the primary axis. */
	public var spacing:Int = 4;
	/** Padding inside the group edges (applied to x and y of first child). */
	public var padding:Int = 0;
	/** Number of columns for LAYOUT_GRID. */
	public var gridColumns:Int = 2;
	/** When true, `doLayout()` is called automatically after each `add()`. */
	public var autoLayout:Bool = false;

	var _layoutMode:Int = LAYOUT_NONE;

	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);
	}

	/**
	 * Set the layout mode and optional spacing / padding.
	 * @param mode     One of LAYOUT_* constants
	 * @param spacing  Gap between children in pixels (default 4)
	 * @param padding  Inset from group origin for first child (default 0)
	 */
	public function setLayout(mode:Int, spacing:Int = 4, padding:Int = 0):Void {
		_layoutMode  = mode;
		this.spacing = spacing;
		this.padding = padding;
	}

	/**
	 * Positions all live children according to the current layout mode.
	 * Ignores dead / invisible children.
	 *
	 * @param auto  When true, sets `autoLayout = true` so future adds
	 *              automatically trigger a re-layout.
	 */
	public function doLayout(auto:Bool = false):Void {
		if (auto) autoLayout = true;
		if (_layoutMode == LAYOUT_NONE) return;

		var alive = [for (m in members) if (m != null && m.alive && m.exists) m];
		if (alive.length == 0) return;

		var cx = padding;
		var cy = padding;
		var col = 0;
		var rowH = 0;

		for (child in alive) {
			var sp = Std.downcast(child, flixel.FlxSprite);
			var cw = (sp != null) ? Std.int(sp.width)  : 0;
			var ch = (sp != null) ? Std.int(sp.height) : 0;

			switch (_layoutMode) {
				case LAYOUT_HORIZONTAL:
					child.x = cx;
					child.y = cy;
					cx += cw + spacing;

				case LAYOUT_VERTICAL:
					child.x = cx;
					child.y = cy;
					cy += ch + spacing;

				case LAYOUT_GRID:
					child.x = padding + col * (cw + spacing);
					child.y = cy;
					if (ch > rowH) rowH = ch;
					col++;
					if (col >= gridColumns) {
						col = 0;
						cy += rowH + spacing;
						rowH = 0;
					}

				default:
			}
		}
	}

	override public function add(basic:FlxBasic):FlxBasic {
		var result = super.add(basic);
		if (autoLayout && _layoutMode != LAYOUT_NONE) doLayout();
		return result;
	}

	override public function remove(basic:FlxBasic, splice:Bool = false):FlxBasic {
		var result = super.remove(basic, splice);
		if (autoLayout && _layoutMode != LAYOUT_NONE) doLayout();
		return result;
	}
}
