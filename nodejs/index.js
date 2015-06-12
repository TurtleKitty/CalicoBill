
// modules

var express = require('express'),
    async   = require('async'),
    fs      = require('fs'),
    http    = require('http'),
    dbi     = require('node-dbi'),
    bparser = require('body-parser'),
    pgconf  = require('../config/db.json'),
    sql     = require('../config/queries.json'),
    db = new dbi.DBWrapper(
        'pg',
        {
            host: "localhost",
            database: "calico",
            user: pgconf.username,
            password: pgconf.password
        }
    ),
    clog    = console.log,
    cerr    = console.error
;

db.connect();


function dbError (e, fn) {
    cerr("Database error:");
    cerr(e);
    return fn(null);
}

function dbq (name, params, fn) {
    db.fetchAll(
        sql[name], 
        params,
        function (e, rows) {
            if (e) {
                return dbError(e, fn);
            }

            fn(rows);
        }
    );
}

function dbx (name, params, fn) {
    db.query(
        sql[name],
        params,
        function (e) {
            if (e) {
                return dbError(e, fn); 
            }

            db.fetchOne(
                "select lastval() as id",
                null,
                function (e2, id) {
                    fn(id);
                }
            );
        }
    );
}


function build_invoice (invoice, fn) {
    var noob = {};

    noob.id = invoice.id;
    noob.created = invoice.created.toString().replace(/T/, " ").replace(/\.*/, "");

    dbq(
        'get_customer',
        [ invoice.customer ],
        function (results) {
            noob.customer = results[0];

            dbq(
                'get_lineitems',
                [ invoice.id ],
                function (results) {
                    noob.lineitems = results.map( function (v) {
                        v.total = v.price * v.quantity;
                        return v;
                    });

                    noob.amount = noob.lineitems.reduce(
                        function (sum, x) {
                            return sum + x.total;
                        },
                        0
                    );

                    dbq(
                        'get_address',
                        [ invoice.billing_address ],
                        function (results) {
                            noob.billing_address = results[0];

                            if (invoice.billing_address == invoice.shipping_address) {
                                noob.shipping_address = noob.billing_address;
                                fn(noob);
                            }
                            else {
                                dbq(
                                    'get_address',
                                    [ invoice.shipping_address ],
                                    function (results) {
                                        noob.shipping_address = results[0];
                                        fn(noob);
                                    }
                                );
                            }
                        }
                    );
                }
            );
        }
    );
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


var app = express();

app.use(bparser.json());
app.use(bparser.urlencoded({ extended: true }));


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
    dbq(
        query,
        params,
        function (results) {
            rez.json(results);
        }
    );
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
    dbq('get_customer', [ req.params.id ], function (results) {
        rez.json(results[0]);
    });
}


function customer_invoices (req, rez) {
    dbq('get_customer_invoices', [ req.params.id ], function (results) {
        build_invoice_list(results, [], function (ilist) {
            rez.json(ilist);
        })
    });
}


function customer_create (req, rez) {
    var p = req.body;

    dbx('add_address', [ p.street_addr, p.street_addr2, p.city, p.state, p.zip ], function (addr_id) {
        dbx('add_customer', [ addr_id, p.email, p.firstname, p.lastname ], function (cust_id) {
            rez.json({ ok: cust_id });
        });
    });
}


function customer_invoice_create (req, rez) {
    var ps = req.body;

    dbq(
        'get_customer',
        [ req.params.id ],
        function (results) {
            var customer = results[0];

            dbx(
                'add_address',
                [ customer.street_addr, customer.street_addr2, customer.city, customer.state, customer.zip ],
                function (bill_addr_id) {
                    dbx(
                        'add_address',
                        [ ps.street_addr, ps.street_addr2, ps.city, ps.state, ps.zip ],
                        function (ship_addr_id) {
                            dbx(
                                'add_invoice',
                                [ req.params.id, bill_addr_id, ship_addr_id ],
                                function (invoice_id) {
                                    async.each(
                                        ps.lineitems,
                                        function (li, cb) {
                                            dbq(
                                                'get_product',
                                                [ li.product ],
                                                function (results) {
                                                    var product = results[0];

                                                    dbx(
                                                        'add_lineitem',
                                                        [ li.product, invoice_id, product.price, li.quantity ],
                                                        function (id) {
    /* Pyramid of DOOOOOOOOOOOOOOOOOOOOOOOM! */            cb();
                                                        }
                                                    );
                                                }
                                            );
                                        },
                                        function (e) {
                                            if (e) {
                                                console.error("Failed to add lineitems!");
                                                return rez.json({ ok: 0 });
                                            }

                                            rez.json({ ok: 1, id: invoice_id });
                                        }
                                    );
                                }
                            );
                        }
                    );
                }
            );
        }
    );
}


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

    dbx('add_product', [ name, price, desc ], function (id) {
        var rval = { ok: 1, id: id };
        rez.json(rval);
    });
}


function invoice (req, rez) {
    dbq('list_invoices', [], function (results) {
        build_invoice_list(results, [], function (ilist) {
            rez.json(ilist);
        })
    });
}

function invoice_view (req, rez) {
    dbq('get_invoice', [ req.params.id ], function (results) {
        build_invoice(results[0], function (invoice) {
            rez.json(invoice);
        });
    });
}


http.createServer(app).listen(
    16386,
    function () {
        clog("CalicoBill node.js listening on port %d", 16386);
    }
);


