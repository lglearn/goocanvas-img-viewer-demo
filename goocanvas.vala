/**
 * Display images from a directory as Thumbnails, displays the full image when its thumbnail is clicked.
 * (Uses Vala + GTK2 + Goocanvas.)
 *
 * USAGE: ./goocanvas  [<directory name>]
 * When no directory is provided, the images from the current directory are displayed.
 *
 * This program is not finished and has a number of known bugs.
 * They will not get corrected as I've started a completely new version using GTK3.
 *
 * I'm making it available because it can help understand how to use GooCanvas.
 * The big problem with tutorials is that they only explain the basics, and an moderately complex
 * program goes far beyond their scope. On the other hand, real programs are usually so big and complex
 * that it's extremely difficult to extract the interesting part without a major learning curve.
 *
 * => This program is short enough to be understood, but complex enough to show how to use Goocanvas in a
 * real program.
 * 
 * Sorry for the lack of comments. It was a very experimental project and I don't much add
 * comments to those (too many changes).
 *
 * Major known bugs:
 *  - image not rotated
 *  - image resizing pb when resizing the window
 * 
 * License: GPLv3
 * */

// valac --pkg gtk+-2.0 --pkg goocanvas --pkg glib-2.0 --thread  --pkg gee-1.0 --target-glib=2.32 --debug   goocanvas.vala
// ( --Xcc=-O3 )
//    export CC=colorgcc
// OR export CC=clang
// export LD_LIBRARY_PATH=/usr/local/lib/gtk-2.0/modules
// GTK_MODULES=gtkparasite ./goocanvas
// debug: gdb ./goocanvas => run --g-fatal-warnings => bt (backtrace)
using Gtk;
using Gdk;
using Goo;
using Gee;
using Cairo;

string fn; // <================== AARRRGGGG!!!!!!!!!!!
string dir_name ;  // <================== AARRRGGGG!!!!!!!!!!!

protected class Thumbnail : GLib.Object {

	public string file_name;
	private GLib.File file;

	private CanvasItem root;
	private CanvasWidget thumb;
	private CanvasRect border_rect;
	private Pixbuf pixbuf;
	private	Gtk.DrawingArea drawing_area;
	private Gdk.Drawable draw;
	private Gdk.GC gc ;

	private int image_padding = 2; // space between image and border of thumbnail

	public enum img_status { UNKNOWN, LOADING, LOADED, EXPOSED }
	public img_status display_status = img_status.UNKNOWN;
	public bool is_locked;

	public int width_thumbnail_default = 300;
	public int height_thumbnail_default = 300;
	public int width_thumbnail = 300;
	public int height_thumbnail = 300;
	public int width_image;
	public int height_image;
	public int width_border_rect;
	public int height_border_rect;
	public bool rect_visibility = true;

	private bool keep_ratio = true;
	private double thumbnail_wh_ratio = 0.6666;

	//---------------------------------------------------------------------------
	public Thumbnail(string file_name, CanvasItem root){
		this.file_name = dir_name + file_name;
		this.file = GLib.File.new_for_commandline_arg(this.file_name);
		this.root = root;
		//stdout.printf("NEW THUMBnail : %s => %s\n", file_name, this.file_name);
	}

	//---------------------------------------------------------------------------
	private bool on_button_pressed (Widget source, Gdk.EventButton btn) {
		//stdout.printf( "BTN %d (%s)  was pressed\n", (int)btn.button, file_name); //source.get_name());
		fn = file_name;

		return false;
	}

