Offline POS Android App — APK-ready Project

دا project ستا د Offline POS v7.5 موبایل نسخه د Android WebView په اصلي app کې اچوي.

په app کې:
- ټول POS/Accounts features offline کار کوي.
- Login/Admin/Salesman users شته.
- Backup/CSV فایلونه د Android Downloads/OfflinePOS فولډر ته save کېږي.
- Restore د Android file picker له لارې کار کوي.
- Print د Android native print dialog کاروي.
- Data د app په WebView local storage کې ساتل کېږي.

د APK جوړولو طریقه:
1. Android Studio نصب کړه.
2. دا ټول OfflinePOS_Android_v1 فولډر Open کړه.
3. Gradle Sync ته انتظار وکړه.
4. Build > Build Bundle(s) / APK(s) > Build APK(s) وټاکه.
5. APK به عموماً app/build/outputs/apk/debug/app-debug.apk کې جوړ شي.

مهم:
- د Chrome پخوانی localStorage data په اتومات ډول Android app ته نه انتقالېږي.
- لومړی په پخواني POS کې Full Backup JSON واخله.
- Android app کې Admin جوړ کړه، بیا Backup / Restore څخه هماغه JSON restore کړه.
- د حسابونو Full Backup منظم اخله.
