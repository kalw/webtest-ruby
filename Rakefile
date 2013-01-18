APP = "webtest-ruby"
ENV['RACK_ENV'] = 'test'

  require 'rack/test'
  require 'test/unit'
  require './wptrb.rb'

desc "Tests webtest-ruby w/ web view. Test Flight only"
task :standalone => "Gemfile.lock" do
  class WptrbTest < Test::Unit::TestCase
    include Rack::Test::Methods
	  def app
      WptrbWww
	  end
	  def test_it_runs
	    get '/'
	    assert last_response.ok?
	    assert last_response.body.include?('harden')
	  end
  end
end

namespace :standalone do
  desc "Validate test w/ default opt is triggered and redir is showed"
  task :test_url => "Gemfile.lock" do
    class WptrbTest < Test::Unit::TestCase
      include Rack::Test::Methods
      def app
        WptrbWww
      end
      def testing_url_triggered
        get '/test/',:url => "www.github.com"
        assert last_response.ok?
        #puts last_response.body
        assert last_response.body.include?('window.location')
        assert last_response.body.include?('www.github.com')
      end
    end
  end
end

desc "Tests webtest w/ command line"
task :command_line_webtest_ruby => "Gemfile.lock" do

	class WptrbTest < Test::Unit::TestCase
	  include Rack::Test::Methods

	  def app
      WptrbWww
	  end

	  def test_it_runs
	    get '/'
	    assert last_response.ok?
	    assert last_response.body.include?('harden')
	  end

#	  def test_it_connects
#	    get '/test/', :url => "?url=http%3A%2F%2Fwww.github.com'"
#	    assert last_response.ok?
#	    last_response.body.include?('github')
#	  end

	end

end

# need to touch Gemfile.lock as bundle doesn't touch the file if there is no change
file "Gemfile.lock" => "Gemfile" do
  sh "bundle && touch Gemfile.lock"
end

task :default => 'standalone'
