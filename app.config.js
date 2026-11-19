// Native (EAS) builds use the app version as runtime version; Expo Go previews keep the SDK runtime.
// EAS_BUILD_PROFILE is set both by eas-cli locally and on the build server, so both sides agree.
// For an OTA update to App Store builds run: NATIVE_RUNTIME=1 eas update --channel production
const native = !!(process.env.EAS_BUILD || process.env.EAS_BUILD_PROFILE || process.env.NATIVE_RUNTIME);
module.exports = ({ config }) => (native ? { ...config, runtimeVersion: { policy: 'appVersion' } } : config);
