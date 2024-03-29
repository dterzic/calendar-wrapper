#
# Be sure to run `pod lib lint CalendarWrapper.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CalendarWrapper'
  s.version          = '0.5.43'
  s.summary          = 'Simple wrapper around the Google AppAuth and calendar API.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = "Simplifying the Google AppAuth process and calendar api implementation. Please check the example app for more details."

  s.homepage         = 'https://github.com/dterzic/calendar-wrapper'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Dusan Terzic' => 'dterzic@gmail.com' }
  s.source           = { :git => 'https://github.com/dterzic/calendar-wrapper.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '13.0'

  s.source_files = 'CalendarWrapper/Classes/**/*'

  # s.resource_bundles = {
  #   'CalendarWrapper' => ['CalendarWrapper/Assets/*.png']
  # }

  s.public_header_files = 'CalendarWrapper/**/*.h'
  s.frameworks = 'UIKit', 'Foundation', 'CoreGraphics'
  s.static_framework = true

  s.dependency 'AppAuth'
  s.dependency 'GTMAppAuth'
  s.dependency 'GTMSessionFetcher'
  s.dependency 'GoogleAPIClientForREST/Calendar'
  s.dependency 'GoogleAPIClientForREST/PeopleService'
  s.dependency 'GoogleAPIClientForREST/Tasks'
end
