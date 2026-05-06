# Eunoia

Flutter 应用工程，附带与产品 UI 对齐的静态手机壳原型 HTML。

## 根目录文件与文件夹说明

| 名称 | 类型 | 功能说明 |
|------|------|----------|
| `lib/` | 目录 | Dart 源码：页面、路由、主题、服务等 Flutter 应用主体代码。 |
| `test/` | 目录 | 单元测试与 Widget 测试。 |
| `android/` | 目录 | Android 平台工程与 Gradle 配置。 |
| `ios/` | 目录 | iOS 平台工程与 Xcode 相关配置。 |
| `web/` | 目录 | Web 平台构建与入口资源。 |
| `windows/`、`linux/`、`macos/` | 目录 | 各桌面平台的 Flutter 宿主工程。 |
| `assets/` | 目录 | 图片、字体等静态资源（需在 `pubspec.yaml` 中声明）。 |
| `build/` | 目录 | 构建输出目录，由 `flutter build` 生成，一般勿手动修改。 |
| `.dart_tool/` | 目录 | Dart/Flutter 工具链缓存与生成文件。 |
| `.idea/` | 目录 | JetBrains IDE（Android Studio 等）项目配置。 |
| `index.html` | 文件 | **主 UI 原型**：手机外框内的练习 / 社区 / 商城 / 个人等 Tab；商城内可进入「全息补给舱」，含**手办池 / E宠池**、**单抽 / 十连**动效与 E 点演示逻辑。 |
| `index2.html` | 文件 | **仅作设计参考**的深度交互原型（含爬词塔、旧版补给舱等），请勿改动此文件。 |
| `pubspec.yaml` | 文件 | 项目元数据、依赖包与资源声明。 |
| `pubspec.lock` | 文件 | 锁定依赖的精确版本，保证可复现构建。 |
| `analysis_options.yaml` | 文件 | Dart 静态分析（analyzer / linter）规则配置。 |
| `.metadata` | 文件 | Flutter SDK 版本与项目通道等元信息。 |
| `.gitignore` | 文件 | Git 忽略规则（构建产物、本地配置等）。 |
| `.flutter-plugins-dependencies` | 文件 | 插件依赖关系快照，由工具自动生成。 |
| `eunoia.iml` | 文件 | IntelliJ 模块描述文件。 |
| `README.md` | 文件 | 本说明文档。 |

## 云服务器（本项目当前部署信息）

- **公网 IP**：`43.155.24.58`（腾讯云香港；若实例更换 IP 请同步修改文档与构建参数）。
- **SSH / 代码路径示例**：`/home/ubuntu/Eunoia`。
- **域名**：`www.eunoia5.top`（可与 IP 并行使用；HTTPS Web 语聊建议走同源 + Nginx，见 `server/voice-match/DEPLOY.md`）。

## 本地运行 Flutter 应用

```bash
flutter pub get
flutter run
```