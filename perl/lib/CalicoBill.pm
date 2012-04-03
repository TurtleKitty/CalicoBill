package CalicoBill;

use Dancer;

use Carp;
use Config::Merge;
use DBI;
use DBIx::Simple;
use File::Slurp;
use List::AllUtils;
use Try::Tiny;


my $rootdir = '/home/calicobill';


# routes

get '/' => \&customer_list;

prefix '/customer' => sub {
    get '/' => \&customer_list;
    get '/:id' => \&customer_view;
    get '/:id/invoice' => \&customer_invoice_list;
    post '/create' => \&customer_create;
    post '/:id/invoice/create' => \&customer_invoice_create;
};

prefix '/invoice' => sub {
    get '/' => \&invoice_list;
    get '/:id' => \&invoice_view;
};

prefix '/product' => sub {
    get '/' => \&product_list;
    post '/create' => \&product_create;
};

get '/test/:id' => \&test;


# init

my $conf = Config::Merge->new("$rootdir/config");
my $sql  = $conf->("queries");

hook before => sub {
    var db => dbix();
    content_type 'application/json';
};


# utils

sub dbix {
    my $dbh = try {
        my $dbh_info = $conf->("db");

	my ($host, $db, $user, $pass) = @$dbh_info{qw/host database username password/};

        my $dbh = DBI->connect_cached(
	    "dbi:Pg:dbname=$db;host=$host",
	    $user,
	    $pass,
	    {
		RaiseError	    => 1,
		FetchHashKeyName    => 1,
	    }
	);

	my $dbix;

	if ($dbh) {
	    $dbix = DBIx::Simple->new($dbh);
	}

	return $dbix;
    }
    catch {
	return;
    };

    if (defined($dbh)) {
	return $dbh
    }

    croak "Undefined database handle.";
}


sub dbid ($) {
    vars->{db}->last_insert_id(undef, "public", $_[0], undef);
}


sub parse_body {
    from_json(request->body);
}


sub is_cool {
    my ($x) = @_;
    return( defined($x) && length($x) > 0 );
}


sub build_invoice {
    my ($invoice) = @_;

    my $struct = {
	id	=> $invoice->{id},
	created => $invoice->{created},
    };

    my $db = vars->{db};

    return try {
	$struct->{customer} = $db->query($sql->{get_customer}, $invoice->{customer})->hash;

	$struct->{billing_address} = $db->query($sql->{get_address}, $invoice->{billing_address})->hash;

	$struct->{shipping_address} = ($invoice->{billing_address} == $invoice->{shipping_address})
				    ? $invoice->{billing_address}
				    : $db->query($sql->{get_address}, $invoice->{shipping_address})->hash;

	my @items = $db->query($sql->{get_lineitems}, $invoice->{id})->hashes;

	$struct->{lineitems} = [
	    map { $_->{total} = $_->{price} * $_->{quantity}; $_; } @items
	];

	$struct->{amount} = List::AllUtils::reduce { $a + $b->{price} * $b->{quantity} } 0, @{ $struct->{lineitems} };

	return $struct;
    }
    catch {
	carp "Failed to build invoice $invoice->{id} : $_";
	return { error => "build_invoice FAIL for $invoice->{id}" };
    };
}


# handlers

sub test {
    warn param("id");
}


sub customer_list {
    return try {
	vars->{db}->query($sql->{list_customers})->hashes;
    }
    catch {
	carp "customer_list FAIL: $_";
	return { error => $_ };
    };
}


sub customer_view {
    return try {
	vars->{db}->query($sql->{get_customer}, param("id"))->hash
	// { message => "Not Found" };
    }
    catch {
	carp "customer_view FAIL: $_";
	return { error => $_ };
    };
}


