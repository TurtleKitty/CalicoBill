
require_relative "db"
require_relative "address"
require_relative "customer"

class Invoice
    def self.list
	begin
	    CalicoDB.new.query(:list_invoices).map do |i|
		self.get(i[:id])
	    end
	rescue Exception => e
	    puts e
	    [ ]
	end
    end

    def self.get (id)
	begin
	    db = CalicoDB.new
	    invoice = db.query(:get_invoice, [ id ])[0]
	    invoice[:customer] = Customer.get(invoice[:customer])
	    invoice[:billing_address] = Address.get(invoice[:billing_address])
	    invoice[:shipping_address] = Address.get(invoice[:shipping_address])
	    invoice[:lineitems] = db.query(:get_lineitems, [ id ]).map do |x|
		x[:price] = x[:price].to_f
		x[:total] = x[:price] * x[:quantity]
		x
	    end
	    invoice[:amount] = invoice[:lineitems].reduce(0) { |t, x| t + x[:total] }
	    invoice
	rescue Exception => e
	    puts e
	    { }
	end
    end

    def self.add (customer_id, ship_addr, lineitems)
	begin
	    db = CalicoDB.new

	    customer = Customer.get(customer_id)

	    bill_id = Address.add(
		customer[:street_addr],
		customer[:street_addr2],
		customer[:city],
		customer[:state],
		customer[:zip],
	    )

	    ship_id = Address.add(
		ship_addr["street_addr"],
		ship_addr["street_addr2"],
		ship_addr["city"],
		ship_addr["state"],
		ship_addr["zip"]
	    )

	    inv_id = db.exec[:invoice].insert(
		:customer => customer_id,
		:billing_address => bill_id,
		:shipping_address => ship_id
	    )

	    lineitems.map do |li|
		product = Product.get(li["product"])

		db.exec[:lineitem].insert(
		    :invoice  => inv_id,
		    :product  => product[:id],
		    :price    => product[:price],
		    :quantity => li["quantity"]
		)
	    end

	    inv_id
	rescue Exception => e
	    puts e
	    nil
	end
    end
end 