	//---------------------------------------------------------------------------
	public async void async_load () {
	  try {
		stdout.printf("BEGIN ASYNC_LOAD: %s  (%s)\n", file_name, display_status.to_string());
		if(display_status != img_status.LOADED){

			stdout.printf("BEGIN get_file_info: %s\n", file_name);

			SourceFunc callback = async_load.callback;
			ThreadFunc<void*> run = () => {
				//stdout.printf("BEGIN ASYNC get_file_info: %s\n", file_name);
				Gdk.Pixbuf.get_file_info(file_name, out width_image, out height_image);
				GLib.Idle.add((owned) callback);
				return null;
			};
			new Thread<void*>.try("?", run);

			// Wait for background thread to schedule our callback
			yield;

			GLib.InputStream stream = yield file.read_async ();

			var pixbuf_load = new Pixbuf (Colorspace.RGB, true, 8, width_thumbnail, height_thumbnail);
			if(width_image>width_thumbnail || height_image>height_thumbnail){
				pixbuf_load = yield new Gdk.Pixbuf.from_stream_at_scale_async(stream, width_thumbnail-(image_padding*2), height_thumbnail-(image_padding*2), keep_ratio);
			}else{
				pixbuf_load = yield new Gdk.Pixbuf.from_stream_async(stream, null);
			}

			pixbuf = pixbuf_load.apply_embedded_orientation (); // rotates image if necessary (gets info from EXIF)
			//var orientation = pixbuf.get_option("orientation");

			var lg = pixbuf_load.get_byte_length();
			stdout.printf("async load =======> %s = %d (%d x %d = %d)\n", file_name, (int)lg, width_image, height_image, width_image * height_image );
			draw = drawing_area.get_window();

			drawing_area.modify_bg(Gtk.StateType.NORMAL , Gdk.Color() {red=0x0000, green=0x0000, blue=0x0000});
			display_status = img_status.LOADED;
		}

		stdout.printf("async load STEP 2 ===> %s\n", file_name);
		// center image (in the thumbnail area)
		var image_w = pixbuf.get_width();
		var new_x = (width_thumbnail-(image_padding*2)-image_w)/2;
		var image_h = pixbuf.get_height();
		var new_y = (height_thumbnail-(image_padding*2)-image_h)/2;

		Gdk.draw_pixbuf(draw, gc, pixbuf, 0, 0, new_x, new_y, -1, -1, Gdk.RgbDither.NONE, 0, 0);

		var scale = (int)( (image_w*100 / width_thumbnail));
		//stdout.printf("==> scale = %d, \n", scale);

		var context = Gdk.cairo_create (drawing_area.window);
		context.move_to(4, 10);
		context.select_font_face("Arial", FontSlant.NORMAL, FontWeight.BOLD);
		context.set_source_rgb(0.9, 0.9, 0.9);
		context.set_font_size(9);
		if(width_image>width_thumbnail || height_image>height_thumbnail){
			context.show_text(scale.to_string()+"% ");
		}else{
			context.show_text(" 100% ");
		}
		stdout.printf("async load STEP 3 ===> %s\n", file_name);

	  } catch ( GLib.Error e ) {
		GLib.error (e.message);
	  }
	  stdout.printf("END ASYNC_LOAD: %s  (%s)\n", file_name, display_status.to_string());
	}

	//---------------------------------------------------------------------------
	public void draw_at( long x, long y){
		stdout.printf("BEGIN draw_at: %s\n", file_name);
		border_rect = CanvasRect.create(root, x, y, width_thumbnail, height_thumbnail);
		border_rect.stroke_color_rgba = (uint)0xf8f824ff;

		drawing_area = new Gtk.DrawingArea();
		drawing_area.modify_bg(Gtk.StateType.NORMAL , Gdk.Color() {red=0x0000, green=0x0000, blue=0x0000});
		drawing_area.name = ""+file_name;
		drawing_area.add_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.POINTER_MOTION_MASK);
		drawing_area.button_press_event.connect(on_button_pressed);
		drawing_area.expose_event.connect ((evt) => {
			async_load.begin ( (obj, async_res) => {
				GLib.debug ("Finished loading.");
			});
			return true;
		});

		this.thumb = CanvasWidget.create(root, drawing_area, x+image_padding, y+image_padding, width_thumbnail-(image_padding*2), height_thumbnail-(image_padding*2));
		stdout.printf("END draw_at: %s\n", file_name);
	}

	//---------------------------------------------------------------------------
	public void move_to(long x, long y){
		border_rect.x = x;
		border_rect.y = y;
		thumb.x = x+image_padding;
		thumb.y = y+image_padding;
	}

	//---------------------------------------------------------------------------
	public void zoom(int zoom_factor){
		width_thumbnail = zoom_factor; //(width_thumbnail_default*zoom_factor)/100;
		height_thumbnail = zoom_factor; //(height_thumbnail_default*zoom_factor)/100;
		reset();
	}

	//---------------------------------------------------------------------------
	public void resize(int w, int h = -1, bool keep_ratio = true){
		width_thumbnail = w;
		height_thumbnail = (int)(w*thumbnail_wh_ratio);
		reset();
	}

	//---------------------------------------------------------------------------
	public void reset(){
		drawing_area = null;

		if(border_rect!=null){
			border_rect.remove();
			border_rect = null;
		}
		if(thumb!=null){
			thumb.remove();
			thumb = null;
		}

		pixbuf = null;
		draw = null;
		gc = null;

		display_status = img_status.UNKNOWN;
	}
}

