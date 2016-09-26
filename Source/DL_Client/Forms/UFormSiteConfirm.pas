unit UFormSiteConfirm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, UFormNormal, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxLayoutControl, StdCtrls, CPort, CPortTypes,
  dxLayoutcxEditAdapters, cxContainer, cxEdit, cxTextEdit, cxMaskEdit,
  cxDropDownEdit, cxLabel;

type
  TfFormSiteConfirm = class(TfFormNormal)
    ComPort1: TComPort;
    EditCard: TcxTextEdit;
    dxLayout1Item3: TdxLayoutItem;
    EditLID: TcxTextEdit;
    dxLayout1Item4: TdxLayoutItem;
    EditTruck: TcxTextEdit;
    dxLayout1Item5: TdxLayoutItem;
    EditStockName: TcxTextEdit;
    dxLayout1Item6: TdxLayoutItem;
    EditPlanWeight: TcxTextEdit;
    dxLayout1Item7: TdxLayoutItem;
    cbxSampleID: TcxComboBox;
    dxLayout1Item8: TdxLayoutItem;
    cxLabel1: TcxLabel;
    dxLayout1Item11: TdxLayoutItem;
    EditType: TcxTextEdit;
    dxLayout1Item12: TdxLayoutItem;
    cbxWorkSet: TcxComboBox;
    dxLayout1Item9: TdxLayoutItem;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ComPort1RxChar(Sender: TObject; Count: Integer);
    procedure BtnOKClick(Sender: TObject);
  private
    { Private declarations }
    FStockType:Integer;
    //���ͣ�1����װ 2��ɢװ
    FBuffer: string;
    //���ջ���
    FSumTon:Double;
    //��װ����
    FWorkOrder:string;
    //���
    procedure ActionComPort(const nStop: Boolean);
    procedure GetBillsInfo(const nCardNo: string); //��ȡ��������Ϣ
    function GetNotOutBill(const nFID: string):Boolean; //��ȡδ����������
    procedure ShowFormData;  //��ʾ����
    procedure ClearFormData; //�������
    procedure GetSampleID(const nStockName,nType: string); //��ȡ�������
    function GetSumTonnage(const nSampleID: string):Double;//��ȡ�����������װ����
    function GetSampleTonnage(const nSampleID: string; var nBatQuaS,nBatQuaE:Double):Boolean; //��ȡ������
    function UpdateSampleValid(const nSampleID: string):Boolean;//�������������Ч��
    function GetWorkOrder:string;//��ȡ���
  public
    { Public declarations }
    class function CreateForm(const nPopedom: string = '';
      const nParam: Pointer = nil): TWinControl; override;
    class function FormID: integer; override;
  end;

var
  fFormSiteConfirm: TfFormSiteConfirm;

implementation

{$R *.dfm}
uses
  IniFiles, ULibFun, UMgrControl, UDataModule, UFormBase, UFormInputbox, USysGrid,
  UFormCtrl, USysDB, UBusinessConst, USysConst ,USysLoger, USmallFunc, USysBusiness;

type
  TReaderType = (ptT800, pt8142);
  //��ͷ����

  TReaderItem = record
    FType: TReaderType;
    FPort: string;
    FBaud: string;
    FDataBit: Integer;
    FStopBit: Integer;
    FCheckMode: Integer;
  end;
  //������ݼ�¼
  TBatQua = record
    FID   : string;
    FTruck : string;
    FStockName: string;
    FValue : Double;
    FType  : string;
    FCenterID: string;
    FLocationID: string;
    FSampleID: string;
  end;
var
  gReaderItem: TReaderItem;
  //ȫ��ʹ��
  gBills: TLadingBillItems;
  //�����¼�б�
  gTiHuo: array of TBatQua;
  
class function TfFormSiteConfirm.FormID: integer;
begin
  Result := cFI_FormSiteConfirm;
end;

class function TfFormSiteConfirm.CreateForm(const nPopedom: string = '';
      const nParam: Pointer = nil): TWinControl;
var
  nP: PFormCommandParam;
