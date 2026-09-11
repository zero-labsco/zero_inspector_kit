#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zero_inspector_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zero_inspector_kit'
  s.version          = '1.11.1'
  s.summary          = 'An in-app developer console for Flutter: network, logs, database, memory, FPS, errors, alerts and routes.'
  s.description      = <<-DESC
An in-app developer console for Flutter that inspects HTTP/Dio traffic, WebSocket and gRPC streams, logs, databases, memory and FPS (with build/raster split), aggregates and persists errors and alerts, tracks routes, and exports a shareable session archive - all auto-disabled in release builds.
                       DESC
  s.homepage         = 'https://github.com/zero-labsco/zero_inspector_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AmisKwok' => 'amiskwok@zerolabsco.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'zero_inspector_kit_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
