// Element hiding from the adblock-rust engine (#5580).
//
// The same file is at apple/Settings.bundle/AdblockResources/Scripts/AdblockCosmeticFilters.js.
// Keep the two copies the same.
//
// Defines window.__lunascapeAdblockCosmetic(resources, fetchGenericSelectors):
// - resources: the engine's url_cosmetic_resources for this frame
//   ({hide_selectors, procedural_actions, exceptions, generichide}).
// - fetchGenericSelectors(classes, ids, exceptions): optional. Returns the generic hide
//   selectors for the given class names and ids (a Promise or an array). Called for the
//   classes and ids on the page, and again for new ones as the page changes.
//
// Rules go into a constructed style sheet (document.adoptedStyleSheets), which a page's
// Content-Security-Policy does not restrict. Where that is not supported (iOS before 16.4),
// a <style> element is used.
(function () {
  'use strict';

  if (window.__lunascapeAdblockCosmetic) {
    return;
  }

  var HIDE = 'display: none !important;';

  function createSheet() {
    var addRule;
    try {
      var sheet = new CSSStyleSheet();
      document.adoptedStyleSheets = document.adoptedStyleSheets.concat([sheet]);
      addRule = function (rule) {
        sheet.insertRule(rule, sheet.cssRules.length);
      };
    } catch (e) {
      var style = document.createElement('style');
      var attach = function () {
        var parent = document.head || document.documentElement;
        if (!parent) {
          return false;
        }
        if (style.parentNode !== parent) {
          parent.appendChild(style);
        }
        return true;
      };
      if (!attach()) {
        new MutationObserver(function (_, observer) {
          if (attach()) {
            observer.disconnect();
          }
        }).observe(document, { childList: true, subtree: true });
      }
      addRule = function (rule) {
        if (style.sheet) {
          style.sheet.insertRule(rule, style.sheet.cssRules.length);
        } else {
          style.appendChild(document.createTextNode(rule + '\n'));
        }
      };
    }
    var added = new Set();
    return function (selector, declarations) {
      var rule = selector + ' { ' + declarations + ' }';
      if (added.has(rule)) {
        return;
      }
      added.add(rule);
      try {
        // One rule per selector: a selector the browser does not support only drops its own rule.
        addRule(rule);
      } catch (e) {}
    };
  }

  // Procedural filters that are plain CSS selectors with an action. The others
  // (:has-text(), :upward(), :xpath(), ...) need a procedural filtering engine and are skipped.
  function applyProcedural(json, addRule, removals) {
    var filter;
    try {
      filter = JSON.parse(json);
    } catch (e) {
      return;
    }
    if (!filter.selector || filter.selector.length !== 1 || filter.selector[0].type !== 'css-selector') {
      return;
    }
    var selector = filter.selector[0].arg;
    var action = filter.action;
    if (!action) {
      addRule(selector, HIDE);
    } else if (action.type === 'style') {
      addRule(selector, action.arg);
    } else if (action.type === 'remove') {
      addRule(selector, HIDE);
      removals.push(function (root) {
        forEachMatch(root, selector, function (el) {
          el.remove();
        });
      });
    } else if (action.type === 'remove-attr') {
      removals.push(function (root) {
        forEachMatch(root, selector, function (el) {
          if (el.hasAttribute(action.arg)) {
            el.removeAttribute(action.arg);
          }
        });
      });
    } else if (action.type === 'remove-class') {
      removals.push(function (root) {
        forEachMatch(root, selector, function (el) {
          if (el.classList.contains(action.arg)) {
            el.classList.remove(action.arg);
          }
        });
      });
    }
  }

  function forEachMatch(root, selector, fn) {
    try {
      if (root.matches && root.matches(selector)) {
        fn(root);
      }
      if (root.querySelectorAll) {
        Array.prototype.forEach.call(root.querySelectorAll(selector), fn);
      }
    } catch (e) {}
  }

  function watchGeneric(fetchGenericSelectors, exceptions, addRule) {
    var seenClasses = new Set();
    var seenIds = new Set();
    var newClasses = [];
    var newIds = [];
    var scheduled = false;

    function collect(el) {
      if (el.id && !seenIds.has(el.id)) {
        seenIds.add(el.id);
        newIds.push(el.id);
      }
      var classList = el.classList;
      if (classList) {
        for (var i = 0; i < classList.length; i++) {
          if (!seenClasses.has(classList[i])) {
            seenClasses.add(classList[i]);
            newClasses.push(classList[i]);
          }
        }
      }
    }

    function flush() {
      scheduled = false;
      if (newClasses.length === 0 && newIds.length === 0) {
        return;
      }
      var classes = newClasses;
      var ids = newIds;
      newClasses = [];
      newIds = [];
      Promise.resolve(fetchGenericSelectors(classes, ids, exceptions))
        .then(function (selectors) {
          (selectors || []).forEach(function (selector) {
            addRule(selector, HIDE);
          });
        })
        .catch(function () {});
    }

    function schedule() {
      if (!scheduled) {
        scheduled = true;
        setTimeout(flush, 100);
      }
    }

    function scan(root) {
      if (root.nodeType !== 1) {
        return;
      }
      collect(root);
      var all = root.querySelectorAll('[id],[class]');
      for (var i = 0; i < all.length; i++) {
        collect(all[i]);
      }
      schedule();
    }

    new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        if (m.type === 'attributes') {
          collect(m.target);
          schedule();
        } else {
          for (var j = 0; j < m.addedNodes.length; j++) {
            scan(m.addedNodes[j]);
          }
        }
      }
    }).observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ['class', 'id'] });

    if (document.documentElement) {
      scan(document.documentElement);
    }
  }

  window.__lunascapeAdblockCosmetic = function (resources, fetchGenericSelectors) {
    if (!resources) {
      return;
    }
    var addRule = createSheet();

    (resources.hide_selectors || []).forEach(function (selector) {
      addRule(selector, HIDE);
    });

    var removals = [];
    (resources.procedural_actions || []).forEach(function (json) {
      applyProcedural(json, addRule, removals);
    });
    if (removals.length > 0) {
      var run = function (root) {
        removals.forEach(function (fn) {
          fn(root);
        });
      };
      // Also on attribute and child changes: an element can start to match after it was inserted. The
      // actions only change what they match on when it is there (see applyProcedural), so their
      // own changes do not set this off again and again.
      new MutationObserver(function (mutations) {
        mutations.forEach(function (m) {
          // The changed element itself; for added or removed children, their parent too, which
          // may now match a :has() selector.
          run(m.target);
          if (m.type === 'attributes') {
            return;
          }
          Array.prototype.forEach.call(m.addedNodes, function (node) {
            if (node.nodeType === 1) {
              run(node);
            }
          });
        });
      }).observe(document, { childList: true, subtree: true, attributes: true });
      if (document.documentElement) {
        run(document.documentElement);
      }
    }

    if (fetchGenericSelectors && !resources.generichide) {
      watchGeneric(fetchGenericSelectors, resources.exceptions || [], addRule);
    }
  };
})();
