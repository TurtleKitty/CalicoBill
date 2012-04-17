#lang racket

(require db)
(require web-server/servlet
         web-server/servlet-env)
(require web-server/managers/none)
(require (planet dherman/json:4:0))


; config

(define (jconf file)
    (json->jsexpr
	(file->string file)))

(define dbconf (jconf "../config/db.json"))


; database

; awesome sauce
(define (?->$n str [n 1])
    (cond
	[(regexp-match? "\\?" str)
	    (?->$n
		(regexp-replace
		    "\\?"
		    str
		    (string-append "$" (number->string n)))
		(+ 1 n))]
	[ else str ]))

(define sql
    (let ([x (jconf "../config/queries.json")])
	(make-immutable-hash
	    (hash-map x (lambda (k v) (cons k (?->$n v)))))))

(define dbh
    (virtual-connection
	(connection-pool
	    (lambda () (postgresql-connect 
		#:user	   (hash-ref dbconf 'username)
		#:database (hash-ref dbconf 'database)
		#:password (hash-ref dbconf 'password)))
	    #:max-connections 60
	    #:max-idle-connections 10)))

(define (num->str->join xs ch)
    (string-join
        (map number->string xs)
        ch))

(define (sql-ts->string ts)
    (string-join
        (list
            (num->str->join
                (list
                    (sql-timestamp-year ts)
                    (sql-timestamp-month ts)
                    (sql-timestamp-day ts))
                "-")
            (num->str->join
                (list
                    (sql-timestamp-hour ts)
                    (sql-timestamp-minute ts)
                    (sql-timestamp-second ts))
                ":"))
        " "))

(define (rows->jsexpr rr)
    (define cols
        (map (lambda (h) (cdr (first h))) (rows-result-headers rr)))
    (define fixer
        (lambda (x)
            (cond
                [(integer? x) x]
                [(real? x) (real->double-flonum x)]
                [(sql-timestamp? x) (sql-ts->string x)]
                [(sql-null? x) #\null]
                [ else x ])))
    (map
        (lambda (record)
            (make-immutable-hash
                (map
                    (lambda (c v) (cons c (fixer v)))
                    cols
                    (vector->list record))))
        (rows-result-rows rr)))

(define (dbq qname [params '()])
    (define x-sql (hash-ref sql qname))
    (apply query dbh x-sql params))

(define (dbx qname [params '()])
    (define x-sql (hash-ref sql qname))
    (begin
	(apply query-exec dbh x-sql params)
	(query-value dbh "select lastval()")))

(define (dbfetch qname [params '()])
    (rows->jsexpr
	(dbq qname params)))

(define (fetch/nf qname [params '()])
    (define rv (dbfetch qname params))
    (cond
	[(empty? rv) (hash "error" "Not Found")]
	[else (first rv)]))


; utilities

(define (add-address args)
    (dbx 'add_address args))

(define (get-address id)
    (fetch/nf 'get_address (list id)))

(define (get-invoice id)
    (define invoice (fetch/nf 'get_invoice (list id)))
    (define billaddr (get-address (hash-ref invoice "billing_address")))
    (define shipaddr (get-address (hash-ref invoice "shipping_address")))
    (define customer (fetch/nf 'get_customer (list (hash-ref invoice "customer"))))
    (define lineitems
	(map
	    (lambda (x)
		(hash-set x "total"
		    (* (hash-ref x "price") (hash-ref x "quantity"))))
	    (dbfetch 'get_lineitems (list id))))
    (hash-set* invoice
	"amount" (foldl (lambda (li sum) (+ sum (hash-ref li "total"))) 0.0 lineitems)
	"billing_address" billaddr
	"shipping_address" shipaddr
	"customer" customer
	"lineitems" lineitems))

(define (build-invoices lst)
    (map
	(lambda (inv)
	    (get-invoice (hash-ref inv "id")))
	lst))

(define (parse-body req)
    (json->jsexpr
        (bytes->string/utf-8
            (request-post-data/raw req))))

(define (uncool x)
    (and (string? x)
	 (not (> (string-length x) 0))))

(define (numstring x)
    (cond
	[(string? x) x]
	[(number? x) (number->string x)]))

(define (hash-vals h xs)
    (map (lambda (x) (hash-ref h x)) xs))

(define (check-params lst)
    (map
	(lambda (x) (if (uncool x) (error (string-join (list "Bad" (symbol->string x) " "))) #f))
	lst))

; handlers

(define (hello-calico req)
    "Hello, Calico!")

(define (customer-list req)
    (dbfetch 'list_customers))

(define (customer-view req id)
    (fetch/nf 'get_customer (list id)))

(define (customer-create req)
    (define params (parse-body req))
    (define firstname (hash-ref params 'firstname))
    (define lastname (hash-ref params 'lastname))
    (define email (hash-ref params 'email))
    (define street_addr (hash-ref params 'street_addr))
    (define street_addr2 (hash-ref params 'street_addr2))
    (define city (hash-ref params 'city))
    (define state (hash-ref params 'state))
    (define zip (numstring (hash-ref params 'zip)))
    (begin
	(check-params (list firstname lastname email street_addr city state zip))
	(hash 'ok
	    (call-with-transaction dbh
		(lambda ()
		    (dbx 'add_customer
			(list
			    (add-address (list street_addr street_addr2 city state zip))
			    email
			    firstname
			    lastname)))))))

(define (customer-invoices req id)
    (build-invoices
	(dbfetch 'get_customer_invoices (list id))))

(define (customer-invoice-create req cid)
    (define params (parse-body req))
    (define street_addr (hash-ref params 'street_addr))
    (define street_addr2 (hash-ref params 'street_addr2))
    (define city (hash-ref params 'city))
    (define state (hash-ref params 'state))
    (define zip (numstring (hash-ref params 'zip)))
    (define lineitems (hash-ref params 'lineitems))
    (define customer (customer-view req cid)) ; unexpected and hilarious bonus!
    (begin
	(check-params (list cid street_addr city state zip))
	(map
	    (lambda (li)
		(check-params (hash-vals li '(product quantity))))
	    lineitems)
	(hash 'ok
	    (call-with-transaction dbh
		(lambda ()
		    (define invoice_id
			(dbx 'add_invoice
			    (list
				cid
				(add-address
				    (hash-vals customer '("street_addr" "street_addr2" "city" "state" "zip")))
				(add-address
				    (list street_addr street_addr2 city state zip)))))
		    (begin
			(map
			    (lambda (li)
				(define product (fetch/nf 'get_product (list (hash-ref li 'product))))
				(dbx 'add_lineitem
				    (list
					(hash-ref product "id")
					invoice_id
					(hash-ref product "price")
					(hash-ref li 'quantity))))
			    lineitems)
			invoice_id))))))

(define (product-list req)
    (dbfetch 'list_products))

(define (product-create req)
    (define params (parse-body req))
    (define name (hash-ref params 'name)) 
    (define price (string->number (hash-ref params 'price))) 
    (define desc (hash-ref params 'desc)) 
    (cond
	[(uncool name) (error "Bad name.") ]
	[(uncool desc) (error "Bad description.") ]
	[(< price 0) (error "Bad price.") ]
	[else (hash 'ok (dbx 'add_product (list name price desc)))]))

(define (invoice-list req)
    (build-invoices
	(dbfetch 'list_invoices)))

(define (invoice-view req id)
    (get-invoice id))


; web server

(define-values (calico-dispatch calico-url)
    (dispatch-rules
     [("customer") customer-list]
     [("customer" (integer-arg)) customer-view]
     [("customer" "create") customer-create]
     [("customer" (integer-arg) "invoice") customer-invoices]
     [("customer" (integer-arg) "invoice" "create") customer-invoice-create]
     [("product") product-list]
     [("product" "create") product-create]
     [("invoice") invoice-list]
     [("invoice" (integer-arg)) invoice-view]
     [else hello-calico] ))

(define (mk-header-list lst)
    (map (lambda (x) (make-header (car x) (cdr x)))
	(append lst (list '(#"X-Secret" . #"CalicoBill by TurtleKitty")))))

(define (text-response data [ headers '() ])
    (response/full
	200 #"OK"
	(current-seconds)
	#"text/plain"
	(mk-header-list headers)
	(list (string->bytes/utf-8 (string-join data "")))))

(define (json-response data [ headers '() ])
    (response/full
	200 #"OK"
	(current-seconds)
	#"application/json"
	(mk-header-list headers)
	(list (string->bytes/utf-8 (jsexpr->json data)))))

(define (calicobill req)
    (json-response
	(with-handlers
	    ([exn:fail? (lambda (e) (hash "error" (exn-message e)))])
	    (calico-dispatch req))))

(displayln "Ready.")

(define ccla (current-command-line-arguments))
(define host (vector-ref ccla 0))
(define port (string->number (vector-ref ccla 1)))

(serve/servlet calicobill
    #:listen-ip host
    #:port port
    #:servlet-regexp #rx""
    #:command-line? #t
    #:stateless? #t
    #:manager (create-none-manager #f)
    #:log-file "calico.log")


