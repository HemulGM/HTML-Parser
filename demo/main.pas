unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IdBaseComponent, System.Contnrs, System.StrUtils, HTML.Parser, IdComponent,
  IdTCPConnection, IdTCPClient, IdHTTP, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Buttons, IdIOHandler, IdIOHandlerSocket,
  IdIOHandlerStack, IdSSL, IdSSLOpenSSL, System.Net.URLClient,
  System.Net.HttpClient, System.Net.HttpClientComponent;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    IdHTTP1: TIdHTTP;
    Edit1: TEdit;
    ParseBt: TButton;
    Panel1: TPanel;
    Panel2: TPanel;
    StatusBar1: TStatusBar;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    Splitter1: TSplitter;
    Panel4: TPanel;
    XPath: TTabSheet;
    Panel5: TPanel;
    Edit2: TEdit;
    FindOneBt: TButton;
    Panel6: TPanel;
    Splitter2: TSplitter;
    Panel7: TPanel;
    TreeView1: TTreeView;
    Panel8: TPanel;
    Panel3: TPanel;
    Splitter3: TSplitter;
    Panel9: TPanel;
    TreeView2: TTreeView;
    TreeView3: TTreeView;
    ClearBt: TButton;
    FindAllBt: TButton;
    Panel10: TPanel;
    Splitter4: TSplitter;
    Button1: TButton;
    Button2: TButton;
    IdSSLIOHandlerSocketOpenSSL1: TIdSSLIOHandlerSocketOpenSSL;
    TabSheet2: TTabSheet;
    Panel11: TPanel;
    Panel12: TPanel;
    Panel13: TPanel;
    Button3: TButton;
    Edit3: TEdit;
    Memo2: TMemo;
    IdHTTP2: TIdHTTP;
    IdSSLIOHandlerSocketOpenSSL2: TIdSSLIOHandlerSocketOpenSSL;
    HTTPClient1: TNetHTTPClient;
    procedure ParseBtClick(Sender: TObject);
    procedure TabSheet1Show(Sender: TObject);
    procedure XPathShow(Sender: TObject);
    procedure TreeView1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TreeView2DragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure TreeView2DragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure TreeView2EndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure ClearBtClick(Sender: TObject);
    procedure FindAllBtClick(Sender: TObject);
    procedure FindOneBtClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    procedure DrawTree1(DTree: TDomTreeNode; prfx: string);
    procedure DrawTree(DTree: TDomTreeNode);
    procedure AddChildNode(ParentNode: TTreeNode; DTree: TDomTreeNode);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  DomTree: TDomTree;

implementation

{$R *.dfm}

procedure TForm1.DrawTree(DTree: TDomTreeNode);
var
  NewNode: TTreeNode;
  NodeCap: string;
  i: integer;
begin
  if DTree.Tag <> '' then
    NodeCap := DTree.GetTagName
  else
    NodeCap := DTree.Text;

  NewNode := TreeView1.Items.Add(nil, NodeCap);
  NewNode.Data := DTree;
  for i := 0 to DTree.Child.Count - 1 do
  begin
    AddChildNode(NewNode, DTree.Child.Items[i]);
  end;
end;

procedure TForm1.DrawTree1(DTree: TDomTreeNode; prfx: string);
var
  i: integer;
  prfxline: string;
begin
  memo1.Lines.Add(prfx + ' ' + DTree.Tag);
  prfxline := prfx + '-';
  for i := 0 to DTree.Child.Count - 1 do
  begin
    drawTree1(DTree.Child.Items[i], prfxline);
  end;
end;

procedure TForm1.TabSheet1Show(Sender: TObject);
begin
  TreeView1.Parent := Panel4;
  Memo1.Parent := Panel2;
  Memo1.Lines.Add('Enter your URL and click button "Parse"')
end;

procedure TForm1.TreeView1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  clickedNode: TTreeNode;
begin

  if Button = mbRight then
  begin
    clickedNode := TreeView1.GetNodeAt(X, Y);
    if clickedNode <> nil then
    begin
      edit2.Text := TDomTreeNode(clickedNode.Data).GetPath(true);
    end;
  end;
end;

procedure TForm1.TreeView2DragDrop(Sender, Source: TObject; X, Y: Integer);
var
  Node: TTreeNode;
  CaptNode: string;
begin
  Node := TreeView2.GetNodeAt(X, Y);
  CaptNode := TDomTreeNode(TreeView1.Selected.Data).GetPath(true);
  if (Node <> nil) and (CaptNode <> '') then
    TreeView2.Items.AddChild(Node, CaptNode)
  else
    TreeView2.Items.Add(nil, CaptNode);
end;

procedure TForm1.TreeView2DragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := (Source = TreeView1); //and (TreeView2.GetNodeAt(x, y) <> nil);
end;

procedure TForm1.TreeView2EndDrag(Sender, Target: TObject; X, Y: Integer);
begin
  TreeView2.FullExpand;
