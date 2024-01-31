const MYAPP_MAXIMUM_HIGHLIGHT_COUNT = 500;
const MYAPP_SCROLL_OFFSET_Y = 40;
const MYAPP_SCROLL_DURATION = 100;

const MYAPP_HIGHLIGHT_CLASS_NAME = '__lunascape__find-highlight';
const MYAPP_HIGHLIGHT_CLASS_NAME_ACTIVE = '__lunascape__find-highlight-active';

const MYAPP_HIGHLIGHT_COLOR = '#ffde49';
const MYAPP_HIGHLIGHT_COLOR_ACTIVE = '#f19750';

// IMPORTANT!!!: If this CSS is ever changed, the sha256-base64
// hash in Client/Frontend/Reader/ReaderModeHandlers.swift will
// also need updated. The value of `ReaderModeStyleHash` in that
// file represents the sha256-base64 hash of the `HIGHLIGHT_CSS`.
const MYAPP_HIGHLIGHT_CSS = `.${MYAPP_HIGHLIGHT_CLASS_NAME} {
    color: #000;
    background-color: ${MYAPP_HIGHLIGHT_COLOR};
    border-radius: 1px;
    box-shadow: 0 0 0 2px ${MYAPP_HIGHLIGHT_COLOR};
    transition: all ${MYAPP_SCROLL_DURATION}ms ease ${MYAPP_SCROLL_DURATION}ms;
  }
  .${MYAPP_HIGHLIGHT_CLASS_NAME}.${MYAPP_HIGHLIGHT_CLASS_NAME_ACTIVE} {
    background-color: ${MYAPP_HIGHLIGHT_COLOR_ACTIVE};
    box-shadow: 0 0 0 4px ${MYAPP_HIGHLIGHT_COLOR_ACTIVE},0 1px 3px 3px rgba(0,0,0,.75);
  }`;

var myAppLastEscapedQuery = '';
var myAppLastFindOperation = null;
var myAppLastReplacements = null;
var myAppLastHighlights = null;
var myAppActiveHighlightIndex = -1;

var myAppHighlightSpan = document.createElement('span');
myAppHighlightSpan.className = MYAPP_HIGHLIGHT_CLASS_NAME;

var myAppStyleElement = document.createElement('style');
myAppStyleElement.innerHTML = MYAPP_HIGHLIGHT_CSS;

function myAppSearchKeywordInThePage(query) {
  let trimmedQuery = query.trim();

  // If the trimmed query is empty, use it instead of the escaped
  // query to prevent searching for nothing but whitepsace.
  let escapedQuery = !trimmedQuery
    ? trimmedQuery
    : query.replace(/([.?*+^$[\]\\(){}|-])/g, '\\$1');
  if (escapedQuery === myAppLastEscapedQuery) {
    return;
  }

  if (myAppLastFindOperation) {
    myAppLastFindOperation.cancel();
  }

  myAppClear();

  myAppLastEscapedQuery = escapedQuery;

  if (!escapedQuery) {
    window.ReactNativeWebView.postMessage(`{"type": "findInPage", "data": {"currentResult": 0, "totalResults": 0}}`);
    return;
  }

  let queryRegExp = new RegExp('(' + escapedQuery + ')', 'gi');

  myAppLastFindOperation = myAppGetMatchingNodeReplacements(
    queryRegExp,
    function (replacements, highlights) {
      let replacement;
      for (let i = 0, length = replacements.length; i < length; i++) {
        replacement = replacements[i];

        replacement.originalNode.replaceWith(replacement.replacementFragment);
      }

      myAppLastFindOperation = null;
      myAppLastReplacements = replacements;
      myAppLastHighlights = highlights;
      myAppActiveHighlightIndex = -1;

      let totalResults = highlights.length;
      window.ReactNativeWebView.postMessage(`{"type": "findInPage", "data": {"totalResults": ${totalResults}}}`);
      myAppSearchNextInThePage();
    },
  );
}

