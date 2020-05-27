{==============================================================================|
| Project : Delphi HTML/XHTML parser module                      | 1.1.2       |
|==============================================================================|
| Content:                                                                     |
|==============================================================================|
| The contents of this file are subject to the Mozilla Public License Ver. 1.0 |
| (the "License"); you may not use this file except in compliance with the     |
| License. You may obtain a copy of the License at http://www.mozilla.org/MPL/ |
|                                                                              |
| Software distributed under the License is distributed on an "AS IS" basis,   |
| WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for |
| the specific language governing rights and limitations under the License.    |
|==============================================================================|
| Initial Developers of the Original Code are:                                 |
|   Sandbil (Russia) sandbil@ya.ru                                             |
| All Rights Reserved.                                                         |
|   Last Modified:                                                             |
|     25.10.2014, Sandbil                                                      |
|     15.04.2020, HemulGM                                                      |
|==============================================================================|
| History: see README                                                          |
|==============================================================================|}


unit HTML.Parser;

interface

uses
  System.Classes, System.RegularExpressionsConsts, System.RegularExpressionsCore, System.Generics.Collections,
  System.StrUtils, System.SysUtils;

type
  TDomTreeNode = class;

  TDomTreeNodeList = class;

  TTagItem = array[0..3] of string;

  TDomTree = class
  private
    FCount: Integer;
    FParseErr: TStringList;
    FRootNode: TDomTreeNode;
  public
    constructor Create;
    destructor Destroy; override;
    property Count: Integer read FCount;
    property RootNode: TDomTreeNode read FRootNode;
    property ParseErr: TStringList read FParseErr;
    class function FromString(Value: string): TDomTree;
  end;

  TDomTreeNode = class(TObject)
  private
    FTag: string;
    FAttributesTxt: string;
    FAttributes: TDictionary<string, string>;
    FText: string;
    FTypeTag: string;
    FChild: TDomTreeNodeList;
    FParent: TDomTreeNode;
    FOwner: TDomTree;
  public
    property Tag: string read FTag;
    property AttributesTxt: string read FAttributesTxt;
    property Attributes: TDictionary<string, string> read FAttributes;
    property Text: string read FText;
    property TypeTag: string read FTypeTag;
    property Child: TDomTreeNodeList read FChild;
    property Parent: TDomTreeNode read FParent;
    property Owner: TDomTree read FOwner;
    constructor Create(AOwner: TDomTree; AParent: Pointer; ATag: string; AAttrTxt: string = ''; AAttr: TDictionary<
      string, string> = nil; ATypeTag: string = ''; AText: string = '');
    destructor Destroy; override;
    /// <summary>
    /// FindNode
    /// </summary>
    /// <param name="NameTag: string">name Tag</param>
    /// <param name="Index: integer">number of a tag one after another (0 - all tag, 1 - each first ..)</param>
    /// <param name="AnyLevel: Boolean">attribute. ex. alt=1</param>
    /// <param name="ListNode: TNodeList">return TNodeList of TDomTreeNode</param>
    function FindNode(NameTag: string; Index: integer; AttrTxt: string; AnyLevel: Boolean; ListNode: TDomTreeNodeList): Boolean;
    /// <summary>
    /// FindTagOfIndex
    /// </summary>
    /// <param name="NameTag: string">name Tag (* - any tag, except text tag)</param>
    /// <param name="Index: integer">number of a tag one after another (0 - all tag, 1 - each first ..)</param>
    /// <param name="AnyLevel: Boolean">true - all level after start node; false - only one child level after start node</param>
    /// <param name="ListNode: TNodeList">return TNodeList of TDomTreeNode</param>
    function FindTagOfIndex(NameTag: string; Index: integer; AnyLevel: Boolean; ListNode: TDomTreeNodeList): Boolean;
    function FindPath(Path: string; ListNode: TDomTreeNodeList; ListValue: TStringList): Boolean;
    function FindPathAttributes(Path, Attrib: string): TArray<string>;
    function FindPathOne(Path: string): TDomTreeNode;
    function GetAttrValue(AttrName: string): string;
    function GetComment(Index: Integer): string;
    function GetTagName: string;
    function GetTextValue(Index: Integer): string;
    function GetPath(Relative: boolean): string;
    function Parse(HtmlTxt: string): Boolean;
  end;

  TDomTreeNodeList = class(TList<TDomTreeNode>);

  TPrmRec = record
    TagName: string;
    Index: Integer;
    Attr: string;
    AnyLevel: Boolean;
  end;

  TPrmRecList = TList<TPrmRec>;

