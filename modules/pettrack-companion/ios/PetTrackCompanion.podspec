Pod::Spec.new do |s|
  s.name           = 'PetTrackCompanion'
  s.version        = '1.0.0'
  s.summary        = 'PetTrack widget + Apple Watch bridge'
  s.description    = 'Writes the PetTrack summary to the shared App Group, reloads widgets and syncs with the Watch app.'
  s.license        = 'UNLICENSED'
  s.author         = 'PetTrack'
  s.homepage       = 'https://pettrack.bagce.dev'
  s.platforms      = { :ios => '16.4' }
  s.source         = { git: '' }
  s.static_framework = true
  s.swift_version  = '5.9'
  s.dependency 'ExpoModulesCore'
  s.frameworks     = 'WatchConnectivity', 'WidgetKit'
  s.source_files   = '**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