function myAppSearchNextInThePage() {
  if (myAppLastHighlights) {
    myAppActiveHighlightIndex =
      (myAppActiveHighlightIndex + myAppLastHighlights.length + 1) %
      myAppLastHighlights.length;
    myAppUpdateActiveHighlight();
  }
}

function myAppSearchPreviousInThePage() {
  if (myAppLastHighlights) {
    myAppActiveHighlightIndex =
      (myAppActiveHighlightIndex + myAppLastHighlights.length - 1) %
      myAppLastHighlights.length;
    myAppUpdateActiveHighlight();
  }
}

function myAppSearchDoneInThePage() {
  myAppStyleElement.remove();
  myAppClear();
  myAppLastEscapedQuery = '';
}

function myAppClear() {
  if (!myAppLastHighlights) {
    return;
  }

  let replacements = myAppLastReplacements;
  let highlights = myAppLastHighlights;

  let highlight;
  for (let i = 0, length = highlights.length; i < length; i++) {
    highlight = highlights[i];

    myAppRemoveHighlight(highlight);
  }

  myAppLastReplacements = null;
  myAppLastHighlights = null;
  myAppActiveHighlightIndex = -1;
}

function myAppUpdateActiveHighlight() {
  if (!myAppStyleElement.parentNode) {
    document.body.appendChild(myAppStyleElement);
  }

  let lastActiveHighlight = document.querySelector(
    '.' + MYAPP_HIGHLIGHT_CLASS_NAME_ACTIVE,
  );
  if (lastActiveHighlight) {
    lastActiveHighlight.className = MYAPP_HIGHLIGHT_CLASS_NAME;
  }

  if (!myAppLastHighlights) {
    return;
  }

  let activeHighlight = myAppLastHighlights[myAppActiveHighlightIndex];
  if (activeHighlight) {
    activeHighlight.className =
      MYAPP_HIGHLIGHT_CLASS_NAME + ' ' + MYAPP_HIGHLIGHT_CLASS_NAME_ACTIVE;
    myAppScrollToElement(activeHighlight, MYAPP_SCROLL_DURATION);
    window.ReactNativeWebView.postMessage(`{"type": "findInPage", "data": {"currentResult": ${myAppActiveHighlightIndex + 1}}}`);
  } else {
    window.ReactNativeWebView.postMessage(`{"type": "findInPage", "data": {"currentResult": 0}}`);
  }
}

function myAppRemoveHighlight(highlight) {
  let parent = highlight.parentNode;
  if (parent) {
    while (highlight.firstChild) {
      parent.insertBefore(highlight.firstChild, highlight);
    }

    highlight.remove();
    parent.normalize();
  }
}

function myAppaAyncTextNodeWalker(iterator) {
  let operation = new MyAppOperation();
  let walker = document.createTreeWalker(
    document.body,
    NodeFilter.SHOW_TEXT,
    null,
    false,
  );

  let timeout = setTimeout(function () {
    myAppChunkedLoop(
      function () {
        return walker.nextNode();
      },
      function (node) {
        if (operation.cancelled) {
          return false;
        }

        iterator(node);
        return true;
      },
      100,
    ).then(function () {
      operation.complete();
    });
  }, 50);

  operation.oncancelled = function () {
    clearTimeout(timeout);
  };

  return operation;
}

