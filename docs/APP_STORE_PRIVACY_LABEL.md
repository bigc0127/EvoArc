# App Store Connect — App Privacy Answers

Use this when filling in **App Store Connect → App Privacy → Get Started**. Answers reflect the current build (no telemetry, no analytics, CloudKit-only optional sync to user's own iCloud account).

## Q1: Does this app collect data from this app?

**Answer: No, we do not collect data from this app**

Reasoning:
- All browsing state (history, bookmarks, pinned tabs, settings, downloads) lives on the user's device.
- iCloud sync uses Apple's CloudKit private database. Per Apple's definition, data stored only in the user's own iCloud account is **not** considered "collected by the developer" — Apple does not require disclosure for private CloudKit sync.
- No analytics SDKs, no crash reporters with PII, no ad networks, no third-party servers.
- The Perplexity feature opens user-initiated queries against `perplexity.ai` in a WKWebView. Anything the user sends there is governed by Perplexity's privacy policy, not ours, and we do not log or relay it.
- AdBlock list downloads (EasyList, AdAway, etc.) are anonymous HTTPS GETs to public URLs from the device — no user identifier attached.

If App Review asks follow-ups, reply with: "EvoArc is a local-first WebKit browser. The only network traffic the app itself initiates is (1) user-typed URLs/searches, and (2) anonymous downloads of public ad-block list files. CloudKit sync, when enabled, writes to the user's private container only."

## Q2: Tracking

**Answer: This app does not track users.**

No `App Tracking Transparency` (ATT) prompt is required because:
- No `AppTrackingTransparency` framework in code
- No `NSUserTrackingUsageDescription` in Info-iOS.plist (correctly absent)
- No advertising/analytics SDKs linked
- No data shared with third parties for cross-app tracking

## Q3: Data Types — leave all toggles OFF

You'll see a long checklist (Contact Info, Health, Financial, Location, etc.). **Do not check any of them.** Reason: nothing is *collected by the developer*.

The only quasi-grey-area items are:

| Data Type | Why it's still "Not Collected" |
|-----------|--------------------------------|
| Browsing History | Stored locally / in user's private iCloud — not transmitted to developer |
| Search History | Same — local only |
| Identifiers (Device ID) | Not used. We don't read IDFV/IDFA |
| Crash Data | No third-party crash reporter; Apple-collected diagnostics opt-in is Apple's, not ours |
| Performance Data | Same — Apple Metrics is Apple's, opt-in by user, not collected by us |

## Privacy Policy URL

App Store Connect requires a publicly hosted URL. Options:

1. GitHub Pages: enable Pages on `bigc0127/EvoArc` → publish `PRIVACY.md`. URL would be roughly `https://bigc0127.github.io/EvoArc/PRIVACY` (verify after enabling Pages).
2. Any other domain you control. Plain HTML file is fine.

The URL is mandatory; submission is blocked without it.

## App Review Notes (paste in Notes field at submission)

```
EvoArc is a privacy-focused WebKit-based web browser for iPhone and iPad.

Testing instructions:
1. Launch the app — first-run setup will appear. Pick any options.
2. Type a URL or search term in the URL bar to browse.
3. Long-press the URL bar to access tab management, history, settings.

The app is fully functional offline-first. No login required.

Network behavior:
- User-initiated URL loads (browsing)
- Anonymous downloads of public FOSS ad-block lists (EasyList, AdAway, etc.)
- Optional CloudKit sync to user's private iCloud container (only if signed into iCloud and enabled in Settings → Pinned Tabs)

The app uses iOS standard frameworks: WKWebView, WKContentRuleList for ad blocking, NSPersistentCloudKitContainer for optional sync, UIDocumentPickerViewController for download-folder selection. No custom URL schemes other than `evoarc://` (used by the Share Extension).

Permission prompts (camera/microphone/location) only appear when a website explicitly requests those APIs. Granting or denying does not affect core browsing.

Default browser entitlement is intentionally not requested in this build.

Source: https://github.com/bigc0127/EvoArc
```

## Encryption Export Compliance

Already handled in `Info-iOS.plist`:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

This claims exempt status. The browser uses only iOS-provided HTTPS / CloudKit encryption (exempt under U.S. EAR §740.17(b)(1)). No further documentation required.

## Content Rights

App Store Connect will ask: "Does this app contain, show, or access third-party content?"

**Answer: Yes** — it's a web browser. You'll be asked to confirm you have all required rights. The standard browser answer is yes; you have the right to display web content fetched per HTTP/HTTPS, same as Safari/Chrome.

## Age Rating

Web browsers must be rated **17+** by Apple's policy because users can navigate to any website. The questionnaire will guide you to this answer automatically when you select "Unrestricted Web Access".

## Submission checklist (paste-ready)

- [ ] Privacy policy URL hosted and reachable
- [ ] Build 1.0 (2) uploaded via Xcode → Archive → Distribute
- [ ] Screenshots: 6.9" iPhone, 6.5" iPhone, 13" iPad (3 per device size)
- [ ] App Privacy questionnaire answered "No data collected"
- [ ] Tracking question answered "No"
- [ ] Encryption: ITSAppUsesNonExemptEncryption = false (already in plist)
- [ ] Age rating 17+ confirmed via questionnaire
- [ ] App Review notes pasted (see above)
- [ ] Default browser entitlement: not requested in this build
- [ ] Sign in / demo account: N/A
