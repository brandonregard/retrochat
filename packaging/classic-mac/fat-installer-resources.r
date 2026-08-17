#ifndef CLIENT_SCRIPT_PATH
#error CLIENT_SCRIPT_PATH must name the MacRoman client script
#endif
#ifndef SERVER_SCRIPT_PATH
#error SERVER_SCRIPT_PATH must name the MacRoman server script
#endif
#ifndef README_PATH
#error README_PATH must name the MacRoman read-me file
#endif
#ifndef ICON_BITMAP_PATH
#error ICON_BITMAP_PATH must name the installer dialog bitmap
#endif
#ifndef ICON_MASK_PATH
#error ICON_MASK_PATH must name the installer dialog mask
#endif
#ifndef CLIENT_COLOR_ICON_PATH
#error CLIENT_COLOR_ICON_PATH must name the color client dialog icon
#endif
#ifndef SERVER_COLOR_ICON_PATH
#error SERVER_COLOR_ICON_PATH must name the color server dialog icon
#endif

read 'RcCl' (128, "RetroChat Client Script", purgeable) CLIENT_SCRIPT_PATH;
read 'RcSv' (128, "RetroChat Server Script", purgeable) SERVER_SCRIPT_PATH;
read 'RcRd' (128, "RetroChat Read Me", purgeable) README_PATH;
read 'RcIb' (128, "RetroChat Dialog Icon", purgeable) ICON_BITMAP_PATH;
read 'RcIm' (128, "RetroChat Dialog Icon Mask", purgeable) ICON_MASK_PATH;
read 'RcCg' (128, "RetroChat Client Color Icon", purgeable) CLIENT_COLOR_ICON_PATH;
read 'RcSg' (128, "RetroChat Server Color Icon", purgeable) SERVER_COLOR_ICON_PATH;
