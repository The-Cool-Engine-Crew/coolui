package coolui;

import flixel.FlxSprite;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;

/**
 * Cool9Slice — Reemplazo de `FlxUI9SliceSprite` sin flixel-ui.
 *
 * Renderiza un bitmap usando la técnica de los 9 slices: las esquinas se
 * mantienen sin escalar, los bordes escalan en un solo eje y el centro
 * escala en los dos ejes.
 *
 * Uso:
 *
 *   // Desde un asset
 *   var s = new Cool9Slice(x, y, "assets/images/panel.png",
 *                          new openfl.geom.Rectangle(8, 8, 8, 8),
 *                          200, 100);
 *
 *   // Redimensionar después
 *   s.resize(300, 150);
 *
 * @param sliceRect  Define los cortes: x/y = tamaño de la esquina superior-izquierda,
 *                   width/height = tamaño de la esquina inferior-derecha.
 *                   Si es null se usa un corte de 1/3 en cada dimensión.
 */
class Cool9Slice extends FlxSprite
{
	var _srcBmp   : BitmapData;
	var _slice    : Rectangle;
	var _tw       : Int;
	var _th       : Int;

	/**
	 * @param px        X
	 * @param py        Y
	 * @param bitmapOrPath  BitmapData o ruta al asset (String)
	 * @param slice     Rectángulo de corte 9-slice
	 * @param w         Ancho de destino
	 * @param h         Alto de destino
	 */
	public function new(px:Float = 0, py:Float = 0,
	                    bitmapOrPath:Dynamic,
	                    ?slice:Rectangle,
	                    w:Int = 100, h:Int = 100)
	{
		super(px, py);

		if (Std.isOfType(bitmapOrPath, BitmapData))
		{
			_srcBmp = (bitmapOrPath : BitmapData);
		}
		else if (Std.isOfType(bitmapOrPath, String))
		{
			try { _srcBmp = openfl.Assets.getBitmapData(bitmapOrPath); }
			catch (_:Dynamic) {}
		}

		if (_srcBmp == null)
		{
			// Fallback: rectángulo de color sólido
			_srcBmp = new BitmapData(16, 16, false, 0xFF444466);
		}

		_tw = (w > 0) ? w : 100;
		_th = (h > 0) ? h : 100;

		// Slice por defecto: 1/3 del origen en cada esquina
		_slice = slice ?? new Rectangle(
			Std.int(_srcBmp.width  / 3), Std.int(_srcBmp.height / 3),
			Std.int(_srcBmp.width  / 3), Std.int(_srcBmp.height / 3)
		);

		_render();
	}

	/** Redimensiona el sprite y re-renderiza los 9 slices. */
	public function resize(w:Float, h:Float):Void
	{
		_tw = Std.int(w);
		_th = Std.int(h);
		_render();
	}

	function _render():Void
	{
		var sw = _srcBmp.width;
		var sh = _srcBmp.height;

		var cx = Std.int(_slice.x);
		var cy = Std.int(_slice.y);
		var cr = Std.int(_slice.width);
		var cb = Std.int(_slice.height);

		// Ancho/alto del centro de la fuente
		var srcCW = sw - cx - cr;
		var srcCH = sh - cy - cb;

		// Ancho/alto del centro en destino
		var dstCW = _tw - cx - cr;
		var dstCH = _th - cy - cb;

		var dst = new BitmapData(_tw, _th, true, 0x00000000);

		// ── Las 9 regiones ────────────────────────────────────────────────
		// top-left corner
		_blit(dst, _srcBmp, 0,       0,       cx,    cy,    0,       0,       1,       1);
		// top-right corner
		_blit(dst, _srcBmp, sw-cr,   0,       cr,    cy,    _tw-cr,  0,       1,       1);
		// bottom-left corner
		_blit(dst, _srcBmp, 0,       sh-cb,   cx,    cb,    0,       _th-cb,  1,       1);
		// bottom-right corner
		_blit(dst, _srcBmp, sw-cr,   sh-cb,   cr,    cb,    _tw-cr,  _th-cb,  1,       1);

		// top edge (scale X)
		if (srcCW > 0 && dstCW > 0)
			_blit(dst, _srcBmp, cx, 0,    srcCW, cy,    cx, 0,    dstCW/srcCW, 1);
		// bottom edge (scale X)
		if (srcCW > 0 && dstCW > 0)
			_blit(dst, _srcBmp, cx, sh-cb, srcCW, cb,   cx, _th-cb, dstCW/srcCW, 1);
		// left edge (scale Y)
		if (srcCH > 0 && dstCH > 0)
			_blit(dst, _srcBmp, 0,  cy,   cx,    srcCH, 0,  cy,    1, dstCH/srcCH);
		// right edge (scale Y)
		if (srcCH > 0 && dstCH > 0)
			_blit(dst, _srcBmp, sw-cr, cy, cr, srcCH, _tw-cr, cy, 1, dstCH/srcCH);
		// center (scale X + Y)
		if (srcCW > 0 && srcCH > 0 && dstCW > 0 && dstCH > 0)
			_blit(dst, _srcBmp, cx, cy, srcCW, srcCH, cx, cy, dstCW/srcCW, dstCH/srcCH);

		pixels = dst;
	}

	static inline function _blit(dst:BitmapData, src:BitmapData,
	                              sx:Int, sy:Int, sw:Int, sh:Int,
	                              dx:Int, dy:Int, scaleX:Float, scaleY:Float):Void
	{
		if (sw <= 0 || sh <= 0) return;
		var m = new Matrix();
		m.scale(scaleX, scaleY);
		m.translate(dx, dy);
		dst.draw(src, m, null, null, new Rectangle(dx, dy, sw * scaleX, sh * scaleY), false);
	}

	override public function destroy():Void
	{
		_srcBmp = null;
		super.destroy();
	}
}
