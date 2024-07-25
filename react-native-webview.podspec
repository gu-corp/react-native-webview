require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = package['name']
  s.version      = package['version']
  s.summary      = package['description']
  s.license      = package['license']

  s.authors      = package['author']
  s.homepage     = package['homepage']
  s.platform     = :ios, "9.0"

  s.source       = { :git => "https://github.com/react-native-community/react-native-webview.git", :tag => "v#{s.version}" }
  s.source_files = "ios/**/*.{h,m,swift}"
  s.resource     = "ios/Settings.bundle"

  s.xcconfig = { 'SWIFT_OBJC_BRIDGING_HEADER' => '${POD_ROOT}/AdBlock/react-native-webview-Bridging-Header.h' } 

  s.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['Defines Module'] = 'Yes'
    end
  end

  s.dependency 'React'
end