begin
  Result:=nil;
  with TfFormSiteConfirm.Create(Application) do
  begin
    Caption := '�ֳ�װ��ȷ��';
    ActionComPort(False);
    FStockType:=0;
    ShowModal;
    Free;
  end;
end;

procedure TfFormSiteConfirm.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  inherited;
  ActionComPort(True);
end;

procedure TfFormSiteConfirm.ActionComPort(const nStop: Boolean);
var nInt: Integer;
    nIni: TIniFile;
begin
  if nStop then
  begin
    ComPort1.Close;
    Exit;
  end;

  with ComPort1 do
  begin
    with Timeouts do
    begin
      ReadTotalConstant := 100;
      ReadTotalMultiplier := 10;
    end;

    nIni := TIniFile.Create(gPath + 'Reader.Ini');
    with gReaderItem do
    try
      nInt := nIni.ReadInteger('Param', 'Type', 1);
      FType := TReaderType(nInt - 1);

      FPort := nIni.ReadString('Param', 'Port', '');
      FBaud := nIni.ReadString('Param', 'Rate', '4800');
      FDataBit := nIni.ReadInteger('Param', 'DataBit', 8);
      FStopBit := nIni.ReadInteger('Param', 'StopBit', 0);
      FCheckMode := nIni.ReadInteger('Param', 'CheckMode', 0);

      Port := FPort;
      BaudRate := StrToBaudRate(FBaud);

      case FDataBit of
       5: DataBits := dbFive;
       6: DataBits := dbSix;
       7: DataBits :=  dbSeven else DataBits := dbEight;
      end;

      case FStopBit of
       2: StopBits := sbTwoStopBits;
       15: StopBits := sbOne5StopBits
       else StopBits := sbOneStopBit;
      end;
    finally
      nIni.Free;
    end;

    if ComPort1.Port <> '' then
      ComPort1.Open;
    //xxxxx
  end;
end;


procedure TfFormSiteConfirm.ComPort1RxChar(Sender: TObject;
  Count: Integer);
var nStr: string;
    nIdx,nLen: Integer;
    nCard:string;
