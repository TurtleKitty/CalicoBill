
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

var pgconf  = jconf('db'),
    sql	    = jconf('queries'),
    pgconn  = "postgres://" + pgconf.username + ":" + pgconf.password + "@localhost:5432/calico";


function dbq (name, params) {
    pg.connect(
	pgconn,
	function (err, client) {
	    if (err) {
		return({ error: "DB connection FAIL: " + err });
	    }

	    client.query(
		sql[name],
		params,
		function (err, results) {
		    
		}
	    );
	}
    );
}


var app = module.exports = express.createServer();

app.configure(function(){
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(app.router);
});

app.configure('development', function(){
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
});

app.configure('production', function(){
    app.use(express.errorHandler());
});


// routes

app.get('/', hello);

app.get('/customer', customer_list);
app.get('/customer/:id', customer_view);
app.get('/customer/:id/invoice', customer_invoices);
app.get('/customer/create', customer_create);
app.get('/customer/:id/invoice/create', customer_invoice_create);

app.get('/product', product);
app.get('/product/create', product_create);

app.get('/invoice', invoice);
app.get('/invoice/:id', invoice_view);


// handlers

function hello (req, rez) {
    rez.json("Hello, Calico!");
}


function customer_list (req, rez) {
    rez.json("NOP");
}


function customer_view (req, rez) {}
function customer_invoices (req, rez) {}
function customer_create (req, rez) {}
function customer_invoice_create (req, rez) {}

function product (req, rez) {}
function product_create (req, rez) {}

function invoice (req, rez) {}
function invoice_view (req, rez) {}


pg.connect(
    pgconn,
    function (err, client) {
	app.listen(16386, function(){
	    console.log("CalicoBill node.js listening on %d in %s mode", app.address().port, app.settings.env);
	});
    }
);



