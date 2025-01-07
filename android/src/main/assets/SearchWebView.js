function getFavicons() {
  var favicons = [];
  delete favicons.toJSON; // Never inherit Array.prototype.toJSON.
  var links = document.getElementsByTagName('link');
  var linkCount = links.length;
  for (var i = 0; i < linkCount; ++i) {
    if (links[i].rel) {
      var rel = links[i].rel.toLowerCase();
      if (rel == 'alternate icon' || rel == 'shortcut icon' || rel == 'icon') {
        var favicon = { rel: links[i].rel.toLowerCase(), href: links[i].href };
        if (links[i].sizes && links[i].sizes.value) {
          favicon.sizes = links[i].sizes.value;
        } else {
          favicon.sizes = '';
        }
        favicons.push(favicon);
      } else if (rel && links[i].href && rel.startsWith('shortcut')) {
        var href = links[i].href;
        if (
          href.endsWith('.ico') ||
          href.endsWith('.png') ||
          href.endsWith('.jpg') ||
          href.endsWith('.jpeg') ||
          href.endsWith('.bmp') ||
          href.endsWith('.webp') ||
          href.endsWith('.svg')
        ) {
          var favicon = {
            rel: links[i].rel.toLowerCase(),
            href: links[i].href,
          };
          if (links[i].sizes && links[i].sizes.value) {
            favicon.sizes = links[i].sizes.value;
          } else {
            favicon.sizes = '';
          }
          favicons.push(favicon);
        }
      }
    }
  }

  var sortFavicons = favicons
    .filter((item) => item.sizes !== '')
    .sort((a, b) => {
      let sizeA = parseInt(a.sizes, 10) || 0;
      let sizeB = parseInt(b.sizes, 10) || 0;
      return sizeB - sizeA;
    });

  var favi = '';

  if (sortFavicons.length > 0) {
    favi = sortFavicons[0].href;
  } else if (favicons.length > 0) {
    favi = favicons[0].href;
  }
  window.FaviconWebView.postFavicon(`${favi}`);
}

function getBase64StringFromBlobUrl(blobUrl) {
  const fileReaderInstance = new FileReader();
  const xhr = new XMLHttpRequest();
  xhr.open('GET', blobUrl, true);
  xhr.setRequestHeader('Content-type', 'application/octet-stream');
  xhr.responseType = 'blob';
  xhr.onload = () => {
    if (xhr.status === 200) {
      const blobResponse = xhr.response;
      const blobType = blobResponse.type;
      const blobSize = blobResponse.size;

      let blobArray = [];
      const stepSize = 10000000;
      const loopSize = Math.floor(blobSize / stepSize);

      for (let i = 0; i <= loopSize; i++) {
        const start = i * stepSize;
        const next = (i + 1) * stepSize;
        const end = next > blobSize ? blobSize : next;
        const tempBlob = blobResponse.slice(start, end, blobType);
        blobArray.push(tempBlob);
      }

      convertBlobToBase64(blobArray, fileReaderInstance);
    }
  };
  xhr.send();
}

function convertBlobToBase64(blobArray, fileReaderInstance) {
  if (blobArray.length > 0) {
    const blob = blobArray.shift();
    fileReaderInstance.onloadend = () => {
      nativeScriptHandler.sendPartialBase64Data(fileReaderInstance.result);
      convertBlobToBase64(blobArray, fileReaderInstance);
    };
    fileReaderInstance.readAsDataURL(blob);
  } else {
    nativeScriptHandler.notifyConvertBlobToBase64Completed();
  }
}
