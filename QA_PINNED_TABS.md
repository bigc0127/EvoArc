# Pinned Tabs QA Checklist

## Pre-Testing Setup

- [ ] **Fresh Install**: Test on clean device/simulator without existing EvoArc data
- [ ] **Migration Test**: Test on device with existing EvoArc data to verify migration
- [ ] **iCloud Account**: Ensure test devices are signed into the same iCloud account
- [ ] **Network**: Test both online and offline scenarios

## Core Functionality Tests

### Pin/Unpin Operations

- [ ] **Pin tab via toolbar button** (iOS & macOS)
  - [ ] Button shows pin icon when tab is unpinned
  - [ ] Button shows pin.slash icon when tab is pinned
  - [ ] Button correctly updates color (primary → accent)
  - [ ] Button is disabled when no URL is loaded

- [ ] **Pin tab via context menu** (iOS & macOS)
  - [ ] Context menu shows "Pin Tab" for unpinned tabs
  - [ ] Context menu shows "Unpin Tab" for pinned tabs
  - [ ] Icons display correctly in context menu

- [ ] **Unpin operations work correctly**
  - [ ] Tab moves from pinned section to regular section
  - [ ] Visual indicators update (pin icon → globe icon)
  - [ ] Core Data record is deleted

### Visual Indicators

- [ ] **Pinned tab icons**
  - [ ] iOS: Pin icon replaces globe icon in tab cards
  - [ ] macOS: Pin icon replaces globe icon in sidebar items
  - [ ] Pin icons are blue/accent colored

- [ ] **Section headers**
  - [ ] iOS: "Pinned" section appears at top of tab drawer
  - [ ] macOS: "PINNED" section appears at top of sidebar
  - [ ] Sections only show when there are pinned tabs

- [ ] **Tab positioning**
  - [ ] Pinned tabs always appear before regular tabs
  - [ ] Order is maintained when adding/removing tabs
  - [ ] New pinned tabs appear at end of pinned section

## Platform-Specific Tests

### iOS

- [ ] **Tab drawer layout**
  - [ ] Pinned section renders correctly above regular tabs
  - [ ] Grid layout works for both sections
  - [ ] Swipe gestures still work on pinned tabs

- [ ] **Bottom toolbar**
  - [ ] Pin button appears and functions correctly
  - [ ] Pin button doesn't interfere with other toolbar items
  - [ ] Button states update when switching between tabs

### macOS

- [ ] **Sidebar layout**
  - [ ] Pinned section renders correctly above regular tabs
  - [ ] List layout works for both sections
  - [ ] Hover effects work on pinned tabs

- [ ] **Bottom toolbar**
  - [ ] Pin button appears and functions correctly
  - [ ] Pin button positioning is appropriate

## Persistence & Sync Tests

### Core Data Persistence

- [ ] **App restart**
  - [ ] Kill app completely and relaunch
  - [ ] Verify pinned tabs restore correctly
  - [ ] Verify pinned tabs appear in correct order
  - [ ] Verify tab content loads correctly

- [ ] **Background/foreground**
  - [ ] Send app to background and return
  - [ ] Verify pinned state is maintained
  - [ ] Verify no duplicate tabs are created

### CloudKit Sync

- [ ] **Cross-device sync** (requires 2+ devices)
  - [ ] Pin tab on Device A
  - [ ] Wait 2-5 minutes for sync
  - [ ] Open app on Device B
  - [ ] Verify pinned tab appears on Device B
  - [ ] Verify tab loads correctly on Device B

- [ ] **Bidirectional sync**
  - [ ] Pin different tabs on both devices
  - [ ] Wait for sync on both devices
  - [ ] Verify both pinned tabs appear on both devices

- [ ] **Unpin sync**
  - [ ] Unpin tab on Device A
  - [ ] Verify tab is unpinned on Device B after sync

## Edge Cases

### URL Handling

- [ ] **Invalid URLs**
  - [ ] Tab with no URL cannot be pinned (button disabled)
  - [ ] Tab with invalid URL handles gracefully

- [ ] **URL changes**
  - [ ] Navigate pinned tab to different URL
  - [ ] Verify pin state is maintained
  - [ ] Verify persistent storage updates with new URL

