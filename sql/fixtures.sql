
insert into address (street_addr, city, state, zip) values
	('221B Baker St', 'London', 'England', 'abcdef'),
	('Yoyodyne Propulsion Systems', 'Grovers Mill', 'New Jersey', '20202'),
	('31337 Hacker Way', 'Austin', 'TX', '78704')
;

insert into customer (address, email, firstname, lastname) values
	(1, 'sherlock@holmes.uk', 'Sherlock', 'Holmes'),
	(2, 'johnbigboote@yoyodyne.com', 'John', 'Bigboote'),
	(3, 'haxor@leet.com', 'Alyssa P', 'Hacker')
;

insert into product (name, price, description) values
	('Chess Set', 499.99, 'A beautiful set made of silver, bronze, and marble.'),
	('Oscillation Overthruster', 88888.88, 'Before there was a Flux Capacitor, there was the Oscillation Overthruster!  Get the original!'),
	('Calico AI Node', 300.00, '1010100101011110010101100000110010111000001101011200001010101010110010101')
;

insert into invoice (customer, billing_address, shipping_address) values
	(3, 3, 1),
	(3, 3, 2),
	(1, 1, 3),
	(2, 2, 3)
;

insert into lineitem (product, invoice, price, quantity) values
	(3, 1, 3.00, 1),
	(3, 2, 3.00, 1),
	(1, 3, 499.99, 1),
	(3, 3, 300.00, 10),
	(2, 4, 88888.88, 1),
	(3, 4, 300.00, 10)
;