protected class CanvasedThumbnails : GLib.Object {

}


// ===========================================================================================================================================


public class ImageViewer : Canvas{

	private int w_max = 300;
	private int h_max = 300;
	private double thumbnail_wh_ratio = 0.6666;
	private static int x_spacer = 15;
	private static int y_spacer = 15;
	private weak VBox vb;
	private weak Gtk.Window win;
	private  Canvas canvas_thumbs;
	private  Canvas canvas_image;
	private ScrolledWindow scr_thmb;
	private ScrolledWindow scr_img;
	private int current_win_width = 0;
	private int current_win_height = 0;
	private HScale slider;
	private ArrayList<string> file_names = new ArrayList<string> ();
	private ArrayList<string> file_names_orig = new ArrayList<string> ();

	private enum display_mode { THUMBS, IMAGE }
	private display_mode current_display_mode = display_mode.THUMBS;
	private HashMap<string, Thumbnail> map_name_to_thumb = new HashMap<string, Thumbnail>();

	private CanvasItem root;

	private Pixbuf pixbuf;
	private Goo.CanvasImage cimg;
	private Goo.CanvasText image_name_text;
	private CanvasRect image_name_rect;


	//---------------------------------------------------------------------------
	private bool on_key_pressed_main (Widget source, Gdk.EventKey key) {
		stdout.printf( "Key str: %s (keyval: %d) keyval_name: %s was pressed\n", key.str, (int)key.keyval, Gdk.keyval_name(key.keyval));

		// If the key pressed was q, quit
		if (key.str == "q") {
			Gtk.main_quit ();
		}
		if (Gdk.keyval_name(key.keyval) == "Return") {

		}
		if (key.str == "i") {
			display_image_view();
		}
		if (Gdk.keyval_name(key.keyval) == "Escape") {
			display_thumbnails_view();
		}
		//if (Gdk.keyval_name(key.keyval) == "Page_Down") {		}

		return false;
	}


	//---------------------------------------------------------------------------
	public async void async_load_single_image (CanvasImage img, string filename, int w_max = w_max, int h_max = h_max) {
	  stdout.printf("LOAD: %s\n", filename);
	  GLib.File file;
	  try{
		file = GLib.File.new_for_commandline_arg (filename);
		img.pixbuf = null; // FIXME useful/useless ???

		if(image_name_text != null) {image_name_text.remove();}

		long real_w=-1, real_h=-1;

		SourceFunc callback = async_load_single_image.callback;
		ThreadFunc<void*> run = () => {
			Gdk.Pixbuf.get_file_info(filename, out real_w, out real_h);
			GLib.Idle.add((owned) callback);
			return null;
		};
		//Thread.create<void*>(run, false);
		new Thread<void*>.try("?", run);

		// Wait for background thread to schedule our callback
		yield;

		GLib.InputStream stream = yield file.read_async ();
		var pixbuf = new Gdk.Pixbuf (Colorspace.RGB, true, 8, w_max, h_max);
		if(real_w>w_max || real_h>h_max){
			pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async (stream, w_max, h_max, true);
		}else{
			pixbuf = yield new Gdk.Pixbuf.from_stream_async (stream, null);
		}

		//var orientation = pixbuf.get_option("orientation");		//stdout.printf("opts: %s => %s\n", filename, orientation);

		img.pixbuf = pixbuf;

		var image_w = pixbuf.get_width();
		var new_x = (w_max-image_w)/2;
		var image_h = pixbuf.get_height();
		var new_y = (h_max-image_h)/2;
		pixbuf = null;

		img.x = new_x;
		img.y = new_y;

		//map_name_to_CanvasImage.set(img, filename);
		//stdout.printf("name %s (%s)\n", img.description, filename);

	  } catch ( GLib.Error e ) {
		///GLib.error (e.message);
		stdout.printf("PB ouverture: %s (%s)\n", filename, e.message);
	  }
	}

