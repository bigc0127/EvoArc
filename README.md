# EvoArc

**Privacy-focused, ARC-inspired Web Browser for iOS and iPadOS**

[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20iPadOS-blue.svg)](https://developer.apple.com/) [![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/) [![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-green.svg)](https://developer.apple.com/swiftui/) [![License: CC BY-NC 4.0](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)

EvoArc is a modern, privacy-first web browser built with SwiftUI that combines the best of privacy protection with an intuitive browsing experience. Inspired by the Arc browser's innovative design principles, EvoArc prioritizes user privacy while delivering powerful browsing capabilities on iPhone and iPad.

## ✨ Key Features

### 🔐 Privacy & Security
- **Local-First Privacy** - All data stays on your device with optional iCloud sync
- **Privacy-focused search engines** - Default to Qwant, DuckDuckGo, Startpage, and other privacy-respecting search engines
- **Advanced Ad Blocking** - Built-in ad and tracker blocking with customizable filter lists
- **External search redirect protection** - Optional redirection of external searches through your preferred private search engine
- **No tracking** - Zero data collection or user tracking
- **iCloud Integration** - Secure sync using your personal iCloud account

### 🌐 Chrome Compatibility Mode
- **WebKit Engine** - Built on Apple's WebKit for optimal performance, privacy, and energy efficiency
- **Chrome Compatibility** - Optional mode that emulates Chrome behavior with custom user agent and Chrome API polyfills
- **Enhanced Compatibility** - Access sites that may detect or prefer Chrome-based browsers without sacrificing WebKit's native advantages

### 🎛️ Advanced Customization
- **Configurable homepage** - Set any URL as your default starting page
- **Custom search engines** - Add your own search engine templates with `{query}` placeholders
- **Desktop/Mobile mode toggle** - Adaptive user agent switching
- **Auto-hiding URL bar** - Distraction-free browsing experience
- **Smart device defaults** - iPad defaults to desktop mode, iPhone to mobile mode
- **Downloads Management** - Customizable download location and behavior
- **Dynamic Type Support** - Full accessibility support with adaptive UI scaling
- **Ad Block Customization** - Choose from multiple filter lists with auto-updates

### 📱 iOS and iPadOS Experience
- **Universal SwiftUI design** - Optimized for both iPhone and iPad
- **iPad-specific features**:
  - Desktop mode by default for full-featured web browsing
  - Configurable navigation button positions (top/bottom, left/right)
  - Split-screen and multitasking support
  - Optimized Arc-like sidebar for larger displays
- **iPhone optimizations**:
  - Mobile mode by default with adaptive layouts
  - Auto-hiding URL bar for immersive browsing
  - Gesture-based navigation

### 🗂️ Tab Management
- **Efficient tab handling** - Advanced tab management system
- **Tab drawer interface** - Clean, organized tab overview
- **Memory optimization** - Intelligent resource management

## 🏗️ Architecture

### Core Components

**App Structure**
- `EvoArcApp.swift` - Main application entry point with platform-specific configurations
- `ContentView.swift` - Primary user interface coordinating all browser components
- `Persistence.swift` - Core Data stack with CloudKit integration for cross-device sync

**Browser Engine**
- `BrowserEngineView.swift` - Manages engine mode selection (WebKit/Chrome Compatibility)
- `ChromiumWebView.swift` - WebKit with Chrome user agent and API emulation
- `ScrollDetectingWebView.swift` - Enhanced WebKit view with scroll detection
- `BrowserEngineProtocol.swift` - Protocol defining browser engine interface

**Privacy & Networking**
- `CloudKitPinnedTabManager.swift` - Secure tab syncing via CloudKit
- `DoHSettingsManager.swift` - DNS settings management
- `AdBlockManager.swift` - Content blocking functionality
- `SearchPreloadManager.swift` - Privacy-focused search preloading
- `SafePinnedTabManager.swift` - Secure tab state management

**Data Models**
- `BrowserSettings.swift` - Comprehensive settings management with UserDefaults persistence
- `Tab.swift` - Individual tab data model
- `TabManager.swift` - Tab lifecycle and state management

**User Interface**
- `SettingsView.swift` - Comprehensive settings interface
- `TabDrawerView.swift` - Tab management drawer
- `BottomBarView.swift` - Navigation controls and action buttons
- `ExternalBrowserFallback.swift` - Fallback mechanisms for unsupported content

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 18.0+ / iPadOS 18.0+
- Swift 5.9+
- iPhone or iPad device/simulator

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/bigc0127/EvoArc.git
   cd EvoArc
   ```

2. **Open in Xcode**
   ```bash
   open EvoArc.xcodeproj
   ```

3. **Build and run**
   - Select your target device/simulator
   - Press ⌘R or click the Run button

### Build Commands

```bash
# Build for iPhone Simulator (Debug)
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -destination "platform=iOS Simulator,OS=18.0,name=iPhone 16" -configuration Debug clean build | xcpretty

# Build for iPad Simulator (Debug)
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -destination "platform=iOS Simulator,OS=18.0,name=iPad Mini (A17 Pro)" -configuration Debug clean build | xcpretty

# Build for Release
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -configuration Release build

# Run tests
xcodebuild test -project EvoArc.xcodeproj -scheme EvoArc -destination 'platform=iOS Simulator,name=iPhone 16'
```

## ⚙️ Configuration

### Default Settings
- **Search Engine**: Qwant (privacy-focused)
- **Homepage**: Qwant (www.qwant.com)
- **Browser Engine**: WebKit (Safari Mode)
- **Desktop Mode**: Enabled on iPad, disabled on iPhone
- **Auto-hide URL Bar**: Enabled
- **Navigation Button Position** (iPad): Top Right

### Privacy Features
- Local-first data storage
- Optional iCloud sync via CloudKit
- No telemetry or analytics collection
- Zero data retention outside your device
- Optional external search redirection

### Supported Search Engines

**Privacy-Focused (Recommended)**
- Qwant - European search engine with strong privacy protection
- DuckDuckGo - No tracking, no search history storage
- Startpage - Google results without tracking
- Presearch - Decentralized search engine
- Ecosia - Plant trees with your searches

**Traditional Engines**
- Google, Bing, Yahoo, Perplexity

**Custom Engines**
- Add any search engine with custom URL templates

## 🛡️ Privacy Philosophy

EvoArc is built with privacy-by-design principles:

- **No Data Collection**: We don't collect, store, or transmit your personal data
- **Local Processing**: All settings and data remain on your device
- **iCloud Integration**: Secure sync using your personal iCloud account
- **Private Search**: Default to search engines that don't track users

## 🤝 Contributing

We welcome contributions to EvoArc! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:

- Code of Conduct
- Development workflow
- Pull request process
- Issue reporting

## 📄 License

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0)**.

**What this means:**
- ✅ **You CAN**: Use, modify, distribute, and build upon this code
- ✅ **You CAN**: Use it for personal, educational, or research purposes
- ✅ **You CAN**: Create derivative works and share them
- ❌ **You CANNOT**: Use this code for commercial purposes or make money from it

**Attribution Required**: You must give appropriate credit and indicate if changes were made.

For commercial licensing inquiries, please contact the project maintainer.

See the [LICENSE](LICENSE) file for full details.

## 🙏 Acknowledgments

- Inspired by the Arc browser's innovative design philosophy
- Built with Apple's SwiftUI and WebKit frameworks
- Privacy-focused search engines for their commitment to user privacy
- The open-source community for tools and inspiration

## 📞 Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/bigc0127/EvoArc/issues) page
2. Create a new issue with detailed information
3. Provide device/OS information and steps to reproduce

---

**EvoArc** - Evolution in privacy-focused browsing 🌐🔒
