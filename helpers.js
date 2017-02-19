var util      = require('util');

function postHeaders(cookie) {
  return {
    "Host": "photos.google.com",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; rv:44.0) Gecko/20100101 Firefox/44.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Accept-Encoding": "gzip, deflate, br",
    "DNT": "1",
    "Referer": "https://photos.google.com",
    "Cookie": (cookie).toString(),
    "Connection": "keep-alive"
  }
}

var postHeadersInit = function(cookie) {
  return util._extend(postHeaders(cookie), {
    "X-GUploader-Client-Info": 'mechanism=scotty xhr resumable; clientVersion=131213166',
    "Content-Type"           : "application/x-www-form-urlencoded;charset=utf-8"
  });
}

var postHeadersUpload = function(cookie) {
  return util._extend(postHeaders(cookie), {
    "X-HTTP-Method-Override": "PUT",
    "X-GUploader-No-308": "yes",
  });
}

var postData = function(fname, size, effectiveId) {
  return {
    "protocolVersion": "0.8",
    "createSessionRequest": {
      "fields": [
        {
          "external": {
            "name": "file",
            "filename": (fname).toString(),
            "put": {
            },
            "size": parseInt(size)
          }
        },
        {
          "inlined": {
            "name": "auto_create_album",
            "content": "camera_sync.active",
            "contentType": "text/plain"
          }
        },
        {
          "inlined": {
            "name": "auto_downsize",
            "content": "true",
            "contentType": "text/plain"
          }
        },
        {
          "inlined": {
            "name": "storage_policy",
            "content": "use_manual_setting",
            "contentType": "text/plain"
          }
        },
        {
          "inlined": {
            "name": "disable_asbe_notification",
            "content": "true",
            "contentType": "text/plain"
          }
        },
        {
          "inlined": {
            "name": "client",
            "content": "photosweb",
            "contentType": "text/plain"
          }
        },
        {
          "inlined": {
            "name": "effective_id",
            "content": (effectiveId).toString(),
            "contentType": "text/plain"
          }
        },
        {
          "inlined": {
            "name": "owner_name",
            "content": (effectiveId).toString(),
            "contentType": "text/plain"
          }
        },
        {
          "inlined": {
            "name": "timestamp_ms",
            "content": (Date.now()).toString(),
            "contentType": "text/plain"
          }
        }
      ]
    }
  }
}

module.exports = {postHeadersInit: postHeadersInit, postHeadersUpload: postHeadersUpload, postData: postData}
