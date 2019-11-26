var MyApp_SearchResultCount = 0;

function MyApp_HighlightAllOccurencesOfStringForElement(element, keyword, color, doc) {
  /* Using try catch block to avoid error when trying to access contentDocument */
  try {
    if (element) {
      if (element.nodeType == 3) {
        while (true) {
          var value = element.nodeValue;
          var idx = value.toLowerCase().indexOf(keyword);

          if (idx < 0) break;

          var span = doc.createElement("span");
          var text = doc.createTextNode(value.substr(idx, keyword.length));
          span.appendChild(text);
          span.setAttribute("class", "MyAppHighlight");
          span.setAttribute("name", "MyAppHighlight");
          span.style.backgroundColor = color;
          span.style.color = "black";
          text = doc.createTextNode(value.substr(idx + keyword.length));
          element.deleteData(idx, value.length - idx);
          var next = element.nextSibling;
          element.parentNode.insertBefore(span, next);
          element.parentNode.insertBefore(text, next);
          element = text;
          MyApp_SearchResultCount++;
        }
      } else if ((element.nodeType == 1) && (element.tagName.toLowerCase() == "iframe") && (element.contentDocument != null)) {
        if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select' && element.nodeName.toLowerCase() != 'script') {
          MyApp_HighlightAllOccurencesOfStringForElement(element.contentDocument.body, keyword, color, element.contentDocument);
        }
      } else if (element.nodeType == 1) {
        if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select' && element.nodeName.toLowerCase() != 'script') {
          for (var i = element.childNodes.length - 1; i >= 0; i--) {
            MyApp_HighlightAllOccurencesOfStringForElement(element.childNodes[i], keyword, color, doc);
          }
        }
      }
    }
  } catch (err) {
  }
}

function MyApp_HighlightAllOccurencesOfString(keyword, color) {
  MyApp_HighlightAllOccurencesOfStringForElement(document.body, keyword.toLowerCase(), color, document);
}

function MyApp_ScrollToHighlightTop() {
  var offset = cumulativeOffsetTop(document.getElementsByName("MyAppHighlight")[0]);
  window.scrollTo(0, offset);
}

function MyApp_RemoveAllHighlightsForElement(element) {
  /* Using try catch block to avoid error when trying to access contentDocument */
  try {
    if (element) {
      if ((element.nodeType == 1) && (element.tagName.toLowerCase() == "iframe") && (element.contentDocument != null)) {
        MyApp_RemoveAllHighlightsForElement(element.contentDocument.body);
      } else if (element.nodeType == 1) {
        if (element.getAttribute("class") == "MyAppHighlight") {
          var text = element.removeChild(element.firstChild);
          element.parentNode.insertBefore(text, element);
          element.parentNode.removeChild(element);
          return true;
        } else {
          var normalize = false;
          for (var i = element.childNodes.length - 1; i >= 0; i--) {
            if (MyApp_RemoveAllHighlightsForElement(element.childNodes[i])) {
              normalize = true;
            }
          }
          if (normalize) {
            element.normalize();
          }
        }
      }
    }
  } catch (err) {
    return false;
  }
  return false;
}

function MyApp_RemoveAllHighlights() {
  MyApp_SearchResultCount = 0;
  MyApp_RemoveAllHighlightsForElement(document.body);
}

function cumulativeOffsetTop(element) {
  var valueT = 0;
  do {
    valueT += element.offsetTop || 0;
    element = element.offsetParent;
  } while (element);
  return valueT;
}
