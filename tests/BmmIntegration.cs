using System;
using System.IO;
using System.Linq;
using BeyondModManager;
class TuningPackageTest {
 static void Check(bool ok,string text){if(!ok)throw new Exception(text);Console.WriteLine("PASS "+text);}
 static void Write(string p,string text){Directory.CreateDirectory(Path.GetDirectoryName(p));File.WriteAllText(p,text);}
 static void Main(string[] args){
  if(args[0]=="install") {var live=new ModStore(args[1],null);var plan=live.PreviewZip(args[2]);Check(plan.Id=="beyondtuning","identity");Check(plan.MissingDependencies.Count==0,"dependencies satisfied");var record=live.Install(plan);Check(record.Managed&&record.Enabled,"installed and enabled by Beyond Mod Manager");return;}
  bool standalone=args.Length>2&&args[2]=="standalone";var root=Path.GetFullPath(args[0]);var game=Path.Combine(root,"Game");var bin=Path.Combine(game,GameInstallation.BinaryRoot);var mods=Path.Combine(game,GameInstallation.ModsRoot);
  Write(Path.Combine(bin,"DriveBeyondHorizons-Win64-Shipping.exe"),"fixture");Write(Path.Combine(bin,"ue4ss/UE4SS.dll"),"fixture");
  if(!standalone){Write(Path.Combine(mods,"BeyondApocalypse/Scripts/main.lua"),"-- fixture");Write(Path.Combine(mods,"mods.txt"),"BeyondApocalypse : 1\n");}
  var store=new ModStore(game,Path.Combine(root,"Data"),()=>false);var plan2=store.PreviewZip(args[1]);
  Check(plan2.Id=="beyondtuning"&&plan2.Version=="1.0.0","Nexus archive recognized");Check(plan2.MissingDependencies.Count==0,"UE4SS detected");
  var record2=store.Install(plan2);Check(record2.Managed&&record2.Enabled,"fresh installation");
  var folder=Path.Combine(mods,"BeyondTuning");var settings=Path.Combine(folder,"state/settings.json");var preset=Path.Combine(folder,"presets/Street.json");
  Write(settings,"user settings");Write(preset,"customized preset");store.Install(store.PreviewZip(args[1]));
  Check(File.ReadAllText(settings)=="user settings"&&File.ReadAllText(preset)=="customized preset","updates preserve user settings and presets");
  var list=File.ReadAllText(Path.Combine(mods,"mods.txt"));Check(standalone?!Directory.Exists(Path.Combine(mods,"BeyondApocalypse")):list.IndexOf("BeyondApocalypse")<list.IndexOf("BeyondTuning"),standalone?"standalone install requires no Apocalypse":"load order follows Apocalypse");
  store.SetEnabled("beyondtuning",false);Check(!File.Exists(Path.Combine(folder,"Scripts/main.lua")),"disable removes active mod");
  store.SetEnabled("beyondtuning",true);Check(File.Exists(Path.Combine(folder,"Scripts/main.lua")),"enable restores mod");
  store.Uninstall("beyondtuning");Check(!File.Exists(Path.Combine(folder,"Scripts/main.lua")),"uninstall removes code");
  if(!standalone)Check(File.ReadAllText(Path.Combine(mods,"BeyondApocalypse/Scripts/main.lua"))=="-- fixture","Apocalypse untouched");
 }
}
