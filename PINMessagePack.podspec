Pod::Spec.new do |s|
  s.name             = "PINMessagePack"
  s.version          = "1.1.0"
  s.summary          = "A fast, streaming Objective-C MessagePack decoder"
  s.homepage         = "https://github.com/Adlai-Holler/PINMessagePack"
  s.author           = { "Adlai Holler" => "adlai@pinterest.com" }
  s.license          = { :type => "Proprietary", :text => <<-LICENSE
    Under development and not licensed.
    LICENSE
  }
  s.source           = { :git => "https://github.com/Adlai-Holler/PINMessagePack.git", :tag => s.version.to_s }

  s.ios.deployment_target = "9.0"

  s.source_files =         'Source/**/*.{h,m}'
  s.public_header_files =  'Source/include/*.h'
  s.private_header_files = 'Source/cmp/*.h', 'Source/internal/*.h'
  
end
