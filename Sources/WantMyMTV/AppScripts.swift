/// JavaScript the app adds to every page.
enum AppScripts {
    /// The name the page uses to tell the app about playback: `{playing: true|false}`.
    static let mediaHandler = "mtvMedia"

    /// Runs in the page and in embedded players (all frames), at document start.
    ///
    /// - App feel: no text selection (except in text fields), no long-press menus,
    ///   no grey flash on tap.
    /// - Tells the app when a video starts or stops, so the screen stays on while
    ///   one plays.
    /// - Lock screen / Control Center: if the site doesn't name what's playing,
    ///   names it I Want My MTV (with the video's title when it has one).
    /// - `window.__mtvPiP(true)` puts the playing video in Picture in Picture,
    ///   `window.__mtvPiP(false)` brings it back. The app calls these when you
    ///   leave and come back.
    static let page = #"""
        (function () {
          if (window.__mtvLoaded) return;
          window.__mtvLoaded = true;

          var css =
            '*{-webkit-touch-callout:none;-webkit-user-select:none;user-select:none;' +
            '-webkit-tap-highlight-color:transparent}' +
            'input,textarea,[contenteditable],[contenteditable] *{' +
            '-webkit-user-select:text;user-select:text;-webkit-touch-callout:default}';
          function addStyle() {
            var style = document.createElement('style');
            style.setAttribute('data-mtv', '');
            style.textContent = css;
            (document.head || document.documentElement).appendChild(style);
          }
          if (document.documentElement) addStyle();
          else document.addEventListener('DOMContentLoaded', addStyle);

          function post(message) {
            try { window.webkit.messageHandlers.mtvMedia.postMessage(message); } catch (e) {}
          }
          function media() {
            return Array.prototype.slice.call(document.querySelectorAll('video, audio'));
          }
          function playingVideo() {
            var list = media();
            for (var i = 0; i < list.length; i++) {
              var m = list[i];
              if (!m.paused && !m.ended) return m;
            }
            return null;
          }

          var ourMetadata = null;
          function nameIt(m) {
            var session = navigator.mediaSession;
            if (!session || typeof MediaMetadata === 'undefined') return;
            // The site named it itself: leave it alone.
            if (session.metadata && session.metadata !== ourMetadata) return;
            var title = (m.getAttribute('title') || m.getAttribute('aria-label') || '').trim();
            // Inside the YouTube player the page title is the video's ("Artist - Song - YouTube").
            if (!title && window.top !== window) {
              title = (document.title || '').replace(/\s*-\s*YouTube\s*$/, '').trim();
            }
            title = title || 'I Want My MTV';
            if (ourMetadata && ourMetadata.title === title) return;
            ourMetadata = new MediaMetadata({
              title: title,
              artist: 'I Want My MTV',
              album: 'Music videos, 24/7'
            });
            session.metadata = ourMetadata;
          }

          var last = null;
          function report() {
            var m = playingVideo();
            var playing = !!m;
            if (playing !== last) {
              last = playing;
              post({ playing: playing });
            }
            if (m) nameIt(m);
          }
          // Media events don't bubble, so listen in the capture phase.
          ['playing', 'play', 'pause', 'ended', 'emptied'].forEach(function (type) {
            document.addEventListener(type, function () { setTimeout(report, 0); }, true);
          });

          window.__mtvPiP = function (enter) {
            if (enter) {
              var m = playingVideo();
              if (!m || m.tagName !== 'VIDEO' || m.disablePictureInPicture) return false;
              if (!m.webkitSupportsPresentationMode || !m.webkitSupportsPresentationMode('picture-in-picture')) return false;
              if (m.webkitPresentationMode !== 'inline') return false;
              m.webkitSetPresentationMode('picture-in-picture');
              return true;
            }
            media().forEach(function (m) {
              if (m.webkitPresentationMode === 'picture-in-picture') m.webkitSetPresentationMode('inline');
            });
            return true;
          };
        })();
        """#

    /// Main page only, at document start: no pinch zoom, like an app.
    static let noZoom = #"""
        (function () {
          var WANT = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
          function patch(meta) {
            if (meta.getAttribute('content') !== WANT) meta.setAttribute('content', WANT);
          }
          function isViewport(node) {
            return node.nodeName === 'META' && (node.getAttribute('name') || '').toLowerCase() === 'viewport';
          }
          new MutationObserver(function (mutations) {
            mutations.forEach(function (m) {
              if (m.type === 'attributes') { if (isViewport(m.target)) patch(m.target); return; }
              m.addedNodes.forEach(function (node) {
                if (isViewport(node)) patch(node);
                else if (node.querySelectorAll) node.querySelectorAll('meta[name="viewport"]').forEach(patch);
              });
            });
          }).observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ['content'] });
          document.addEventListener('DOMContentLoaded', function () {
            var metas = document.querySelectorAll('meta[name="viewport"]');
            if (metas.length) { metas.forEach(patch); return; }
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = WANT;
            (document.head || document.documentElement).appendChild(meta);
          });
        })();
        """#
}
