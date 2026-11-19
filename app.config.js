// Expo Go loads updates by SDK version; EAS (App Store / TestFlight) builds use the app version,
// so a JS update never reaches a binary with different native code.
module.exports = ({ config }) => (process.env.EAS_BUILD ? { ...config, runtimeVersion: { policy: 'appVersion' } } : config);
