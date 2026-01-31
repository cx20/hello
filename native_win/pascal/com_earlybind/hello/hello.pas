program hello;

{$mode delphi}

uses
  Windows, ActiveX, ShlObj, ComObj;

const
  ssfWINDOWS = 36;
  CLSID_Shell: TGUID = '{13709620-C279-11CE-A49E-444553540000}';
  IID_IShellDispatch: TGUID = '{D8F015C0-C278-11CE-A49E-444553540000}';

type
  IShellDispatch = interface(IDispatch)
    ['{D8F015C0-C278-11CE-A49E-444553540000}']
    function get_Application(out ppid: IDispatch): HRESULT; stdcall;
    function get_Parent(out ppid: IDispatch): HRESULT; stdcall;
    function NameSpace(vDir: OleVariant; out ppsdf: IDispatch): HRESULT; stdcall;
    function BrowseForFolder(Hwnd: Integer; Title: WideString; 
      Options: Integer; RootFolder: OleVariant; out ppsdf: IDispatch): HRESULT; stdcall;
  end;

var
  pShell: IShellDispatch;
  pFolder: IDispatch;
  vRootFolder: OleVariant;
  hr: HRESULT;

begin
  CoInitialize(nil);
  try
    hr := CoCreateInstance(CLSID_Shell, nil, CLSCTX_INPROC_SERVER, 
                           IID_IShellDispatch, pShell);
    if Succeeded(hr) then
    begin
      vRootFolder := ssfWINDOWS;
      
      hr := pShell.BrowseForFolder(0, 'Hello, COM World!', 0, vRootFolder, pFolder);
      
      if (Succeeded(hr)) and (pFolder <> nil) then
      begin
        pFolder := nil;
      end;
      
      pShell := nil;
    end;
  finally
    CoUninitialize;
  end;
end.
	