function Get(Url: string): string;

implementation

uses
  System.Net.HttpClient;

function Get(Url: string): string;
var
  Stream: TStringStream;
  HTTP: THTTPClient;
begin
  Stream := TStringStream.Create;
  HTTP := THTTPClient.Create;
  HTTP.HandleRedirects := True;
  try
    try
      if HTTP.Get(Url, Stream).StatusCode = 200 then
        Result := UTF8ToString(Stream.DataString);
    finally
      Stream.Free;
      HTTP.Free;
    end;
  except
  end;
end;

{ TDomTree }

constructor TDomTree.Create;
begin
  FParseErr := TStringList.Create;
  FRootNode := TDomTreeNode.Create(Self, Self, 'Root');
  FCount := 0;
end;

destructor TDomTree.Destroy;
begin
  FreeAndNil(FParseErr);
  FreeAndNil(FRootNode);
  inherited;
end;

class function TDomTree.FromString(Value: string): TDomTree;
begin
  Result := TDomTree.Create;
  Result.RootNode.Parse(Value);
end;

{ TDomTreeNode }

constructor TDomTreeNode.Create(AOwner: TDomTree; AParent: Pointer; ATag, AAttrTxt: string; AAttr: TDictionary<string,
  string>; ATypeTag, AText: string);
begin
  FChild := TDomTreeNodeList.Create;
  FParent := AParent;
  FTag := ATag;
  FAttributesTxt := AAttrTxt;
  FAttributes := AAttr;
  FTypeTag := ATypeTag;
  FText := AText;
  FOwner := AOwner;
  Inc(AOwner.FCount);
end;

destructor TDomTreeNode.Destroy;
var
  i: Integer;
begin
  for i := 0 to FChild.Count - 1 do
    FChild[i].Free;
  FreeAndNil(FAttributes);
  FreeAndNil(FChild);
  inherited;
end;

function TDomTreeNode.FindNode(NameTag: string; Index: integer; AttrTxt: string; AnyLevel: Boolean; ListNode:
  TDomTreeNodeList): Boolean;
var
  RegEx: TPerlRegEx;
  i, a: integer;
  TagNodeList: TDomTreeNodeList;
  tValue: string;

  function FindAttrChildNode(aNode: TDomTreeNode; aAttrName, aAttrValue: string): TDomTreeNodeList;
  var
    aValue: string;
    j: integer;
  begin
    for j := 0 to aNode.Child.Count - 1 do
    begin
      if aNode.Child[j].Attributes <> nil then
        if aNode.Child[j].Attributes.ContainsKey(aAttrName) then
          if aNode.Child[j].Attributes.TryGetValue(aAttrName, aValue) then
            if aAttrValue = aValue then
              ListNode.Add(aNode.Child[j]);
      if AnyLevel then
        FindAttrChildNode(aNode.Child[j], aAttrName, aAttrValue);
    end;
    Result := ListNode;
  end;

begin
  RegEx := nil;
  try
    Result := False;
    RegEx := TPerlRegEx.Create;
    RegEx.Subject := AttrTxt;
    RegEx.RegEx := '([^\s]*?[^\S]*)=([^\S]*".*?"[^\S]*)|' +
      '([^\s]*?[^\S]*)=([^\S]*#39.*?#39[^\S]*)|' +
      '([^\s]*?[^\S]*)=([^\S]*[^\s]+[^\S]*)|' +
      '(autofocus[^\S]*)()|' +
      '(disabled[^\S]*)()|' +
      '(selected[^\S]*)()';

    if (not (AttrTxt = '')) and (RegEx.Match) then
    begin
      for i := 1 to RegEx.GroupCount do
        if Trim(RegEx.Groups[i]) <> '' then
          Break;
      if NameTag = '' then
      begin
        if FindAttrChildNode(Self, RegEx.Groups[i], RegEx.Groups[i + 1]).Count > 0
          then
          Result := True;
      end
      else
      begin
        TagNodeList := TDomTreeNodeList.Create;
        if FindTagOfIndex(NameTag, Index, AnyLevel, TagNodeList) then
          for a := 0 to TagNodeList.Count - 1 do
            if TagNodeList[a].Attributes <> nil then
              if TagNodeList[a].Attributes.ContainsKey(RegEx.Groups[i]) then
                if TagNodeList[a].Attributes.TryGetValue(RegEx.Groups[i], tValue) then
                       //There was a strong compareson of values of attribute
                       // if RegEx.Groups = tValue)
                  if Pos(RegEx.Groups[i + 1], tValue) > 0
                    then
                  begin
                    ListNode.Add(TagNodeList[a]);
                    Result := True;
                  end;
        TagNodeList.Free;
      end;
    end
    else if AttrTxt = '' then
    begin
      TagNodeList := TDomTreeNodeList.Create;
      if FindTagOfIndex(NameTag, Index, AnyLevel, TagNodeList) then
        for a := 0 to TagNodeList.Count - 1 do
        begin
          ListNode.Add(TagNodeList[a]);
          Result := True;
        end;
      TagNodeList.Free;
    end
    else
      raise Exception.Create('Attribute not found: ' + AttrTxt);
  finally
    RegEx.Free
  end;
