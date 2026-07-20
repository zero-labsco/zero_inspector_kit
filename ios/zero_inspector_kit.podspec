#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zero_inspector_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zero_inspector_kit'
  s.version          = '1.0.6'
  s.summary          = 'A Flutter plugin for in-app developer console.'
  s.description      = <<-DESC
A Flutter plugin for in-app developer console with network request viewing, logging, database inspection, and route tracking.
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
