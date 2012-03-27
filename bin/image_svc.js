// EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
// Copyright © 2012 EMC Corporation, All Rights Reserved
//
// Node.js Endpoint for ProjectRazor Image Service



var razor_bin = __dirname+ "/razor -w"; // Set project_razor.rb path
var exec = require("child_process").exec; // create our exec object
var express = require('express'); // include our express libs
var mime = require('mime');
var fs = require('fs');
var image_svc_path;

app = express.createServer(); // our express server


app.get('/razor/image/mk*',
    function(req, res) {
        args = req.path.split("/");
        args.splice(0,3);
        var args_string = getArguments(args);
        if (args.length < 2) {
            args_string = args_string + "default "
        }

        exec(razor_bin + " imagesvc path " + args_string, function (err, stdout, stderr) {
            console.log(stdout);
            path = getPath(stdout);
            respondWithFileMK(path, res)
        });
    });


app.get('/razor/image/*',
    function(req, res) {
        path = decodeURIComponent(req.path.replace(/^\/razor\/image/, image_svc_path));
        respondWithFile(path, res);
    });


function respondWithFileMK(path, res) {
    if (path != null) {
        var filename = path.split("/")[path.split("/").length - 1];

        res.setHeader('Content-disposition', 'attachment; filename=' + filename);
        res.writeHead(200, {'Content-Type': 'application/octet-stream'});

        var fileStream = fs.createReadStream(path);
        fileStream.on('data', function(chunk) {
            res.write(chunk);
        });
        fileStream.on('end', function() {
            res.end();
        });
    } else {
        res.send("Error", 404, {"Content-Type": "application/octet-stream"});
    }
}

function respondWithFile(path, res) {
    if (path != null) {
        try {

            var mimetype = mime.lookup(path);
            var stat = fs.statSync(path);

            res.setHeader('Content-length', stat.size);
            res.writeHead(200, {'Content-Type': mimetype});

            var fileStream = fs.createReadStream(path);
            fileStream.on('data', function(chunk) {
                res.write(chunk);
            });
            fileStream.on('end', function() {
                res.end();
            });
            console.log("Sending: " + path + ", Mimetype: " + mimetype + ",  Size:" + stat.size);
        }
        catch (err)
        {
            console.log("Error: " + err.message);
            res.send("Error: File Not Found", 404, {"Content-Type": "text/plain"});
        }

    } else {
        res.send("Error", 404, {"Content-Type": "text/plain"});
    }
}

function getPath(json_string) {
    var response = JSON.parse(json_string);
    if (response['errcode'] == 0) {
        return response['response'];
    } else {
        console.log("Error: finding file" )
        return null
    }

}

function getConfig() {
    exec(razor_bin + " config read", function (err, stdout, stderr) {
        //console.log(stdout);
        startServer(stdout);
    });
}

function getArguments(args_array) {
    var arg_string = " ";
    for (x = 0; x < args.length; x++) {
        arg_string = arg_string + args[x] + " "
    }
    return arg_string;
}

// TODO Add catch for if project_razor.js is already running on port
// Start our server if we can get a valid config
function startServer(json_config) {
    var config = JSON.parse(json_config);
    if (config['@image_svc_port'] != null) {
        image_svc_path = config['@image_svc_path'];
        app.listen(config['@image_svc_port']);
        console.log("");
        console.log('ProjectRazor Image Service Web Server started and listening on:%s', app.address().port);
        console.log("Image root path: " + image_svc_path);
    } else {
        console.log("There is a problem with your ProjectRazor configuration. Cannot load config.");
    }
}


mime.define({
    'text/plain': ['gpg']
});

getConfig();