- [ ] **Duplicate URLs**
  - [ ] Try to pin same URL twice
  - [ ] Verify second pin attempt is ignored
  - [ ] Verify only one pinned tab exists

### Tab Management

- [ ] **Closing pinned tabs**
  - [ ] Close pinned tab normally
  - [ ] Verify pinned state is removed from persistence
  - [ ] Verify tab is properly removed from UI

- [ ] **Many pinned tabs**
  - [ ] Pin 10+ tabs
  - [ ] Verify performance remains good
  - [ ] Verify UI scrolling works properly
  - [ ] Verify sync works with many tabs

### Memory & Performance

- [ ] **Memory usage**
  - [ ] Pin and unpin tabs repeatedly
  - [ ] Check for memory leaks in Instruments
  - [ ] Verify Core Data contexts are properly managed

- [ ] **UI responsiveness**
  - [ ] Pin/unpin operations complete quickly (<1s)
  - [ ] UI updates happen immediately
  - [ ] No blocking of main thread during operations

## Error Handling

### Network Issues

- [ ] **Offline pinning**
  - [ ] Turn off internet
  - [ ] Pin/unpin tabs
  - [ ] Verify local persistence works
  - [ ] Turn on internet and verify sync catches up

- [ ] **CloudKit errors**
  - [ ] Sign out of iCloud
  - [ ] Verify pinning still works locally
  - [ ] Sign back in and verify sync resumes

### Data Corruption

- [ ] **Core Data issues**
  - [ ] Manually corrupt Core Data store (if possible)
  - [ ] Verify app doesn't crash
  - [ ] Verify graceful degradation

## Accessibility

- [ ] **VoiceOver support** (iOS)
  - [ ] Pin buttons are accessible
  - [ ] Pin status is announced
  - [ ] Tab sections are properly labeled

- [ ] **Voice Control** (macOS)
  - [ ] Pin buttons can be activated by voice
  - [ ] Context menus work with voice control

## Integration Tests

### Browser Engine Switching

- [ ] **Engine + Pin combination**
  - [ ] Pin tab with WebKit engine
  - [ ] Switch to Chromium engine
  - [ ] Verify pin state is maintained
  - [ ] Switch back and verify again

### Settings Integration

- [ ] **Tab drawer positioning** (macOS)
  - [ ] Change tab drawer from left to right
  - [ ] Verify pinned sections appear correctly in both positions

- [ ] **Auto-hide URL bar**
  - [ ] Enable auto-hide URL bar
  - [ ] Verify pin button still accessible
  - [ ] Pin tab and verify URL bar behavior

## Performance Benchmarks

- [ ] **App launch time**
  - [ ] Measure launch time with 0 pinned tabs: _____ ms
  - [ ] Measure launch time with 5 pinned tabs: _____ ms
  - [ ] Measure launch time with 20 pinned tabs: _____ ms
  - [ ] Verify performance degradation is acceptable

- [ ] **Pin/unpin operations**
  - [ ] Measure time to pin tab: _____ ms
  - [ ] Measure time to unpin tab: _____ ms
  - [ ] Measure time to restore pinned tabs on launch: _____ ms

## Sign-off Criteria

All items above must be completed and passing before feature can be considered ready for release.

**Platform Testing:**
- [ ] iOS (iPhone) ✅
- [ ] iOS (iPad) ✅
- [ ] macOS ✅

**Environment Testing:**
- [ ] Fresh install ✅
- [ ] Migration from previous version ✅
- [ ] CrossCloud device sync ✅

**Performance:**
- [ ] No memory leaks detected ✅
- [ ] Launch time impact < 10% ✅
- [ ] Operations complete in < 1 second ✅

**Final QA Sign-off:**
- [ ] Lead QA: _________________ Date: _______
- [ ] iOS Dev: _________________ Date: _______  
- [ ] macOS Dev: _______________ Date: _______
- [ ] Product: _________________ Date: _______

## Known Issues

Document any issues found during testing that are accepted for release:

1. _None at this time_

## Post-Release Monitoring

Items to monitor after release:
- [ ] CloudKit sync error rates
- [ ] Core Data migration success rates  
- [ ] User adoption of pinning feature
- [ ] Performance metrics in production