end;

function TDomTreeNode.FindTagOfIndex(NameTag: string; Index: integer; AnyLevel: Boolean; ListNode: TDomTreeNodeList): Boolean;

  function SubStringOccurences(const subString, sourceString: string; caseSensitive: Boolean): integer;
  var
    pEx: integer;
    sub, source: string;
  begin
    if caseSensitive then
    begin
      sub := subString;
      source := sourceString;
    end
    else
    begin
      sub := LowerCase(subString);
      source := LowerCase(sourceString);
    end;

    Result := 0;
    pEx := PosEx(sub, source, 1);
    while pEx <> 0 do
    begin
      Inc(Result);
      pEx := PosEx(sub, source, pEx + Length(sub));
    end;
  end;

  function FindChildTagOfIndex(aNode: TDomTreeNode): TDomTreeNodeList;
  var
    countNode, j: integer;
    enumTags: string;
  begin
    countNode := 0;
    for j := 0 to aNode.Child.Count - 1 do
    begin
      if NameTag <> '*' then
      begin
        if ((AnsiUpperCase(aNode.Child[j].Tag) = AnsiUpperCase(NameTag)) and (aNode.Child[j].TypeTag <> '</%s>'))
          or ((AnsiUpperCase(aNode.Child[j].Tag) = '') and (AnsiUpperCase(NameTag) = 'TEXT()') and (aNode.Child[j].Text <> ''))
          or ((LeftStr(AnsiUpperCase(aNode.Child[j].Tag), 4) = '<!--') and (AnsiUpperCase(NameTag) = 'COMMENT()'))
          then
        begin
          Inc(countNode);
          if (countNode = Index) or (Index = 0) then
            ListNode.Add(aNode.Child[j])
        end;
        if (AnyLevel) and (aNode.Child.Count > 0) then
          FindChildTagOfIndex(aNode.Child[j]);
      end
      else
      begin
        if (aNode.Child[j].TypeTag <> '</%s>') then
        begin
          enumTags := enumTags + AnsiUpperCase(aNode.Child[j].Tag) + ',';

          if (SubStringOccurences(AnsiUpperCase(aNode.Child[j].Tag) + ',', enumTags, false) = Index) or (Index = 0) then
            ListNode.Add(aNode.Child[j])
        end;
        if (AnyLevel) and (aNode.Child.Count > 0) then
          FindChildTagOfIndex(aNode.Child[j]);
      end;
    end;
    Result := ListNode;
  end;

begin
  Result := False;
  if FindChildTagOfIndex(Self).Count > 0 then
    Result := True;
end;

function TDomTreeNode.FindPathAttributes(Path, Attrib: string): TArray<string>;
begin
  var Nodes := TDomTreeNodeList.Create;
  var Values := TStringList.Create;
  try
    if FindPath(Path, Nodes, Values) then
    begin
      SetLength(Result, Nodes.Count);
      for var i := 0 to Nodes.Count - 1 do
        Result[i] := Nodes[i].Attributes[Attrib].Trim(['"']);
    end;
  finally
    Nodes.Free;
    Values.Free;
  end;
end;

function TDomTreeNode.FindPathOne(Path: string): TDomTreeNode;
begin
  var Nodes := TDomTreeNodeList.Create;
  var Values := TStringList.Create;
  try
    if FindPath(Path, Nodes, Values) then
    begin
      if Nodes.Count > 0 then
        Result := Nodes[0];
    end;
  finally
    Nodes.Free;
    Values.Free;
  end;
end;

