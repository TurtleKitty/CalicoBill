
require_relative "db"

class Address
    def self.add (addr, addr2, city, state, zip)
	begin
	    CalicoDB.new.exec[:address].insert(
		:street_addr => addr,
		:street_addr2 => addr2,
		:city => city,
		:state => state,
		:zip => zip
	    )
	rescue Exception => e
	    puts e
	    nil
	end
    end

    def self.get (id)
	begin
	    CalicoDB.new.query("get_address", [ id ])[0]
	rescue Exception => e
	    puts e
	    { }
	end
    end
end 
