# EvoArc

**Privacy-focused, ARC-inspired Web Browser for iOS and macOS**
[![License: CC BY-NC 4.0](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)


[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-blue.svg)](https://developer.apple.com/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-green.svg)](https://developer.apple.com/swiftui/)

EvoArc is a modern, privacy-first web browser built with SwiftUI that combines the best of privacy protection with an intuitive browsing experience. Inspired by the Arc browser's innovative design principles, EvoArc prioritizes user privacy while delivering powerful browsing capabilities across iOS and macOS platforms.

## ✨ Key Features

### 🔐 Privacy & Security
- **DNS over HTTPS (DoH)** - Built-in DoH proxy server for encrypted DNS queries
- **Privacy-focused search engines** - Default to Qwant, DuckDuckGo, Startpage, and other privacy-respecting search engines
- **External search redirect protection** - Optional redirection of external searches through your preferred private search engine
- **No tracking** - Zero data collection or user tracking

### 🌐 Dual Browser Engine Support
- **Safari Mode (WebKit)** - Native WebKit integration for optimal performance and privacy
- **Chrome Mode (Blink)** - Chromium-based engine support for enhanced compatibility
- **Intelligent fallback** - Automatic engine switching based on site requirements

### 🎛️ Advanced Customization
- **Configurable homepage** - Set any URL as your default starting page
- **Custom search engines** - Add your own search engine templates with `{query}` placeholders
- **Desktop/Mobile mode toggle** - Adaptive user agent switching
- **Auto-hiding URL bar** - Distraction-free browsing experience
- **Smart device defaults** - iPad defaults to desktop mode, iPhone to mobile mode

### 📱 Cross-Platform Experience
- **Universal SwiftUI design** - Consistent experience across iOS and macOS
- **Platform-specific optimizations** - Native feel on each platform
- **macOS-specific features**:
  - Configurable tab drawer (left/right positioning)
  - Keyboard shortcuts (⌘T for new tab, ⌘⇧Y for tab drawer)
  - Native menu bar integration

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
- `BrowserEngineView.swift` - Unified interface for both WebKit and Chromium engines
- `ChromiumWebView.swift` - Chromium/Blink engine implementation
- `ScrollDetectingWebView.swift` - Enhanced WebKit view with scroll detection
- `BrowserEngineProtocol.swift` - Protocol defining browser engine interface

**Privacy & Networking**
- `DNSProxyServer.swift` - Local DNS over HTTPS proxy implementation
- `DoHProxy.swift` - DNS over HTTPS client and query handler
- `DoHSchemeHandler.swift` - Custom URL scheme handler for DoH requests
- `WebView+DoH.swift` - WebKit extensions for DNS over HTTPS integration
- `DNSProfileGenerator.swift` - DNS configuration profile generation

**Data Models**
- `BrowserSettings.swift` - Comprehensive settings management with UserDefaults persistence
- `Tab.swift` - Individual tab data model
- `TabManager.swift` - Tab lifecycle and state management

**User Interface**
- `SettingsView.swift` - Comprehensive settings interface
- `TabDrawerView.swift` - Tab management drawer
- `MacOSViews.swift` - macOS-specific UI components
- `ExternalBrowserFallback.swift` - Fallback mechanisms for unsupported content

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

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
# Build for iOS Simulator (Debug)
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -sdk iphonesimulator -configuration Debug build

# Build for macOS (Debug)
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -configuration Debug build

# Build for Release
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -configuration Release build

# Run tests
xcodebuild test -project EvoArc.xcodeproj -scheme EvoArc -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## ⚙️ Configuration

### Default Settings
- **Search Engine**: Qwant (privacy-focused)
- **Homepage**: Qwant homepage
- **Browser Engine**: WebKit (Safari Mode)
- **Desktop Mode**: Enabled on iPad and macOS, disabled on iPhone
- **Auto-hide URL Bar**: Enabled
- **Tab Drawer Position** (macOS): Left side

### Privacy Features
- DNS over HTTPS is enabled by default
- No telemetry or analytics collection
- Minimal data retention
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
- **Encrypted DNS**: DNS over HTTPS prevents ISP tracking of your browsing
- **Private Search**: Default to search engines that don't track users
- **CloudKit Integration**: Optional iCloud sync uses Apple's privacy-preserving CloudKit

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
