/* Windows file-transfer UI. No Lua ABI or game-memory access, no networking.
 * Entry points take an opaque Lua state and return zero Lua results.
 * Background workers only handle files/windows; Lua polls completed transfers. */
#ifndef UNICODE
#define UNICODE
#endif
#define _UNICODE
#define COBJMACROS
#include <windows.h>
#include <shellapi.h>
#include <commdlg.h>
#include <stdio.h>
#include <wchar.h>
#include <wincodec.h>
#include <stdlib.h>
static HMODULE module;
static volatile LONG busy;
static wchar_t root[32768];
static HWND dropWindow;
/* GPU normals are exported by Unreal. WIC decodes them; contour extraction
 * never reads cooked mesh buffers and never copies game assets into the mod. */
__declspec(dllexport) int bt_hologram(void *state);
static void path(wchar_t *out,const wchar_t *suffix){swprintf(out,32768,L"%ls\\%ls",root,suffix);}
static void init(void){
 if(root[0])return;
 GetModuleFileNameW(module,root,32768);
 wchar_t *p=wcsrchr(root,L'\\');if(p)*p=0; /* native */
 p=wcsrchr(root,L'\\');if(p)*p=0; /* assets */
 p=wcsrchr(root,L'\\');if(p)*p=0; /* mod root */
 wchar_t d[32768];path(d,L"state");CreateDirectoryW(d,0);path(d,L"presets");CreateDirectoryW(d,0);
}
/* The Lua adapter has already validated and backed up BA's entry point. Commit
 * the prepared sibling in one filesystem operation, including on Windows. */
__declspec(dllexport) int bt_commit_backpack_loader(void *state){
 wchar_t target[32768],pending[32768];init();
 path(target,L"..\\BeyondApocalypse\\Scripts\\main.lua");
 path(pending,L"..\\BeyondApocalypse\\Scripts\\main.lua.bt-pending");
 MoveFileExW(pending,target,MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH);return 0;
}
/* Migrate native-save sidecars before a player removes the old mod. These
 * records are immutable. An existing Tuning snapshot always wins. */
