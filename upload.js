var fs        = require('fs');
var request   = require('request');
var hlp       = require("./helpers.js");

var fname                   = process.argv.slice(2)[0],
    apiUploadUrl            = "https://photos.google.com/_/upload/photos/resumable?authuser=0",
    secrets                 = JSON.parse(fs.readFileSync('conf.json', 'utf8'));

var effectiveId             = secrets.effective_id,
    cookie                  = secrets.gphoto_cookie;

function genUploadUrl(size, callback) {
  request.post({
    url: apiUploadUrl,
    headers: hlp.postHeadersInit(cookie),
    body: JSON.stringify(hlp.postData(fname, size, effectiveId))
  }, function(err, resp, body) {
    if (err || resp.statusCode !== 200) {
      callback(err || resp.statusCode, null);
      return;
    } else {
      var uploadUrl = JSON.parse(body).sessionStatus.externalFieldTransfers[0].putInfo.url;
      if (uploadUrl) {
        uploadFile(uploadUrl, function(e, s) {
          callback(e, s);
          return;
        });
      } else {
        callback('Response not containing valid upload url', null);
        return;
      }
    }
  });
}

function uploadFile(uploadUrl, callback) {
  request.post({
    url: uploadUrl,
    headers: hlp.postHeadersUpload(cookie),
    body: fs.createReadStream(fname)
  }, function(err, resp, body) {
    if (err || resp.statusCode !== 200) {
      callback(err || resp.statusCode, null);
      return;
    } else {
      var parsedResponse = JSON.parse(body);
      if (parsedResponse.errorMessage) {
        callback('Failed uploading file: ' + body, null);
        return;
      } else {
        callback(null, body);
        return;
      }
    }
  });
}

function logRes(s, m) {
  console.log(JSON.stringify({status: s, msg: m}));
}

fs.stat(fname, function(err, file) {
  if (err) {
    logRes("fatal", err);
  } else {
    genUploadUrl(file.size, function(e, s) {
      if (e) {
        logRes("error", e);
      } else {
        logRes("ok", s);
      }
    });
  }
});
