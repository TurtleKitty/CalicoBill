
require_relative "db"

class Product
    def self.list
	begin
	    CalicoDB.new.query("list_products").map do |p|
		p[:price] = p[:price].to_f
		p
	    end
	rescue Exception => e
	    puts e
	    [ ]
	end
    end

    def self.get (id)
	begin
	    CalicoDB.new.query("get_product", [ id ])[0]
	rescue Exception => e
	    puts e
	    { }
	end
    end

    def self.add (name, price, desc)
	begin
	    CalicoDB.new.exec[:product].insert(
		:name	    => name,
		:price	    => price,
		:description    => desc
	    )
	rescue Exception => e
	    puts e
	    nil
	end
    end
end 
