
// modules

var express = require('express'),
    JSON    = require('JSON'),
    fs	    = require('fs'),
    pg	    = require('pg').native
;


// conf

function jconf (fname) {
    var json;

    try {
	json = JSON.parse(
	    fs.readFileSync('../config/' + fname + '.json', 'ascii')
	);
    }
    catch (err) {
	console.error("There was an error opening the file " + fname + ": ");
	console.log(err);
    }

    return json;
}


function requestion (query, n) {
    var reg = /\?/;

    if (reg.test(query)) {
	return requestion(query.replace(reg, "$" + n), n + 1);
    }

    return query;
}


var pgconf  = jconf('db'),
    sql     = { },
    sqltmp  = jconf('queries'),
    pgconn  = "postgres://" + pgconf.username + ":" + pgconf.password + "@localhost:5432/calico"
;


sql = Object.keys(sqltmp).reduce(
    function (struct, query) {
	struct[query] = requestion(sqltmp[query], 1);
	return struct;
    },
    { }
);


function dbq (name, params, fn) {
    pg.connect(
	pgconn,
	function (err, client) {
	    if (err) {
		return({ error: "DB connection FAIL: " + err });
	    }

	    client.query(
		sql[name],
		params,
		fn
	    );
	}
    );
}


function dbadd (name, params, fn) {
    dbq(name, params, function (err, rval) {
	pg.connect(
	    pgconn,
	    function (err, client) {
		client.query("select lastval() as id", null, function (err2, rval2) {
console.log("error: " + err2);
console.log(rval2);
		    fn(rval2.rows[0].id);
		});
	    }
	);
    })
}


function build_invoice (invoice, fn) {
    var noob = {};

    noob.id = invoice.id;
    noob.created = invoice.created.toString().replace(/T/, " ").replace(/\.*/, "");

    dbq('get_customer', [ invoice.customer ], function (err, results) {
	noob.customer = results.rows[0];

	dbq('get_lineitems', [ invoice.id ], function (err, results) {
	    noob.lineitems = results.rows.map( function (v) {
		v.total = v.price * v.quantity;
		return v;
	    });

	    noob.amount = noob.lineitems.reduce(function (sum, x) {
		return sum + x.total;
	    }, 0);

	    dbq('get_address', [ invoice.billing_address ], function (err, results) {
		noob.billing_address = results.rows[0];

		if (invoice.billing_address == invoice.shipping_address) {
		    noob.shipping_address = noob.billing_address;
		    fn(noob);
		}
		else {
		    dbq('get_address', [ invoice.shipping_address ], function (err, results) {
			noob.shipping_address = results.rows[0];
			fn(noob);
		    });
		}
	    });
	});
    });
}


function build_invoice_list(invoices, ilist, fn) {
    var thisguy = invoices.shift();

    if (thisguy == null) {
	fn(ilist);
    }
    else {
	build_invoice(thisguy, function (invoice) {
	    ilist.push(invoice);
	    build_invoice_list(invoices, ilist, fn);
	});
    }
}


var app = module.exports = express.createServer();

app.configure(function(){
    app.use(express.bodyParser());
    app.use(express.methodOverride());
});

app.configure('development', function(){
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
});

app.configure('production', function(){
    app.use(express.errorHandler());
});


// routes

app.get('/', hello);
app.all('/test', test);

app.get('/customer', customer_list);
app.get('/customer/:id', customer_view);
app.get('/customer/:id/invoice', customer_invoices);
app.post('/customer/create', customer_create);
app.post('/customer/:id/invoice/create', customer_invoice_create);

app.get('/product', product);
app.post('/product/create', product_create);

app.get('/invoice', invoice);
app.get('/invoice/:id', invoice_view);


function simple_q (query, params, rez) {
    dbq(query, params, function (err, results) {
	var rval = []

	if (!err) {
	    rval = results.rows;
	}

	rez.json(rval);
    });
}


function not_cool(thing) {
    if (thing == null || thing.length < 1) {
	return true;
    }

    return false;
}



// handlers

function hello (req, rez) {
    rez.json("Hello, Calico!");
}


function test (req, rez) {
    rez.json(req.body);
}


function customer_list (req, rez) {
    simple_q('list_customers', [], rez);
}


function customer_view (req, rez) {
    dbq('get_customer', [ req.params.id ], function (err, results) {
	rez.json(results.rows[0]);
    });
}


function customer_invoices (req, rez) {
    dbq('get_customer_invoices', [ req.params.id ], function (err, results) {
	build_invoice_list(results.rows, [], function (ilist) {
	    rez.json(ilist);
	})
    });
}


function customer_create (req, rez) {
    var p = req.body;

    dbadd('add_address', [ p.street_addr, p.street_addr2, p.city, p.state, p.zip ], function (addr_id) {
	dbadd('add_customer', [ addr_id, p.email, p.firstname, p.lastname ], function (cust_id) {
	    rez.json({ ok: cust_id });
	});
    });
}


function customer_invoice_create (req, rez) {}


function product (req, rez) {
    simple_q('list_products', [], rez);
}


function product_create (req, rez) {
    var name = req.body.name,
	desc = req.body.desc,
	price = req.body.price
    ;

    if (not_cool(name)) {
	rez.json("Bad name.");
	return;
    }

    if (not_cool(desc)) {
	rez.json("Bad description.");
	return;
    }

    if (price < 0) {
	rez.json("Bad price.");
	return;
    }

    dbq('add_product', [ name, price, desc ], function (err, results) {
	var rval;

	if (err) {
	    rval = { fail: "Error adding product." };
	}
	else {
	    rval = { ok: 1 };
	}

	rez.json(rval);
    });
}


function invoice (req, rez) {
    dbq('list_invoices', [], function (err, results) {
	build_invoice_list(results.rows, [], function (ilist) {
	    rez.json(ilist);
	})
    });
}

function invoice_view (req, rez) {
    dbq('get_invoice', [ req.params.id ], function (err, results) {
        build_invoice(results.rows[0], function (invoice) {
	    rez.json(invoice);
	});
    });
}


app.listen(16386, function(){
    console.log("CalicoBill node.js listening on %d in %s mode", app.address().port, app.settings.env);
});



