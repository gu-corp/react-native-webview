// We're using a global variable to store the number of occurrences
var MyApp_SearchResultCount = 0;

// helper function, recursively searches in elements and their child nodes
function MyApp_HighlightAllOccurencesOfStringForElement(element,keyword,color,doc) {
    if (element) {
        if (element.nodeType == 3) {        // Text node
            while (true) {
                var value = element.nodeValue;  // Search for keyword in text node
                var idx = value.toLowerCase().indexOf(keyword);

                if (idx < 0) break;             // not found, abort

                var span = doc.createElement("span");
                var text = doc.createTextNode(value.substr(idx,keyword.length));
                span.appendChild(text);
                span.setAttribute("class","MyAppHighlight");
                span.setAttribute("name","MyAppHighlight");
                span.style.backgroundColor=color;
                span.style.color="black";
                text = doc.createTextNode(value.substr(idx+keyword.length));
                element.deleteData(idx, value.length - idx);
                var next = element.nextSibling;
                element.parentNode.insertBefore(span, next);
                element.parentNode.insertBefore(text, next);
                element = text;
                MyApp_SearchResultCount++;    // update the counter
            }
        } else if ((element.nodeType == 1)&&(element.tagName.toLowerCase() == "iframe")&&(element.contentDocument != null)) {
            //alert("iframe: " + element.contentDocument.body.outerHTML);
            if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select' && element.nodeName.toLowerCase() != 'script') {
                MyApp_HighlightAllOccurencesOfStringForElement(element.contentDocument.body,keyword,color,element.contentDocument);
            }
        } else if (element.nodeType == 1) { // Element node
            //if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select') {
            if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select' && element.nodeName.toLowerCase() != 'script') {
                for (var i=element.childNodes.length-1; i>=0; i--) {
                    MyApp_HighlightAllOccurencesOfStringForElement(element.childNodes[i],keyword,color,doc);
                }
            }
        }
    }
}


// the main entry point to start the search
function MyApp_HighlightAllOccurencesOfString(keyword,color) {
    MyApp_HighlightAllOccurencesOfStringForElement(document.body, keyword.toLowerCase(), color, document);
}

function MyApp_ScrollToHighlightTop() {
    // scroll
    var offset = cumulativeOffsetTop(document.getElementsByName("MyAppHighlight")[0]);
    window.scrollTo(0,offset);
}

// helper function, recursively removes the highlights in elements and their childs
function MyApp_RemoveAllHighlightsForElement(element) {
    if (element) {
        if ((element.nodeType == 1)&&(element.tagName.toLowerCase() == "iframe")&&(element.contentDocument != null)) {
            MyApp_RemoveAllHighlightsForElement(element.contentDocument.body);
        } else if (element.nodeType == 1) {
            if (element.getAttribute("class") == "MyAppHighlight") {
                var text = element.removeChild(element.firstChild);
                element.parentNode.insertBefore(text,element);
                element.parentNode.removeChild(element);
                return true;
            } else {
                var normalize = false;
                for (var i=element.childNodes.length-1; i>=0; i--) {
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
    return false;
}

// the main entry point to remove the highlights
function MyApp_RemoveAllHighlights() {
    MyApp_SearchResultCount = 0;
    MyApp_RemoveAllHighlightsForElement(document.body);
}


//参考：http://d.hatena.ne.jp/susie-t/20061004/1159942798
function cumulativeOffsetTop(element) {
    var valueT = 0;
    do {
        valueT += element.offsetTop  || 0;
        element = element.offsetParent;
    } while (element);
    return valueT;
}
