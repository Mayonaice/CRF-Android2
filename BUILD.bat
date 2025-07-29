@echo off
echo ======================================
echo CRF Android Build Script
echo ======================================

echo Killing any running Gradle processes...
taskkill /F /IM java.exe /FI "WINDOWTITLE eq Gradle" 2>nul
taskkill /F /IM java.exe /FI "WINDOWTITLE eq gradle" 2>nul

echo Setting environment variables...
set JAVA_HOME=C:\Program Files\Java\jdk-17
set PATH=%JAVA_HOME%\bin;%PATH%

echo Creating optimized gradle.properties...
(
echo org.gradle.jvmargs=-Xmx4096M -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8 -XX:+UseParallelGC
echo android.useAndroidX=true
echo android.enableJetifier=true
echo android.nonTransitiveRClass=true
echo org.gradle.daemon=false
echo org.gradle.parallel=true
echo org.gradle.configureondemand=true
echo kotlin.code.style=official
echo android.defaults.buildfeatures.buildconfig=true
echo android.nonFinalResIds=false
echo flutter.minSdkVersion=21
echo flutter.targetSdkVersion=34
echo flutter.compileSdkVersion=34
) > android\gradle.properties

echo Cleaning project...
flutter clean
cd android
call gradlew clean
cd ..

echo Getting dependencies...
flutter pub get

echo Building APK with optimized settings...
flutter build apk --debug --android-skip-build-dependency-validation

if %ERRORLEVEL% NEQ 0 (
  echo Primary build method failed, trying alternative approach...
  
  echo Cleaning Gradle cache...
  rmdir /S /Q %USERPROFILE%\.gradle\caches 2>nul
  
  echo Trying alternative build with minimal validation...
  flutter build apk --debug --no-tree-shake-icons --no-pub --android-skip-build-dependency-validation
  
  if %ERRORLEVEL% NEQ 0 (
    echo Alternative build failed, trying direct Gradle build...
    cd android
    call gradlew assembleDebug --stacktrace --info
    cd ..
  )
)

echo Checking for APK...
if exist build\app\outputs\flutter-apk\app-debug.apk (
  echo Build successful! APK is at build\app\outputs\flutter-apk\app-debug.apk
  start explorer.exe build\app\outputs\flutter-apk\
) else if exist build\app\outputs\apk\debug\app-debug.apk (
  echo Build successful! APK is at build\app\outputs\apk\debug\app-debug.apk
  start explorer.exe build\app\outputs\apk\debug\
) else (
  echo APK not found. Please check the build logs for errors.
)

echo Build process completed.
pause 