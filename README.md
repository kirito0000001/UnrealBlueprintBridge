# 虚幻：蓝图连结

`unreal_blueprint_bridge` 是一个基于 Flutter 的通用节点图 / 蓝图草稿编辑器，目标平台先支持 Windows 和 Android。

应用显示名称：`虚幻：蓝图连结`

Android 包名：`com.TFAC.unreal_blueprint_bridge`

第一版先专注于绘制蓝图风格的节点草稿、连接引脚、编辑节点说明，并保存 / 加载结构化 JSON 数据。它不会执行图逻辑，不会生成 Unreal 资产，也不会直接修改 `.uasset` 文件。

## 当前范围

- Windows 和 Android Flutter 应用。
- 共享的 Dart 节点图数据模型。
- JSON 编码 / 解码基础服务。
- 桌面端和移动端共用的编辑器外壳。
- 为节点画布、引脚、连线、图文件保存加载流程打基础。

## 开发环境

Flutter SDK:

```text
C:\Users\liuyu\develop\flutter
```

如果当前终端还没有刷新 `PATH`，可以直接使用 Flutter 的完整路径：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' --version
```

Android 构建建议使用单独的 Gradle 缓存目录，避免和 Unreal 相关的全局 Gradle 配置冲突：

```powershell
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:GRADLE_USER_HOME='C:\Users\liuyu\.gradle_flutter'
```

## 常用命令

安装依赖：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' pub get
```

格式化：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\dart.bat' format .
```

静态分析：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' analyze
```

运行测试：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' test
```

构建 Windows 版本：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' build windows
```

构建 Android 调试 APK：

```powershell
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:GRADLE_USER_HOME='C:\Users\liuyu\.gradle_flutter'
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' build apk --debug
```

## 节点图 JSON 结构

第一版计划使用 `.ubbridge.json` 文档，顶层结构类似下面这样：

```json
{
  "schemaVersion": 1,
  "graph": {
    "id": "graph_001",
    "title": "Login Flow",
    "description": "登录流程草稿",
    "createdAt": "2026-07-07T12:00:00+08:00",
    "updatedAt": "2026-07-07T12:20:00+08:00",
    "viewport": {
      "offsetX": 0,
      "offsetY": 0,
      "zoom": 1.0
    }
  },
  "nodes": [],
  "links": []
}
```

其中：

- `graph` 保存图本身的标题、说明、创建时间、更新时间和视口信息。
- `nodes` 保存节点列表，包括节点位置、标题、说明、类型和引脚。
- `links` 保存连线列表，用于记录输出引脚到输入引脚之间的连接关系。

后续 Unreal 插件或其他工具可以读取这些 JSON，把它们作为蓝图设计草稿、逻辑说明文档或 AI 可读的节点参考数据。
