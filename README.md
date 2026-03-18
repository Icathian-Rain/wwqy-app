# 游戏点位助手

一个基于 Flutter 开发的本地点位记录应用，当前内置《无畏契约》预设数据，支持按**游戏 → 地图 → 点位**逐级浏览，并可记录特工、攻防、包点、说明和多张示意图。

## 功能特性

- 内置《无畏契约》游戏、地图、特工预设数据
- 按地图查看点位列表
- 支持按**特工 / 攻防 / 包点**筛选点位
- 支持新增点位记录
- 支持为点位添加多张图片
- 支持点位详情查看、图片轮播、全屏查看
- 支持删除点位及关联图片
- 使用 SQLite 本地存储，离线可用
- 适配 Windows 桌面端，兼容中文字体显示

## 技术栈

- Flutter
- Provider
- SQLite (`sqflite`)
- 桌面端 SQLite 兼容：`sqflite_common_ffi`
- 图片选择：`image_picker`

## 项目结构

```text
lib/
├─ app.dart                    # 根应用、主题、Provider 注入
├─ main.dart                   # 应用入口，桌面端数据库初始化
├─ data/
│  ├─ database_helper.dart     # SQLite 建表与预置数据初始化
│  ├─ lineup_repository.dart   # 数据访问封装
│  └─ preset_data.dart         # 游戏 / 地图 / 特工预置数据
├─ models/                     # 数据模型
├─ providers/
│  └─ lineup_provider.dart     # UI 状态管理
├─ screens/                    # 页面
│  ├─ home_screen.dart         # 游戏列表
│  ├─ map_select_screen.dart   # 地图列表
│  ├─ lineup_list_screen.dart  # 点位列表与筛选
│  ├─ add_lineup_screen.dart   # 新增点位
│  └─ lineup_detail_screen.dart# 点位详情与图片浏览
└─ utils/
   └─ image_helper.dart        # 图片选择与复制到应用目录
```

## 数据流

本项目采用如下数据流：

```text
Screen -> LineupProvider -> LineupRepository -> DatabaseHelper(SQLite)
```

- `screens/`：页面与交互
- `providers/`：页面状态、筛选状态、异步加载
- `data/`：数据库访问与预置数据初始化
- `models/`：数据库实体映射

## 开发环境

建议使用：

- Flutter 3.x
- Dart 3.x
- Windows 11 / Android

## 安装与运行

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 启动应用

```bash
flutter run
```

### 3. 指定平台运行

```bash
flutter run -d windows
flutter run -d chrome
```

### 4. 查看可用设备

```bash
flutter devices
```

## 常用命令

### 静态检查

```bash
flutter analyze
```

### 运行测试

```bash
flutter test
```

### 运行单个测试文件

```bash
flutter test test/widget_test.dart
```

### 按名称运行单个测试

```bash
flutter test --plain-name "App should render"
```

### 构建

```bash
flutter build windows
flutter build web
flutter build apk
```

## 数据存储说明

### SQLite 数据库

应用使用本地 SQLite 数据库，数据库文件名固定为：

```text
wwqy_app.db
```

数据库路径由 `sqflite` 的 `getDatabasesPath()` 决定，不同平台实际位置可能不同。

### 图片存储

选中的图片不会直接依赖原始路径，而是复制到应用私有目录下的：

```text
lineup_images/
```

删除点位时，会同时删除数据库记录和对应图片文件。

## 如何重置预设数据

预设游戏、地图、特工数据只会在**首次建库**时写入。

如果你修改了 [lib/data/preset_data.dart](lib/data/preset_data.dart)，想让新预设重新生效，需要：

1. 关闭应用
2. 删除本机数据库文件 `wwqy_app.db`
3. 重新启动应用

重新启动后会自动重新建库，并写入最新预设数据。

## 平台说明

### Windows / Linux

桌面端在 [lib/main.dart](lib/main.dart) 中使用 `sqflite_common_ffi` 初始化数据库工厂。

### 图片拍照

由于 `image_picker` 在 Windows 桌面端不能直接使用 `ImageSource.camera`，当前项目仅在 **Android / iOS** 显示“拍照”入口；桌面端仅支持从本地选择图片。

## 当前内置内容

当前项目主要围绕《无畏契约》点位记录使用场景，内置：

- 1 款游戏：无畏契约
- 多张地图预设
- 多名特工预设

相关预置数据位于：

- [lib/data/preset_data.dart](lib/data/preset_data.dart)

## 测试现状

当前仓库包含一个基础 Widget 测试：

- [test/widget_test.dart](test/widget_test.dart)

用于验证根应用是否可以正常渲染。

## 后续可扩展方向

- 支持更多游戏
- 支持编辑点位
- 支持搜索点位
- 支持导出 / 导入点位数据
- 支持云同步
- 支持地图封面与特工头像资源

## License

当前仓库未声明开源许可证，如需开源请补充 License 文件。
