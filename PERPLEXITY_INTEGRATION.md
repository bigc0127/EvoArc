# Perplexity Integration for EvoArc

EvoArc now includes built-in integration with Perplexity AI to help you quickly summarize web pages and send URLs for AI-powered analysis.

## Features

- **Right-click Context Menus**: Right-click anywhere on a webpage to access Perplexity options
- **Link Context Menus**: Right-click on any link to summarize or send to Perplexity
- **Browser Menu Integration**: Access Perplexity features from the ellipsis menu in the browser toolbar
- **Modal Popup**: Perplexity opens in a convenient modal within EvoArc (no external browser required)
- **Cross-platform**: Works on both iOS and macOS

## Setup

### Method 1: OAuth Authentication (Recommended)
1. Open EvoArc Settings
2. Navigate to the "Perplexity Integration" section
3. Toggle "Enable Perplexity Features"
4. Click "Sign in with OAuth" to authenticate with your Perplexity account

### Method 2: Manual API Key Entry
1. Open EvoArc Settings
2. Navigate to the "Perplexity Integration" section
3. Toggle "Enable Perplexity Features"
4. Enter your Perplexity API key manually

**Note**: API keys are stored securely in UserDefaults on your device and are not synced across devices.

## Usage

### Right-click Context Menu (All Platforms)
- **Right-click anywhere on a webpage**: Access "Summarize Page with Perplexity" and "Send Page to Perplexity"
- **Right-click on any link**: Access "Summarize Link with Perplexity" and "Send Link to Perplexity"

### Browser Menu
- **iOS**: Tap the ellipsis (⋯) button in the bottom toolbar
- **macOS**: Click the Perplexity brain icon in the bottom toolbar or access via the settings gear menu

### Available Actions
- **Summarize with Perplexity**: Opens Perplexity with a pre-filled query to summarize the webpage or link
- **Send to Perplexity**: Opens Perplexity with the URL for general AI-powered analysis

## Privacy Notes

- **Local Storage**: API keys and authentication tokens are stored locally on your device using iOS/macOS UserDefaults
- **No Cloud Sync**: Perplexity authentication is not synced between devices for security
- **Data Transmission**: Only URLs and page titles are sent to Perplexity when using the integration
- **Session Isolation**: Perplexity sessions in EvoArc use isolated web contexts

## Troubleshooting

### Perplexity Options Not Appearing
- Ensure "Enable Perplexity Features" is toggled on in Settings
- Verify you're signed in (check for green checkmark in Settings)
- Try signing out and back in if authentication seems stale

### OAuth Issues
- Ensure you have a stable internet connection
- Clear browser cache and try OAuth flow again
- Fall back to manual API key entry if OAuth continues to fail

### Modal Not Opening
- Check that popup blockers aren't interfering (shouldn't affect in-app modals)
- Restart EvoArc if the integration becomes unresponsive

## Development Notes

The Perplexity integration is implemented using:
- `PerplexityManager`: Singleton for managing authentication and actions
- `PerplexityModalView`: Cross-platform modal presentation
- Context menu extensions in `ScrollDetectingWebView` for iOS and macOS
- Settings integration in `SettingsView`

Authentication uses `ASWebAuthenticationSession` for secure OAuth flow with fallback to manual API key entry.
