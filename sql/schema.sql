
create table address (
	id serial primary key,
	street_addr varchar(128) not null,
	street_addr2 varchar(128),
	city varchar(64) not null,
	state varchar(32) not null,
	zip varchar(16) not null
);

create table customer (
	id serial primary key,
	address integer not null references address (id) on delete restrict,
	email varchar(255) not null,
	firstname varchar(32) not null,
	lastname varchar(32) not null
);

create index email_idx on customer (email);

create table product (
	id serial primary key,
	name varchar(64) not null,
	price numeric(16, 2),
	description text
);

create table invoice (
	id serial primary key,
	created timestamp not null default current_timestamp,
	customer integer not null references customer (id) on delete cascade,
	billing_address integer not null references address (id),
	shipping_address integer not null references address (id)
);

create index customer_idx on invoice (customer);

create table lineitem (
	id serial primary key,
	product integer not null references product (id),
	invoice integer not null references invoice (id),
	price numeric(16,2) not null,
	quantity integer not null default 1
);

create index invoice_idx on lineitem (invoice);
create index product_idx on lineitem (product);

