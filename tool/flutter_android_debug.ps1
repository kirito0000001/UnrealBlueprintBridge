$ErrorActionPreference = 'Stop'

$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:GRADLE_USER_HOME = 'C:\Users\liuyu\.gradle_flutter'
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' build apk --debug
