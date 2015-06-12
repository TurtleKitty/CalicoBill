
var Calico = (function () {
    var obj = {
	baseuri: "",
	templates: { },
    };

    // templates[], callback 
    obj.init = function (args) {
	var n	    = args.templates.length,
	    done    = 0
	;

	if (args.baseuri && args.baseuri.length > 0) {
	    obj.baseuri = args.baseuri;
	}

	$.each(
	    args.templates,
	    function (idx, tmpl) {
		var ckey = "calico/templates/" + tmpl;
		var cached = false; //localStorage.getItem(ckey);

		if (cached) {
		    obj.templates[tmpl] = cached;

		    done++;

		    if (done == n) {
			args.callback();
		    }
		}
		else {
		    $.ajax(
			obj.baseuri + '/views/' + tmpl + '.txt', {
			    type: "GET",
			    success: function (data) {
				obj.templates[tmpl] = data;

				try {
				    localStorage.setItem(ckey, data);
				}
				catch (e) {
				    alert("localStorage FAIL: " + e.toString());
				}
			    },
			    error: function (jqXHR, textStatus, errorThrown) {
				alert("Template error: " + tmpl);
				console.log(textStatus + " : " + errorThrown);
			    },
			    complete: function (jqXHR, textStatus) {
				done++;

				if (done == n) {
				    args.callback();
				}
			    }
			}
		    );
		}
	    }
	);
    };

    // get query string params
    obj.params = function () {
	return window.location.search.substring(1).split("&").map(
	    function (item) {
		return item.split('=');
	    }
	).reduce(
	    function(prev, current, idx, yarr){
		prev[current[0]] = current[1];
		return prev;
	    },
	    { }
	);
    };

    // get form values by id
    obj.formvals = function(ids) {
	var struct = { };

	ids.map(
	    function (arg) {
		struct[arg] = $("#" + arg).val();
	    }
	);

	return struct;
    };

    // render one template
    obj.render = function (tmpl, data) {
	return Mustache.render(obj.templates[tmpl], data);
    };

    // render a list of templates in order
    obj.render_cat = function (list) {
	return list.map(
	    function (arg) {
		return Calico.render(arg[0], arg[1]);
	    }
	).join("");
    };

    // render a list of templates with header and footer
    obj.render_layout = function(items) {
	items.unshift( [ "header", {} ] );
	items.push( [ "footer", {} ] );

	return obj.render_cat(items);
    };

    // uri, callback
    obj.phonehome = function (args) {
	$.ajax(
	    obj.baseuri + args.uri, {
		type: "GET",
		dataType: "json",
		success: function (data) {
		    args.callback(data);
		},
		error: function (jqXHR, textStatus, errorThrown) {
		    console.log(textStatus + " : " + errorThrown);
		}
	    }
	);
    };

    obj.validate = function (fields) {
	var fails = fields.filter(
	    function (item, index) {
		var val = $("#" + item).val();

		if (val.length < 1) {
		    return true;
		}

		return false;
	    }
	);

	if (fails.length > 0) {
	    alert(
		fails.reduce(
		    function (prev, curr) {
			return prev + curr + " is required.\n";
		    },
		    ""
		)   
	    );

	    return false;
	}

	return true;
    };

    // post_uri, body, callback
    obj.posthome = function (args) {
        var body = JSON.stringify(args.body);

        $.ajax(
            args.post_uri, {
                type: "POST",
                dataType: "json",
                contentType: "application/json",
                processData: false,
                data: body,
                success: function (data) {
                    if (data.error) {
                        console.log("error: " + data.error);
                    }
                    else {
                        args.callback();
                    }
                },
                error: function (jqxhr, text, err) {
                    console.log(text + " ::: " + err);
                    args.callback();
                }
            }
        );
    };

    return obj;
})();