begin
  ComPort1.ReadStr(nStr, Count);
  FBuffer := FBuffer + nStr;

  nLen := Length(FBuffer);
  if nLen < 7 then Exit;

  for nIdx:=1 to nLen do
  begin
    if (FBuffer[nIdx] <> #$AA) or (nLen - nIdx < 6) then Continue;
    if (FBuffer[nIdx+1] <> #$FF) or (FBuffer[nIdx+2] <> #$00) then Continue;

    nStr := Copy(FBuffer, nIdx+3, 4);
    nCard:= ParseCardNO(nStr, True);
    if nCard <> EditCard.Text then
    begin
      EditCard.Text := nCard;
      cxLabel1.Caption:='��װ������';
      FSumTon:=0;
      GetBillsInfo(Trim(EditCard.Text));
    end;
    FBuffer := '';
    Exit;
  end;
end;

procedure TfFormSiteConfirm.GetBillsInfo(const nCardNo: string);
var nStr,nHint: string;
    nIdx,nInt: Integer;
    nFID, nTruck:string;
begin
  nFID:='';
  if GetLadingBills(nCardNo, sFlag_TruckFH, gBills) then
  begin
    nInt := 0 ;
    nHint := '';
    FStockType := 2;
    for nIdx:=Low(gBills) to High(gBills) do
    with gBills[nIdx] do
    begin
      FSelected := FNextStatus = sFlag_TruckFH;
      if FSelected then
      begin
        Inc(nInt);
        Continue;
      end;

      nStr := '��.����:[ %s ] ״̬:[ %-6s -> %-6s ]   ';
      if nIdx < High(gBills) then nStr := nStr + #13#10;

      nStr := Format(nStr, [FID,
              TruckStatusToStr(FStatus), TruckStatusToStr(FNextStatus)]);
      nHint := nHint + nStr;
      nFID:=FID;
      nTruck:=FTruck;
    end;

    if (nHint <> '') and (nInt = 0) then
    begin
      if GetLadingBills(nCardNo, sFlag_TruckZT, gBills) then
      begin
        nInt := 0;
        nHint := '';
        FStockType := 1;
        for nIdx:=Low(gBills) to High(gBills) do
        with gBills[nIdx] do
        begin
          FSelected := FNextStatus = sFlag_TruckZT;
          if FSelected then
          begin
            Inc(nInt);
            Continue;
          end;

          nStr := '��.����:[ %s ] ״̬:[ %-6s -> %-6s ]   ';
          if nIdx < High(gBills) then nStr := nStr + #13#10;

          nStr := Format(nStr, [FID,
                  TruckStatusToStr(FStatus), TruckStatusToStr(FNextStatus)]);
          nHint := nHint + nStr;
          nFID:=FID;
          nTruck:=FTruck;
        end;

        if (nHint <> '') and (nInt = 0) then
        begin
          nHint := '����['+nTruck+']��ǰ����װ��,��������: ' + #13#10#13#10 +
                   nHint + #13#10#13#10 + '�Ƿ��޸�������ţ�';
          if not QueryDlg(nHint, sAsk) then
          begin
            EditCard.Text:='��ˢ��';
            Exit;
          end;
          if GetNotOutBill(nFID) then
          begin
            BtnOK.Caption:='�޸�';
            BtnOK.Enabled:=True;
          end else
          begin
            nHint := '����['+nTruck+']��ֹ�޸�,�������£�'+ #13#10#13#10 + nStr;
            ShowDlg(nHint, sHint);
          end;
          Exit;
        end;
        ShowFormData;
      end else
      begin
        nHint := '����['+nTruck+']��ǰ����װ��,��������: ' + #13#10#13#10 +
                 nHint + #13#10#13#10 + '�Ƿ��޸�������ţ�';
        if not QueryDlg(nHint, sAsk) then
        begin
          EditCard.Text:='��ˢ��';
          Exit;
        end;
        if GetNotOutBill(nFID) then
        begin
          BtnOK.Caption:='�޸�';
          BtnOK.Enabled:=True;
        end else
        begin
          nHint := '����['+nTruck+']��ֹ�޸�,�������£�'+ #13#10#13#10 + nStr;
          ShowDlg(nHint, sHint);
        end;
        Exit;
      end;
    end;
    ShowFormData;
    cbxWorkSet.Text:=GetWorkOrder;
  end else
  begin
    nHint := '�޽���������';
    ShowDlg(nHint, sHint);
  end;
end;

//��ȡδ����������
function TfFormSiteConfirm.GetNotOutBill(const nFID: string):Boolean;
var
  nSQL,nType:string;
  nLocationID:string;
  i:Integer;
begin
  Result:=False;
  SetLength(gTiHuo,0);
  nSQL := 'select * from %s '+
          'where ((L_Status=''%s'') or (L_Status=''%s'') or (L_Status=''%s'')) '+
          'and L_ID=''%s'' ';
  nSQL := Format(nSQL,[sTable_Bill, sFlag_TruckZT, sFlag_TruckFH, sFlag_TruckBFM, nFID]);
  with FDM.QueryTemp(nSQL) do
  begin
    if RecordCount > 0 then
    begin
      SetLength(gTiHuo,RecordCount);
      with gTiHuo[0] do
      begin
        FID:= FieldByName('L_ID').AsString;
        FTruck:= FieldByName('L_Truck').AsString;
        FStockName:= FieldByName('L_StockName').AsString;
        FValue:= FieldByName('L_Value').AsFloat;
        if FieldByName('L_Type').AsString='0' then
          nType:='S'
        else
          nType:= FieldByName('L_Type').AsString;
        FType:= nType;
        FCenterID:= FieldByName('L_InvCenterId').AsString;
        FLocationID:= FieldByName('L_InvLocationId').AsString;
        FSampleID:= FieldByName('L_HYDan').AsString;
      end;
    end;
  end;
  with gTiHuo[0] do
  begin
    EditLID.Text:= FID;
    EditTruck.Text:= FTruck;
    EditStockName.Text:= FStockName;
    EditPlanWeight.Text:= FloatToStr(FValue);
    EditType.Text:= FType;
    GetSampleID(FStockName,nType);
    cbxSampleID.Text:= FSampleID;
  end;
  Result:=True;
end;

procedure TfFormSiteConfirm.ShowFormData;
var
  nIdx: Integer;
  nLocationID:string;
  nType:string;
begin
  with gBills[0] do
  begin
    EditLID.Text:= gBills[0].FID;
    EditTruck.Text:= gBills[0].FTruck;
    EditStockName.Text:= gBills[0].FStockName;
    EditPlanWeight.Text:= FloatToStr(gBills[0].FValue);
    if FType='0' then nType:='S' else nType:=FType;
    EditType.Text:= nType;
    GetSampleID(FStockName,nType);
  end;
  BtnOK.Enabled:=True;
end;

procedure TfFormSiteConfirm.GetSampleID(const nStockName,nType: string);
var nSQL:string;
    nIdx:Integer;
begin
  cbxSampleID.Properties.Items.Clear;
  nSQL := 'select IsNull(R_SerialNo,'''') as R_SerialNo,R_BatQuaStart,R_Date from %s a,%s b '+
          'where a.R_PID = b.P_ID and b.P_Stock= ''%s'' and b.P_Type=''%s'' and R_BatValid=''%s'' ';
  nSQL := Format(nSQL,[sTable_StockRecord, sTable_StockParam, nStockName, nType, sFlag_Yes]);
  with FDM.QueryTemp(nSQL) do
  begin
    if RecordCount > 0 then
    begin
      First;
      while not Eof do
      begin
        cbxSampleID.Properties.Items.Add(Fields[0].AsString);
        Next;
      end;
      cbxSampleID.ItemIndex:=0;
    end;
  end;
end;

//��ȡ������
function TfFormSiteConfirm.GetSampleTonnage(const nSampleID: string; var nBatQuaS,nBatQuaE:Double):Boolean;
var nSQL: string;
begin
  Result:=False;  
  nSQL := 'select R_BatQuaStart,R_BatQuaEnd,R_Date from %s where R_SerialNo= ''%s'' ';
  nSQL := Format(nSQL,[sTable_StockRecord, nSampleID]);
  with FDM.QueryTemp(nSQL) do
  begin
    if RecordCount > 0 then
    begin
      nBatQuaS:=Fields[0].AsFloat;
      nBatQuaE:=Fields[1].AsFloat;
      Result:=True;
    end;
  end;
end;

//�������������Ч��
function TfFormSiteConfirm.UpdateSampleValid(const nSampleID: string):Boolean;
var nSQL: string;
begin
  Result:=False;  
  nSQL := 'Update %s set R_BatValid=''%s'' where R_SerialNo= ''%s'' ';
  nSQL := Format(nSQL,[sTable_StockRecord, sFlag_No, nSampleID]);
  FDM.ADOConn.BeginTrans;
  try
    FDM.ExecuteSQL(nSQL);
    FDM.ADOConn.CommitTrans;
    Result:=True;
  except
    FDM.ADOConn.RollbackTrans;
    ShowMsg('����'+nSampleID+'��Ч��ʧ��', '��ʾ');
  end;
end;


function TfFormSiteConfirm.GetSumTonnage(const nSampleID: string):Double;//��ȡ�����������װ����
var nStr:string;
begin
  nStr := 'Select sum(L_Value) From %s Where L_HYDan=''%s''';
  nStr := Format(nStr, [sTable_Bill, nSampleID]);
  with FDM.QueryTemp(nStr) do
  begin
    Result:=Fields[0].AsFloat;
  end;
end;

procedure TfFormSiteConfirm.ClearFormData;
var i:Integer;
begin
  for i:= 0 to ComponentCount-1 do
  begin
    if Components[i] is TcxTextEdit then
      (Components[i] as TcxTextEdit).Text:='';
    if Components[i] is TcxComboBox then
      (Components[i] as TcxComboBox).Text:='';
  end;
end;

//��ȡ���
function TfFormSiteConfirm.GetWorkOrder:string;
var
  nNow,nStr:string;
begin
  nNow := FormatDateTime('hh:mm:ss',Now);
  nStr := 'Select Z_WorkOrder From %s Where Z_StartTime < ''%s'' and Z_EndTime >= ''%s'' ';
  nStr := Format(nStr, [sTable_ZTWorkSet, nNow, nNow]);
  with FDM.QueryTemp(nStr) do
  begin
    Result:=Fields[0].AsString;
  end;
end;

procedure TfFormSiteConfirm.BtnOKClick(Sender: TObject);
var nFoutData,nStr:string;
    nPos:Integer;
    nPlanW,nBatQuaS,nBatQuaE:Double;
    nSQL:string;
begin
  FSumTon:=0.00;
  if cbxSampleID.ItemIndex<0 then
  begin
    ShowMsg('��ѡ���������', sHint);
    Exit;
  end;
  FSumTon:=GetSumTonnage(cbxSampleID.Text);
  cxLabel1.Caption:='��װ������'+Floattostr(FSumTon);
  if GetSampleTonnage(cbxSampleID.Text, nBatQuaS, nBatQuaE) then
  begin
    if FSumTon-nBatQuaS>0 then
    begin
      ShowMsg('�������['+cbxSampleID.Text+']�ѳ���',sHint);
      if UpdateSampleValid(cbxSampleID.Text) then
        GetSampleID(EditStockName.Text,EditType.Text);
      Exit;
    end;

    nPlanW:=StrToFloat(EditPlanWeight.Text);
    FSumTon:=FSumTon+nPlanW;
    if nBatQuaS-FSumTon<=nBatQuaE then    //��Ԥ����
    begin
      nStr:='�������['+cbxSampleID.Text+']�ѵ�Ԥ����,�Ƿ�������棿';
      if not QueryDlg(nStr, sAsk) then
      begin
        {if UpdateSampleValid(cbxSampleID.Text) then
          GetSampleID(EditStockName.Text,EditType.Text); }
        Exit;
      end;
    end;
    if FSumTon-nBatQuaS>0 then
    begin
      ShowMsg('�������['+cbxSampleID.Text+']�ѳ���',sHint);
      Exit;
    end;
  end else
  begin
    ShowMsg('�������['+cbxSampleID.Text+']��ʧЧ',sHint);
    Exit;
  end;
  if BtnOK.Caption='�޸�' then
  begin
    nSQL := 'Update %s set L_HYDan=''%s'' where L_ID= ''%s'' ';
    nSQL := Format(nSQL,[sTable_Bill, cbxSampleID.Text, EditLID.Text]);
    FDM.ADOConn.BeginTrans;
    try
      FDM.ExecuteSQL(nSQL);
      FDM.ADOConn.CommitTrans;
      ShowMsg('�޸�'+EditLID.Text+'������ųɹ�', sHint);
      PrintDaiBill(EditLID.Text, False);
    except
      FDM.ADOConn.RollbackTrans;
      ShowMsg('�޸�'+EditLID.Text+'��Ϣʧ��', '��ʾ');
      Exit;
    end;
  end else
  begin
    if cbxWorkSet.Text='' then
    begin
      cbxWorkSet.Focused;
      ShowMsg('��ѡ����',sHint);
      Exit;
    end;
    with gBills[0] do
    begin
      FSampleID:= cbxSampleID.Text;
      FYSValid:= sFlag_No;
      FLocationID:= cbxWorkSet.Text;
    end;
    if FStockType=1 then
    begin
      if SaveLadingBills(nFoutData,sFlag_TruckZT, gBills) then
      begin
        ShowMsg('��װ����ɹ�', sHint);
        PrintDaiBill(EditLID.Text, False);
      end;
    end else
    if FStockType=2 then
    begin
      if SaveLadingBills(nFoutData,sFlag_TruckFH, gBills) then
      begin
        ShowMsg('ɢװ����ɹ�', sHint);
        PrintDaiBill(EditLID.Text, False);
      end;
    end else
    begin
      ShowMsg('���ʧ�ܣ�������ˢ��',sHint);
      Exit;
    end;
  end;
  FStockType:=0;
  ClearFormData;
  EditCard.Text:='��ˢ��';
  BtnOK.Caption:='�ύ';
  BtnOK.Enabled:=False;
end;

initialization
  gControlManager.RegCtrl(TfFormSiteConfirm, TfFormSiteConfirm.FormID);

end.