# 游戏点位助手

一个基于 Flutter 开发的本地点位记录应用，当前内置《无畏契约》预设数据，支持按 **游戏 → 地图 → 点位** 逐级浏览，并可记录特工、攻防、包点、说明和多张示意图。

## 功能特性

- 内置《无畏契约》游戏、地图、特工预设数据
- 按地图查看点位列表
- 支持按 **特工 / 攻防 / 包点** 筛选点位
- 支持按 **标题 / 说明 / 特工 / 攻防 / 包点** 搜索点位
- 支持新增、编辑、删除点位记录
- 支持为点位添加多张图片
- 支持图片封面与顺序调整
- 支持点位详情查看、图片轮播、全屏查看
- 支持批量导入 / 导出点位数据（ZIP）
- 导入前支持预检，识别重复点位与阻塞问题
- 使用 SQLite 本地存储，离线可用
- 适配 Windows 桌面端，兼容中文字体显示

## 技术栈

- Flutter
- Provider
- SQLite (`sqflite`)
- 桌面端 SQLite 兼容：`sqflite_common_ffi`
- 图片选择：`image_picker`
- 压缩打包：`archive`
- 文件选择：`file_picker`
- 文件分享：`share_plus`

## 项目结构

```text
lib/
├─ app.dart                         # 根应用、主题、Provider 注入
├─ main.dart                        # 应用入口，桌面端数据库初始化
├─ data/
│  ├─ database_helper.dart          # SQLite 建表与预置数据初始化
│  ├─ lineup_repository.dart        # 数据访问封装
│  └─ preset_data.dart              # 游戏 / 地图 / 特工预置数据
├─ models/                          # 数据模型
├─ providers/
│  └─ lineup_provider.dart          # UI 状态管理与业务编排
├─ screens/
│  ├─ home_screen.dart              # 游戏列表
│  ├─ map_select_screen.dart        # 地图列表、导入导出入口
│  ├─ lineup_list_screen.dart       # 点位列表、搜索与筛选
│  ├─ add_lineup_screen.dart        # 新增 / 编辑点位
│  └─ lineup_detail_screen.dart     # 点位详情与图片浏览
├─ services/
│  └─ lineup_transfer_service.dart  # ZIP 导入导出、预检、冲突处理
└─ utils/
   └─ image_helper.dart             # 图片选择与复制到应用目录
```

## 数据流

本项目采用如下数据流：

```text
Screen -> LineupProvider -> LineupRepository -> DatabaseHelper(SQLite)
```

- `screens/`：页面与交互
- `providers/`：页面状态、筛选状态、异步加载、导入导出编排
- `data/`：数据库访问与预置数据初始化
- `services/`：导入导出等独立业务流程
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
flutter test test/lineup_repository_test.dart
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

## 批量导入 / 导出说明

当前项目支持按 **游戏维度** 导出点位 ZIP，也支持从 ZIP 批量导入。

### 入口位置

在地图页右上角菜单中可看到：

- `导入 ZIP`
- `导出当前游戏`

### 导出规则

- 只导出业务数据和图片资源
- 不导出 SQLite 数据库文件
- 不导出本机绝对路径
- 图片路径只会写成 ZIP 包内相对路径

### 导入规则

- 导入时只认业务 ID：`gameId / mapId / agentId`
- 不信任旧的本地图片路径
- 图片会重新复制到当前设备的私有目录 `lineup_images/`
- 支持导入前预检
- 对重复点位支持：
  - 继续追加导入
  - 跳过重复后导入

### ZIP 包结构模板

导出包固定为如下结构：

```text
wwqy-lineups-无畏契约-20260321-153000.zip
├─ manifest.json
└─ images/
   ├─ 4f8f8a2a-1.jpg
   ├─ 3a9f2d77-2.png
   └─ ...
```

要求：

- `manifest.json` 必须位于 ZIP 根目录
- 所有图片必须位于 `images/` 子目录
- `manifest.json` 中的图片路径必须是相对路径，例如 `images/4f8f8a2a-1.jpg`
- 不允许出现本机绝对路径，如 `C:\...` 或 `/Users/...`

## manifest.json 模板

当前导入导出格式版本：

- `format`: `wwqy.lineup-bundle`
- `version`: `1`

仓库中也提供了一个可直接参考的完整示例文件：

