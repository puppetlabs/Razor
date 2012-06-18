// Node.js endpoint for ProjectRazor API

var razor_bin = __dirname+ "/razor -w"; // Set project_razor.rb path
console.log(razor_bin);
var exec = require("child_process").exec; // create our exec object
var express = require('express'); // include our express libs

app = express.createServer(); // our express server
app.use(express.bodyParser()); // Enable body parsing for POST
// app.use(express.profiler()); // Uncomment for profiling to console
// app.use(express.logger()); // Uncomment for logging to console

// Exception for boot API request
app.get('/razor/api/boot*',
    function(req, res) {
        args = req.path.split("/");
        args.splice(0,3);
        var args_string = getArguments(args);
        if (args.length < 2) {
            args_string = args_string + "default "
        }
        query_param = "'" + JSON.stringify(req.query) + "'";
        console.log(razor_bin + args_string + query_param);
        //process.stdout.write('\033[2J\033[0;0H'); - screen clearing trick
        exec(razor_bin + args_string + query_param, function (err, stdout, stderr) {
            res.send(stdout, 200, {"Content-Type": "text/plain"});
        });
    });

app.get('/razor/api/*',
    // TODO - need to decode vars

    function(req, res) {
        console.log("GET called");
        args = req.path.split("/");
        args.splice(0,3);
        var args_string = getArguments(args);
        if (args.length < 2) {
            args_string = args_string + "default "
        }
        query_param = "'" + JSON.stringify(req.query) + "'";
        console.log(razor_bin + args_string + query_param);
        exec(razor_bin + args_string + query_param, function (err, stdout, stderr) {
            returnResult(res, stdout);
        });
    });



app.post('/razor/api/*',
    function(req, res) {
        console.log("POST called");
        args = req.path.split("/");
        args.splice(0,3);
        if (command_included(args, "add") == undefined &&
            command_included(args, "checkin") == undefined &&
            command_included(args, "register") == undefined) {
            args.push("add");
        }
        var json_data = "'" + req.param('json_hash', null) + "'";
        var args_string = getArguments(args);
        //process.stdout.write('\033[2J\033[0;0H');
        console.log(args_string);
        console.log(razor_bin + args_string + json_data);
        exec(razor_bin + args_string + json_data, function (err, stdout, stderr) {
            returnResult(res, stdout);
        });
    });

app.put('/razor/api/*',
    function(req, res) {
        console.log("PUT called");
        args = req.path.split("/");
        args.splice(0,3);
        if (command_included(args, "update") == undefined) {
            args.splice(-1,0,"update");
        }
        var json_data = "'" + req.param('json_hash', null) + "'";
        var args_string = getArguments(args);
        console.log(args_string);
        console.log(razor_bin + args_string + json_data);
        exec(razor_bin + args_string + json_data, function (err, stdout, stderr) {
            returnResult(res, stdout);
        });
    });

app.delete('/razor/api/*',
    function(req, res) {
        console.log("DELETE called");
        args = req.path.split("/");
        args.splice(0,3);
        if (command_included(args, "remove") == undefined) {
            args.splice(-1,0,"remove");
        }
        var json_data = '{}';
        var args_string = getArguments(args);
        console.log(args_string);
        console.log(razor_bin + args_string);
        exec(razor_bin + args_string, function (err, stdout, stderr) {
            returnResult(res, stdout);
        });
    });


app.get('/*',
    function(req, res) {
        switch(req.path)
        {
            case "/":
                res.send('404 Error: Bad Request', 404);
                break;
            case "/razor":
                res.send('404 Error: Bad Request(No module selected)', 404);
                break;
            case "/razor/api":
                res.send('404 Error: Bad Request(No slice selected)', 404);
                break;
            default:
                res.send('404 Error: Bad Request', 404);
        }
    });

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
        // Parsing Error | Razor sent us something wrong - we just assume output
        res.send(json_string, 200, {"Content-Type": "application/json"});
    }
}

function getArguments(args) {
    var arg_string = " ";
    for (x = 0; x < args.length; x++) {
        arg_string = arg_string + args[x] + " "
    }
    return arg_string;
}

function getConfig() {
    exec(razor_bin + " config read", function (err, stdout, stderr) {
        console.log(stdout);
        startServer(stdout);
    });
}

function command_included(arr, obj) {
    for(var i=0; i<arr.length; i++) {
        if (arr[i] == obj) return true;
    }
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

