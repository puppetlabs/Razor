exports.getRange = function getRange(range_header, size) {
    // This handles range requests per (http://tools.ietf.org/html/draft-ietf-http-range-retrieval-00)
    // Note at this point does not handle multiple range requests. Will add if we discover a distro installer requires this.
    var range_array = range_header.replace("bytes=","").split("-");
    if (range_array.length < 2) {
        console.log('HTTP Range: Invalid range request. Missing "-".');
        console.log("HTTP Range: Returning entire file.");
        return [0, size - 1];
    }
    start_offset = parseInt(range_array[0]);
    end_offset = parseInt(range_array[1]);

    // Check for empty range
    if (isNaN(start_offset) && isNaN(end_offset)) {
        console.log('HTTP Range: No range defined');
        console.log("HTTP Range: Returning entire file.");
        return [0, size - 1];
    }

    // Check for missing start
    if  (isNaN(start_offset)) {
        if (end_offset >= (size - 1)) {
            console.log('HTTP Range: Only range end given. But end is greater or equal to file size.');
            console.log('HTTP Range: Returning entire file.');
            return [0, size - 1];
        } else {
            console.log('HTTP Range: Only range end given.');
            console.log('HTTP Range: Returning ' + end_offset + ' last bytes of file.');
            return [size - end_offset, size - 1];
        }
    }

    // Check for missing end
    if  (isNaN(end_offset)) {
        if (start_offset >= size) {
            console.log('HTTP Range: Range requested start greater or equal to size.');
            console.log("HTTP Range: Returning entire file.");
            return [0, size - 1];
        } else {
            console.log('HTTP Range: Only range start given.');
            console.log('HTTP Range: Returning from ' + start_offset + ' bytes to end of  file.');
            return [start_offset, size - 1];
        }
    }

    // Check if start_offset is greater than end
    if (start_offset > end_offset) {
        console.log('HTTP Range: Range requested start greater than end requested.');
        console.log("HTTP Range: Returning entire file.");
        return [0, size - 1];
    }

    // Check if start_offset is greater than size
    if (start_offset > size) {
        console.log('HTTP Range: Range requested start greater than size.');
        console.log("HTTP Range: Returning entire file.");
        return [0, size - 1];
    }

    // Check if range is greater than file size.
    if ((end_offset - start_offset + 1) > size ) {
        console.log('HTTP Range: Range requested longer than size.');
        console.log("HTTP Range: Returning to end of file.");
        return [start_offset, size - 1];
    }
    return [start_offset, end_offset];
}