function myAppGetMatchingNodeReplacements(regExp, callback) {
  let replacements = [];
  let highlights = [];
  let isMaximumHighlightCount = false;

  let operation = myAppaAyncTextNodeWalker(function (originalNode) {
    if (!myAppIsTextNodeVisible(originalNode)) {
      return;
    }

    let originalTextContent = originalNode.textContent;
    let lastIndex = 0;
    let replacementFragment = document.createDocumentFragment();
    let hasReplacement = false;
    let match;

    while ((match = regExp.exec(originalTextContent))) {
      let matchTextContent = match[0];

      // Add any text before this match.
      if (match.index > 0) {
        let leadingSubstring = originalTextContent.substring(
          lastIndex,
          match.index,
        );
        replacementFragment.appendChild(
          document.createTextNode(leadingSubstring),
        );
      }

      // Add element for this match.
      let element = myAppHighlightSpan.cloneNode(false);
      element.textContent = matchTextContent;
      replacementFragment.appendChild(element);
      highlights.push(element);

      lastIndex = regExp.lastIndex;
      hasReplacement = true;

      if (highlights.length > MYAPP_MAXIMUM_HIGHLIGHT_COUNT) {
        isMaximumHighlightCount = true;
        break;
      }
    }

    if (hasReplacement) {
      // Add any text after the matches.
      if (lastIndex < originalTextContent.length) {
        let trailingSubstring = originalTextContent.substring(
          lastIndex,
          originalTextContent.length,
        );
        replacementFragment.appendChild(
          document.createTextNode(trailingSubstring),
        );
      }

      replacements.push({
        originalNode: originalNode,
        replacementFragment: replacementFragment,
      });
    }

    if (isMaximumHighlightCount) {
      operation.cancel();
      callback(replacements, highlights);
    }
  });

  // Callback for if/when the text node loop completes (should
  // happen unless the maximum highlight count is reached).
  operation.oncompleted = function () {
    callback(replacements, highlights);
  };

  return operation;
}

function myAppChunkedLoop(condition, iterator, chunkSize) {
  return new Promise(function (resolve, reject) {
    setTimeout(doChunk, 0);

    function doChunk() {
      let argument;
      for (let i = 0; i < chunkSize; i++) {
        argument = condition();
        if (!argument || iterator(argument) === false) {
          resolve();
          return;
        }
      }

      setTimeout(doChunk, 0);
    }
  });
}

function myAppScrollToElement(element, duration) {
  let rect = element.getBoundingClientRect();

  let targetX = myAppClamp(
    rect.left + window.scrollX - window.innerWidth / 2,
    0,
    document.body.scrollWidth,
  );
  let targetY = myAppClamp(
    MYAPP_SCROLL_OFFSET_Y + rect.top + window.scrollY - window.innerHeight / 2,
    0,
    document.body.scrollHeight,
  );

  let startX = window.scrollX;
  let startY = window.scrollY;

  let deltaX = targetX - startX;
  let deltaY = targetY - startY;

  let startTimestamp;

  function step(timestamp) {
    if (!startTimestamp) {
      startTimestamp = timestamp;
    }

    let time = timestamp - startTimestamp;
    let percent = Math.min(time / duration, 1);

    let x = startX + deltaX * percent;
    let y = startY + deltaY * percent;

    window.scrollTo(x, y);

    if (time < duration) {
      requestAnimationFrame(step);
    }
  }

  requestAnimationFrame(step);
}

function myAppIsTextNodeVisible(textNode) {
  let element = textNode.parentElement;
  return !!(
    element.offsetWidth ||
    element.offsetHeight ||
    element.getClientRects().length
  );
}

function myAppClamp(value, min, max) {
  return Math.max(min, Math.min(value, max));
}

function MyAppOperation() {
  this.cancelled = false;
  this.completed = false;
}

MyAppOperation.prototype.constructor = MyAppOperation;

MyAppOperation.prototype.cancel = function () {
  this.cancelled = true;
  if (typeof this.oncancelled === 'function') {
    this.oncancelled();
  }
};

MyAppOperation.prototype.complete = function () {
  this.completed = true;
  if (typeof this.oncompleted === 'function') {
    if (!this.cancelled) {
      this.oncompleted();
    }
  }
};

function MyApp_HighlightAllOccurencesOfString(keyword) {
  myAppSearchDoneInThePage();
  myAppSearchKeywordInThePage(keyword);
}

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
