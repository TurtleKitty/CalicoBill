
select street_addr, street_addr2, city, state, zip
from address
where id = ?;

select c.id, email, firstname, lastname, street_addr, street_addr2, city, state, zip
from customer c
join address a on (c.address = a.id)
where c.id = ?;

select id, customer, billing_address, shipping_address
from invoice
where id = ?;

select l.id, l.price, l.quantity, p.name, p.price, p.description
from lineitem l join product p on (l.product = p.id)
where invoice = ?;

select id, firstname, lastname, email
from customer;

select id, customer, billing_address, shipping_address
from invoice;

select id, customer, billing_address, shipping_address
from invoice
where customer = ?;

insert into address (street_addr, street_addr2, city, state, zip) values (?, ?, ?, ?, ?);
insert into customer (address, email, firstname, lastname) values (?, ?, ?, ?);
insert into product (name, price, description) values (?, ?, ?);
insert into invoice (customer, billing_address, shipping_address) values (?, ?, ?);
insert into lineitems (product, invoice, price, quantity) values (?, ?, ?, ?);

