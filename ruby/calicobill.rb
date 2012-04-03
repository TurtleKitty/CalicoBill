#!/usr/local/bin/ruby

require "rubygems"
require "sinatra/base"
require "json"

require_relative "product"
require_relative "customer"
require_relative "invoice"


class CalicoBill < Sinatra::Base

    def parse_body
	begin
	    JSON.parse(request.body.read)
	rescue Exception => e
	    r = { :error => "Parse FAIL: " + e.to_s }
	    puts r.inspect
	    r
	end
    end

    before do
	enable :logging, :dump_errors
	disable :static
	content_type :json
    end

    get "/" do
	[ "Hello, Calico!" ].to_json
    end

    get "/customer" do
	Customer.list.to_json
    end

    get "/customer/:id" do |id|
	Customer.get(id).to_json
    end

    get "/customer/:id/invoice" do |id|
	Customer.invoices(id).to_json
    end

    post "/customer/create" do
	cs = parse_body

	rval = Customer.add(
	    cs["firstname"],
	    cs["lastname"],
	    cs["email"],
	    cs["street_addr"],
	    cs["street_addr2"],
	    cs["city"],
	    cs["state"],
	    cs["zip"]
	)

	{ :rval => rval.to_s }.to_json
    end

    post "/customer/:id/invoice/create" do |id|
	inv = parse_body
	shipaddr = { }

	%w{ street_addr street_addr2 city state zip }.each do |thing|
	    shipaddr[thing] = inv[thing]
	end

	rval = Invoice.add(id, shipaddr, inv["lineitems"])

	{ :rval => rval.to_s }.to_json
    end

    get "/invoice" do
	Invoice.list.to_json
    end

    get "/invoice/:id" do |id|
	Invoice.get(id).to_json
    end

    get "/product" do
	Product.list.to_json
    end

    post "/product/create" do
	prd = parse_body

	rval = Product.add(prd["name"], prd["price"], prd["desc"])

	{ :rval => rval.to_s }.to_json
    end 

end 


