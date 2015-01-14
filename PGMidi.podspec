Pod::Spec.new do |s|

  s.name         = "PGMidi"
  s.version      = "0.0.5"
  s.summary      = "CoreMidi made simple on iOS."
  s.description  = <<-DESC
                   PGMidi is a simple library for access to MIDI devices presented via the CoreMidi framework on iOS. It comes with an example project to illustrate how to use the library in your own iOS application.

                   It has become the de-facto iOS API for simple MIDI access, incorporated into many of the popular MIDI applications for iOS. Thanks to everyone who has used it and provided feedback.
                   DESC

  s.homepage     = "https://github.com/petegoodliffe/PGMidi"
  s.license      = <<-LICENSE
                   Feel free to incorporate this code in your own applications.

                   I'd appreciate hearing from you if you do so. It's nice to know that I've been helpful. Attribution is welcomed, but not required.

                   Copyright (c) 2010-2015 Pete Goodliffe. All rights reserved.
                   LICENSE

  s.author       = { "Pete Goodliffe" => "pete@goodliffe.net" }
  s.platform     = :ios
  s.ios.deployment_target = '5.0'

  s.source       = { :git => "https://github.com/petegoodliffe/PGMidi.git", :commit => "9b62de60a147cd524e9faa653db3123ccc129084" }

  s.source_files  = 'Sources/PGMidi', 'Sources/PGMidi/*.{h,mm}'

  s.framework  = 'CoreMidi'
  s.libraries = 'c++'

end
