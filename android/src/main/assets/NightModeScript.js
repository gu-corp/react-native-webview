Object.defineProperty(window, "NightMode", {
  enumerable: false,
  configurable: false,
  writable: false,
  value: { enabled: false }
});

const NIGHT_MODE_INVERT_FILTER_CSS = 'brightness(80%) invert(100%) hue-rotate(180deg)';

const NIGHT_MODE_STYLESHEET =
`html {
  -webkit-filter: hue-rotate(180deg) invert(100%) !important;
}
iframe,img,video {
  -webkit-filter: ${NIGHT_MODE_INVERT_FILTER_CSS} !important;
}

div.video-overlay, header.site-header {
  -webkit-filter: ${NIGHT_MODE_INVERT_FILTER_CSS} !important;
}

header.site-header img {
  -webkit-filter: none !important;
}`;

// ^ Two site specific hacks for Brave.com site included in the stylesheet
// One fixes the image preview of embedded video
// second keeps the navbar header color instact as well as the brand image.
// This specific rules should be removed once we upgrade to a more robust night mode stylesheets.

var styleElement;

function getStyleElement() {
  if (styleElement) {
    return styleElement;
  }

  styleElement = document.createElement("style");
  styleElement.type = "text/css";
  styleElement.appendChild(document.createTextNode(NIGHT_MODE_STYLESHEET));

  return styleElement;
}

function applyInvertFilterToChildBackgroundImageElements(parentNode) {
  [...parentNode.children].forEach(function(el) {
    if ((getComputedStyle(el)["background-image"] || "").startsWith("url")) {
      applyInvertFilterToElement(el);
    }
  });
}

function applyInvertFilterToElement(el) {
  invertedBackgroundImageElements.push(el);
  el.__firefox__NightMode_originalFilter = el.style.webkitFilter;
  el.style.webkitFilter = NIGHT_MODE_INVERT_FILTER_CSS;
}

function removeInvertFilterFromElement(el) {
  el.style.webkitFilter = el.__firefox__NightMode_originalFilter;
  delete el.__firefox__NightMode_originalFilter;
}

var invertedBackgroundImageElements = null;

// Create a `MutationObserver` that checks for new elements
// added that have a `background-image` in their `style`
// property/attribute.
var observer = new MutationObserver(function(mutations) {
  mutations.forEach(function(mutation) {
    mutation.addedNodes.forEach(function(node) {
      if (node.nodeType === Node.ELEMENT_NODE) {
        applyInvertFilterToChildBackgroundImageElements(node);
      }
    });
  });
});

Object.defineProperty(window.NightMode, "setEnabled", {
  enumerable: false,
  configurable: false,
  writable: false,
  value: function(enabled) {
    if (enabled === window.NightMode.enabled) {
      return;
    }

    window.NightMode.enabled = enabled;

    var styleElement = getStyleElement();

    if (enabled) {
      invertedBackgroundImageElements = [];

      // Apply the NightMode CSS to the document.
      document.documentElement.appendChild(styleElement);

      // Add the "invert" CSS class name to all elements with a
      // `background-image` in their `style` property/attribute.
      applyInvertFilterToChildBackgroundImageElements(document);

      // Observe for future elements in the document containing
      // `background-image` in their `style` property/attribute
      // so that we can also apply the "invert" CSS class name
      // to them as they are added.
      observer.observe(document.documentElement, {
        childList: true,
        subtree: true
      });
      return;
    }

    // Stop observing for future elements in the document.
    observer.disconnect();

    // Remove the "invert" CSS class name from all elements
    // it was previously applied to.
    invertedBackgroundImageElements.forEach(removeInvertFilterFromElement);

    // Remove the NightMode CSS from the document.
    var styleElementParentNode = styleElement.parentNode;
    if (styleElementParentNode) {
      styleElementParentNode.removeChild(styleElement);
    }

    invertedBackgroundImageElements = null;

    // Workaround for Bug 1424243 where turning Night Mode *off*
    // in some cases has no effect on the background color for
    // web pages that do not specify a background color.
    var computedBackgroundColor = getComputedStyle(document.documentElement)["background-color"];
    if (computedBackgroundColor === "rgba(0, 0, 0, 0)") {
      document.documentElement.style.backgroundColor = "#fff";
    }
  }
});
