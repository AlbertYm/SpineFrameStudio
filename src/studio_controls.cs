using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
namespace SpineStudio {
 public class SourceListView : ListView {
  public SourceListView(){OwnerDraw=true;DoubleBuffered=true;}
  protected override void OnDrawItem(DrawListViewItemEventArgs e){if(View!=View.Details)e.DrawDefault=true;}
  protected override void OnDrawSubItem(DrawListViewSubItemEventArgs e){
   Color bg=e.Item.Selected?ColorTranslator.FromHtml("#303F55"):BackColor;
   using(var b=new SolidBrush(bg))e.Graphics.FillRectangle(b,e.Bounds);
   var r=e.Bounds;r.X+=4;r.Width-=8;
   TextRenderer.DrawText(e.Graphics,e.SubItem.Text,Font,r,Theme.Text,TextFormatFlags.Left|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis|TextFormatFlags.NoPrefix);
   if(e.Item.Selected&&Focused&&e.ColumnIndex==Columns.Count-1)ControlPaint.DrawFocusRectangle(e.Graphics,e.Item.Bounds,Theme.Cyan,bg);
  }
  protected override void OnDrawColumnHeader(DrawListViewColumnHeaderEventArgs e){e.DrawDefault=true;}
 }
 public class StudioMark : Control {
  public StudioMark(){DoubleBuffered=true;SetStyle(ControlStyles.SupportsTransparentBackColor,true);BackColor=Color.Transparent;}
  protected override void OnPaint(PaintEventArgs e){
   var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;float s=Width/60f;g.ScaleTransform(s,s);
   for(int i=0;i<3;i++)using(var p=Theme.Round(new Rectangle(3+i*10,3+i*6,34,34),9))using(var b=new SolidBrush(Theme.Background))using(var pen=new Pen(i==2?Theme.Cyan:Theme.Pink,2)){g.FillPath(b,p);g.DrawPath(pen,p);}
   using(var b=new SolidBrush(Theme.Cyan)){g.FillPolygon(b,new Point[]{new Point(35,25),new Point(35,39),new Point(44,32)});}
  }
 }
 public class StudioProgress : Control {
  int maximum=100,value;
  public int Maximum{get{return maximum;}set{maximum=Math.Max(1,value);Invalidate();}}
  public int Value{get{return value;}set{this.value=Math.Max(0,Math.Min(value,maximum));Invalidate();}}
  public StudioProgress(){DoubleBuffered=true;TabStop=false;AccessibleRole=AccessibleRole.ProgressBar;}
  protected override void OnPaint(PaintEventArgs e){var g=e.Graphics;g.Clear(Parent.BackColor);g.SmoothingMode=SmoothingMode.AntiAlias;using(var p=Theme.Round(new Rectangle(0,0,Width-1,Height-1),4))using(var b=new SolidBrush(ColorTranslator.FromHtml("#363C44"))){g.FillPath(b,p);}int w=(int)((Width-1)*(value/(double)maximum));if(w>1)using(var p=Theme.Round(new Rectangle(0,0,w,Height-1),4))using(var b=new SolidBrush(Theme.Cyan)){g.FillPath(b,p);}}
 }
 public static class Theme {
  public static Color Background = ColorTranslator.FromHtml("#191C20"), Surface = ColorTranslator.FromHtml("#22262B"), Input = ColorTranslator.FromHtml("#191D22"), Border = ColorTranslator.FromHtml("#515963"), Text = ColorTranslator.FromHtml("#EEF0F3"), Muted = ColorTranslator.FromHtml("#B5BCC5"), Cyan = ColorTranslator.FromHtml("#A9C8FF"), Pink = ColorTranslator.FromHtml("#A9C8FF");
  public static GraphicsPath Round(Rectangle r, int radius) {
   var p = new GraphicsPath(); int d = Math.Max(2, Math.Min(radius * 2, Math.Min(r.Width, r.Height)));
   p.AddArc(r.X,r.Y,d,d,180,90); p.AddArc(r.Right-d,r.Y,d,d,270,90); p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90); p.AddArc(r.X,r.Bottom-d,d,d,90,90); p.CloseFigure(); return p;
  }
 }
 public class RoundButton : Button {
  public string Variant {get;set;}
  bool hover, pressed;
  public RoundButton() { Variant="secondary"; FlatStyle=FlatStyle.Flat; FlatAppearance.BorderSize=0; Cursor=Cursors.Hand; SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw,true); }
  protected override void OnMouseEnter(EventArgs e){hover=true;Invalidate();base.OnMouseEnter(e);}
  protected override void OnMouseLeave(EventArgs e){hover=false;pressed=false;Invalidate();base.OnMouseLeave(e);}
  protected override void OnMouseDown(MouseEventArgs e){pressed=true;Invalidate();base.OnMouseDown(e);}
  protected override void OnMouseUp(MouseEventArgs e){pressed=false;Invalidate();base.OnMouseUp(e);}
  protected override void OnGotFocus(EventArgs e){Invalidate();base.OnGotFocus(e);}
  protected override void OnLostFocus(EventArgs e){Invalidate();base.OnLostFocus(e);}
  protected override void OnPaint(PaintEventArgs e) {
   var g=e.Graphics; g.Clear(Parent == null ? Theme.Background : Parent.BackColor);g.SmoothingMode=SmoothingMode.AntiAlias;
   bool primary=Variant=="primary", selected=Variant=="selected", accent=Variant=="accent";
   Color fill=primary?Theme.Cyan:selected?ColorTranslator.FromHtml("#303F55"):accent?ColorTranslator.FromHtml("#30363E"):ColorTranslator.FromHtml("#30363E");
   if(hover&&Enabled)fill=ControlPaint.Light(fill,.12f);if(pressed&&Enabled)fill=ControlPaint.Dark(fill,.1f);if(!Enabled)fill=ColorTranslator.FromHtml("#292D33");
   using(var p=Theme.Round(new Rectangle(1,1,Width-3,Height-3),Math.Min(5,Height/2-1)))using(var b=new SolidBrush(fill))using(var pen=new Pen(primary?Theme.Cyan:selected?Theme.Cyan:accent?Theme.Pink:Theme.Border,1)){g.FillPath(b,p);g.DrawPath(pen,p);}
   if(Focused&&ShowFocusCues)using(var p=Theme.Round(new Rectangle(4,4,Width-9,Height-9),9))using(var pen=new Pen(primary?Theme.Background:Theme.Cyan,2)){g.DrawPath(pen,p);}
   TextRenderer.DrawText(g,Text,Font,new Rectangle(7,2,Width-14,Height-4),!Enabled?Theme.Muted:primary?Theme.Background:Theme.Text,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
  }
 }
 public class RoundPanel : Panel {
  public RoundPanel(){DoubleBuffered=true;BackColor=Theme.Surface;SetStyle(ControlStyles.ResizeRedraw,true);}
  protected override void OnResize(EventArgs e){base.OnResize(e);if(Width>2&&Height>2)using(var p=Theme.Round(ClientRectangle,5)){var old=Region;Region=new Region(p);if(old!=null)old.Dispose();}}
  protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;using(var p=Theme.Round(new Rectangle(0,0,Width-1,Height-1),5))using(var pen=new Pen(ColorTranslator.FromHtml("#363C44"))){e.Graphics.DrawPath(pen,p);}}
 }
 public class RoundTextBox : UserControl {
  readonly TextBox editor = new TextBox();
  public RoundTextBox(){
   DoubleBuffered=true;TabStop=false;BackColor=Theme.Input;ForeColor=Theme.Text;editor.BorderStyle=BorderStyle.None;editor.BackColor=BackColor;editor.ForeColor=ForeColor;Controls.Add(editor);
   editor.Enter+=(s,e)=>Invalidate();editor.Leave+=(s,e)=>Invalidate();editor.TextChanged+=(s,e)=>OnTextChanged(e);
   editor.AllowDrop=true;editor.DragEnter+=(s,e)=>OnDragEnter(e);editor.DragDrop+=(s,e)=>OnDragDrop(e);
  }
  public override string Text{get{return editor==null?"":editor.Text;}set{if(editor!=null)editor.Text=value;}}
  public bool Multiline{get{return editor.Multiline;}set{editor.Multiline=value;LayoutEditor();}}
  public bool ReadOnly{get{return editor.ReadOnly;}set{editor.ReadOnly=value;}}
  public bool WordWrap{get{return editor.WordWrap;}set{editor.WordWrap=value;}}
  public ScrollBars ScrollBars{get{return editor.ScrollBars;}set{editor.ScrollBars=value;}}
  public int SelectionStart{get{return editor.SelectionStart;}set{editor.SelectionStart=value;}}
  public int TextLength{get{return editor.TextLength;}}
  public void AppendText(string value){editor.AppendText(value);}
  public void Clear(){editor.Clear();}
  public void ScrollToCaret(){editor.ScrollToCaret();}
  public void SelectAll(){editor.SelectAll();}
  protected override void OnFontChanged(EventArgs e){base.OnFontChanged(e);if(editor!=null){editor.Font=Font;LayoutEditor();}}
  protected override void OnBackColorChanged(EventArgs e){base.OnBackColorChanged(e);if(editor!=null)editor.BackColor=BackColor;}
  protected override void OnForeColorChanged(EventArgs e){base.OnForeColorChanged(e);if(editor!=null)editor.ForeColor=ForeColor;}
  protected override void OnResize(EventArgs e){base.OnResize(e);LayoutEditor();Invalidate();}
  void LayoutEditor(){if(editor==null)return;int pad=Math.Max(4,DeviceDpi/24);int h=editor.Multiline?Math.Max(1,Height-pad*2):editor.PreferredHeight;editor.SetBounds(pad*2,Math.Max(pad,(Height-h)/2),Math.Max(1,Width-pad*4),h);}
  protected override void OnPaint(PaintEventArgs e){
   e.Graphics.Clear(Parent==null?Theme.Surface:Parent.BackColor);e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
   using(var p=Theme.Round(new Rectangle(1,1,Width-3,Height-3),4))using(var b=new SolidBrush(BackColor))using(var pen=new Pen(ContainsFocus?Theme.Cyan:Theme.Border,ContainsFocus?2:1)){e.Graphics.FillPath(b,p);e.Graphics.DrawPath(pen,p);}
  }
 }
}
