
require "sequel"
require "psych"

# not the best way to use Sequel, but it fits with the current architecture

class CalicoDB

    def initialize
	conf = Psych.load( IO.read("../config/db.yml") ) 
	@sql = Psych.load( IO.read("../config/queries.yml") ) 

	@conf = {
	    :host	=> conf["host"],
	    :database	=> conf["database"],
	    :user	=> conf["username"],
	    :password	=> conf["password"],
	}
    end

    def query (name, params = [])
	begin
	    Sequel.postgres(@conf) do |db|
		db[@sql[name], *params].all
	    end
	rescue Exception => e
	    puts e
	    nil
	end
    end

    def exec
	Sequel.postgres(@conf)
    end

end

