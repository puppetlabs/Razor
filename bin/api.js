// Node.js endpoint for ProjectRazor API

var razor_bin = __dirname+ "/razor"; // Set project_razor.rb path
console.log(razor_bin);
var execFile = require("child_process").execFile; // create our execFile object
var express = require('express'); // include our express libs
var common = require('./common.js');
var InvalidURIPathError = common.InvalidURIPathError;
var urlDecode = common.urlDecode;
var returnError = common.returnError;

var os = require('os');
var spawn = require("child_process").spawn;
var Lazy = require('lazy');
var pool = require('generic-pool').Pool({
    name: 'razor',
    create: function(callback) {
        proc = spawn(razor_bin, ['-b'], options={'stdio': ['pipe', 'pipe', 'ignore']});
        callback(null, proc);
    },
    destroy: function(proc) {
        proc.stdin.end();
    },
    max: os.cpus().length,
    min: os.cpus().length / 2,
    refreshIdle: false
});

app = express.createServer(); // our express server
app.use(express.bodyParser()); // Enable body parsing for POST
// app.use(express.profiler()); // Uncomment for profiling to console
// app.use(express.logger()); // Uncomment for logging to console

// Exception for boot API request
app.get('/razor/api/boot*',
    function(req, res) {
        try {
            args = getRequestArgs(req);
            if (args.length < 3)
                args.push('default');
            args.push(JSON.stringify(req.query));
            console.log(razor_bin + getArguments(args));
            pool.acquire(function(err, proc) {
                if (err) {
                    console.log(err);
                }
                else {
                    error_cb = function (return_code) {
                        if (return_code != 0) {
                            Lazy(proc.stdout).head(function(data) {
                                returnError(res, data);
                            });
                        }
                    };
                    proc.on('close', error_cb);
                    proc.stdin.write(getArguments(args) + '\n', callback=function(error) {
                        Lazy(proc.stdout).head(function(data) {
                            res.send(data, 200, {"Content-Type": "text/plain"});
                        });
                        proc.removeListener('close', error_cb);
                        pool.release(proc);
                    });
                }
            });
        } catch(e) {
            returnError(res, e);
        }
   });

app.get('/razor/api/*',
    function(req, res) {
        console.log("GET " + req.path);
        try {
            args = getRequestArgs(req);
            if (args.length < 3)
                args.push('default');
            	
            args.push(JSON.stringify(req.query));
            console.log(razor_bin + getArguments(args));
            pool.acquire(function(err, proc) {
                if (err) {
                    console.log(err);
                }
                else {
                    error_cb = function (return_code) {
                        if (return_code != 0) {
                            Lazy(proc.stdout).head(function(data) {
                                returnError(res, data);
                            });
                        }
                    };
                    proc.on('close', error_cb);
                    proc.stdin.write(getArguments(args) + '\n', callback=function(error) {
                        Lazy(proc.stdout).head(function(data) {
                            returnResult(res, data);
                        });
                        proc.removeListener('close', error_cb);
                        pool.release(proc);
                    });
                }
            });
        } catch(e) {
            returnError(res, e);
        }
    });

app.post('/razor/api/*',
    function(req, res) {
        console.log("POST " + req.path);
        try {
            args = getRequestArgs(req);
            if (!(command_included(args, "add") || command_included(args, "checkin") || command_included(args, "register"))) {
                args.push("add");
            }
            args.push(req.param('json_hash', null));
            //process.stdout.write('\033[2J\033[0;0H');
            console.log(razor_bin + getArguments(args));
            pool.acquire(function(err, proc) {
                if (err) {
                    console.log(err);
                }
                else {
                    error_cb = function (return_code) {
                        if (return_code != 0) {
                            Lazy(proc.stdout).head(function(data) {
                                returnError(res, data);
                            });
                        }
                    };
                    proc.on('close', error_cb);
                    proc.stdin.write(getArguments(args) + '\n', callback=function(error) {
                        Lazy(proc.stdout).head(function(data) {
                            returnResult(res, data);
                        });
                        proc.removeListener('close', error_cb);
                        pool.release(proc);
                    });
                }
            });
        } catch(e) {
            returnError(res, e);
        }
    });