function TDomTreeNode.FindPath(Path: string; ListNode: TDomTreeNodeList; ListValue: TStringList): Boolean;
var
  RegExXPath, RegExXPathElmt: TPerlRegEx;
  i, PrmCount: integer;
  NextAnyLevel: boolean;
  PrmXPath: TPrmRecList;
  PrmXPathSTR: string;
  PrmItem: TPrmRec;

  procedure MatchPath(aContext, aTxtElmt: string);
  var
    Prm: TPrmRec;
  begin
    if (aContext = '/') and (Trim(aTxtElmt) = '') then
      NextAnyLevel := True
    else if (aContext = '/') and (Trim(aTxtElmt) = '..') then
    begin
      Prm.TagName := '..';
      Prm.Index := 0;
      Prm.Attr := '';
      Prm.AnyLevel := False;
      PrmXPath.Add(Prm);
    end
    else
    begin
      RegExXPathElmt.Options := [preCaseLess];
      RegExXPathElmt.Subject := Trim(aTxtElmt);
      RegExXPathElmt.RegEx := '^([\.\*@A-Z][-A-Z0-9\(\)]*)\[?([0-9]*)\]?\[?@?([^\]]*)';
      if RegExXPathElmt.Match then
      begin
        Prm.TagName := RegExXPathElmt.Groups[1];
        if not TryStrToInt(RegExXPathElmt.Groups[2], Prm.Index) then
          Prm.Index := 0;
        Prm.Attr := RegExXPathElmt.Groups[3];
        Prm.AnyLevel := NextAnyLevel;
        if (aContext = '/') then
          NextAnyLevel := False;
        PrmXPath.Add(Prm);
      end
      else
        raise Exception.Create('XPath is not correct ' + aContext + aTxtElmt);
    end;
  end;

  function FindWithPrm(aPrm: integer; aCurNode: TDomTreeNode; aListNode: TDomTreeNodeList): boolean;
  var
    i: integer;
    cLNode: TDomTreeNodeList;
  begin
    Result := False;
    if PrmXPath[aPrm].TagName = '..' then
      FindWithPrm(aPrm + 1, aCurNode.Parent, aListNode)
    else
    begin
      cLNode := TDomTreeNodeList.Create;
      if aCurNode.FindNode(PrmXPath[aPrm].TagName, PrmXPath[aPrm].Index, PrmXPath[aPrm].Attr, PrmXPath[aPrm].AnyLevel,
        cLNode) then
        for i := 0 to cLNode.Count - 1 do
          if aPrm < PrmCount then
            FindWithPrm(aPrm + 1, cLNode[i], aListNode)
          else
            aListNode.Add(cLNode[i]);
      cLNode.Free;
    end;
    if aListNode.Count > 0 then
      Result := True;
  end;

begin
  ListNode.Clear;
  ListValue.Clear;
  PrmXPath := nil;
  RegExXPath := nil;
  RegExXPathElmt := nil;
  try
    NextAnyLevel := False;
    PrmXPath := TPrmRecList.Create;
    PrmXPathSTR := '';
    RegExXPath := TPerlRegEx.Create;
    RegExXPathElmt := TPerlRegEx.Create;

    RegExXPath.Subject := Path;
    RegExXPath.RegEx := '(/)([\*@]?[^/]*)';
    if RegExXPath.Match then
    begin
      MatchPath(RegExXPath.Groups[1], RegExXPath.Groups[2]);
      while RegExXPath.MatchAgain do
        MatchPath(RegExXPath.Groups[1], RegExXPath.Groups[2]);
      for i := 0 to PrmXPath.Count - 1 do
        PrmXPathSTR := PrmXPathSTR + PrmXPath[i].TagName + ',' + inttostr(PrmXPath[i].Index) + ',' + PrmXPath[i].Attr +
          ',' + BoolToStr(PrmXPath[i].AnyLevel, True) + #13#10;

      if PrmXPath.Count > 0 then
      begin
        if (PrmXPath[PrmXPath.Count - 1].TagName[1] = '@')
          then
        begin
          PrmCount := PrmXPath.Count - 2;
          PrmItem := PrmXPath[PrmXPath.Count - 1];
          PrmItem.TagName := AnsiReplaceStr(PrmItem.TagName, '@', '');
          PrmXPath[PrmXPath.Count - 1] := PrmItem;
          if FindWithPrm(0, Self, ListNode) then
          begin
            for i := 0 to ListNode.Count - 1 do
              if ListNode[i].GetAttrValue(PrmItem.TagName) <> '' then
                ListValue.Add(ListNode[i].GetAttrValue(PrmItem.TagName));
            if ListValue.Count > 0 then
              Result := True
            else
              Result := False;
          end
          else
            Result := False;
        end
        else
        begin
          PrmCount := PrmXPath.Count - 1;
          Result := FindWithPrm(0, Self, ListNode);
          PrmItem := PrmXPath[PrmXPath.Count - 1];
          if (AnsiLowerCase(PrmItem.TagName) = 'comment()')
            or (AnsiLowerCase(PrmItem.TagName) = 'text()') then
            for i := 0 to ListNode.Count - 1 do
            begin
              if (AnsiLowerCase(PrmItem.TagName) = 'text()')
                then
                ListValue.Add(ListNode[i].Text)
              else
                ListValue.Add(ListNode[i].Tag);
            end;
        end;
      end
      else
        raise Exception.Create('XPath is not correct or empty.');
    end
    else
      raise Exception.Create('XPath is not correct or empty.');
  finally
    PrmXPath.Free;
    RegExXPath.Free;
    RegExXPathElmt.Free;
  end;
