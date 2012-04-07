
require "sequel"
require "psych"

# not the best way to use Sequel, but it fits with the current architecture

class CalicoDB
    def self.grabyml (fname)
	Psych.load( IO.read( fname ) ).each_with_object({}){ |(k,v), h| h[k.to_sym] = v }
    end

    @@conf = grabyml("../config/db.yml")
    @@conf[:user] = @@conf[:username]
    @@sql  = grabyml("../config/queries.yml")
    @@connection = nil;

    def initialize
	if @@connection.nil?
	    connect
	end

	begin
	    if @@connection.test_connection.nil?
		@@connection.disconnect
		raise
	    end
	rescue Exception => e
	    connect    
	end

	@@connection
    end

    def connect
	begin
	    @@connection = Sequel.postgres(@@conf)
	rescue Exception => e
	    puts e
	    nil
	end
    end

    def query (name, params = [])
	begin
	    @@connection[@@sql[name], *params].all
	rescue Exception => e
	    puts e
	    nil
	end
    end

    def exec
	@@connection
    end

    def inspect
	[ @@conf, @@sql, @@connection ].map { |v| v.inspect }
    end
end

