// Node.js Endpoint for ProjectRazor Image Service

var razor_bin = __dirname + "/razor"; // Set project_razor.rb path
var execFile = require("child_process").execFile; // create our execFile object
var express = require('express'); // include our express libs
var mime = require('mime');
var fs = require('fs');
var path = require('path');
var http_range_req = require('./http_range_req.js');
var common = require('./common.js');
var InvalidURIPathError = common.InvalidURIPathError;
var urlDecode = common.urlDecode;
var returnError = common.returnError;
var image_svc_path;

var io_id = 0;
var pool = require('generic-pool').Pool({
    name: 'io',
    create: function(callback) {
        var id = io_id++;
        console.info('Created IO resource: ' + id);
        callback(null, id);
    },
    destroy: function(id) {
        console.info('Destroyed IO resource: ' + id);
    },
    max: 5,
    min: 1,
    refreshIdle: false
});

app = express.createServer(); // our express server

app.get('/razor/image/*', function(req, res) {
    try {
        var args = req.path.split('/');
        args.splice(0, 3);
        if (args.length > 0) {
            if (args[args.length - 1] == '')
                // Path ended with slash. Just skip this one
                args.pop();
            for ( var i = 0; i < args.length; ++i)
                args[i] = urlDecode(args[i]);
        }
        var absPath = path.resolve(image_svc_path + args.join('/'));
        if(absPath.indexOf(image_svc_path) != 0)
        	throw new InvalidURIPathError("Illegal path: '" + path + "'");

        console.log("Image requested: '" + absPath + "'");
        respondWithFile(absPath, res, req);
    } catch (e) {
        returnError(res, e);
    }
});

function respondWithFile(path, res, req) {
    if (path != null) {
        try {
            var start_offset;
            var end_offset;
            var mimetype = mime.lookup(path);
            var stat = fs.statSync(path);

            if (req.headers['range'] != undefined) {
                var offsets = http_range_req.getRange(req.headers['range'], stat.size);
                start_offset = offsets[0];
                end_offset = offsets[1];
            } else {
                start_offset = 0;
                end_offset = stat.size - 1;
            }
            pool.acquire(function(err, id) {
                if (err) {
                    console.error(err);
                }
                else {
                    console.info('Acquired IO resource: ' + id);
                    var fileStream = fs.createReadStream(path, {start: start_offset, end: end_offset});
                    res.setHeader('Content-length', (end_offset - start_offset + 1));
                    res.writeHead(200, {'Content-Type': mimetype});

                    fileStream.on('data', function(chunk) {
                        process.stdout.write(".");
                        res.write(chunk);
                    });
                    fileStream.on('end', function() {
                        process.stdout.write("!\n");
                        res.end();
                        console.info('Released IO resource: ' + id);
                        pool.release(id);
                    });
                    console.log("\tSending: " + path);
                    console.log("\tMimetype: " + mimetype);
                    console.log("\tSize: " + stat.size);
                    console.log("\tStart: " + start_offset + " / End: " + end_offset);
                }
            });
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

function getConfig() {
    execFile(razor_bin, [ '-j', 'config', 'read' ], function(err, stdout, stderr) {
        //console.log(stdout);
        startServer(stdout);
    });
}

function getRange() {
    // This handles range requests per (http://tools.ietf.org/html/draft-ietf-http-range-retrieval-00)


}

// TODO Add catch for if project_razor.js is already running on port
// Start our server if we can get a valid config
function startServer(json_config) {
    var config = JSON.parse(json_config);
    if (config['@image_svc_port'] != null) {
        image_svc_path = path.resolve(config['@image_svc_path']) + '/';
        app.listen(config['@image_svc_port']);
        console.log("");
        console.log('ProjectRazor Image Service Web Server started and listening on:%s', config['@image_svc_port']);
        console.log("Image root path: " + image_svc_path);
    } else {
        console.log("There is a problem with your ProjectRazor configuration. Cannot load config.");
    }
}


mime.define({
    'text/plain': ['gpg']
});

getConfig();