	//---------------------------------------------------------------------------
	// Switch to the Thumbnail view (hides the Image view)
	private void display_thumbnails_view(){
		win.title = "Vala-Goocanvas Viewer";;
		current_display_mode = display_mode.THUMBS;
		scr_img.hide();
		scr_thmb.show_all();
		slider.set_sensitive(true);
		win.set_focus(canvas_thumbs);
	}

	//---------------------------------------------------------------------------
	// Switch to the Image view (hides the Thumbnail view)
	private void display_image_view(){
		win.title = ""+fn;
		current_display_mode = display_mode.IMAGE;
		scr_thmb.hide();
		scr_img.show_all();
		slider.set_sensitive(false);
		win.set_focus(canvas_image); 		//canvas_image.show_all();

		int canvas_width, canvas_height;
		canvas_image.get_window().get_size(out canvas_width, out canvas_height);
		//stdout.printf( "--IMAGE CANVAS SIZE= %d x  %d\n",canvas_width, canvas_height);
	}

	//---------------------------------------------------------------------------
	private void put_image_on_canvas(){
		CanvasItem root = canvas_image.get_root_item ();

		int width, height;
		canvas_image.get_window().get_size(out width, out height); // FIXME pourquoi canvas_thumbs ?
		//stdout.printf( "2PIOC CANVAS IMG (%s) SIZE= %d x  %d\n", fn, width, height);

		pixbuf = null;
		pixbuf = new Pixbuf (Colorspace.RGB, true, 8, width, height);
		if(cimg != null) {
			cimg.remove();
			cimg = null;
		}
		cimg = CanvasImage.create(root, pixbuf, 0, 0);

		canvas_image.set_bounds(0, 0, width, height);
		async_load_single_image.begin (cimg, fn, width, height, (obj, async_res) => {
			GLib.debug ("Finished loading.");
		});
	}

	//---------------------------------------------------------------------------
	private void put_image_name_on_canvas(string image_name){


		int cnv_width=0;
		int cnv_height=0;
		stdout.printf( "PINOC 1 => IMAGE  CANVAS SIZE= %d x  %d\n", cnv_width, cnv_height);
		canvas_image.get_window().get_size(out cnv_width, out cnv_height);
		stdout.printf( "PINOC 2 => IMAGE  CANVAS SIZE= %d x  %d\n", cnv_width, cnv_height);
		canvas_image.background_color_rgb=((uint)0x000000);
		var root = canvas_image.get_root_item ();

		if(image_name_text != null) {
			image_name_text.remove();
			image_name_text = null;
		}
		image_name_text = CanvasText.create(root, image_name, cnv_width, cnv_height, -1,  Gtk.AnchorType.SOUTH_EAST, "font", "Sans 8");
		//text.stroke_color_rgba = (uint)0xf8f824ff;
		image_name_text.fill_color_rgba = (uint)0xc8c804ff;

		Goo.CanvasBounds gb;
		image_name_text.get_bounds(out gb);
		var txt_height = (int)(gb.y2-gb.y1);

		if(image_name_rect != null) {
			image_name_rect.remove();
			image_name_rect = null;
		}
		image_name_rect = CanvasRect.create(root, 0, cnv_height-txt_height-2, cnv_width, cnv_height);
		image_name_rect.fill_color_rgba = (uint)0x92926822;   //rect.stroke_color_rgba = (uint)0xd8d814ff;

	}

	//---------------------------------------------------------------------------
	private bool on_button_pressed (Widget source, Gdk.EventButton btn) {
		//double tilt;		//Gdk.Event.get_axis(AxisUse.XTILT, out tilt);
		stdout.printf( "==Button %d (filename=%s)  was pressed\n", (int)btn.button, fn);
		//if(current_display_mode == display_mode.THUMBS){			 stdout.printf( "  current_display_mode= THUMBS\n");		}else{			stdout.printf( "  current_display_mode= IMAGE\n");		}
		//if(source == win) {	stdout.printf( "SOURCE Win\n");	}else{	stdout.printf( "SOURCE non WIN\n");	}
		//win.set_focus(scr_thmb);

		if(current_display_mode == display_mode.THUMBS){
			// TODO  if((int)btn.button == 8){			}
			display_image_view();
			put_image_on_canvas();
			put_image_name_on_canvas(fn);
		} else {
			//fn = null;
			display_thumbnails_view();
		}

		//var real_h=0, real_w=0;		scr_thmb.get_window().get_size(out real_w, out real_h);		stdout.printf( "3 MAIN SIZE= %d x  %d\n", real_w, real_h);
		return false;
	}