- [examples/lineup_bundle_manifest.example.json](examples/lineup_bundle_manifest.example.json)

可参考以下模板：

```json
{
  "format": "wwqy.lineup-bundle",
  "version": 1,
  "exportedAt": "2026-03-21T10:30:00.000Z",
  "lineups": [
    {
      "id": "source-lineup-id-1",
      "gameId": "valorant",
      "mapId": "bind",
      "agentId": "brimstone",
      "side": "attack",
      "site": "A",
      "title": "A 包默认烟",
      "description": "站位贴左墙，瞄准屋檐角后投掷。",
      "createdAt": "2026-03-21T09:00:00.000Z",
      "images": [
        {
          "imageId": "bundle-image-1",
          "sortOrder": 0
        },
        {
          "imageId": "bundle-image-2",
          "sortOrder": 1
        }
      ]
    }
  ],
  "images": [
    {
      "id": "bundle-image-1",
      "path": "images/bundle-image-1.jpg",
      "fileName": "bundle-image-1.jpg",
      "sizeBytes": 123456
    },
    {
      "id": "bundle-image-2",
      "path": "images/bundle-image-2.png",
      "fileName": "bundle-image-2.png",
      "sizeBytes": 234567
    }
  ]
}
```

### 字段说明

#### 顶层字段

- `format`：固定为 `wwqy.lineup-bundle`
- `version`：当前固定为 `1`
- `exportedAt`：导出时间，UTC ISO8601 格式
- `lineups`：点位数据列表
- `images`：图片资源清单

#### lineups[]

- `id`：导出包内部引用 ID，仅用于包内标识
- `gameId`：游戏 ID，例如 `valorant`
- `mapId`：地图 ID，例如 `bind`
- `agentId`：特工 ID，例如 `brimstone`
- `side`：仅支持 `attack` / `defense`
- `site`：当前仅支持 `A` / `B` / `C`
- `title`：点位标题
- `description`：点位说明
- `createdAt`：创建时间
- `images`：当前点位引用的图片列表

#### lineups[].images[]

- `imageId`：引用 `images[].id`
- `sortOrder`：图片顺序，`0` 表示第一张图，也是封面图

#### images[]

- `id`：图片资源 ID
- `path`：ZIP 内相对路径，必须位于 `images/` 目录下
- `fileName`：文件名
- `sizeBytes`：文件大小（字节）

## 导入导出模板注意事项

为了保证能被当前版本正确识别，请遵循以下约束：

1. `gameId / mapId / agentId` 必须是当前项目已存在的业务 ID
2. `side` 只能是：
   - `attack`
   - `defense`
3. `site` 只能是：
   - `A`
   - `B`
   - `C`
4. 每条点位至少要有一张图片
5. 图片引用必须能在 `images[]` 中找到
6. `images[].path` 不能包含 `..`
7. 导入时会重新生成本地 `Lineup.id` 和 `LineupImage.id`

也就是说：

- `lineups[].id`
- `images[].id`

只作为 **导出包内部引用** 使用，不会直接复用为本地数据库主键。

## 如何手动准备导入包

如果你想手工构造一个可导入 ZIP，建议按以下步骤：

1. 新建一个临时目录
2. 在目录根部创建 `manifest.json`
3. 新建 `images/` 子目录
4. 把图片放进 `images/`
5. 保证 `manifest.json` 中引用的 `path` 与真实文件一致
6. 将整个目录压缩成 ZIP

例如：

```text
my_bundle/
├─ manifest.json
└─ images/
   ├─ bundle-image-1.jpg
   └─ bundle-image-2.png
```

再把 `my_bundle/` 压缩为 ZIP 即可。

## 如何重置预设数据

预设游戏、地图、特工数据只会在 **首次建库** 时写入。

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

当前仓库包含：

- [test/widget_test.dart](test/widget_test.dart)
- [test/lineup_repository_test.dart](test/lineup_repository_test.dart)

用于验证：

- 根应用可正常渲染
- repository 的基础增删改查、筛选、批量插入等行为

## 后续可扩展方向

- 增强列表检索能力（如更复杂的组合查询）
- 优化导入冲突策略（如更细粒度合并）
- 增加收藏 / 最近使用
- 支持更多游戏
- 支持云同步
- 支持地图封面与特工头像资源

## License

当前仓库未声明开源许可证，如需开源请补充 License 文件。