end;

procedure TForm1.XPathShow(Sender: TObject);
begin
  TreeView1.Parent := Panel6;
  Memo1.Parent := Panel10;
  TreeView2.FullExpand;
  Memo1.Lines.Add('Enter your XPath to Edit and click button "Find in DOM" for search node in DOM model');
  Memo1.Lines.Add('or');
  ;
  Memo1.Lines.Add('Drag and drop from DOM Tree to XPath Tree window and click button "Find all result"');
end;

procedure TForm1.AddChildNode(ParentNode: TTreeNode; DTree: TDomTreeNode);
var
  NewNode: TTreeNode;
  NodeCap: string;
  i: integer;
begin
  if DTree.Tag <> '' then
    NodeCap := DTree.GetTagName
  else
    NodeCap := DTree.Text;
  NewNode := TreeView1.Items.AddChild(ParentNode, NodeCap);
  NewNode.Data := DTree;
  for i := 0 to DTree.Child.Count - 1 do
  begin
    AddChildNode(NewNode, DTree.Child.Items[i]);
  end;
end;

procedure TForm1.ParseBtClick(Sender: TObject);
var
  // cnt,i,j,x,y,ind: integer;
  HtmlTxt: string;
  HtmlTxtList: TStringList;
begin
  try
    if not (DomTree = nil) then
      FreeAndNil(DomTree);

    Memo1.Clear;
    TreeView1.Items.Clear;
    Memo1.Lines.Add('Start time GET- ' + DateTimeToStr(Now));
    {HtmlTxtList:=TStringList.Create;
    HtmlTxtList.LoadFromFile('lotto.html');
    HtmlTxt:=HtmlTxtList.Text;}
    HtmlTxt := HTTPClient1.Get(Edit1.Text).ContentAsString;

    Memo1.Lines.Add('End time GET- ' + DateTimeToStr(Now));

    // create root node tree's structure
    DomTree := TDomTree.Create();


    // parse HTML in tree's structure
    if not DomTree.RootNode.Parse(HtmlTxt) then
      showmessage('Don'#39'tParse HTML!');

    Memo1.Lines.Add('End match time - ' + DateTimeToStr(Now));
    if DomTree.ParseErr.Count = 0 then
      StatusBar1.Panels[0].Text := 'Parse result: OK'
    else
      StatusBar1.Panels[0].Text := 'Parse result: ' + IntToStr(DomTree.ParseErr.Count) + ' Error';

    Memo1.Lines.Add('Parsing error and warning: ' + IntToStr(DomTree.ParseErr.Count));
    Memo1.Lines.AddStrings(DomTree.ParseErr);
    // Show status Parse result
    if DomTree.ParseErr.Count = 0 then
      StatusBar1.Panels[0].Text := 'Parse result: OK'
    else
      StatusBar1.Panels[0].Text := 'Parse result: Error';
    // Show total count of parsing nodes
    StatusBar1.Panels[1].Text := 'Count node: ' + inttostr(DomTree.Count);

    drawTree(DomTree.RootNode);
    TreeView1.Items.Item[1].Selected := true;

    Freeandnil(HtmlTxtList);
  except
    on E: Exception do
      ShowMessage(E.ClassName + ' : ' + E.Message);
  end;
end;

procedure TForm1.FindOneBtClick(Sender: TObject);
var
  a: TDomTreeNodeList;
  b: tstringlist;
  i, j: integer;
begin
  if TreeView1.Items.Count = 0 then
    exit;

  a := TDomTreeNodeList.Create;
  b := TStringList.Create;
  begin
    if DomTree.RootNode.FindPath(edit2.Text, a, b) then
    begin
      for j := 0 to a.Count - 1 do
        for i := 0 to TreeView1.Items.Count - 1 do
          if TreeView1.Items[i].Data = a[j] then
          begin
            TreeView1.Items.Item[i].TreeView.Select(TreeView1.Items.Item[i], [ssCtrl]);
            TreeView1.SetFocus;
          end;
      for i := 0 to b.Count - 1 do
        showmessage(b[i]);
    end
    else
      showmessage('Not found!');
  end;
  a.Free;
  b.Free;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  TreeView2.FullCollapse;
  TreeView3.FullCollapse;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  TreeView2.FullExpand;
  TreeView3.FullExpand;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  HtmlTxt, href: string;
  ListNode: TDomTreeNodeList;
  i: integer;
  DomChildTree: TDomTree;
begin
  try
    if not (DomTree = nil) then
      FreeAndNil(DomTree);

    Memo2.Clear;
    Memo2.Lines.Add('Start time GET- ' + DateTimeToStr(Now));
    HtmlTxt := IdHTTP1.Get(Edit3.Text);
    Memo2.Lines.Add('End time GET- ' + DateTimeToStr(Now));
    DomTree := TDomTree.Create();

    // parse HTML in tree's structure
    if not DomTree.RootNode.Parse(HtmlTxt) then
      showmessage('Don'#39'tParse HTML!');
    Memo2.Lines.Add('End match time - ' + DateTimeToStr(Now));
    if DomTree.ParseErr.Count = 0 then
      StatusBar1.Panels[0].Text := 'Parse result: OK'
    else
      StatusBar1.Panels[0].Text := 'Parse result: ' + IntToStr(DomTree.ParseErr.Count) + ' Error';

    Memo2.Lines.Add('Parsing error: - ' + IntToStr(DomTree.ParseErr.Count));
    Memo2.Lines.AddStrings(DomTree.ParseErr);
    // Show status Parse result
    if DomTree.ParseErr.Count = 0 then
      StatusBar1.Panels[0].Text := 'Parse result: OK'
    else
      StatusBar1.Panels[0].Text := 'Parse result: Error';
    // Show total count of parsing nodes
    StatusBar1.Panels[1].Text := 'Count node: ' + inttostr(DomTree.Count);

    ListNode := TDomTreeNodeList.Create;
    if DomTree.RootNode.FindNode('a', 0, 'href="http', true, ListNode) then
    begin
//    if DomTree.RootNode.FindNode('a',0,'',true,ListNode) then
      for i := 0 to ListNode.Count - 1 do
        if ListNode[i].Attributes.TryGetValue('href', href) then
        begin
          Memo2.Lines.Add(href);
        end;

      Memo2.Lines.Add(' ');
      Memo2.Lines.Add(' ');

      for i := 0 to ListNode.Count - 1 do
      begin
        if ListNode[i].Attributes.TryGetValue('href', href) then
        begin
          FreeAndNil(DomChildTree);
          Memo2.Lines.Add(href);
          DomChildTree := TDomTree.Create();
          try
            HtmlTxt := IdHTTP2.Get(AnsiDequotedStr(href, '"'));
            DomChildTree.RootNode.Parse(HtmlTxt);
            Memo2.Lines.Add('Parsing error and warning: ' + IntToStr(DomChildTree.ParseErr.Count));
            Memo2.Lines.AddStrings(DomChildTree.ParseErr);
            Memo2.Lines.Add('');
          except
            on E: Exception do                       // Memo2.Lines.Add(E.ClassName + ' : ' + E.Message);
              Memo2.Lines.Add(E.Message);
          end;
        end;
      end;
      FreeAndNil(DomChildTree);
    end;
  except
    on E: Exception do
      ShowMessage(E.ClassName + ' : ' + E.Message);
  end;
end;

procedure TForm1.ClearBtClick(Sender: TObject);
begin
  TreeView2.Items.Clear;
  TreeView3.Items.Clear;
end;

procedure TForm1.FindAllBtClick(Sender: TObject);

  function AddResultToTree(hXPathNode: TTreeNode; hLevel: integer; hParentView: TTreeNode; hDomTreeNode: TDomTreeNode): TTreeNode;
  var
    FListNode: TDomTreeNodeList;
    FListText: tstringlist;
    i, j: integer;
    ToMemo: string;
  begin
    result := nil;

    FListNode := TDomTreeNodeList.Create;
    FListText := TStringList.Create;
    if hDomTreeNode.FindPath(hXPathNode.Text, FListNode, FListText) then
    begin
      memo1.Lines.Add('Found nodes: ' + IntToStr(FListNode.Count));
      for i := 0 to FListNode.Count - 1 do
        ToMemo := ToMemo + format('[%s],', [FListNode[i].GetTagName]);
      memo1.Lines.Add('[' + LeftStr(ToMemo, Length(ToMemo) - 1) + ']');
      ToMemo := '';
      memo1.Lines.Add('Found text: ' + IntToStr(FListText.Count));
      for i := 0 to FListText.Count - 1 do
        ToMemo := ToMemo + format('%s,', [FListText[i]]);
      memo1.Lines.Add(LeftStr(ToMemo, Length(ToMemo) - 1));

      if FListText.Count > 0 then
        result := TreeView3.Items.AddChild(hParentView, LeftStr(ToMemo, Length(ToMemo) - 1));

      for i := 0 to FListNode.Count - 1 do
      begin
        if FListText.Count = 0 then
        begin
          result := TreeView3.Items.AddChild(hParentView, FListNode[i].GetTagName);
          if hXPathNode.Count > 0 then
            for j := 0 to hXPathNode.Count - 1 do
              AddResultToTree(hXPathNode[j], hLevel + 1, result, FListNode[i]);
        end;
      end;
    end
    else
      memo1.Lines.Add(hXPathNode.Text + ' not found!');
    FListNode.Free;
    FListText.Free;
  end;

begin
  if (TreeView1.Items.Count = 0) or (TreeView2.Items.Count = 0) then
    exit;

  TreeView3.Items.Clear;
  begin
    AddResultToTree(TreeView2.Items[0], 1, nil, DomTree.RootNode)
  end;
  TreeView3.FullExpand;
end;

end.
