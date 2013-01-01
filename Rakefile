  require 'rack/test'
  require 'test/unit'
  require './wptrb.rb'

desc "Local: Tests sinatra"
task :local_sinatra => "Gemfile.lock" do

	class CheckSinatraWptrb < Test::Unit::TestCase
	  include Rack::Test::Methods

	  def app
	    Sinatra::Application
	  end

	  def test_it_runs
	    get '/'
#	    assert last_response.ok?
	    last_response.body.include?('harden')
	  end

	  def test_it_connects
	    get '/test/', :url => "?url=http%3A%2F%2Fwww.github.com'"
	    assert last_response.ok?
	    last_response.body.include?('HOME')
	  end

	end

end

# need to touch Gemfile.lock as bundle doesn't touch the file if there is no change
file "Gemfile.lock" => "Gemfile" do
  sh "bundle && touch Gemfile.lock"
end

task :default => 'local_sinatra'