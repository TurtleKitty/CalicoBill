
require_relative "db"
require_relative "invoice"

class Customer
    def self.list
	CalicoDB.new.query(:list_customers) || []
    end

    def self.get (id)
	begin
	    CalicoDB.new.query(:get_customer, [ id ])[0]
	rescue Exception => e
	    puts e
	    { }
	end
    end

    def self.add (first, last, email, staddr, staddr2, city, state, zip)
	begin
	    addr_id = Address.add(staddr, staddr2, city, state, zip)

	    CalicoDB.new.exec[:customer].insert(
		:firstname => first,
		:lastname => last,
		:email => email,
		:address => addr_id
	    )
	rescue Exception => e
	    puts e
	    nil
	end
    end

    def self.invoices (id)
	begin
	    CalicoDB.new.query(:get_customer_invoices, [ id ]).map do |i|
		Invoice.get(i[:id])
	    end
	rescue Exception => e
	    puts e
	    [ ]
	end
    end
end 

