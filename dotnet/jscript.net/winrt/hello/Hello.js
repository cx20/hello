// Hello.js - WinRT Toast (Desktop / no UWP)
// Build with jsc.exe (this script compiles a tiny C# helper in-memory for WinRT APIs)

import System;
import System.CodeDom.Compiler;
import System.Reflection;
import System.Threading;
import Microsoft.CSharp;

function Log(msg : String)
{
    var line = "[JScript.WinRT.Toast] " + DateTime.Now.ToString("HH:mm:ss.fff") + " " + msg;
    Console.WriteLine(line);
}

function BuildWinRtToastHelper() : Type
{
    Log("BuildWinRtToastHelper: begin");

    var source =
        "using System;\n" +
        "using System.Runtime.InteropServices;\n" +
        "using System.Threading;\n" +
        "using Windows.Data.Xml.Dom;\n" +
        "using Windows.UI.Notifications;\n" +
        "public static class WinRtToastBridge {\n" +
        "  [DllImport(\"kernel32.dll\", CharSet = CharSet.Unicode)]\n" +
        "  static extern void OutputDebugStringW(string text);\n" +
        "  [DllImport(\"shell32.dll\", CharSet = CharSet.Unicode, SetLastError = true)]\n" +
        "  static extern int SetCurrentProcessExplicitAppUserModelID(string appID);\n" +
        "  public static void Log(string text) {\n" +
        "    OutputDebugStringW(\"[JScript.WinRT.Toast.CS] \" + DateTime.Now.ToString(\"HH:mm:ss.fff\") + \" \" + text + \"\\n\");\n" +
        "  }\n" +
        "  public static void Show() {\n" +
        "    try {\n" +
        "      Log(\"Show: begin\");\n" +
        "      const string AppId = \"Hello, World!\";\n" +
        "      int hrAumid = SetCurrentProcessExplicitAppUserModelID(AppId);\n" +
        "      Log(\"SetCurrentProcessExplicitAppUserModelID hr=0x\" + hrAumid.ToString(\"X8\"));\n" +
        "      var xml = new XmlDocument();\n" +
        "      xml.LoadXml(\"<toast activationType=\\\"protocol\\\" launch=\\\"imsprevn://0\\\" duration=\\\"long\\\">\" +\n" +
        "                  \"  <visual>\" +\n" +
        "                  \"    <binding template=\\\"ToastGeneric\\\">\" +\n" +
        "                  \"      <text><![CDATA[Hello, WinRT(JScript.NET) World!]]></text>\" +\n" +
        "                  \"    </binding>\" +\n" +
        "                  \"  </visual>\" +\n" +
        "                  \"  <audio src=\\\"ms-winsoundevent:Notification.Mail\\\" loop=\\\"false\\\" />\" +\n" +
        "                  \"</toast>\");\n" +
        "      Log(\"XmlDocument.LoadXml: ok\");\n" +
        "      var toast = new ToastNotification(xml);\n" +
        "      Log(\"ToastNotification ctor: ok\");\n" +
        "      var notifier = ToastNotificationManager.CreateToastNotifier(AppId);\n" +
        "      Log(\"CreateToastNotifier: ok\");\n" +
        "      notifier.Show(toast);\n" +
        "      Log(\"ToastNotifier.Show: ok\");\n" +
        "      Thread.Sleep(3000);\n" +
        "      Log(\"Show: end\");\n" +
        "    } catch (Exception ex) {\n" +
        "      Log(\"Show: exception: \" + ex.ToString());\n" +
        "      throw new Exception(\"WinRtToastBridge.Show failed: \" + ex.ToString());\n" +
        "    }\n" +
        "  }\n" +
        "}\n";

    var provider = new CSharpCodeProvider();
    var cp = new CompilerParameters();
    cp.GenerateExecutable = false;
    cp.GenerateInMemory = true;
    cp.WarningLevel = 0;
    cp.TreatWarningsAsErrors = false;
    cp.ReferencedAssemblies.Add("System.dll");
    cp.ReferencedAssemblies.Add("mscorlib.dll");
    cp.ReferencedAssemblies.Add("System.Core.dll");
    cp.ReferencedAssemblies.Add("C:\\Program Files (x86)\\Reference Assemblies\\Microsoft\\Framework\\.NETFramework\\v4.8\\Facades\\System.Runtime.dll");
    cp.ReferencedAssemblies.Add("C:\\Program Files (x86)\\Windows Kits\\10\\UnionMetadata\\10.0.26100.0\\Windows.winmd");
    cp.ReferencedAssemblies.Add("C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\System.Runtime.WindowsRuntime.dll");

    Log("BuildWinRtToastHelper: compiling C# bridge");
    var cr = provider.CompileAssemblyFromSource(cp, [source]);
    if (cr.Errors.HasErrors)
    {
        var lines = "C# helper compile failed:";
        for (var i = 0; i < cr.Errors.Count; i++)
        {
            lines += "\n" + cr.Errors[i].ToString();
        }
        Log(lines);
        throw new Exception(lines);
    }
    Log("BuildWinRtToastHelper: compile ok");
    return cr.CompiledAssembly.GetType("WinRtToastBridge", true);
}

try
{
    Log("Main: begin");
    var helperType = BuildWinRtToastHelper();
    helperType.InvokeMember("Log", BindingFlags.Public + BindingFlags.Static + BindingFlags.InvokeMethod, null, null, ["Bridge loaded"]);
    var showMethod = helperType.GetMethod("Show", BindingFlags.Public + BindingFlags.Static);
    if (showMethod == null)
    {
        throw new Exception("Show method not found on WinRtToastBridge.");
    }
    helperType.InvokeMember("Log", BindingFlags.Public + BindingFlags.Static + BindingFlags.InvokeMethod, null, null, ["Invoking Show"]);
    showMethod.Invoke(null, null);
    helperType.InvokeMember("Log", BindingFlags.Public + BindingFlags.Static + BindingFlags.InvokeMethod, null, null, ["Show returned"]);
    Log("Main: end");
}
catch (e)
{
    Log("ERROR: WinRT toast failed.");
    try { Console.WriteLine("Message: " + e.Message); } catch (_1) {}
    try { Console.WriteLine("Detail : " + e); } catch (_2) {}
    try { if (e.InnerException != null) Console.WriteLine("Inner : " + e.InnerException.ToString()); } catch (_3) {}
    Thread.Sleep(1000);
    throw e;
}
