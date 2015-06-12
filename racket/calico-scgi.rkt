#lang racket

(require db)
(require (planet neil/scgi))
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
	    #:max-connections 3
	    #:max-idle-connections 5)))

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

(define (parse-body)
    (json->jsexpr
	(sequence-fold
	    (lambda (x y) (string-append x y))
	    ""
	    (in-lines (current-input-port)))))

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

(define (hello-calico)
    "Hello, Calico!")

(define (customer-list)
    (dbfetch 'list_customers))

(define (customer-view id)
    (fetch/nf 'get_customer (list id)))

(define (customer-create)
    (define params (parse-body))
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

(define (customer-invoices id)
    (build-invoices
	(dbfetch 'get_customer_invoices (list id))))

(define (customer-invoice-create cid)
    (define params (parse-body))
    (define street_addr (hash-ref params 'street_addr))
    (define street_addr2 (hash-ref params 'street_addr2))
    (define city (hash-ref params 'city))
    (define state (hash-ref params 'state))
    (define zip (numstring (hash-ref params 'zip)))
    (define lineitems (hash-ref params 'lineitems))
    (define customer (customer-view cid)) ; unexpected and hilarious bonus!
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

(define (product-list)
    (dbfetch 'list_products))

(define (product-create)
    (define params (parse-body))
    (define name (hash-ref params 'name)) 
    (define price (string->number (hash-ref params 'price))) 
    (define desc (hash-ref params 'desc)) 
    (cond
	[(uncool name) (error "Bad name.") ]
	[(uncool desc) (error "Bad description.") ]
	[(< price 0) (error "Bad price.") ]
	[else (hash 'ok (dbx 'add_product (list name price desc)))]))

(define (invoice-list)
    (build-invoices
	(dbfetch 'list_invoices)))

(define (invoice-view id)
    (get-invoice id))


; web server

(define (calico-dispatch path)
    (define parts (rest (rest (rest (rest (regexp-split #rx"/" path))))))
    ((let ([x (car parts)] [xs (cdr parts)])
	(cond
	    [(equal? x "product")
		(cond [(null? xs) product-list]
		      [else product-create])]
	    [(equal? x "invoice")
		(cond [(null? xs) invoice-list]
		      [else (lambda () (invoice-view (string->number (car xs))))])]
	    [(equal? x "customer") 
		(cond [(null? xs) customer-list]
		      [else
			(let ([y (car xs)] [ys (cdr xs)])
			    (cond [(equal? y "create") customer-create]
				  [else
				    (let ([id (string->number y)])
					(cond [(null? ys) (lambda () (customer-view id))]
					      [(null? (cdr ys)) (lambda () (customer-invoices id))]
					      [else (lambda () (customer-invoice-create id))]))]))])]
	    [ else hello-calico ]))))

(define (calicobill)
    (jsexpr->json
	(with-handlers
	    ([exn:fail? (lambda (e) (hash "error" (exn-message e)))])
	    (calico-dispatch (cgi-request-uri)))))

(define stderr (current-error-port))

(define (start)
    (displayln "Ready." stderr))

(define (go)
    (displayln "Content-type: application/json\n")
    (displayln (calicobill)))

(define (end)
    (displayln "OK I LOVE YOU BYE BYE!!" stderr))

(define ccla (current-command-line-arguments))
(define host (vector-ref ccla 0))
(define port (string->number (vector-ref ccla 1)))

(cgi
    #:startup start
    #:request go
    #:shutdown end
    #:scgi-hostname host
    #:scgi-portnum port
    #:scgi-max-allow-wait 20)