__declspec(dllexport) int bt_import_nitrous_saves(void *state){
 init();
 const wchar_t *folders[]={L"..\\BeyondApocalypse\\state",L"..\\BasicM4\\state"};
 for(int i=0;i<2;i++){
  wchar_t dir[32768],query[32768],src[32768],dst[32768],tmp[32768];
  path(dir,folders[i]);swprintf(query,32768,L"%ls\\nitrous-*.txt",dir);
  WIN32_FIND_DATAW f;HANDLE h=FindFirstFileW(query,&f);
  if(h==INVALID_HANDLE_VALUE)continue;
  do{
   if(f.dwFileAttributes&(FILE_ATTRIBUTE_DIRECTORY|FILE_ATTRIBUTE_REPARSE_POINT))continue;
   if(f.nFileSizeHigh||f.nFileSizeLow>4194304)continue;
   swprintf(src,32768,L"%ls\\%ls",dir,f.cFileName);
   swprintf(dst,32768,L"%ls\\state\\%ls",root,f.cFileName);
   if(GetFileAttributesW(dst)!=INVALID_FILE_ATTRIBUTES)continue;
   swprintf(tmp,32768,L"%ls.import",dst);
   if(CopyFileW(src,tmp,FALSE)&&!MoveFileExW(tmp,dst,MOVEFILE_WRITE_THROUGH))DeleteFileW(tmp);
  }while(FindNextFileW(h,&f));
  FindClose(h);
 }
 return 0;
}
static int transfer(const wchar_t *file){
 wchar_t dest[32768],tmp[32768];
 HANDLE h=CreateFileW(file,GENERIC_READ,FILE_SHARE_READ,0,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
 if(h==INVALID_HANDLE_VALUE)return 0;
 LARGE_INTEGER size;int ok=GetFileSizeEx(h,&size)&&size.QuadPart>0&&size.QuadPart<=65536;CloseHandle(h);
 if(!ok){MessageBoxW(dropWindow,L"Choose one Beyond Tuning JSON preset under 64 KB.",L"Preset not imported",MB_OK|MB_ICONINFORMATION);return 0;}
 path(dest,L"state\\import.json");path(tmp,L"state\\import.tmp");
 if(!CopyFileW(file,tmp,FALSE)||!MoveFileExW(tmp,dest,MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH))return 0;
 return 1;
}
static int browse(HWND owner){
 wchar_t file[32768]=L"";OPENFILENAMEW of={sizeof(of)};of.hwndOwner=owner;of.lpstrFile=file;of.nMaxFile=32768;
 of.lpstrFilter=L"Beyond Tuning preset (*.json)\0*.json\0All files\0*.*\0";of.lpstrTitle=L"Import Beyond Tuning preset";
 of.Flags=OFN_FILEMUSTEXIST|OFN_PATHMUSTEXIST|OFN_NOCHANGEDIR;
 return GetOpenFileNameW(&of)&&transfer(file);
}
static LRESULT CALLBACK proc(HWND w,UINT m,WPARAM a,LPARAM b){
 if(m==WM_CREATE){
  CreateWindowW(L"STATIC",L"Drop your preset JSON here",WS_CHILD|WS_VISIBLE|SS_CENTER,20,32,460,32,w,0,module,0);
  CreateWindowW(L"STATIC",L"It loads as a draft. Return to Car Tuning and press Apply.",WS_CHILD|WS_VISIBLE|SS_CENTER,20,80,460,40,w,0,module,0);
  CreateWindowW(L"BUTTON",L"Browse for preset...",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,160,142,180,34,w,(HMENU)1,module,0);
  DragAcceptFiles(w,TRUE);return 0;
 }
 if(m==WM_DROPFILES){wchar_t file[32768];HDROP d=(HDROP)a;UINT count=DragQueryFileW(d,0xFFFFFFFF,0,0);DragQueryFileW(d,0,file,32768);DragFinish(d);if(count==1&&transfer(file))DestroyWindow(w);return 0;}
 if(m==WM_COMMAND&&LOWORD(a)==1){if(browse(w))DestroyWindow(w);return 0;}
 if(m==WM_DESTROY){dropWindow=0;PostQuitMessage(0);return 0;}
 return DefWindowProcW(w,m,a,b);
}
static DWORD WINAPI import_thread(void *unused){
 WNDCLASSW wc={0};wc.lpfnWndProc=proc;wc.hInstance=module;wc.hCursor=LoadCursor(0,IDC_ARROW);wc.hbrBackground=(HBRUSH)(COLOR_WINDOW+1);wc.lpszClassName=L"BeyondTuningPresetDrop";RegisterClassW(&wc);
 dropWindow=CreateWindowExW(WS_EX_TOPMOST,wc.lpszClassName,L"Beyond Tuning - Import preset",WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_VISIBLE,CW_USEDEFAULT,CW_USEDEFAULT,516,240,0,0,module,0);
 if(dropWindow){SetForegroundWindow(dropWindow);MSG msg;while(GetMessageW(&msg,0,0,0)>0){TranslateMessage(&msg);DispatchMessageW(&msg);}}
 InterlockedExchange(&busy,0);return 0;
}
static DWORD WINAPI export_thread(void *unused){
 wchar_t file[32768]=L"My Beyond Tuning preset.json",src[32768];OPENFILENAMEW of={sizeof(of)};
 of.lpstrFile=file;of.nMaxFile=32768;of.lpstrFilter=L"Beyond Tuning preset (*.json)\0*.json\0";of.lpstrDefExt=L"json";of.lpstrTitle=L"Export Beyond Tuning preset";of.Flags=OFN_OVERWRITEPROMPT|OFN_NOCHANGEDIR|OFN_PATHMUSTEXIST;
 if(GetSaveFileNameW(&of)){path(src,L"state\\export.json");if(!CopyFileW(src,file,FALSE))MessageBoxW(0,L"The preset could not be saved at that location.",L"Beyond Tuning",MB_OK|MB_ICONERROR);}
 InterlockedExchange(&busy,0);return 0;
}
__declspec(dllexport) int bt_init(void *state){init();return 0;}
__declspec(dllexport) int bt_import(void *state){init();if(InterlockedCompareExchange(&busy,1,0)==0){HANDLE t=CreateThread(0,0,import_thread,0,0,0);if(t)CloseHandle(t);else InterlockedExchange(&busy,0);}else if(dropWindow)SetForegroundWindow(dropWindow);return 0;}
__declspec(dllexport) int bt_export(void *state){init();if(InterlockedCompareExchange(&busy,1,0)==0){HANDLE t=CreateThread(0,0,export_thread,0,0,0);if(t)CloseHandle(t);else InterlockedExchange(&busy,0);}return 0;}
__declspec(dllexport) int bt_folder(void *state){init();wchar_t p[32768];path(p,L"presets");ShellExecuteW(0,L"open",p,0,0,SW_SHOWNORMAL);return 0;}
__declspec(dllexport) int bt_list(void *state){
 init();wchar_t pattern[32768],dest[32768];path(pattern,L"presets\\*.json*");path(dest,L"state\\presets.txt");
 FILE *out=_wfopen(dest,L"wb");if(!out)return 0;WIN32_FIND_DATAW data;HANDLE h=FindFirstFileW(pattern,&data);
 if(h!=INVALID_HANDLE_VALUE){int count=0;do{if(!(data.dwFileAttributes&FILE_ATTRIBUTE_DIRECTORY)&&++count<=384){size_t len=wcslen(data.cFileName);if(len>9&&(!_wcsicmp(data.cFileName+len-9,L".json.bak")||!_wcsicmp(data.cFileName+len-9,L".json.tmp")))data.cFileName[len-4]=0;len=wcslen(data.cFileName);if(len<5||_wcsicmp(data.cFileName+len-5,L".json"))continue;char name[2048];int n=WideCharToMultiByte(CP_UTF8,0,data.cFileName,-1,name,sizeof(name),0,0);if(n>0)fprintf(out,"%s\n",name);}}while(FindNextFileW(h,&data));FindClose(h);}fclose(out);return 0;
}
__declspec(dllexport) int bt_hologram(void *state){
 init();wchar_t src[32768],dest[32768];path(src,L"state\\engine-normal.png");path(dest,L"state\\engine-hologram.png");DeleteFileW(dest);
 HRESULT co=CoInitializeEx(0,COINIT_MULTITHREADED);IWICImagingFactory *factory=0;IWICBitmapDecoder *decoder=0;IWICBitmapFrameDecode *frame=0;IWICFormatConverter *converter=0;IWICStream *stream=0;IWICBitmapEncoder *encoder=0;IWICBitmapFrameEncode *encoded=0;IPropertyBag2 *properties=0;BYTE *pixels=0,*out=0;UINT w=0,h=0;
 if(FAILED(CoCreateInstance(&CLSID_WICImagingFactory,0,CLSCTX_INPROC_SERVER,&IID_IWICImagingFactory,(void**)&factory)))goto done;
 if(FAILED(IWICImagingFactory_CreateDecoderFromFilename(factory,src,0,GENERIC_READ,WICDecodeMetadataCacheOnLoad,&decoder)))goto done;
 if(FAILED(IWICBitmapDecoder_GetFrame(decoder,0,&frame))||FAILED(IWICBitmapFrameDecode_GetSize(frame,&w,&h))||w<3||h<3||w>1024||h>1024)goto done;
 if(FAILED(IWICImagingFactory_CreateFormatConverter(factory,&converter)))goto done;
 if(FAILED(IWICFormatConverter_Initialize(converter,(IWICBitmapSource*)frame,&GUID_WICPixelFormat32bppRGBA,WICBitmapDitherTypeNone,0,0,WICBitmapPaletteTypeCustom)))goto done;
 pixels=(BYTE*)malloc(w*h*4);out=(BYTE*)calloc(w*h,4);if(!pixels||!out)goto done;
 if(FAILED(IWICFormatConverter_CopyPixels(converter,0,w*4,w*h*4,pixels)))goto done;
 for(UINT y=1;y<h-1;y++)for(UINT x=1;x<w-1;x++){
  UINT i=(y*w+x)*4;int edge=0;for(int c=0;c<3;c++){
   int gx=abs((int)pixels[i+4+c]-pixels[i-4+c]);int gy=abs((int)pixels[i+w*4+c]-pixels[i-w*4+c]);if(gx+gy>edge)edge=gx+gy;
  }
  int body=pixels[i]+pixels[i+1]+pixels[i+2]>20;int v=edge>12?min(255,30+edge*2):(body?(y%4==0?23:12):0);
  out[i]=out[i+1]=out[i+2]=255;out[i+3]=(BYTE)v;
 }
 if(FAILED(IWICImagingFactory_CreateStream(factory,&stream))||FAILED(IWICStream_InitializeFromFilename(stream,dest,GENERIC_WRITE)))goto done;
 if(FAILED(IWICImagingFactory_CreateEncoder(factory,&GUID_ContainerFormatPng,0,&encoder))||FAILED(IWICBitmapEncoder_Initialize(encoder,(IStream*)stream,WICBitmapEncoderNoCache)))goto done;
 if(FAILED(IWICBitmapEncoder_CreateNewFrame(encoder,&encoded,&properties))||FAILED(IWICBitmapFrameEncode_Initialize(encoded,properties)))goto done;
 WICPixelFormatGUID format=GUID_WICPixelFormat32bppRGBA;
 if(FAILED(IWICBitmapFrameEncode_SetSize(encoded,w,h))||FAILED(IWICBitmapFrameEncode_SetPixelFormat(encoded,&format)))goto done;
 if(FAILED(IWICBitmapFrameEncode_WritePixels(encoded,h,w*4,w*h*4,out)))goto done;
 IWICBitmapFrameEncode_Commit(encoded);IWICBitmapEncoder_Commit(encoder);
 done:free(pixels);free(out);if(properties)IPropertyBag2_Release(properties);if(encoded)IWICBitmapFrameEncode_Release(encoded);if(encoder)IWICBitmapEncoder_Release(encoder);if(stream)IWICStream_Release(stream);if(converter)IWICFormatConverter_Release(converter);if(frame)IWICBitmapFrameDecode_Release(frame);if(decoder)IWICBitmapDecoder_Release(decoder);if(factory)IWICImagingFactory_Release(factory);if(SUCCEEDED(co))CoUninitialize();return 0;
}
/* Called only while the user is dragging the model viewport. It reads pointer
 * state; it never moves the pointer, captures a screen, or sends input. */
__declspec(dllexport) int bt_pointer(void *state){init();POINT p;wchar_t file[32768];if(!GetCursorPos(&p))return 0;path(file,L"state\\pointer.txt");FILE *f=_wfopen(file,L"wb");if(f){fprintf(f,"%ld %ld %d",p.x,p.y,(GetAsyncKeyState(VK_LBUTTON)&0x8000)!=0);fclose(f);}return 0;}
BOOL WINAPI DllMain(HINSTANCE h,DWORD reason,LPVOID r){if(reason==DLL_PROCESS_ATTACH){module=h;DisableThreadLibraryCalls(h);}return TRUE;}