end;

function TDomTreeNode.GetAttrValue(AttrName: string): string;
begin
  Result := '';
  if Self.Attributes <> nil then
    if Self.Attributes.ContainsKey(AttrName) then
      if not Self.Attributes.TryGetValue(AttrName, Result) then
        Result := '';
end;

function TDomTreeNode.GetComment(Index: Integer): string;
var
  countNode, j: integer;
begin
  Result := '';
  countNode := 0;
  for j := 0 to Child.Count - 1 do
  begin
    if (LeftStr(Child[j].Tag, 4) = '<!--') and
      (Child[j].TypeTag = '%s') and
      (Child[j].Text = '')
      then
    begin
      Inc(countNode);
      if (countNode = Index) or (Index = 0) then
      begin
        Result := Child[j].Tag;
        Break;
      end;
    end;
  end;
end;

function TDomTreeNode.GetTagName: string;
begin
  if TypeTag = '</%s>' then
    Result := Format(AnsiReplaceStr(TypeTag, '/', ''), [Tag + ' ' + AttributesTxt])
  else
    Result := Format(TypeTag, [Tag + ' ' + AttributesTxt]);
end;

function TDomTreeNode.GetTextValue(Index: Integer): string;
var
  countNode, j: integer;
begin
  Result := '';
  countNode := 0;
  for j := 0 to Child.Count - 1 do
  begin
    if (Child[j].Tag = '') and
      (Child[j].TypeTag = '') and
      (Child[j].Text <> '')
      then
    begin
      Inc(countNode);
      if (countNode = Index) or (Index = 0) then
      begin
        Result := Child[j].Text;
        Break;
      end;
    end;
  end;
end;

function TDomTreeNode.GetPath(Relative: Boolean): string;

  function GetCountTag(Node: TDomTreeNode): string;
  var
    CountNode, nNode, i: integer;
  begin
    nNode := 0;
    CountNode := 0;
    Result := '';
    if TObject(Node.Parent) is TDomTreeNode then
    begin
      for i := 0 to Node.Parent.Child.Count - 1 do
      begin
        if (Node.Tag = Node.Parent.Child[i].Tag)
          or ((LeftStr(Node.Tag, 4) = '<!--') and (LeftStr(Node.Parent.Child[i].Tag, 4) = '<!--'))
          then
          Inc(CountNode);
        if Node = Node.Parent.Child[i] then
          nNode := CountNode;
      end;
      if (CountNode <> nNode) or ((CountNode = nNode) and (CountNode > 1)) then
        Result := Format('[%d]', [nNode]);
    end;
  end;

  function GetParent(Node: TDomTreeNode): string;
  begin
    if TObject(Node.Parent) is TDomTreeNode then
    begin
      if (Relative) and (Node.Parent.GetAttrValue('id') <> '') then
        Result := Format('//*[@id=%s]', [Node.Parent.GetAttrValue('id')]) +
          '/' + Result
      else
        Result := GetParent(Node.Parent) +
          Node.Parent.Tag + GetCountTag(Node.Parent) + '/' + Result
    end
    else
      Result := '.' + Result;
  end;

begin
  if (LeftStr(Tag, 2) <> '<?') and (LeftStr(Tag, 9) <> '<!DOCTYPE') then
  begin
    if LeftStr(Tag, 4) = '<!--' then
      Result := 'comment()'
    else if Tag <> '' then
      Result := Tag
    else
      Result := 'text()';
    Result := GetParent(Self) + Result + GetCountTag(Self);
    if Result[1] = '.' then
      Result := '.' + RightStr(Result, Length(Result) - Pos('/', Result, 1) + 1);
  end
  else
    Result := '';
end;

