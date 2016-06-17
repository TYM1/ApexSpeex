Pod::Spec.new do |s|
  s.name             = "ApexSpeex"
  s.version          = "1.0.0"
  s.summary          = "A short description of speex." 
  s.description      = <<-DESC
                       DESC

  s.homepage         = "https://github.com/TYM1/ApexSpeex"
  s.license          = 'MIT'
  s.author           = { "TYM" => "www.tym@hotmail.com" }
  s.source           = { :git => "https://github.com/TYM1/ApexSpeex.git", :tag => "1.0.0" }
  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'ApexSpeex' => ['Pod/Assets/*.png']
  }
  s.library = 'c++'
end