    //---------------------------------------------------------------------------
	private void print_size(string from){
		int canvas_width, canvas_height;
		canvas_thumbs.get_window().get_size(out canvas_width, out canvas_height);
		//stdout.printf( "%s => THUMBS CANVAS SIZE= %d x  %d\n", from, canvas_width, canvas_height);
		canvas_image.get_window().get_size(out canvas_width, out canvas_height);
		//stdout.printf( "%s => IMAGE  CANVAS SIZE= %d x  %d\n\n",from, canvas_width, canvas_height);

	}

	//---------------------------------------------------------------------------
	private bool on_win_exposed (Widget source, Gdk.EventExpose ev) {
		//CanvasItem root = canvas_image.get_root_item ();		//stdout.printf( "WIN exposed\n");
		int width = 1;
		int height = 1;
		win.get_size (out width, out height);
		bool size_changed = false;
		if(width != current_win_width){
			current_win_width = width;
			current_win_height = height;
			size_changed = true;
		}

		//stdout.printf("==================================================================================\non_win_exposed debut = %d x %d\n", width,  height);
		//print_size("on_win_exposed debut");
		if(size_changed){
			//stdout.printf( "WIN exposed\n");
			if(current_display_mode == display_mode.THUMBS){
				// TODO  if((int)btn.button == 8){	}
				////display_image_view();
				display_thumbnails_view();
			} else {
				display_image_view();
			}

			int canvas_width_t, canvas_height_t;
			int canvas_width_i, canvas_height_i;
			canvas_thumbs.get_window().get_size(out canvas_width_t, out canvas_height_t);
			canvas_image.get_window().get_size(out canvas_width_i, out canvas_height_i);
			if(canvas_height_i<canvas_height_t){
				//scr_thmb.hide();
				canvas_image.show();	//scr_thmb.show();
				canvas_image.hide();
				//print_size("    CORRECTIF");
			}

			//stdout.printf("   non_win_exposed debut = %d x %d\n", width,  height);
			print_size("    on_win_exposed debut");
			//int width_thumbnail = 300;			//int height_thumbnail = 300;
			if(current_display_mode == display_mode.IMAGE){
				put_image_on_canvas();
				put_image_name_on_canvas(fn);
			}else{

				int canvas_width, canvas_height;
				canvas_thumbs.get_window().get_size(out canvas_width, out canvas_height);

				int curr_col = 0;
				int curr_row = 0;
				//long nb_cimg_per_col = current_win_width / (w_max+x_spacer);
				int nb_cols = (int)slider.get_value();
				w_max = (canvas_width - ((nb_cols+1) *x_spacer)) /nb_cols;
				h_max = (int)(w_max*thumbnail_wh_ratio); //(canvas_height - ((nb_cols+1) *y_spacer)) /nb_cols;

				//stdout.printf("THB (%s): loaded %ld x %ld   w_max:%ld, %d %d, nb_cimg_per_col:%ld\n", name, new_x, new_y, w_max, curr_col, curr_row, nb_cimg_per_col);  					//width_thumbnail = w_max;			}
				int dist_from_top = 4;

				foreach (string name in file_names) {
					long new_x = x_spacer+1+ (curr_col * (w_max + x_spacer));
					long new_y = dist_from_top + 1+ (curr_row * (h_max + y_spacer));

					if(map_name_to_thumb.has_key(name)){
						// nothing
						var thb = map_name_to_thumb.get(name);
						thb.resize(w_max);
						//stdout.printf("RESIZE: (%s), w_max=%d h_max=%d  x=%ld y=%ld\n", name, w_max,h_max, new_x, new_y);
						if(thb.display_status != Thumbnail.img_status.LOADED){
							//stdout.printf("THB1 (%s): not loaded\n", name);
							thb.reset();
							//thb.resize(w_max);
							thb.draw_at(new_x, new_y);
						}else{
							//stdout.printf("THB2 (%s): other\n", name);
							//thb.resize(w_max);
							//thb.reset();
							thb.move_to(new_x, new_y);
						}
					}else{
						//stdout.printf("THB0 (%s): NEW\n", name);
						var thb = new Thumbnail(name, root);
						thb.resize(w_max);
						thb.draw_at(new_x, new_y);
						map_name_to_thumb.set(name, thb);
					}

					curr_col++;
					if(curr_col >= nb_cols){
						curr_col = 0;
						curr_row++;
					}

				}
				var nb_rows = file_names.size/nb_cols;
				if(file_names.size%nb_cols != 0){nb_rows++;}
				canvas_thumbs.set_bounds(0, 0, canvas_width-1, (nb_rows)*(h_max+y_spacer));

			}
		}
		print_size("on_win_exposed end");
		return false;
	}
	//========================================= MAIN ==============================================================================
	private int init_main (string[] args) {
		//stdout.printf( "ARGS= %s %s\n", args[0], args[1]);
		Gtk.init (ref args);
		var window = new Gtk.Window ();
		window.title = "Vala-Goocanvas Viewer";
		window.border_width = 0;
		window.window_position = WindowPosition.CENTER;
		window.set_default_size (800, 600);
		window.destroy.connect (Gtk.main_quit);
		window.key_press_event.connect(on_key_pressed_main);
		window.expose_event.connect(on_win_exposed);
		window.button_press_event.connect(on_button_pressed);
		win = window;

		string fname = "";
		dir_name = "";
		fn = "";

		// Recognized extensions.  (converted to HashTable for easy reference)
		const string[] extensions_array = {"JPG","JPEG","GIF", "PNG", "BMP", "TIFF", "TGA", "PCX", "SVG"};
		HashTable<string, bool> map_extensions = new HashTable<string, bool>(str_hash, str_equal);
		foreach (string ext in extensions_array){
			map_extensions.add(ext);  // ADD only adds a KEY (no need for value) => equivalent to a SET
		}

		if(args.length>=2){
			var tmp_path = args[1];
			stdout.printf("Direct==> (%s)\n", tmp_path);
			var file = File.new_for_path (tmp_path);
			if (!file.query_exists ()) {
				stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
				return 1;
			}

			try {
				// Open file for reading and wrap returned FileInputStream into a
				// DataInputStream, so we can read line by line

				if (file.query_file_type (0) == FileType.DIRECTORY) {
					// It's a directory
					stdout.printf( " ************************  is a directory \n");
					var d = Dir.open(tmp_path);
					while ((fname = d.read_name()) != null) {
						var fname_upper = fname.up();

						string[] name_parts = fname_upper.split(".");
						string ext = name_parts[name_parts.length-1];

						if( map_extensions.contains(ext) ){
							file_names.add (fname);
						}
					}
				} else if  (file.query_file_type (0) == FileType.REGULAR) {
					stdout.printf( " ************************  is a file \n");
				} else {
					// should not happen!
					stderr.printf( "   is not a file nor a directory \n");
					return 1;
				}
			} catch (Error e) {
				error ("%s", e.message);
			}

		}else{
			// default: open current directory
			//stdout.printf(" ELSE CURRENT\n");
			var d = Dir.open(".");
			while ((fname = d.read_name()) != null) {
				var fname_upper = fname.up();

				string[] name_parts = fname_upper.split(".");
				string ext = name_parts[name_parts.length-1];
				if( map_extensions.contains(ext) ){
					file_names.add (fname);
				}
			}
		}

		stdout.printf(" FILE_NAMES SIZE= %d\n", file_names.size);

		file_names.sort();
		file_names_orig = file_names;

		// var menu = new Gtk.Menu ();var menu_about ) new Gtk.MenuItem.with_label("About");		menu.append ("About", "win.about");
		long win_width;
		long win_height;
		win.get_size (out win_width, out win_height);
		//stdout.printf( "WIN size: %d x %d\n", (int)win_width, (int)win_height);

		var vbox = new VBox(false, 0);
		var hbox = new HBox(false, 0);

		var toolbar = new Toolbar ();
		var open_button = new ToolButton.from_stock (Stock.OPEN);
		//open_button.is_important = true;
		//toolbar.add (open_button);
		hbox.pack_start (toolbar, true, true, 0);

		var cbe = new ComboBoxEntry.text();
		cbe.changed.connect (() => {
			stdout.printf( ": cbe => %s \n", cbe.get_active_text());
			//file_names = file_names.map
			win.expose_event(Gdk.EventExpose());
		});
		hbox.pack_start (cbe, false, true, 0);

		// used to set the number of cols (images/row)
		slider = new HScale.with_range(1, 15, 4);
		slider.set_value_pos(Gtk.PositionType.LEFT);
		const int vals[] =  { 2, 3, 4, 6, 8, 10 };
		foreach (int val in vals){
			slider.add_mark(val, Gtk.PositionType.BOTTOM, null); //"<span size='x-small'>"+val.to_string()+"</span>");
		}
		slider.set_value(4);
		slider.set_update_policy(Gtk.UpdateType.DELAYED); // VITAL for performances! (the update signal must not be instant)
		slider.adjustment.value_changed.connect (() => {
			int nb_cols = (int)slider.get_value();

			int canvas_width, canvas_height;
			canvas_thumbs.get_window().get_size(out canvas_width, out canvas_height);

			//int nb_cols = (int)slider.get_value();
			w_max = (canvas_width - ((nb_cols+1) *x_spacer)) /nb_cols;
			h_max = (int)(w_max*thumbnail_wh_ratio); //(canvas_height - ((nb_cols+1) *y_spacer)) /nb_cols;
			foreach(var key in map_name_to_thumb.keys){
				var wdgt = map_name_to_thumb.get(key);
				wdgt.resize(w_max, h_max);
			}
			current_win_width = -1;
			current_win_height = -1;
			//win.expose_event(Gdk.EventExpose());
		});
		hbox.pack_start (slider, true, true, 0);

		canvas_thumbs = new Canvas();		//canvas_thumbs.name = "cnv A THUMB";
		root = canvas_thumbs.get_root_item ();
		canvas_thumbs.set_bounds(0, 0, 1200, 1500);
		canvas_thumbs.background_color_rgb=((uint)0x333333);
		scr_thmb = new ScrolledWindow (null, null);
		scr_thmb.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		scr_thmb.add (canvas_thumbs);
		scr_thmb.name = "scr_thmb";

		canvas_image = new Canvas();    //canvas_image.name = "cnv B IMG";
		canvas_image.set_bounds(0, 0, 1200, 1500);
		canvas_image.background_color_rgb=((uint)0x000000);
		scr_img = new ScrolledWindow (null, null);
		scr_img.set_policy (PolicyType.NEVER, PolicyType.NEVER); // hidden by default (will only be enabled when zooming)
		scr_img.add (canvas_image);
		scr_img.name = "scr_img";
		//scr_img.hide(); //????????????????????????????????????????????

		vbox.pack_start (hbox, false, true, 0);
		vbox.pack_start (scr_thmb, true, true, 0);
		vbox.pack_start (scr_img, true, true, 0);

		vb = vbox;
		vb.name = "box";
		window.add (vbox);

		window.set_focus(scr_thmb);

		// If an argument (image name) is provided => display the Image view (instead of the Thumbnails view)
		// IMPORTANT:  this block MUST be located after window.show_all() which shows ALL the widgets!
		if(args.length>=2){

			var tmp_path = args[1];
			stdout.printf("Direct==> (%s)\n", tmp_path);
			//scr_thmb.hide();

			var file = File.new_for_path (tmp_path);

			if (!file.query_exists ()) {
				stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
				return 1;
			}

			try {
				// Open file for reading and wrap returned FileInputStream into a
				// DataInputStream, so we can read line by line

				if (file.query_file_type (0) == FileType.DIRECTORY) {
					// It's a directory
					current_display_mode = display_mode.THUMBS;
					dir_name = tmp_path;
					if(dir_name.last_index_of("/") != dir_name.length-1 ){
						dir_name = dir_name + "/";
					}
					fn = "";
					stdout.printf( " ************************  is a directory \n");
				} else if  (file.query_file_type (0) == FileType.REGULAR) {
					stdout.printf( " ************************  is a file \n");
					current_display_mode = display_mode.IMAGE;
					dir_name = "";
					fn = tmp_path;
					display_image_view();
					put_image_on_canvas();
					put_image_name_on_canvas(fn);
				} else {
					// should not happen!
					stderr.printf( "   is not a file nor a directory \n");
					return 1;
				}

			} catch (Error e) {
				error ("%s", e.message);
			}

		}else{
			//scr_img.hide();
			stdout.printf(" ELSE\n");
		}

		window.show_all ();
		scr_thmb.hide();

		Gtk.main ();
		return 0;
	}

	//========================================================
	static int main (string[] args) {
		var m = new ImageViewer();
		m.init_main(args);
		return 0;
	}
}
