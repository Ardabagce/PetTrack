/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = (config) => ({
  type: 'widget',
  name: 'PetTrackWidget',
  displayName: 'PetTrack',
  bundleIdentifier: '.widget',
  deploymentTarget: '17.0',
  frameworks: ['SwiftUI', 'WidgetKit'],
  colors: {
    $widgetBackground: { light: '#F4EFE7', dark: '#0E1311' },
    $accent: { light: '#CF5F3B', dark: '#EE875F' },
    ptInk: { light: '#17201C', dark: '#F1ECE3' },
    ptMuted: { light: '#5D6962', dark: '#A8B2AC' },
    ptSage: { light: '#4F7F63', dark: '#86B596' },
    ptSurface: { light: '#FFFDF9', dark: '#171E1B' },
  },
  entitlements: {
    'com.apple.security.application-groups': config.ios.entitlements['com.apple.security.application-groups'],
  },
});
