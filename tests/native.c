/* File transfer logic test. The fixture directory must already contain
 * state/, presets/ and input.json. No windows or input automation are used. */
#include "../native/preset_bridge.c"
int wmain(int argc,wchar_t **argv){
 if(argc!=2)return 2;wcsncpy(root,argv[1],32767);
 wchar_t input[32768],output[32768];path(input,L"input.json");path(output,L"state\\import.json");
 if(!transfer(input))return 3;
 FILE *a=_wfopen(input,L"rb"),*b=_wfopen(output,L"rb");if(!a||!b)return 4;
 int x,y;do{x=fgetc(a);y=fgetc(b);if(x!=y)return 5;}while(x!=EOF);fclose(a);fclose(b);
 bt_list(0);wprintf(L"PASS atomic native import copies exact preset bytes; preset listing completes\n");return 0;
}
