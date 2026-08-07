Unicode True
Name "反戒网校项目"
OutFile "反戒网校项目.exe"


VIProductVersion "1.0.0.0"
VIAddVersionKey "ProductName" "反戒网校项目"
VIAddVersionKey "CompanyName" "反戒网校项目团队"
VIAddVersionKey "FileDescription" "浏览器自动化工具"
VIAddVersionKey "FileVersion" "1.0.0.0"
VIAddVersionKey "ProductVersion" "1.0.0.0"
VIAddVersionKey "LegalCopyright" "Copyright (C) 2026"
VIAddVersionKey "OriginalFilename" "反戒网校项目.exe"


RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\PlaywrightRPA"

Page instfiles

Section "安装"
    SetOutPath $INSTDIR
    File "setup.ps1"
    File "rpa.js"
    

    File /nonfatal "node-v20.11.1-win-x64.zip"
    File /nonfatal "playwright-1.45.0.tgz"
    File /nonfatal "chromium-win64.zip"

    
    DetailPrint "正在配置 Node.js 和 Playwright，请等待 3-5 分钟..."
    
    ExecWait '"powershell.exe" -ExecutionPolicy Bypass -NoProfile -File $\"$INSTDIR\setup.ps1$\" -ProjectDir $\"$INSTDIR$\"' $0
    
    IntCmp $0 0 setup_ok
        DetailPrint "环境配置失败！错误码: $0"
        MessageBox MB_OK "环境配置失败，错误码: $0" /SD IDOK
        Abort
    setup_ok:
    
 
    CreateShortcut "$DESKTOP\反戒网校项目.lnk" "$INSTDIR\run.bat" "" "$INSTDIR\run.bat" 0
    
    CreateDirectory "$SMPROGRAMS\反戒网校项目"
    CreateShortcut "$SMPROGRAMS\反戒网校项目\运行.lnk" "$INSTDIR\run.bat" "" "$INSTDIR\run.bat" 0
    CreateShortcut "$SMPROGRAMS\反戒网校项目\卸载.lnk" "$INSTDIR\uninst.exe" "" "$INSTDIR\uninst.exe" 0
    
    WriteUninstaller "$INSTDIR\uninst.exe"
    
    DetailPrint "安装完成！"
SectionEnd

Section "Uninstall"
    Delete "$DESKTOP\反戒网校项目.lnk"
    Delete "$SMPROGRAMS\反戒网校项目\运行.lnk"
    Delete "$SMPROGRAMS\反戒网校项目\卸载.lnk"
    RMDir "$SMPROGRAMS\反戒网校项目"
    
    MessageBox MB_YESNO "是否同时删除 Node.js 运行时？" /SD IDNO IDYES delete_nodejs IDNO skip_nodejs
    delete_nodejs:
        RMDir /r "$LOCALAPPDATA\NodeJS"
    skip_nodejs:
    
    MessageBox MB_YESNO "是否同时删除 Playwright 浏览器缓存？" /SD IDNO IDYES delete_cache IDNO skip_cache
    delete_cache:
        RMDir /r "$LOCALAPPDATA\ms-playwright"
    skip_cache:
    
    RMDir /r "$INSTDIR"
SectionEnd