function TDomTreeNode.Parse(HtmlTxt: string): Boolean;
var
  RegExHTML, RegExTag: TPerlRegEx;
  prev, ErrParseHTML: integer;
  ChildTree: TDomTreeNode;
  HtmlUtf8, RegExException: string;

  function GetAttr(aAttrTxt: string): TDictionary<string, string>;
  var
    CheckAttr: string;

    procedure MatchAttr;
    var
      i, kn: integer;
      KeyStr: string;
    begin
      CheckAttr := StuffString(CheckAttr, RegExTag.MatchedOffset + 1, RegExTag.MatchedLength, StringOfChar(' ', RegExTag.MatchedLength));
      for i := 1 to RegExTag.GroupCount do
        if RegExTag.Groups[i].Trim <> '' then
        begin
          try
            //Для случаев дублирования атрибутов (class="class1", class="class2")
            KeyStr := RegExTag.Groups[i].Trim;
            if Result.ContainsKey(KeyStr) then
            begin
              kn := 1;
              while Result.ContainsKey(KeyStr + '_' + kn.ToString) do
              begin
                Inc(kn);
              end;
              KeyStr := KeyStr + '_' + kn.ToString;
            end;
            //
            Result.Add(KeyStr, RegExTag.Groups[i + 1].Trim);
          except
            on E: Exception do
              Owner.FParseErr.Add('Warning: not add Attributtes ' +
                E.ClassName + ' : ' + E.Message + 'Sourse string: ' + aAttrTxt +
                ';' + #13#10 + ' attributtes: ' + RegExTag.Groups[i]);
          end;
          Break;
        end;
    end;

  begin
    try
      Result := TDictionary<string, string>.Create;
      if Trim(aAttrTxt) <> '' then
      begin
        RegExTag.Subject := aAttrTxt;
        CheckAttr := aAttrTxt;
        RegExTag.Options := [preCaseLess, preMultiLine, preSingleLine];
        RegExTag.Replacement := '';
        // here RegExp for processing attributes of tags
        // First not Empty - attribute, next - value
        RegExTag.RegEx := '([^\s]*?[^\S]*)=([^\S]*".*?"[^\S]*)|' +
          '([^\s]*?[^\S]*)=([^\S]*'#39'.*?'#39'[^\S]*)|' +
          '([^\s]*?[^\S]*)=([^\S]*[^\s]+[^\S]*)|' +
          '(allowTransparency[^\S]*)()|' +
          '(allowfullscreen[^\S]*)()|' +
          '(novalidate[^\S]*)()|' +
          '(autofocus[^\S]*)()|' +
          '(itemscope[^\S]*)()|' +
          '(disabled[^\S]*)()|' +
          '(readonly[^\S]*)()|' +
          '(selected[^\S]*)()|' +
          '(checked[^\S]*)()|' +
          '(pubdate[^\S]*)()|' +
          '(nowrap[^\S]*)()|' +
          '(hidden[^\S]*)()|' +
          '(async[^\S]*)()';
        if RegExTag.Match then
        begin
          MatchAttr;
          while RegExTag.MatchAgain do
            MatchAttr;
          // ***Start Check Parsing Tag Attributes Error****
          if Length(Trim(CheckAttr)) > 0 then
            Owner.FParseErr.Add('Warning: parsed not all attributes, ' +
              'sourse string: ' + aAttrTxt + #13#10 +
              'not parsed string: ' + Trim(CheckAttr));
          // ***End Check Parsing Tag Attributes Error************
        end
        else
          Owner.FParseErr.Add('Attributtes not found - ' +
            'Sourse string: ' + aAttrTxt);
      end;
    except
      on E: Exception do
        Owner.FParseErr.Add('Attributtes - ' + E.ClassName + ' : ' +
          E.Message + 'Sourse string: ' + aAttrTxt);
    end;
  end;

  function GetTagTxt(aTxt: string): TTagItem;
  begin
    try
      Result[0] := ''; // name tag
      Result[1] := ''; // text attributes
      Result[2] := ''; // text value following for tag
      Result[3] := ''; // type tag
      if LeftStr(Trim(aTxt), 2) = '</' then
        Result[3] := '</%s>'  //close
      else if RightStr(Trim(aTxt), 2) = '/>' then
        Result[3] := '<%s/>'  //selfclose
      else if LeftStr(Trim(aTxt), 2) = '<!' then
        Result[3] := '%s'
      else if LeftStr(Trim(aTxt), 2) = '<?' then
        Result[3] := '%s'
      else
        Result[3] := '<%s>';  // open
      RegExTag.Subject := aTxt;
      RegExTag.Options := [preCaseLess, preMultiLine, preSingleLine];
      // here RegExp for processing HTML tags
      // Group 1- tag, 2- attributes, 3- text
      RegExTag.RegEx := '<([/A-Z][:A-Z0-9]*)\b([^>]*)>([^<]*)';
      if RegExTag.Match then
      begin
          // ****************Start Check Parsing HTML Tag Error************
        if aTxt <> '<' + RegExTag.Groups[1] + RegExTag.Groups[2] + '>' + RegExTag.Groups[3] then
          Owner.FParseErr.Add('Check error Tags parsing - ' + 'Sourse string: ' + aTxt);
          // ****************End Check Parsing HTML Tag Error************
        Result[0] := Trim(RegExTag.Groups[1]);
        if Trim(RegExTag.Groups[2]) <> '' then
          if RightStr(Trim(RegExTag.Groups[2]), 1) = '/' then
            Result[1] := LeftStr(Trim(RegExTag.Groups[2]), Length(Trim(RegExTag.Groups[2])) - 1)
          else
            Result[1] := Trim(RegExTag.Groups[2]);
        Result[2] := RegExTag.Groups[3];
      end
      else
        Result[0] := Trim(aTxt);
    except
      on E: Exception do
        Owner.FParseErr.Add('Tags - ' + E.ClassName + ' : ' + E.Message +
          'Sourse string: ' + aTxt);
    end;
  end;

  function GetPairTagTxt(aTxt, aPattern: string): TTagItem;
  begin
    try
      Result[0] := ''; // name tag
      Result[1] := ''; // text attributes
      Result[2] := ''; // text value following for tag
      Result[3] := ''; // close tag

      RegExTag.Subject := aTxt;
      RegExTag.Options := [preCaseLess, preMultiLine, preSingleLine];
      // here RegExp for processing HTML tags
      // Group 1- tag, 2- attributes, 3- text
      RegExTag.RegEx := aPattern;
      if RegExTag.Match then
      begin
          // ****************Start Check Parsing HTML Tag Error************
        if Trim(aTxt) <> '<' + RegExTag.Groups[1] + RegExTag.Groups[2] + '>' + RegExTag.Groups[3] + '<' + RegExTag.Groups
          [4] + '>' then
          Owner.FParseErr.Add('Check error Exception Tags parsing - ' + 'Sourse string: ' + aTxt);
          // ****************End Check Parsing HTML Tag Error************
        Result[0] := Trim(RegExTag.Groups[1]);
        Result[1] := Trim(RegExTag.Groups[2]);
        Result[2] := Trim(RegExTag.Groups[3]);
        Result[3] := Trim(RegExTag.Groups[4]);
      end
      else
        Result[0] := aTxt;
    except
      on E: Exception do
        Owner.FParseErr.Add('Exception Tags - ' + E.ClassName + ' : ' + E.Message +
          'Sourse string: ' + aTxt);
    end;
  end;

  function CheckParent(aChildTree: TDomTreeNode; aTag: string): TDomTreeNode;
  var
    ParentTag: string;
  begin
    Result := aChildTree.Parent;
    if aTag = '<%s>' then
      Result := aChildTree
    else if aTag = '</%s>' then
      if Assigned(aChildTree.Parent.Parent) then
      begin
        ParentTag := aChildTree.Parent.Tag;
        if ParentTag = RightStr(aChildTree.Tag, Length(aChildTree.Tag) - 1) then
          Result := aChildTree.Parent.Parent;
      end;
  end;

  procedure MatchTag(aTxtMatch: string);
  var
    ExceptTag: string;
    ChildIndex: Integer;
    TagItem: TTagItem;
  begin
    // tag without close tag
    ExceptTag :=
      ',META,LINK,IMG,COL,AREA,BASE,BASEFONT,ISINDEX,BGSOUNDCOMMAND,PARAM,INPUT,EMBED,FRAME,BR,WBR,HR,TRACK,';

    if (LeftStr(aTxtMatch, 4) = '<!--') then
    begin
      TagItem[0] := Trim(aTxtMatch);
      TagItem[1] := '';
      TagItem[2] := '';
      TagItem[3] := '%s';
      ChildTree.Child.Add(TDomTreeNode.Create(ChildTree.Owner, ChildTree, TagItem[0], '', nil, '%s'));
    end
    else if (AnsiUpperCase(LeftStr(aTxtMatch, 7)) = '<TITLE>')        // tag with any symbol
      or (AnsiUpperCase(LeftStr(aTxtMatch, 10)) = '<PLAINTEXT>')
      or (AnsiUpperCase(LeftStr(aTxtMatch, 5)) = '<XMP>')
      or (AnsiUpperCase(LeftStr(aTxtMatch, 7)) = '<SCRIPT')
      or (AnsiUpperCase(LeftStr(aTxtMatch, 9)) = '<TEXTAREA')
          //or (AnsiUpperCase(leftstr(mTxtMatch, 4)) = '<PRE')
        then
    begin
      TagItem := GetPairTagTxt(aTxtMatch, '<([A-Z][A-Z0-9]*)\b([^>]*?)>(.*)<(/\1)>');
      ChildIndex := ChildTree
        .Child.Add(TDomTreeNode.Create(ChildTree.Owner, ChildTree, TagItem[0], TagItem[1], GetAttr(TagItem[1]), '<%s>'));

      if TagItem[2] <> '' then
        ChildTree.Child[ChildIndex]
          .Child.Add(TDomTreeNode.Create(ChildTree.Owner, ChildTree.Child[ChildIndex], '', '', nil, '', TagItem[2]));

      ChildTree.Child[ChildIndex]
        .Child.Add(TDomTreeNode.Create(ChildTree.Owner, ChildTree.Child[ChildIndex], TagItem[3], '', nil, '</%s>'));
    end
    else
    begin
      TagItem := GetTagTxt(aTxtMatch);

      ChildIndex := ChildTree.Child.Add(
        TDomTreeNode.Create(ChildTree.Owner, ChildTree, TagItem[0], TagItem[1], GetAttr(TagItem[1]), TagItem[3]));

      if (Pos(',' + AnsiUpperCase(Trim(TagItem[0])) + ',', ExceptTag) = 0)
        and (LeftStr(TagItem[0], 2) <> '<?')
        and (LeftStr(TagItem[0], 2) <> '<!')
        then
        ChildTree := CheckParent(ChildTree.Child[ChildIndex], TagItem[3]);

      if TagItem[2] <> '' then
      begin
        ChildTree.Child.Add(TDomTreeNode.Create(ChildTree.Owner, ChildTree, '', '', nil, '', TagItem[2]));
        {if ChildTree.FText.IsEmpty then
          if not StartsText('<', TagItem[2]) then
            ChildTree.FText := Trim(TagItem[2]);  }
      end;
    end;
  end;

begin
  RegExHTML := nil;
  RegExTag := nil;
  try
    HtmlUtf8 := HtmlTxt;
    RegExHTML := TPerlRegEx.Create;
    RegExTag := TPerlRegEx.Create;
    ErrParseHTML := 0;
    RegExHTML.Options := [preCaseLess, preMultiLine, preSingleLine];
    ChildTree := Self;
    with RegExHTML do
    begin
      // (<title>.*</title>[^<]*)   - title
      // (<\!--.+?-->[^<]*)         - comment
      // (<script.*?</script>[^<]*) - script
      // (<[^>]+>[^<]*)             - all remaining  tags
      // [^<]*                      - text
      RegExException := '(<PLAINTEXT>.*?</PLAINTEXT>[^<]*)|' +
        '(<title>.*?</title>[^<]*)|' +
        '(<xmp>.*?</xmp>[^<]*)|' +
        '(<script.*?</script>[^<]*)|' +
        '(<textarea.*?</textarea>[^<]*)|' +
      //'(<pre.*?</pre>[^<]*)|'+
          '(<!--.+?-->[^<]*)|';
      RegEx := RegExException + '(<[^>]+>[^<]*)'; // all teg and text
      Subject := HtmlUtf8;
      if Match then
      begin
        MatchTag(RegExHTML.MatchedText);
        prev := MatchedOffset + MatchedLength;
        while MatchAgain do
        begin
          MatchTag(RegExHTML.MatchedText);
          // *****Start Check Parsing HTML Error************
          if MatchedOffset - prev > 0 then
          begin
            Owner.FParseErr.Add(IntToStr(ErrParseHTML) + '- Check error found after HTML parsing');
            Inc(ErrParseHTML)
          end;
          prev := MatchedOffset + MatchedLength;
          // *****End Check Parsing HTML  Error************
        end;
      end
      else
        raise Exception.Create('Input text not contain HTML tags');
    end;
  finally
    RegExHTML.Free;
    RegExTag.Free;
    Result := Owner.FCount > 0;
  end;
end;

end.

