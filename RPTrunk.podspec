Pod::Spec.new do |spec|
	spec.name             = 'RPTrunk'
	spec.version          = '0.0.0'
	spec.license          = { :type => 'BSD' }
	spec.homepage         = 'https://github.com/bitwit/RPTrunk'
	spec.authors          = { 'Kyle Newsome' => 'kyle@bitwit.ca' }
	spec.summary          = 'A flexible state machine for games'
	spec.source           = { :git => 'https://github.com/bitwit/RPTrunk.git', :tag => '0.0.0' }
	spec.source_files     = 'RPG Trunk/**/**'
	spec.ios.deployment_target = "8.0"
	spec.tvos.deployment_target = "9.0"
	spec.requires_arc     = true
	spec.social_media_url = "https://twitter.com/kylnew"
end
