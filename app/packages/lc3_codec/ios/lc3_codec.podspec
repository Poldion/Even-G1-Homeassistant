#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint lc3_codec.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'lc3_codec'
  s.version          = '0.0.1'
  s.summary          = 'LC3 decoder (liblc3) for the Even G1 microphone stream.'
  s.description      = <<-DESC
LC3 decoder (google/liblc3) exposed through dart:ffi.
                       DESC
  s.homepage         = 'https://github.com/poldion/even-g1-homeassistant'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'poldion' => 'noreply@github.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../src" "${PODS_TARGET_SRCROOT}/../src/liblc3/include" "${PODS_TARGET_SRCROOT}/../src/liblc3/src"',
  }
  s.swift_version = '5.0'
end
