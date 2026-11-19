/** @type {import('@bacons/apple-targets/app.plugin').Config} */
module.exports = {
  type: 'watch',
  name: 'PetTrackWatch',
  displayName: 'PetTrack',
  bundleIdentifier: '.watchkitapp',
  deploymentTarget: '10.0',
  icon: '../../assets/icon.png',
  frameworks: ['SwiftUI', 'WatchConnectivity'],
  colors: {
    $accent: '#EE875F',
    ptSage: '#86B596',
    ptCard: '#1D3529',
  },
};