app.put('/razor/api/*',
    function(req, res) {
        console.log("PUT " + req.path);
        try {
            args = getRequestArgs(req);
            if (!command_included(args, "update")) {
                args.splice(-1, 0, "update");
            }
            args.push(req.param('json_hash', null));
            console.log(razor_bin + getArguments(args));
            pool.acquire(function(err, proc) {
                if (err) {
                    console.log(err);
                }
                else {
                    error_cb = function (return_code) {
                        if (return_code != 0) {
                            Lazy(proc.stdout).head(function(data) {
                                returnError(res, data);
                            });
                        }
                    };
                    proc.on('close', error_cb);
                    proc.stdin.write(getArguments(args) + '\n', callback=function(error) {
                        Lazy(proc.stdout).head(function(data) {
                            returnResult(res, data);
                        });
                        proc.removeListener('close', error_cb);
                        pool.release(proc);
                    });
                }
            });
        } catch(msg) {
            returnError(res, e);
        }
    });

app.delete('/razor/api/*',
    function(req, res) {
        console.log("DELETE " + req.path);
        try {
            args = getRequestArgs(req);
            if (!command_included(args, "remove")) {
                args.splice(-1, 0, "remove");
            }
            console.log(razor_bin + getArguments(args));
            pool.acquire(function(err, proc) {
                if (err) {
                    console.log(err);
                }
                else {
                    error_cb = function (return_code) {
                        if (return_code != 0) {
                            Lazy(proc.stdout).head(function(data) {
                                returnError(res, data);
                            });
                        }
                    };
                    proc.on('close', error_cb);
                    proc.stdin.write(getArguments(args) + '\n', callback=function(error) {
                        Lazy(proc.stdout).head(function(data) {
                            returnResult(res, data);
                        });
                        proc.removeListener('close', error_cb);
                        pool.release(proc);
                    });
                }
            });
        } catch(msg) {
            returnError(res, e);
        }
    });


app.get('/*',
    function(req, res) {
        switch(req.path)
        {
            case "/razor":
                res.send('Bad Request(No module selected)', 404);
                break;
            case "/razor/api":
                res.send('Bad Request(No slice selected)', 404);
                break;
            default:
                res.send('Bad Request', 404);
        }
    });

/**
 * Assembles an array of argument, starting with the string '-w' and then
 * followed by URI decoded path elements from the request path. The first
 * two path elements are skipped.
 *
 * @param req The Express Request object
 * @returns An array of arguments
 * @throws An 'Illegal path component' if some path element is considered unsafe
 */
function getRequestArgs(req) {
    args = req.path.split("/");
    args.splice(0,3);
    if(args.length > 0) {
        if(args[args.length-1] == '')
            // Path ended with slash. Just skip this one
            args.pop();
    
        for(var i = 0; i < args.length; ++i)
            args[i] = urlDecode(args[i]);
    }
    args.unshift('-w');
    return args;
}

function returnResult(res, json_string) {
    var return_obj;
    var http_err_code;
    try
    {
        return_obj = JSON.parse(json_string);
        http_err_code = return_obj['http_err_code'];
        res.writeHead(http_err_code, {'Content-Type': 'application/json'});
        res.end(json_string);
    }
    catch(err)
    {
    	// Apparently not JSON and should be sent as plain text.
    	// TODO: This approach is bad. We should know what to do with
    	// the json_string, not guess. What if the response can be parsed but
    	// still isn't JSON?
        res.send(json_string, 200, {'Content-Type': 'text/plain'});
    }
}

function getArguments(args) {
    var arg_string = " ";
    for (x = 0; x < args.length; x++) {
        arg_string = arg_string + "'" + args[x] + "' "
    }
    return arg_string;
}

function getConfig() {
    execFile(razor_bin, ['-j', 'config', 'read'], function (err, stdout, stderr) {
        console.log(stdout);
        startServer(stdout);
    });
}

function command_included(arr, obj) {
    return arr.indexOf(obj) >= 0;
}

// TODO Add catch for if project_razor.js is already running on port
// Start our server if we can get a valid config
function startServer(json_config) {
    config = JSON.parse(json_config);
    if (config['@api_port'] != null) {
        app.listen(config['@api_port']);
        console.log('ProjectRazor API Web Server started and listening on:%s', config['@api_port']);
    } else {
        console.log("There is a problem with your ProjectRazor configuration. Cannot load config.");
    }
}


getConfig();
