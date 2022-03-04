import core.sys.windows.windef;
import core.sys.windows.com;

GUID CLSID_Shell         = { 0x13709620, 0xC279, 0x11CE, [0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00] };
GUID IID_Folder          = { 0xBBCBDE60, 0xC3FF, 0x11CE, [0x83, 0x50, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00] };
GUID IID_FolderItem      = { 0xFAC32C80, 0xCBE4, 0x11CE, [0x83, 0x50, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00] };
GUID IID_FolderItems     = { 0x744129E0, 0xCBE5, 0x11CE, [0x83, 0x50, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00] };
GUID IID_IShellDispatch  = { 0xD8F015C0, 0xC278, 0x11CE, [0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00] };

alias DWORD* DWORD_PTR;
alias uint LCID;
alias uint REFIID;
alias uint DISPID;
alias uint DISPPARAMS;
alias uint EXCEPINFO;
alias wchar*  BSTR;
alias uint ITypeInfo;
alias short VARIANT_BOOL;
alias double DATE;
 
enum /*VARENUM*/ : ushort {
  VT_I4               = 3
}
 
struct VARIANT {
 
  union {
    struct {
      /// Describes the type of the instance.
      ushort vt;
      ushort wReserved1;
      ushort wReserved2;
      ushort wReserved3;
      union {
        int lVal;
      }
    }
  }
}
 
extern (System) {
    interface IDispatch : IUnknown {
        HRESULT GetTypeInfoCount(UINT *pctinfo);
        HRESULT GetTypeInfo(UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
        HRESULT GetIDsOfNames(REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
        HRESULT Invoke(DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    }
 
    interface FolderItemVerb : IDispatch
    {
        HRESULT Application (IDispatch **ppid);
        HRESULT Parent(IDispatch **ppid);
        HRESULT Name(BSTR *pbs);
        HRESULT DoIt();
    }
 
    interface FolderItemVerbs : IDispatch
    {
        HRESULT Count(LONG *plCount);
        HRESULT Application (IDispatch **ppid);
        HRESULT Parent(IDispatch **ppid);
        HRESULT Item(VARIANT index, FolderItemVerb **ppid);
        HRESULT _NewEnum(IUnknown **ppunk);
    }
 
    interface FolderItem : IDispatch
    {
        alias FolderItem* LPFOLDERITEM;      // For C callers
        HRESULT Application (IDispatch **ppid);
        HRESULT Parent(IDispatch **ppid);
        HRESULT Name(BSTR *pbs);
        HRESULT Name(BSTR bs);
        HRESULT Path(BSTR *pbs);
        HRESULT GetLink(IDispatch **ppid);
        HRESULT GetFolder(IDispatch **ppid);
        HRESULT IsLink(VARIANT_BOOL *pb);
        HRESULT IsFolder(VARIANT_BOOL *pb);
        HRESULT IsFileSystem(VARIANT_BOOL *pb);
        HRESULT IsBrowsable(VARIANT_BOOL *pb);
        HRESULT ModifyDate(DATE *pdt);
        HRESULT ModifyDate(DATE dt);
        HRESULT Size(LONG *pul);
        HRESULT Type(BSTR *pbs);
        HRESULT Verbs(FolderItemVerbs **ppfic);
        HRESULT InvokeVerb(VARIANT vVerb);
    }
 
    interface FolderItems : IDispatch
    {
        HRESULT Count(LONG *plCount);
        HRESULT Application (IDispatch **ppid);
        HRESULT Parent(IDispatch **ppid);
        HRESULT Item(VARIANT index, FolderItem **ppid);
        HRESULT _NewEnum(IUnknown **ppunk);
    }
 
    interface Folder : IDispatch
    {
        HRESULT Title(BSTR *pbs);
        HRESULT Application (IDispatch **ppid);
        HRESULT Parent(IDispatch **ppid);
        HRESULT ParentFolder(Folder **ppsf);
        HRESULT Items(FolderItems **ppid);
        HRESULT ParseName(BSTR bName, FolderItem **ppid);
        HRESULT NewFolder(BSTR bName, VARIANT vOptions);
        HRESULT MoveHere(VARIANT vItem, VARIANT vOptions);
        HRESULT CopyHere(VARIANT vItem, VARIANT vOptions);
        HRESULT GetDetailsOf(VARIANT vItem, LONG iColumn, BSTR *pbs);
    }
 
    interface IShellDispatch : IDispatch
    {
        HRESULT get_Application( IDispatch **ppid);
        HRESULT get_Parent( IDispatch **ppid);
        HRESULT NameSpace( VARIANT vDir, Folder **ppsdf);
        HRESULT BrowseForFolder( LONG Hwnd, BSTR Title, LONG Options, VARIANT RootFolder /*, Folder **ppsdf */);
        HRESULT Windows( IDispatch **ppid);
        HRESULT Open( VARIANT vDir);
        HRESULT Explore( VARIANT vDir);
        HRESULT MinimizeAll();
        HRESULT UndoMinimizeALL();
        HRESULT FileRun();
        HRESULT CascadeWindows();
        HRESULT TileVertically();
        HRESULT TileHorizontally();
        HRESULT ShutdownWindows();
        HRESULT Suspend();
        HRESULT EjectPC();
        HRESULT SetTime();
        HRESULT TrayProperties();
        HRESULT Help();
        HRESULT FindFiles();
        HRESULT FindComputer();
        HRESULT RefreshMenu();
        HRESULT ControlPanelItem( BSTR bstrDir);
    }
}
 
int main( char[][] args )
{
    HRESULT hr;
    IShellDispatch pShell;
 
    VARIANT vRootFolder;
    vRootFolder.vt = VT_I4;
    vRootFolder.lVal = 36;
    vRootFolder.wReserved1 = 0;
    vRootFolder.wReserved2 = 0;
    vRootFolder.wReserved3 = 0;
 
    hr = CoInitialize(null);
    hr = CoCreateInstance(&CLSID_Shell, null, CLSCTX_ALL, &IID_IShellDispatch, cast(PVOID*)&pShell);
    hr = pShell.BrowseForFolder( 0, cast(wchar*)"Hello, COM(D) World!", 0, vRootFolder );
 
    CoUninitialize();
    return 0;
}