sub customer_create {
    my $db = vars->{db};

    return try {
	my $data = parse_body();

	for my $p ( qw| firstname lastname email street_addr city state zip | ) {
	    unless ( is_cool($data->{$p}) ) {
		die "Bad $p";
	    }
	}

	$db->query(
	    $sql->{add_address},
	    @$data{qw| street_addr street_addr2 city state zip |}
	);

	my $addr_id = dbid("address");

	$db->query(
	    $sql->{add_customer},
	    $addr_id,
	    @$data{qw| email firstname lastname |},
	);

	return { ok => 1 }
    }
    catch {
	carp "customer_create FAIL: $_";
	return { error => $_ };
    };
}


sub customer_invoice_list {
    return try {
	my $id = param("id") // return { message => "Not Found" };
	my @invoices = vars->{db}->query($sql->{get_customer_invoices}, param("id"))->hashes;
	return [ map { build_invoice($_) } @invoices ];
    }
    catch {
	carp "customer_invoice_list FAIL: $_";
	return { error => $_ };
    };
}


sub customer_invoice_create {
    my $db  = vars->{db};
    my $cid = param("id") // 0;

    return try {
	my $data = parse_body();

	unless ( is_cool($cid) ) {
	    die "Bad customer ID";
	}

	for my $p ( qw| street_addr city state zip | ) {
	    unless ( is_cool($data->{$p}) ) {
		die "Bad $p";
	    }
	}

	for my $item (@{$data->{lineitems}}) {
	    for my $p ( qw| product quantity | ) {
		unless ( is_cool($item->{$p}) ) {
		    die "Bad $p";
		}
	    }
	}

	my $customer = $db->query($sql->{get_customer}, $cid)->hash;

	$db->query(
	    $sql->{add_address},
	    @{$customer}{qw| street_addr street_addr2 city state zip |}
	);

	my $bill_addr_id = dbid("address");

	$db->query(
	    $sql->{add_address},
	    @{$data}{qw| street_addr street_addr2 city state zip |}
	);

	my $ship_addr_id = dbid("address");

	$db->query(
	    $sql->{add_invoice},
	    $cid,
	    $bill_addr_id,
	    $ship_addr_id
	);

	my $invoice_id = dbid("invoice");

	for my $li (@{$data->{lineitems}}) {
	    my $product = $db->query($sql->{get_product}, $li->{product})->hash;

	    $db->query(
		$sql->{add_lineitem},
		$li->{product},
		$invoice_id,
		$product->{price},
		$li->{quantity},
	    );
	}

	return { ok => 1 };
    }
    catch {
	carp "customer_invoice_create FAIL: $_";
	return { error => $_ };
    };
}


sub invoice_list {
    return try {
	my @invoices = vars->{db}->query($sql->{list_invoices})->hashes;
	return [ map { build_invoice($_) } @invoices ];
    }
    catch {
	carp "invoice_list FAIL: $_";
	return { error => $_ };
    };
}


sub invoice_view {
    return try {
	my $invoice = vars->{db}->query($sql->{get_invoice}, param("id"))->hash;

	unless ($invoice) {
	    return { message => "Not Found" };
	}

	return build_invoice($invoice);
    }
    catch {
	carp "customer_view FAIL: $_";
	return { error => $_ };
    };
}


sub product_list {
    return try {
	vars->{db}->query($sql->{list_products})->hashes;
    }
    catch {
	carp "product_list FAIL: $_";
	return { error => $_ };
    };

}


sub product_create {
    return try {
	my $data = parse_body();

	unless ( is_cool($data->{name}) ) {
	    die "Bad name";
	}

	unless ( is_cool($data->{description}) ) {
	    die "Bad description";
	}

	unless ( $data->{price} > 0 ) {
	    die "Bad price";
	}

	my $rv = vars->{db}->query($sql->{add_product}, $data->{name}, $data->{price}, $data->{description})->rows;

	return { ok => $rv }
    }
    catch {
	carp "product_create FAIL: $_";
	return { error => $_ };
    };
}


true;

